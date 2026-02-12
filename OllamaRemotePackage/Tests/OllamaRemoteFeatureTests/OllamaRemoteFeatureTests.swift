import Foundation
import Testing
@testable import OllamaRemoteFeature

// MARK: - Provider Metadata

@Suite("OpenClaw Provider Metadata")
struct OpenClawProviderMetadataTests {

    @Test("Provider type metadata is configured correctly")
    func providerTypeMetadata() {
        #expect(ProviderType.openClaw.displayName == "OpenClaw")
        #expect(ProviderType.openClaw.requiresAPIKey)
        #expect(ProviderType.openClaw.iconName == "pawprint")
    }
}

// MARK: - URL Construction

@Suite("OpenClaw URL Construction")
struct OpenClawURLConstructionTests {

    @Test("Default config produces correct base URL")
    func defaultBaseURL() {
        let config = OpenClawConfig()
        #expect(config.baseURL.absoluteString == "http://localhost:18789/v1")
    }

    @Test("TLS produces https scheme")
    func tlsScheme() {
        let config = OpenClawConfig(useTLS: true)
        #expect(config.baseURL.scheme == "https")
    }

    @Test("Custom port is reflected in URL")
    func customPort() {
        let config = OpenClawConfig(port: 8080)
        #expect(config.baseURL.absoluteString == "http://localhost:8080/v1")
    }

    @Test("Custom domain host is reflected in URL")
    func customDomainHost() {
        let config = OpenClawConfig(host: "api.openclaw.example.com")
        #expect(config.baseURL.host == "api.openclaw.example.com")
    }

    @Test("Deep path prefix is preserved")
    func deepPathPrefix() {
        let config = OpenClawConfig(pathPrefix: "/api/v2")
        #expect(config.baseURL.absoluteString == "http://localhost:18789/api/v2")
    }

    @Test("Full combination of host, port, TLS, and path")
    func fullCombination() {
        let config = OpenClawConfig(
            host: "claw.example.com",
            port: 443,
            useTLS: true,
            pathPrefix: "/gateway/v1"
        )
        #expect(config.baseURL.absoluteString == "https://claw.example.com:443/gateway/v1")
    }
}

// MARK: - Path Normalization

@Suite("OpenClaw Path Normalization")
struct OpenClawPathNormalizationTests {

    @Test("Path normalization handles various formats",
          arguments: [
              ("/v1", "/v1"),
              ("v1", "/v1"),
              ("   ", "/v1"),
              ("", "/v1"),
              (" /api/v2 ", "/api/v2"),
          ])
    func pathNormalization(input: String, expected: String) {
        let config = OpenClawConfig(host: "localhost", port: 18789, pathPrefix: input)
        #expect(config.baseURL.path == expected)
    }
}

// MARK: - Input Validation

@Suite("OpenClaw Input Validation")
struct OpenClawInputValidationTests {

    @Test("Valid config passes validation")
    func validConfig() throws {
        let config = OpenClawConfig()
        let validated = try config.validated()
        #expect(validated.host == "localhost")
    }

    @Test("Host with slash throws invalidHost")
    func hostWithSlash() {
        let config = OpenClawConfig(host: "host/path")
        #expect(throws: ConfigValidationError.self) {
            try config.validated()
        }
    }

    @Test("Empty host throws invalidHost")
    func emptyHost() {
        let config = OpenClawConfig(host: "")
        #expect(throws: ConfigValidationError.self) {
            try config.validated()
        }
    }

    @Test("Port 0 throws invalidPort")
    func portZero() {
        let config = OpenClawConfig(port: 0)
        #expect(throws: ConfigValidationError.self) {
            try config.validated()
        }
    }

    @Test("Port 70000 throws invalidPort")
    func portTooHigh() {
        let config = OpenClawConfig(port: 70000)
        #expect(throws: ConfigValidationError.self) {
            try config.validated()
        }
    }

    @Test("Path with query marker throws invalidPathPrefix")
    func pathWithQuery() {
        let config = OpenClawConfig(pathPrefix: "/v1?key=val")
        #expect(throws: ConfigValidationError.self) {
            try config.validated()
        }
    }

    @Test("Path with traversal throws invalidPathPrefix")
    func pathWithTraversal() {
        let config = OpenClawConfig(pathPrefix: "/v1/../secret")
        #expect(throws: ConfigValidationError.self) {
            try config.validated()
        }
    }
}

// MARK: - Config Properties

@Suite("OpenClaw Config Properties")
struct OpenClawConfigPropertiesTests {

    @Test("Type is openClaw")
    func typeIsOpenClaw() {
        let config = OpenClawConfig()
        #expect(config.type == .openClaw)
    }

    @Test("Default values are sensible")
    func defaultValues() {
        let config = OpenClawConfig()
        #expect(config.displayName == "OpenClaw")
        #expect(config.isEnabled)
        #expect(config.host == "localhost")
        #expect(config.port == 18789)
        #expect(!config.useTLS)
        #expect(config.pathPrefix == "/v1")
    }

    @Test("Each config gets a unique ID")
    func uniqueIDs() {
        let a = OpenClawConfig()
        let b = OpenClawConfig()
        #expect(a.id != b.id)
    }

    @Test("API key reference follows expected format")
    func apiKeyReferenceFormat() {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let config = OpenClawConfig(id: id)
        #expect(config.apiKeyReference == "openclaw_AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
    }
}

// MARK: - Codable Round-Trip

@Suite("OpenClaw Codable Round-Trip")
struct OpenClawCodableTests {

    @Test("Disabled config survives encode/decode")
    func disabledConfigRoundTrip() throws {
        let original = OpenClawConfig(isEnabled: false)
        let wrapped = AnyProviderConfiguration.openClaw(original)
        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(AnyProviderConfiguration.self, from: data)

        guard case .openClaw(let value) = decoded else {
            Issue.record("Expected openClaw case")
            return
        }

        #expect(!value.isEnabled)
    }

    @Test("TLS config survives encode/decode")
    func tlsConfigRoundTrip() throws {
        let original = OpenClawConfig(useTLS: true)
        let wrapped = AnyProviderConfiguration.openClaw(original)
        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(AnyProviderConfiguration.self, from: data)

        guard case .openClaw(let value) = decoded else {
            Issue.record("Expected openClaw case")
            return
        }

        #expect(value.useTLS)
    }

    @Test("ProviderType is excluded from JSON (derived from case)")
    func typeExcludedFromJSON() throws {
        let config = OpenClawConfig()
        let data = try JSONEncoder().encode(config)
        let json = try JSONDecoder().decode([String: AnyCodableValue].self, from: data)
        #expect(json["type"] == nil)
    }
}

// MARK: - AnyProviderConfiguration Delegation

@Suite("AnyProviderConfiguration OpenClaw Delegation")
struct AnyProviderConfigurationOpenClawTests {

    @Test("All delegated properties match inner config")
    func delegatedProperties() {
        let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let inner = OpenClawConfig(
            id: id,
            displayName: "OpenClaw Lab",
            isEnabled: true,
            host: "10.10.0.129",
            port: 18789,
            useTLS: false,
            pathPrefix: "/v1"
        )
        let wrapped = AnyProviderConfiguration.openClaw(inner)

        #expect(wrapped.id == id)
        #expect(wrapped.type == .openClaw)
        #expect(wrapped.displayName == "OpenClaw Lab")
        #expect(wrapped.isEnabled)
        #expect(wrapped.baseURL == inner.baseURL)
        #expect(wrapped.apiKeyReference == "openclaw_11111111-2222-3333-4444-555555555555")
    }

    @Test("Full round-trip preserves all values")
    func fullRoundTrip() throws {
        let original = OpenClawConfig(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            displayName: "OpenClaw Lab",
            isEnabled: true,
            host: "10.10.0.129",
            port: 18789,
            useTLS: false,
            pathPrefix: "/v1"
        )

        let wrapped = AnyProviderConfiguration.openClaw(original)
        let encoded = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(AnyProviderConfiguration.self, from: encoded)

        guard case .openClaw(let value) = decoded else {
            Issue.record("Decoded config should be openClaw")
            return
        }

        #expect(value.id == original.id)
        #expect(value.displayName == "OpenClaw Lab")
        #expect(value.host == "10.10.0.129")
        #expect(value.port == 18789)
        #expect(value.pathPrefix == "/v1")
        #expect(value.apiKeyReference == "openclaw_11111111-2222-3333-4444-555555555555")
    }
}

// MARK: - Helper for JSON key inspection

private enum AnyCodableValue: Decodable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { self = .string(s) }
        else if let i = try? container.decode(Int.self) { self = .int(i) }
        else if let b = try? container.decode(Bool.self) { self = .bool(b) }
        else { self = .null }
    }
}
