import Foundation
@testable import MoteCore
import Testing

struct ConfigLoaderTests {
    @Test
    func defaultConfigRoundTripsThroughJSON() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(AppConfig.default)

        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        #expect(decoded == AppConfig.default)
    }

    @Test
    func legacyConfigDecodesWithoutProvider() throws {
        let data = Data("""
        {
          "base_url": "http://127.0.0.1:1234/v1",
          "api_key": "",
          "model": "local-model",
          "temperature": 0.1,
          "max_tokens": 256
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        #expect(decoded.provider == "")
        #expect(decoded.baseURL == "http://127.0.0.1:1234/v1")
        #expect(decoded.model == "local-model")
        #expect(decoded.temperature == 0.1)
        #expect(decoded.maxTokens == 256)
    }
}
