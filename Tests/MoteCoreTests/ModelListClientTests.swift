import Foundation
@testable import MoteCore
import Testing

struct ModelListClientTests {
    @Test
    func buildsModelsURLFromBaseURL() throws {
        let client = ModelListClient()

        #expect(
            client.buildURL(baseURL: "https://openrouter.ai/api/v1")?.absoluteString
                == "https://openrouter.ai/api/v1/models"
        )
        #expect(
            client.buildURL(baseURL: "http://localhost:11434/v1/")?.absoluteString
                == "http://localhost:11434/v1/models"
        )
    }

    @Test
    func modelListRequestUsesBearerTokenWhenProvided() throws {
        let client = ModelListClient()
        let request = try client.makeRequest(baseURL: "https://openrouter.ai/api/v1", apiKey: "sk-test")

        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
    }

    @Test
    func detectsAndRecommendsFreeOpenRouterModel() {
        let freeSmall = ProviderModel(
            id: "provider/free-small:free",
            name: "Free Small",
            contextLength: 8_192,
            pricing: .init(prompt: "0", completion: "0")
        )
        let freeLarge = ProviderModel(
            id: "provider/free-large",
            name: "Free Large",
            contextLength: 65_536,
            pricing: .init(prompt: "0", completion: "0", request: "0")
        )
        let paid = ProviderModel(
            id: "provider/paid",
            name: "Paid",
            contextLength: 131_072,
            pricing: .init(prompt: "0.000001", completion: "0")
        )

        #expect(freeSmall.isFree)
        #expect(freeLarge.isFree)
        #expect(!paid.isFree)
        #expect(ModelListClient.recommendedFreeModel(from: [paid, freeSmall, freeLarge])?.id == freeLarge.id)
    }

    @Test
    func decodesOpenRouterModelShape() throws {
        let data = Data("""
        {
          "id": "google/gemini-2.0-flash-exp:free",
          "name": "Gemini Flash",
          "context_length": 1048576,
          "pricing": {
            "prompt": "0",
            "completion": "0"
          }
        }
        """.utf8)

        let model = try JSONDecoder().decode(ProviderModel.self, from: data)

        #expect(model.id == "google/gemini-2.0-flash-exp:free")
        #expect(model.name == "Gemini Flash")
        #expect(model.contextLength == 1_048_576)
        #expect(model.isFree)
    }
}
