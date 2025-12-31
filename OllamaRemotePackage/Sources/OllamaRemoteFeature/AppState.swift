import Foundation
import SwiftUI

@Observable
@MainActor
public final class AppState {
    public var selectedProviderId: UUID?
    public var providerConfigurations: [AnyProviderConfiguration] = []
    public var selectedConversation: Conversation?
    public var availableModels: [LLMModel] = []
    public var selectedModelId: String?
    public var isLoadingModels = false
    public var modelError: Error?
    public var autoSaveChats: Bool = true
    public var pendingMessage: String?
    public var fontSizeOffset: Int = 0 // -2 to +2
    public var hapticsEnabled: Bool = true
    public var showFollowUpQuestions: Bool = true
    public var autoDeleteDays: Int = 30 // 0 = never delete
    public var defaultModelIds: [String: String] = [:] // providerId -> modelId
    public var configuredProviderIds: Set<String> = [] // providers with API keys set
    public var showInspector: Bool = false // iPad inspector panel

    private let settingsStore: SettingsStore
    private let providerFactory: ProviderFactory

    public var enabledProviders: [AnyProviderConfiguration] {
        providerConfigurations.filter { $0.isEnabled }
    }

    /// Providers that are enabled AND properly configured (have API keys or don't need them)
    public var readyProviders: [AnyProviderConfiguration] {
        enabledProviders.filter { isProviderConfigured($0) }
    }

    /// Check if a provider is properly configured to be used
    public func isProviderConfigured(_ config: AnyProviderConfiguration) -> Bool {
        switch config.type {
        case .localOllama:
            // Local Ollama is always ready (uses default host/port)
            return true
        case .ollamaCloud, .openRouter:
            // Cloud providers need API key
            return configuredProviderIds.contains(config.id.uuidString)
        case .onDevice:
            // On-device needs at least one downloaded model
            return !LocalModelManager.shared.downloadedModels.isEmpty
        }
    }

    public var activeProvider: AnyProviderConfiguration? {
        guard let id = selectedProviderId,
              let provider = providerConfigurations.first(where: { $0.id == id }),
              provider.isEnabled else {
            return enabledProviders.first
        }
        return provider
    }

    public init(
        settingsStore: SettingsStore = .shared,
        providerFactory: ProviderFactory = .shared
    ) {
        self.settingsStore = settingsStore
        self.providerFactory = providerFactory
        loadConfigurations()
        autoSaveChats = settingsStore.loadAutoSaveChats()
        fontSizeOffset = settingsStore.loadFontSizeOffset()
        hapticsEnabled = settingsStore.loadHapticsEnabled()
        showFollowUpQuestions = settingsStore.loadShowFollowUpQuestions()
        autoDeleteDays = settingsStore.loadAutoDeleteDays()
        defaultModelIds = settingsStore.loadDefaultModelIds()
        configuredProviderIds = settingsStore.loadConfiguredProviderIds()
    }

    public func loadConfigurations() {
        providerConfigurations = settingsStore.loadProviderConfigurations()
        let savedId = settingsStore.loadSelectedProviderId()

        // Use saved ID if that provider is enabled, otherwise use first enabled provider
        if let savedId, providerConfigurations.first(where: { $0.id == savedId })?.isEnabled == true {
            selectedProviderId = savedId
        } else {
            selectedProviderId = enabledProviders.first?.id
        }
    }

    public func saveConfigurations() {
        settingsStore.saveProviderConfigurations(providerConfigurations)
        settingsStore.saveSelectedProviderId(selectedProviderId)
    }

    public func selectProvider(_ id: UUID) {
        selectedProviderId = id
        // Use default model for this provider if set
        selectedModelId = defaultModelIds[id.uuidString]
        availableModels = []
        saveConfigurations()
    }

    public func loadModels() async {
        guard let config = activeProvider else { return }

        isLoadingModels = true
        modelError = nil

        let provider = providerFactory.provider(for: config)
        do {
            availableModels = try await provider.fetchModels()
            // Use default model for this provider, or first available
            let providerId = config.id.uuidString
            if let defaultId = defaultModelIds[providerId],
               availableModels.contains(where: { $0.id == defaultId }) {
                selectedModelId = defaultId
            } else if selectedModelId == nil, let first = availableModels.first {
                selectedModelId = first.id
            }
        } catch {
            modelError = error
            availableModels = []
        }

        isLoadingModels = false
    }

    public func updateProviderConfiguration(_ config: AnyProviderConfiguration) {
        if let index = providerConfigurations.firstIndex(where: { $0.id == config.id }) {
            providerConfigurations[index] = config

            // If the disabled provider was selected, switch to first enabled
            if config.id == selectedProviderId && !config.isEnabled {
                selectedProviderId = enabledProviders.first?.id
                selectedModelId = nil
                availableModels = []
            }

            saveConfigurations()
            providerFactory.clearCache()
        }
    }

    public func setAutoSaveChats(_ enabled: Bool) {
        autoSaveChats = enabled
        settingsStore.saveAutoSaveChats(enabled)
    }

    public func setFontSizeOffset(_ offset: Int) {
        fontSizeOffset = max(-2, min(2, offset))
        settingsStore.saveFontSizeOffset(fontSizeOffset)
    }

    public func setHapticsEnabled(_ enabled: Bool) {
        hapticsEnabled = enabled
        settingsStore.saveHapticsEnabled(enabled)
    }

    public func setShowFollowUpQuestions(_ enabled: Bool) {
        showFollowUpQuestions = enabled
        settingsStore.saveShowFollowUpQuestions(enabled)
    }

    public func setAutoDeleteDays(_ days: Int) {
        autoDeleteDays = max(0, days)
        settingsStore.saveAutoDeleteDays(autoDeleteDays)
    }

    // MARK: - Default Model per Provider

    public func setDefaultModel(_ modelId: String?, for providerId: UUID) {
        let key = providerId.uuidString
        if let modelId {
            defaultModelIds[key] = modelId
        } else {
            defaultModelIds.removeValue(forKey: key)
        }
        settingsStore.saveDefaultModelIds(defaultModelIds)
    }

    public func getDefaultModel(for providerId: UUID) -> String? {
        defaultModelIds[providerId.uuidString]
    }

    // MARK: - Provider Configuration Status

    public func markProviderConfigured(_ providerId: UUID) {
        configuredProviderIds.insert(providerId.uuidString)
        settingsStore.saveConfiguredProviderIds(configuredProviderIds)
    }

    public func markProviderUnconfigured(_ providerId: UUID) {
        configuredProviderIds.remove(providerId.uuidString)
        settingsStore.saveConfiguredProviderIds(configuredProviderIds)
    }
}
