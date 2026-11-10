import CodexBarCore
import Foundation
import Testing

/// Removing both quotes with mutating String operations formerly trapped on a lone quote.
struct SettingsReaderQuoteUnwrapTrapTests {
    @Test
    func `Claude admin API key rejects a lone double quote`() {
        for key in ClaudeAdminAPISettingsReader.apiKeyEnvironmentKeys {
            let env = [key: "\""]
            #expect(ClaudeAdminAPISettingsReader.apiKey(environment: env) == nil)
        }
    }

    @Test
    func `Claude admin API key rejects a lone apostrophe`() {
        for key in ClaudeAdminAPISettingsReader.apiKeyEnvironmentKeys {
            let env = [key: "'"]
            #expect(ClaudeAdminAPISettingsReader.apiKey(environment: env) == nil)
        }
    }

    @Test
    func `Claude admin API key unwraps double quotes`() {
        let env = [ClaudeAdminAPISettingsReader.adminAPIKeyEnvironmentKey: "\"sk-ant-admin-token\""]
        #expect(ClaudeAdminAPISettingsReader.apiKey(environment: env) == "sk-ant-admin-token")
    }

    @Test
    func `Claude admin API key unwraps single quotes`() {
        let env = [ClaudeAdminAPISettingsReader.adminAPIKeyEnvironmentKey: "'sk-ant-admin-token'"]
        #expect(ClaudeAdminAPISettingsReader.apiKey(environment: env) == "sk-ant-admin-token")
    }

    @Test
    func `OpenAI API key rejects a lone double quote`() {
        for key in OpenAIAPISettingsReader.apiKeyEnvironmentKeys {
            let env = [key: "\""]
            #expect(OpenAIAPISettingsReader.apiKey(environment: env) == nil)
        }
    }

    @Test
    func `OpenAI API key rejects a lone apostrophe`() {
        for key in OpenAIAPISettingsReader.apiKeyEnvironmentKeys {
            let env = [key: "'"]
            #expect(OpenAIAPISettingsReader.apiKey(environment: env) == nil)
        }
    }

    @Test
    func `OpenAI API key unwraps quotes`() {
        let env = [OpenAIAPISettingsReader.apiKeyEnvironmentKey: "\"sk-token\""]
        #expect(OpenAIAPISettingsReader.apiKey(environment: env) == "sk-token")
    }
}
