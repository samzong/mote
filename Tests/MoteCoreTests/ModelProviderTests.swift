@testable import MoteCore
import Testing

struct ModelProviderTests {
    @Test
    func presetsUseOpenAICompatibleBaseURLs() {
        #expect(ModelProvider.openRouter.defaultBaseURL == "https://openrouter.ai/api/v1")
        #expect(ModelProvider.ollama.defaultBaseURL == "http://localhost:11434/v1")
        #expect(ModelProvider.lmStudio.defaultBaseURL == "http://localhost:1234/v1")
        #expect(ModelProvider.openRouter.supportsFreeModelAutoSelection)
        #expect(!ModelProvider.ollama.apiKeyRequired)
    }

    @Test
    func resolvesLegacyConfigProviderFromBaseURL() {
        #expect(ModelProvider.resolve(providerID: "", baseURL: "http://localhost:11434/v1/") == .ollama)
        #expect(ModelProvider.resolve(providerID: "", baseURL: "http://localhost:1234/v1") == .lmStudio)
        #expect(ModelProvider.resolve(providerID: "", baseURL: "https://example.test/v1") == .custom)
        #expect(ModelProvider.resolve(providerID: "openrouter", baseURL: "https://example.test/v1") == .openRouter)
    }
}
