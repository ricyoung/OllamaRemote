import Foundation

public final class SettingsStore: @unchecked Sendable {
    public static let shared = SettingsStore()

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let providerConfigs = "providerConfigurations"
        static let selectedProviderId = "selectedProviderId"
    }

    private init() {}

    public func loadProviderConfigurations() -> [AnyProviderConfiguration] {
        guard let data = defaults.data(forKey: Keys.providerConfigs) else {
            return defaultConfigurations()
        }
        return (try? decoder.decode([AnyProviderConfiguration].self, from: data))
            ?? defaultConfigurations()
    }

    public func saveProviderConfigurations(_ configs: [AnyProviderConfiguration]) {
        if let data = try? encoder.encode(configs) {
            defaults.set(data, forKey: Keys.providerConfigs)
        }
    }

    public func loadSelectedProviderId() -> UUID? {
        guard let string = defaults.string(forKey: Keys.selectedProviderId) else {
            return nil
        }
        return UUID(uuidString: string)
    }

    public func saveSelectedProviderId(_ id: UUID?) {
        defaults.set(id?.uuidString, forKey: Keys.selectedProviderId)
    }

    private func defaultConfigurations() -> [AnyProviderConfiguration] {
        [
            .local(LocalOllamaConfig()),
            .cloud(OllamaCloudConfig()),
            .openRouter(OpenRouterConfig())
        ]
    }
}
