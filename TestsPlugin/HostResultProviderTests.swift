import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import CodexBarCore

struct HostResultProviderTests {
    static let now = Date(timeIntervalSince1970: 1_700_179_200)
    static let emptyPage = #"{"data":[],"has_more":false}"#

    @Test(arguments: ProviderPluginTransportTests.engines)
    func `OpenAI billing fallback retains balance and source`(engine: ProviderPluginEngineKind) async throws {
        let transport = ResultFixtureTransport([
            .init("/v1/organization/costs", "{}", 403),
            .init(
                "/v1/dashboard/billing/credit_grants",
                #"{"total_granted":100,"total_used":25,"total_available":75,"grants":{"data":[{"expires_at":1800000000},{"expires_at":1}]}}"#),
        ])
        let result = try await Self.runtime("openai", transport: transport, engine: engine).fetchResult(
            settings: ["OPENAI_ALLOW_BALANCE_FALLBACK": "1"], secrets: ["OPENAI_API_KEY": "fixture-key"], now: Self.now)
        #expect(result.sourceLabel == "billing-api" && result.usage.openAIAPIUsage == nil)
        #expect(result.usage.providerCost?.used == 25 && result.usage.primary?.usedPercent == 25)
        #expect(result.usage.identity?.loginMethod == "API balance: $75.00")
        #expect(result.usage.primary?.resetsAt == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(result.usage.details.isEmpty)
    }

    @Test(arguments: ProviderPluginTransportTests.engines)
    func `OpenAI rejects service account billing with useful guidance`(engine: ProviderPluginEngineKind) async throws {
        let transport = ResultFixtureTransport([
            .init("/v1/organization/costs", "{}", 401), .init("/v1/dashboard/billing/credit_grants", "{}", 401),
        ])
        do {
            _ = try await Self.runtime("openai", transport: transport, engine: engine).fetchResult(
                settings: ["OPENAI_ALLOW_BALANCE_FALLBACK": "1"], secrets: ["OPENAI_API_KEY": "fixture-key"])
            Issue.record("Expected authentication error")
        } catch let error as ProviderFetchClassifiedError {
            #expect(error.kind == .authenticationExpired)
            #expect(error.message.contains("service-account keys"))
        }
    }

    @Test(arguments: [true, false])
    func `OpenAI configured project preserves scoped source and fallback policy`(adminKey: Bool) async throws {
        let transport = ResultFixtureTransport([
            .init("/v1/organization/costs", Self.emptyPage), .init(
                "/v1/organization/usage/completions",
                Self.emptyPage),
        ])
        let key = adminKey ? "OPENAI_ADMIN_KEY" : "OPENAI_API_KEY"
        let context = Self.context(environment: [key: "fixture-key", "OPENAI_PROJECT_ID": "proj_fixture"])
        let result = try await OpenAIAPIProviderDescriptor.scriptStrategy(transport: transport).fetch(context)
        #expect(result.sourceLabel == "admin-api:project")
        #expect(result.usage.openAIAPIUsage?.projectID == "proj_fixture")
        #expect(result.usage.identity?.accountOrganization == "Project: proj_fixture")
        #expect(await transport.requests.allSatisfy { Self.query("project_ids", $0) == "proj_fixture" })
        let rejected = ResultFixtureTransport([
            .init("/v1/organization/costs", "{}", 403),
            .init(
                "/v1/dashboard/billing/credit_grants",
                #"{"total_granted":100,"total_used":25,"total_available":75}"#),
        ])
        do {
            let fallback = try await OpenAIAPIProviderDescriptor.scriptStrategy(transport: rejected).fetch(context)
            #expect(!adminKey && fallback.sourceLabel == "billing-api")
        } catch let error as ProviderFetchClassifiedError {
            #expect(adminKey && error.kind == .authenticationExpired)
        }
        #expect(await rejected.requests.count == (adminKey ? 1 : 2))
    }

    static func runtime(_ provider: String, transport: any ProviderHTTPTransport, engine: ProviderPluginEngineKind)
        throws -> ProviderPluginRuntime
    {
        try BundledPluginTestSupport.runtime(provider, engine: engine, transport: transport)
    }

    static func context(
        environment: [String: String],
        writer: ProviderFetchContext.SettingsWriter? = nil) -> ProviderFetchContext
    {
        let browser = BrowserDetection(cacheTTL: 0)
        return ProviderFetchContext(
            runtime: .cli,
            sourceMode: .api,
            includeCredits: false,
            webTimeout: 1,
            webDebugDumpHTML: false,
            verbose: false,
            env: environment,
            settings: nil,
            fetcher: UsageFetcher(environment: environment),
            claudeFetcher: ClaudeUsageFetcher(browserDetection: browser),
            browserDetection: browser,
            settingsWriter: writer)
    }

    static func query(_ key: String, _ request: URLRequest) -> String? {
        URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == key }?.value
    }
}

actor ResultFixtureTransport: ProviderHTTPTransport {
    struct Step: Sendable {
        let path: String
        let body: String
        let status: Int
        init(_ path: String, _ body: String, _ status: Int = 200) {
            self.path = path
            self.body = body
            self.status = status
        }
    }

    let steps: [Step]
    var requests: [URLRequest] = []
    init(_ steps: [Step]) { self.steps = steps }
    func data(for request: URLRequest) throws -> (Data, URLResponse) {
        let index = self.requests.count
        self.requests.append(request)
        guard self.steps.indices.contains(index) else { throw URLError(.badServerResponse) }
        let step = self.steps[index]
        #expect(request.url?.path == step.path)
        return (Data(step.body.utf8), HTTPURLResponse(
            url: request.url!,
            statusCode: step.status,
            httpVersion: nil,
            headerFields: nil)!)
    }
}

extension HostResultProviderTests {
    @Test(arguments: ProviderPluginTransportTests.engines)
    func `OpenAI preserves non-auth usage failures when billing also fails`(
        engine: ProviderPluginEngineKind) async throws
    {
        let transport = ResultFixtureTransport([
            .init("/v1/organization/costs", "<html>unavailable</html>", 418),
            .init("/v1/dashboard/billing/credit_grants", "<html>forbidden</html>", 403),
        ])
        do {
            _ = try await Self.runtime("openai", transport: transport, engine: engine).fetchResult(
                settings: ["OPENAI_ALLOW_BALANCE_FALLBACK": "1"], secrets: ["OPENAI_API_KEY": "fixture-key"])
            Issue.record("Expected usage failure")
        } catch let error as ProviderFetchClassifiedError {
            #expect(error.kind == .apiFailure && error.message.contains("418"))
        }
    }

    @Test(arguments: ProviderPluginTransportTests.engines)
    func `OpenAI scoped outage retries without unscoped billing`(engine: ProviderPluginEngineKind) async throws {
        let transport = ResultFixtureTransport([
            .init("/v1/organization/costs", "<html>unavailable</html>", 503),
            .init("/v1/organization/costs", "<html>unavailable</html>", 503),
        ])
        await #expect(throws: ProviderFetchClassifiedError.self) {
            try await Self.runtime("openai", transport: transport, engine: engine).fetchResult(
                settings: ["OPENAI_PROJECT_ID": "proj_fixture", "OPENAI_ALLOW_BALANCE_FALLBACK": "0"],
                secrets: ["OPENAI_API_KEY": "fixture-key"])
        }
        #expect(await transport.requests.count == 2)
    }
}

extension HostResultProviderTests {
    @Test(arguments: ProviderPluginTransportTests.engines)
    func `OpenAI queries and filters buckets using the refresh clock`(engine: ProviderPluginEngineKind) async throws {
        let future = Int(Self.now.timeIntervalSince1970) + 86400
        let body = """
        {"data":[{"start_time":\(future),"end_time":\(future + 86400),
          "results":[{"amount":{"value":1,"currency":"usd"}}]}],"has_more":false}
        """
        let transport = ResultFixtureTransport([
            .init("/v1/organization/costs", body), .init("/v1/organization/usage/completions", Self.emptyPage),
        ])
        let result = try await Self.runtime("openai", transport: transport, engine: engine).fetchResult(
            settings: ["OPENAI_HISTORY_DAYS": "1"], secrets: ["OPENAI_API_KEY": "fixture-key"], now: Self.now)
        #expect(result.usage.openAIAPIUsage?.daily.isEmpty == true)
        let requests = await transport.requests
        #expect(Self.query("start_time", requests[0]) == String(Int(Self.now.timeIntervalSince1970)))
    }
}
