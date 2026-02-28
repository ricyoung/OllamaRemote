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

    @Test("Full URL host input passes validation")
    func hostWithPath() throws {
        let config = OpenClawConfig(host: "http://host.example.com:18789/v1")
        let validated = try config.validated()
        #expect(validated.host == "http://host.example.com:18789/v1")
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

    @Test("Host with embedded port is resolved")
    func hostWithEmbeddedPort() {
        let config = OpenClawConfig(host: "89.167.78.155:18789", port: 11434)
        #expect(config.baseURL.absoluteString == "http://89.167.78.155:18789/v1")
    }

    @Test("Full URL host overrides port, scheme, and pathPrefix")
    func fullURLOverridesConnectionParts() {
        let config = OpenClawConfig(
            host: "https://89.167.78.155:18789/custom/v1",
            port: 11434,
            useTLS: false,
            pathPrefix: "/v1"
        )
        #expect(config.baseURL.absoluteString == "https://89.167.78.155:18789/custom/v1")
    }

    @Test("Full URL host without explicit port does not force default port")
    func fullURLWithoutPortKeepsImplicitSchemePort() {
        let config = OpenClawConfig(
            host: "https://openclaw-gate.taild2f3cc.ts.net",
            port: 18789,
            useTLS: false,
            pathPrefix: "/v1"
        )
        #expect(config.baseURL.absoluteString == "https://openclaw-gate.taild2f3cc.ts.net/v1")
    }
}

// MARK: - Local Ollama Validation

@Suite("Local Ollama Input Validation")
struct LocalOllamaInputValidationTests {

    @Test("Default config produces expected base URL")
    func defaultBaseURL() {
        let config = LocalOllamaConfig()
        #expect(config.baseURL.absoluteString == "http://localhost:11434")
    }

    @Test("Full URL host does not crash and preserves explicit port")
    func fullURLHostDoesNotCrash() {
        let config = LocalOllamaConfig(host: "http://10.10.0.129:11434", port: 9999)
        #expect(config.baseURL.absoluteString == "http://10.10.0.129:11434")
    }

    @Test("Host with embedded port overrides manual port")
    func embeddedPortOverridesManualPort() {
        let config = LocalOllamaConfig(host: "10.10.0.129:22445", port: 11434)
        #expect(config.baseURL.absoluteString == "http://10.10.0.129:22445")
    }

    @Test("Empty host fails validation")
    func emptyHostFailsValidation() {
        let config = LocalOllamaConfig(host: "   ")
        #expect(throws: ConfigValidationError.self) {
            try config.validated()
        }
    }

    @Test("Out-of-range port fails validation")
    func invalidPortFailsValidation() {
        let config = LocalOllamaConfig(host: "localhost", port: 70000)
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

// MARK: - Gateway WS URL Derivation

@Suite("OpenClaw Gateway WS URL Derivation")
struct OpenClawGatewayURLTests {

    @Test("Default host derives ws URL")
    func defaultGatewayURL() throws {
        let config = OpenClawConfig()
        #expect(try config.gatewayWebSocketURL().absoluteString == "ws://localhost:18789")
    }

    @Test("HTTPS host derives wss URL")
    func httpsHostBecomesWSS() throws {
        let config = OpenClawConfig(host: "https://openclaw-gate.taild2f3cc.ts.net", useTLS: false)
        #expect(try config.gatewayWebSocketURL().absoluteString == "wss://openclaw-gate.taild2f3cc.ts.net")
    }

    @Test("Chat share URL strips /chat path for gateway WS")
    func chatShareURLUsesGatewayRoot() throws {
        let config = OpenClawConfig(host: "https://openclaw-gate.taild2f3cc.ts.net/chat?session=agent%3Amain%3Amain")
        #expect(try config.gatewayWebSocketURL().absoluteString == "wss://openclaw-gate.taild2f3cc.ts.net")
        #expect(config.baseURL.absoluteString == "https://openclaw-gate.taild2f3cc.ts.net/v1")
    }

    @Test("Direct ws URL is preserved")
    func directWSURLPreserved() throws {
        let config = OpenClawConfig(host: "wss://openclaw-gate.taild2f3cc.ts.net")
        #expect(try config.gatewayWebSocketURL().absoluteString == "wss://openclaw-gate.taild2f3cc.ts.net")
    }
}

// MARK: - Model Fallback Selection

@Suite("AppState Model Selection Fallback")
struct AppStateModelSelectionFallbackTests {

    @Test("Saved default model is kept when provider returns no models")
    @MainActor
    func keepsSavedDefaultModelWhenDiscoveryUnavailable() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw NetworkError.invalidURL
            }
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ) else {
                throw NetworkError.invalidResponse
            }
            let body = """
            { "models": [] }
            """
            return (response, Data(body.utf8))
        }

        defer { MockURLProtocol.requestHandler = nil }

        let httpClient = HTTPClient(configuration: configuration)
        let providerFactory = ProviderFactory(httpClient: httpClient, keychainService: .shared)
        let state = AppState(providerFactory: providerFactory)

        let providerId = UUID(uuidString: "8B20C14A-3A2A-4420-B754-EE0C12831E83")!
        let config = LocalOllamaConfig(
            id: providerId,
            displayName: "Local Test",
            host: "localhost",
            port: 11434,
            isEnabled: true
        )

        state.providerConfigurations = [.local(config)]
        state.selectedProviderId = providerId
        state.defaultModelIds = [providerId.uuidString: "manual-model-id"]
        state.selectedModelId = nil

        await state.loadModels()

        #expect(state.availableModels.isEmpty)
        #expect(state.selectedModelId == "manual-model-id")
    }
}

// MARK: - Diagnostics Redaction

@Suite("Diagnostics Redaction")
struct DiagnosticsRedactionTests {

    @Test("Bearer tokens and hex-like secrets are redacted in export")
    func exportRedactsSecrets() async {
        let suiteName = "DiagnosticsRedactionTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let store = DiagnosticsStore(defaults: defaults)
        await store.record(
            category: "OpenClaw",
            level: .error,
            message: "Authorization: Bearer 75e155ea1b044456d321aa52dd80d65a1bdc3c3b5dbc4ca1",
            metadata: ["rawToken": "75e155ea1b044456d321aa52dd80d65a1bdc3c3b5dbc4ca1"]
        )

        let text = await store.exportText(limit: 20)
        #expect(!text.contains("75e155ea1b044456d321aa52dd80d65a1bdc3c3b5dbc4ca1"))
        #expect(text.contains("Bearer [REDACTED]"))
        #expect(text.contains("rawToken=[REDACTED]"))
    }

    @Test("Sensitive metadata keys are redacted")
    func sensitiveMetadataKeysAreRedacted() async {
        let suiteName = "DiagnosticsMetadataTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let store = DiagnosticsStore(defaults: defaults)
        await store.record(
            category: "OpenClaw",
            message: "probe",
            metadata: [
                "apiKey": "abc123",
                "authorization": "Bearer should_not_show",
                "status": "ok"
            ]
        )

        let entries = await store.recentEntries(limit: 10)
        guard let first = entries.first else {
            Issue.record("Expected at least one diagnostics entry")
            return
        }

        #expect(first.metadata["apiKey"] == "[REDACTED]")
        #expect(first.metadata["authorization"] == "[REDACTED]")
        #expect(first.metadata["status"] == "ok")
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

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: NetworkError.invalidResponse)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
