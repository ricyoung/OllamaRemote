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
        static let defaultModelIds = "defaultModelIds"
        static let configuredProviderIds = "configuredProviderIds"
    }

    private init() {}

    public func loadProviderConfigurations() -> [AnyProviderConfiguration] {
        guard let data = defaults.data(forKey: Keys.providerConfigs),
              let configs = try? decoder.decode([AnyProviderConfiguration].self, from: data) else {
            return defaultConfigurations()
        }

        // Ensure new providers are added to existing configs
        var updatedConfigs = configs
        let existingTypes = Set(configs.map { $0.type })

        // Add Apple Intelligence if not present
        if !existingTypes.contains(.appleIntelligence) {
            updatedConfigs.insert(.appleIntelligence(AppleIntelligenceConfig()), at: 0)
        }

        // Add On-Device MLX if not present
        if !existingTypes.contains(.onDevice) {
            let insertIndex = updatedConfigs.firstIndex { $0.type != .appleIntelligence } ?? updatedConfigs.endIndex
            updatedConfigs.insert(.onDevice(OnDeviceConfig()), at: insertIndex)
        }

        // Add OpenClaw if not present
        if !existingTypes.contains(.openClaw) {
            updatedConfigs.append(.openClaw(OpenClawConfig()))
        }

        return updatedConfigs.isEmpty ? defaultConfigurations() : updatedConfigs
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

    // MARK: - Default Model per Provider

    public func loadDefaultModelIds() -> [String: String] {
        guard let data = defaults.data(forKey: Keys.defaultModelIds),
              let dict = try? decoder.decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    public func saveDefaultModelIds(_ ids: [String: String]) {
        if let data = try? encoder.encode(ids) {
            defaults.set(data, forKey: Keys.defaultModelIds)
        }
    }

    // MARK: - Configured Provider IDs

    public func loadConfiguredProviderIds() -> Set<String> {
        guard let data = defaults.data(forKey: Keys.configuredProviderIds),
              let set = try? decoder.decode(Set<String>.self, from: data) else {
            return []
        }
        return set
    }

    public func saveConfiguredProviderIds(_ ids: Set<String>) {
        if let data = try? encoder.encode(ids) {
            defaults.set(data, forKey: Keys.configuredProviderIds)
        }
    }

    private func defaultConfigurations() -> [AnyProviderConfiguration] {
        [
            .appleIntelligence(AppleIntelligenceConfig()),
            .onDevice(OnDeviceConfig()),
            .local(LocalOllamaConfig()),
            .cloud(OllamaCloudConfig()),
            .openRouter(OpenRouterConfig()),
            .openClaw(OpenClawConfig())
        ]
    }
}
