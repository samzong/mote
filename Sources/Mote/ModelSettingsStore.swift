import Foundation
import MoteCore

@MainActor
final class ModelSettingsStore: ObservableObject {
    @Published var selectedProviderID: String
    @Published var baseURL: String
    @Published var apiKey: String
    @Published var selectedModelID: String
    @Published var models: [ProviderModel]
    @Published var isDiscovering = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    let providers = ModelProvider.all

    private var existingConfig: AppConfig
    private let persistConfig: @MainActor (AppConfig) throws -> Void

    var selectedProvider: ModelProvider {
        ModelProvider.find(id: selectedProviderID) ?? .custom
    }

    var canUseFreeModel: Bool {
        selectedProvider.supportsFreeModelAutoSelection
    }

    var canSave: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!selectedProvider.apiKeyRequired || !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    convenience init() {
        let loadedConfig = (try? ConfigLoader.loadConfig()) ?? .default
        self.init(config: loadedConfig, persistConfig: ConfigLoader.saveConfig)
    }

    init(
        config loadedConfig: AppConfig,
        persistConfig: @MainActor @escaping (AppConfig) throws -> Void = ConfigLoader.saveConfig
    ) {
        let resolvedProvider = ModelProvider.resolve(
            providerID: loadedConfig.provider,
            baseURL: loadedConfig.baseURL
        ) ?? .custom

        existingConfig = loadedConfig
        self.persistConfig = persistConfig
        selectedProviderID = resolvedProvider.id
        baseURL = loadedConfig.baseURL.isEmpty ? resolvedProvider.defaultBaseURL : loadedConfig.baseURL
        apiKey = loadedConfig.apiKey
        selectedModelID = loadedConfig.model
        models = loadedConfig.model.isEmpty ? [] : [ProviderModel(id: loadedConfig.model)]
    }

    func selectProvider(_ provider: ModelProvider) {
        guard provider.id != selectedProviderID else { return }

        let previousProvider = selectedProvider
        let shouldReplaceBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || baseURLMatchesKnownDefault(previousProvider)

        selectedProviderID = provider.id
        selectedModelID = ""
        models = []
        statusMessage = nil
        errorMessage = nil

        if shouldReplaceBaseURL {
            baseURL = provider.defaultBaseURL
        }
    }

    func discoverModels() async {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedBaseURL.isEmpty else {
            errorMessage = "Base URL is required."
            statusMessage = nil
            return
        }

        guard !selectedProvider.apiKeyRequired || !trimmedAPIKey.isEmpty else {
            errorMessage = "API key is required for \(selectedProvider.name)."
            statusMessage = nil
            return
        }

        isDiscovering = true
        errorMessage = nil
        statusMessage = nil

        do {
            let discoveredModels = try await ModelListClient().listModels(
                baseURL: trimmedBaseURL,
                apiKey: trimmedAPIKey
            )
            models = discoveredModels

            if !models.contains(where: { $0.id == selectedModelID }) {
                selectedModelID = suggestedModelID(from: discoveredModels) ?? ""
            }

            statusMessage = "Found \(discoveredModels.count) models."
        } catch {
            errorMessage = localizedDescription(for: error)
        }

        isDiscovering = false
    }

    func selectFreeModel() async {
        if ModelListClient.recommendedFreeModel(from: models) == nil {
            await discoverModels()
            if errorMessage != nil {
                return
            }
        }

        guard let model = ModelListClient.recommendedFreeModel(from: models) else {
            errorMessage = "No free OpenRouter model was found."
            statusMessage = nil
            return
        }

        selectedModelID = model.id
        errorMessage = nil
        statusMessage = "Selected \(model.id)."
    }

    func save() -> Bool {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModelID = selectedModelID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedBaseURL.isEmpty else {
            errorMessage = "Base URL is required."
            return false
        }

        guard !selectedProvider.apiKeyRequired || !trimmedAPIKey.isEmpty else {
            errorMessage = "API key is required for \(selectedProvider.name)."
            return false
        }

        guard !trimmedModelID.isEmpty else {
            errorMessage = "Model is required."
            return false
        }

        let config = AppConfig(
            baseURL: trimmedBaseURL,
            apiKey: trimmedAPIKey,
            model: trimmedModelID,
            temperature: existingConfig.temperature,
            maxTokens: existingConfig.maxTokens,
            provider: selectedProvider.id
        )

        do {
            try persistConfig(config)
            existingConfig = config
            errorMessage = nil
            statusMessage = "Saved."
            return true
        } catch {
            errorMessage = localizedDescription(for: error)
            return false
        }
    }

    private func suggestedModelID(from models: [ProviderModel]) -> String? {
        if canUseFreeModel, let freeModel = ModelListClient.recommendedFreeModel(from: models) {
            return freeModel.id
        }

        return models.first?.id
    }

    private func baseURLMatchesKnownDefault(_ provider: ModelProvider) -> Bool {
        let normalizedBaseURL = normalized(baseURL)
        return normalizedBaseURL == normalized(provider.defaultBaseURL)
            || providers.contains { normalizedBaseURL == normalized($0.defaultBaseURL) }
    }

    private func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func localizedDescription(for error: Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }

        return error.localizedDescription
    }
}
