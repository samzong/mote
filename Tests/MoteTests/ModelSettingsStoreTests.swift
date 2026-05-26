import MoteCore
@testable import Mote
import Testing

@MainActor
struct ModelSettingsStoreTests {
    @Test
    func switchingProviderClearsProviderSpecificModelAndReplacesKnownDefaultBaseURL() {
        let store = ModelSettingsStore(
            config: AppConfig(
                baseURL: ModelProvider.lmStudio.defaultBaseURL,
                apiKey: "",
                model: "local-model",
                temperature: 0.2,
                maxTokens: 1024,
                provider: ModelProvider.lmStudio.id
            )
        )

        store.selectProvider(.ollama)

        #expect(store.selectedProviderID == ModelProvider.ollama.id)
        #expect(store.baseURL == ModelProvider.ollama.defaultBaseURL)
        #expect(store.selectedModelID == "")
        #expect(store.models.isEmpty)
        #expect(!store.canSave)
    }

    @Test
    func savingPersistsProviderAndPreservesGenerationSettings() throws {
        var savedConfig: AppConfig?
        let store = ModelSettingsStore(
            config: AppConfig(
                baseURL: ModelProvider.openRouter.defaultBaseURL,
                apiKey: "",
                model: "old-model",
                temperature: 0.7,
                maxTokens: 2048,
                provider: ModelProvider.openRouter.id
            ),
            persistConfig: { config in
                savedConfig = config
            }
        )

        store.apiKey = "sk-test"
        store.selectedModelID = "provider/new-model"

        #expect(store.save())

        let config = try #require(savedConfig)
        #expect(config.provider == ModelProvider.openRouter.id)
        #expect(config.baseURL == ModelProvider.openRouter.defaultBaseURL)
        #expect(config.apiKey == "sk-test")
        #expect(config.model == "provider/new-model")
        #expect(config.temperature == 0.7)
        #expect(config.maxTokens == 2048)
    }

    @Test
    func selectingFreeModelKeepsDiscoveryValidationError() async {
        let store = ModelSettingsStore(
            config: AppConfig(
                baseURL: ModelProvider.openRouter.defaultBaseURL,
                apiKey: "",
                model: "",
                temperature: 0.2,
                maxTokens: 1024,
                provider: ModelProvider.openRouter.id
            )
        )

        await store.selectFreeModel()

        #expect(store.errorMessage == "API key is required for OpenRouter.")
        #expect(store.selectedModelID == "")
    }
}
