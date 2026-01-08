import Foundation

@MainActor
public final class ProviderFactory {
    public static let shared = ProviderFactory()

    private let httpClient: HTTPClient
    private let keychainService: KeychainService
    private var providerCache: [UUID: any LLMProvider] = [:]

    public init(
        httpClient: HTTPClient = .shared,
        keychainService: KeychainService = .shared
    ) {
        self.httpClient = httpClient
        self.keychainService = keychainService
    }

    public func provider(for configuration: AnyProviderConfiguration) -> any LLMProvider {
        if let cached = providerCache[configuration.id] {
            return cached
        }

        let provider: any LLMProvider
        switch configuration {
        case .local(let config):
            provider = LocalOllamaProvider(
                configuration: config,
                httpClient: httpClient
            )
        case .cloud(let config):
            provider = OllamaCloudProvider(
                configuration: config,
                httpClient: httpClient,
                keychainService: keychainService
            )
        case .openRouter(let config):
            provider = OpenRouterProvider(
                configuration: config,
                httpClient: httpClient,
                keychainService: keychainService
            )
        case .onDevice:
            provider = OnDeviceProvider()
        case .appleIntelligence(let config):
            provider = AppleIntelligenceProvider(configuration: config)
        }

        providerCache[configuration.id] = provider
        return provider
    }

    public func clearCache() {
        providerCache.removeAll()
    }
}
