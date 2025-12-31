import Foundation

public final class SettingsStore: @unchecked Sendable {
    public static let shared = SettingsStore()

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let providerConfigs = "providerConfigurations"
        static let selectedProviderId = "selectedProviderId"
        static let autoSaveChats = "autoSaveChats"
        static let fontSizeOffset = "fontSizeOffset"
        static let hapticsEnabled = "hapticsEnabled"
        static let showFollowUpQuestions = "showFollowUpQuestions"
        static let autoDeleteDays = "autoDeleteDays"
    }

    private init() {}

    public func loadProviderConfigurations() -> [AnyProviderConfiguration] {
        guard let data = defaults.data(forKey: Keys.providerConfigs),
              var configs = try? decoder.decode([AnyProviderConfiguration].self, from: data) else {
            return defaultConfigurations()
        }

        // Migration: Add On-Device provider if it doesn't exist
        if !configs.contains(where: { $0.type == .onDevice }) {
            configs.insert(.onDevice(OnDeviceConfig()), at: 0)
            saveProviderConfigurations(configs)
        }

        return configs
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

    public func loadAutoSaveChats() -> Bool {
        // Default to true if not set
        if defaults.object(forKey: Keys.autoSaveChats) == nil {
            return true
        }
        return defaults.bool(forKey: Keys.autoSaveChats)
    }

    public func saveAutoSaveChats(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.autoSaveChats)
    }

    public func loadFontSizeOffset() -> Int {
        defaults.integer(forKey: Keys.fontSizeOffset)
    }

    public func saveFontSizeOffset(_ offset: Int) {
        defaults.set(offset, forKey: Keys.fontSizeOffset)
    }

    public func loadHapticsEnabled() -> Bool {
        // Default to true if not set
        if defaults.object(forKey: Keys.hapticsEnabled) == nil {
            return true
        }
        return defaults.bool(forKey: Keys.hapticsEnabled)
    }

    public func saveHapticsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.hapticsEnabled)
    }

    public func loadShowFollowUpQuestions() -> Bool {
        // Default to true if not set
        if defaults.object(forKey: Keys.showFollowUpQuestions) == nil {
            return true
        }
        return defaults.bool(forKey: Keys.showFollowUpQuestions)
    }

    public func saveShowFollowUpQuestions(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.showFollowUpQuestions)
    }

    public func loadAutoDeleteDays() -> Int {
        // Default to 30 days if not set, 0 means never delete
        if defaults.object(forKey: Keys.autoDeleteDays) == nil {
            return 30
        }
        return defaults.integer(forKey: Keys.autoDeleteDays)
    }

    public func saveAutoDeleteDays(_ days: Int) {
        defaults.set(days, forKey: Keys.autoDeleteDays)
    }

    private func defaultConfigurations() -> [AnyProviderConfiguration] {
        [
            .onDevice(OnDeviceConfig()),
            .local(LocalOllamaConfig()),
            .cloud(OllamaCloudConfig()),
            .openRouter(OpenRouterConfig())
        ]
    }
}
