import Foundation

public enum ModelListClientError: LocalizedError {
    case invalidEndpoint(String)
    case invalidResponse
    case serverStatus(Int, String)
    case emptyModelList
    case malformedResponse(String)
    case transport(Error)

    public var errorDescription: String? {
        switch self {
            case let .invalidEndpoint(value):
                return "Invalid model list endpoint URL: \(value)"
            case .invalidResponse:
                return "Invalid response from model list endpoint"
            case let .serverStatus(statusCode, body):
                if body.isEmpty {
                    return "Model list endpoint returned HTTP \(statusCode)"
                }

                return "Model list endpoint returned HTTP \(statusCode): \(body)"
            case .emptyModelList:
                return "Model list endpoint returned no models"
            case let .malformedResponse(message):
                return message
            case let .transport(error):
                return error.localizedDescription
        }
    }
}

public struct ProviderModel: Decodable, Equatable, Sendable {
    public struct Pricing: Decodable, Equatable, Sendable {
        public let prompt: String?
        public let completion: String?
        public let request: String?
        public let image: String?

        public init(prompt: String? = nil, completion: String? = nil, request: String? = nil, image: String? = nil) {
            self.prompt = prompt
            self.completion = completion
            self.request = request
            self.image = image
        }
    }

    public let id: String
    public let name: String?
    public let contextLength: Int?
    public let pricing: Pricing?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case contextLength = "context_length"
        case pricing
    }

    public init(id: String, name: String? = nil, contextLength: Int? = nil, pricing: Pricing? = nil) {
        self.id = id
        self.name = name
        self.contextLength = contextLength
        self.pricing = pricing
    }

    public var displayName: String {
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name != id else {
            return id
        }

        return "\(name) (\(id))"
    }

    public var isFree: Bool {
        if id.localizedCaseInsensitiveContains(":free") {
            return true
        }

        guard let pricing else {
            return false
        }

        let prices = [pricing.prompt, pricing.completion, pricing.request, pricing.image]
            .compactMap { $0 }
        guard !prices.isEmpty else {
            return false
        }

        return prices.allSatisfy(Self.isZeroPrice)
    }

    private static func isZeroPrice(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        return Double(trimmed) == 0
    }
}

public final class ModelListClient {
    private struct ModelListResponse: Decodable {
        let data: [ProviderModel]
    }

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func buildURL(baseURL: String) -> URL? {
        guard !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        guard var components = URLComponents(string: baseURL) else {
            return nil
        }

        let requestPath = normalizedPath("/models")
        let basePath = normalizedPath(components.path)

        if basePath.isEmpty {
            components.path = requestPath
        } else {
            components.path = "\(basePath)\(requestPath)"
        }

        return components.url
    }

    public func makeRequest(baseURL: String, apiKey: String) throws -> URLRequest {
        guard let url = buildURL(baseURL: baseURL) else {
            throw ModelListClientError.invalidEndpoint(baseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    public func listModels(baseURL: String, apiKey: String) async throws -> [ProviderModel] {
        let request = try makeRequest(baseURL: baseURL, apiKey: apiKey)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ModelListClientError.invalidResponse
            }

            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw ModelListClientError.serverStatus(httpResponse.statusCode, body)
            }

            let decoder = JSONDecoder()
            let modelList: ModelListResponse

            do {
                modelList = try decoder.decode(ModelListResponse.self, from: data)
            } catch {
                let responseBody = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw ModelListClientError.malformedResponse(
                    responseBody.isEmpty
                        ? "Model list response could not be parsed."
                        : "Model list response could not be parsed: \(responseBody)"
                )
            }

            let models = modelList.data
                .filter { !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .sorted { lhs, rhs in
                    if lhs.isFree != rhs.isFree {
                        return lhs.isFree
                    }

                    return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
                }

            guard !models.isEmpty else {
                throw ModelListClientError.emptyModelList
            }

            return models
        } catch let error as ModelListClientError {
            throw error
        } catch {
            throw ModelListClientError.transport(error)
        }
    }

    public static func recommendedFreeModel(from models: [ProviderModel]) -> ProviderModel? {
        models
            .filter(\.isFree)
            .sorted { lhs, rhs in
                let lhsContext = lhs.contextLength ?? 0
                let rhsContext = rhs.contextLength ?? 0

                if lhsContext != rhsContext {
                    return lhsContext > rhsContext
                }

                return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
            }
            .first
    }

    private func normalizedPath(_ value: String) -> String {
        guard !value.isEmpty, value != "/" else {
            return ""
        }

        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else {
            return ""
        }

        return "/\(trimmed)"
    }
}
