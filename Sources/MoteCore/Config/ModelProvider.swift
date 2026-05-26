import Foundation

public struct ModelProvider: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let defaultBaseURL: String
    public let apiKeyRequired: Bool
    public let supportsFreeModelAutoSelection: Bool

    public init(
        id: String,
        name: String,
        defaultBaseURL: String,
        apiKeyRequired: Bool,
        supportsFreeModelAutoSelection: Bool
    ) {
        self.id = id
        self.name = name
        self.defaultBaseURL = defaultBaseURL
        self.apiKeyRequired = apiKeyRequired
        self.supportsFreeModelAutoSelection = supportsFreeModelAutoSelection
    }

    public static let openRouter = ModelProvider(
        id: "openrouter",
        name: "OpenRouter",
        defaultBaseURL: "https://openrouter.ai/api/v1",
        apiKeyRequired: true,
        supportsFreeModelAutoSelection: true
    )

    public static let ollama = ModelProvider(
        id: "ollama",
        name: "Ollama",
        defaultBaseURL: "http://localhost:11434/v1",
        apiKeyRequired: false,
        supportsFreeModelAutoSelection: false
    )

    public static let lmStudio = ModelProvider(
        id: "lm-studio",
        name: "LM Studio",
        defaultBaseURL: "http://localhost:1234/v1",
        apiKeyRequired: false,
        supportsFreeModelAutoSelection: false
    )

    public static let custom = ModelProvider(
        id: "custom",
        name: "Custom OpenAI-compatible",
        defaultBaseURL: "",
        apiKeyRequired: false,
        supportsFreeModelAutoSelection: false
    )

    public static let all: [ModelProvider] = [
        .openRouter,
        .ollama,
        .lmStudio,
        .custom,
    ]

    public static func find(id: String) -> ModelProvider? {
        all.first { $0.id == id }
    }

    public static func resolve(providerID: String, baseURL: String) -> ModelProvider? {
        let trimmedProviderID = providerID.trimmingCharacters(in: .whitespacesAndNewlines)
        if let provider = find(id: trimmedProviderID) {
            return provider
        }

        let normalizedInputBaseURL = normalizedBaseURL(baseURL)
        guard !normalizedInputBaseURL.isEmpty else {
            return nil
        }

        if let provider = all.first(where: { provider in
            provider.id != custom.id && normalizedBaseURL(provider.defaultBaseURL) == normalizedInputBaseURL
        }) {
            return provider
        }

        return .custom
    }

    private static func normalizedBaseURL(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
