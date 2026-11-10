import Foundation
import Testing
@testable import CodexBarCore

struct ProviderPluginResultTests {
    @Test(arguments: ProviderPluginTransportTests.engines)
    func `result envelope preserves usage`(engine: ProviderPluginEngineKind) async throws {
        let runtime = try Self.runtime("{ usage: { primary: { usedPercent: 42 } }, sourceLabel: 'api' }", engine)
        let usage = try await runtime.fetchUsage()
        #expect(usage.primary?.usedPercent == 42)
    }

    @Test(arguments: ProviderPluginTransportTests.engines)
    func `unknown result fields are rejected`(engine: ProviderPluginEngineKind) async throws {
        let runtime = try Self.runtime("{ primary: { usedPercent: 42 }, persist: { OTHER_KEY: 'bad' } }", engine)
        await #expect(throws: ProviderPluginError.self) { try await runtime.fetchUsage() }
    }

    static func runtime(_ result: String, _ engine: ProviderPluginEngineKind) throws -> ProviderPluginRuntime {
        try ProviderPluginRuntime(source: """
        defineProvider({id: 'openai', name: 'Fixture', endpoints: ['https://api.openai.com'], settings: [],
          async fetchUsage(ctx) { return \(result); }});
        """, engine: engine)
    }
}

extension ProviderPluginResultTests {
    @Test(arguments: ProviderPluginTransportTests.engines, [
        "{usage:{empty:true}, sourceLabel:null}", "{usage:{empty:true}, sourceLabel:1}",
        "{usage:{empty:true}, sourceLabel:''}", "{usage:{empty:true}, sourceLabel:'x'.repeat(257)}",
        "{usage:{empty:true}, sourceLabel:'line\\nfeed'}", "{usage:{empty:true}, surprise:1}",
        "{usage:{empty:true}, persist:null}", "{usage:{empty:true}, persist:[]}",
        "{usage:{empty:true}, persist:{ACCOUNT_SLUG:3}}", "{usage:{empty:true}, persist:{ACCOUNT_SLUG:'..'}}",
        "{usage:{empty:true}, persist:{OPENAI_PROJECT_ID:'project'}}",
        "{usage:{empty:true}, persist:{FIREWORKS_API_KEY:'secret'}}",
        "{usage:{empty:true}, persist:{ACCOUNT_SLUG:'x'.repeat(257)}}",
        "{usage:{empty:true}, card:{openAIAPIUsage:{}}}", "{usage:{empty:true, typo:1}}",
    ])
    func `malformed envelope values are rejected on both engines`(
        engine: ProviderPluginEngineKind,
        value: String) async throws
    {
        let runtime = try Self.runtime(value, engine)
        await #expect(throws: ProviderPluginError.self) { try await runtime.fetchResult() }
    }

    @Test(arguments: ProviderPluginTransportTests.engines)
    func `OpenAI card adapter rejects unknown unbounded and malformed fields`(
        engine: ProviderPluginEngineKind) async throws
    {
        for card in [
            "null",
            "[]",
            "{}",
            "{unknown:1}",
            "{openAIAPIUsage:{daily:[],historyDays:1,unknown:true}}",
            "{openAIAPIUsage:{daily:[],historyDays:0}}",
            "{openAIAPIUsage:{daily:[],historyDays:366}}",
            "{openAIAPIUsage:{daily:[],historyDays:'1'}}",
            "{openAIAPIUsage:{daily:Array(367).fill({}),historyDays:1}}",
            "{openAIAPIUsage:{daily:[],historyDays:1,projectID:1}}",
        ] {
            let source = """
            defineProvider({id:'openai',name:'Fixture',endpoints:['https://api.openai.com'],settings:[],
              async fetchUsage(ctx) { return {usage:{empty:true},card:\(card)}; }});
            """
            let runtime = try ProviderPluginRuntime(source: source, engine: engine)
            await #expect(throws: ProviderPluginError.self) { try await runtime.fetchResult() }
        }
        let other = try ProviderPluginRuntime(source: """
        defineProvider({id:'openai',name:'Fixture',endpoints:['https://api.openai.com'],settings:[],
          async fetchUsage(ctx) { return {usage:{empty:true},persist:{ACCOUNT_SLUG:'fixture'}}; }});
        """, engine: engine)
        await #expect(throws: ProviderPluginError.self) { try await other.fetchResult() }
    }

    @Test
    func `CLI writes reject unapproved settings`() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CodexBarConfigStore(fileURL: directory.appendingPathComponent("config.json"))
        var config = CodexBarConfig.makeDefault()
        let openai = ProviderConfig(id: .openai)
        config.setProviderConfig(openai)
        try store.save(config)
        let writer = ProviderPluginConfigWriter()
        #expect(await writer.save(
            provider: .openai,
            values: ["UNAPPROVED": "fixture"],
            expected: openai,
            store: store) == .failed)
    }
}

extension ProviderPluginResultTests {
    @Test(arguments: ProviderPluginTransportTests.engines)
    func `hidden unknown keys and user plugin write requests are refused`(
        engine: ProviderPluginEngineKind) async throws
    {
        for value in [
            "Object.defineProperty({usage:{empty:true}}, 'unknown', {value:1})",
            "Object.defineProperty({usage:{empty:true}}, 'sourceLabel', {value:1})",
            "{usage:{empty:true}, [Symbol('usage')]:1}",
            "{usage:{details:Array(2147483648)}}",
        ] {
            let runtime = try Self.runtime(value, engine)
            await #expect(throws: ProviderPluginError.self) { try await runtime.fetchResult() }
        }
        let runtime = try ProviderPluginRuntime(source: """
        defineProvider({id:'openai',name:'Fixture',endpoints:['https://api.openai.com'],settings:[],
          async fetchUsage(ctx) { return {usage:{empty:true},persist:{ACCOUNT_SLUG:'fixture'}}; }});
        """, enforcesUserResponsePolicy: true, engine: engine)
        await #expect(throws: ProviderPluginError.self) { try await runtime.fetchResult() }
    }

    @Test
    func `cancelled CLI discovery cannot write settings`() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CodexBarConfigStore(fileURL: directory.appendingPathComponent("config.json"))
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await ProviderPluginConfigWriter.shared.save(
                provider: .openai, values: ["ACCOUNT_SLUG": "fixture"], expected: nil, store: store)
        }
        #expect(await task.value == .stale)
        #expect(!FileManager.default.fileExists(atPath: store.fileURL.path))
    }
}
