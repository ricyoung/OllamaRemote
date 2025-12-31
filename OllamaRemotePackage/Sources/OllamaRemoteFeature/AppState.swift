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

    private let settingsStore: SettingsStore
    private let providerFactory: ProviderFactory

    public var enabledProviders: [AnyProviderConfiguration] {
        providerConfigurations.filter { $0.isEnabled }
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
        selectedModelId = nil
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
            if selectedModelId == nil, let first = availableModels.first {
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
}
