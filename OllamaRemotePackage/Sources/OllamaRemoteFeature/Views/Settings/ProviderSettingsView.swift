import SwiftUI

public struct ProviderSettingsView: View {
    let configuration: AnyProviderConfiguration
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var isEnabled: Bool = true
    @State private var host: String = ""
    @State private var port: String = ""
    @State private var apiKey: String = ""
    @State private var preferFreeModels: Bool = true
    @State private var isSaving = false
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var isApiKeyVisible = false
    @State private var availableModels: [LLMModel] = []
    @State private var isLoadingModels = false
    @State private var selectedDefaultModelId: String?

    enum TestResult {
        case success
        case failure(String)
    }

    public init(configuration: AnyProviderConfiguration) {
        self.configuration = configuration
    }

    public var body: some View {
        Form {
            Section("General") {
                TextField("Display Name", text: $displayName)
                Toggle("Enabled", isOn: $isEnabled)
            }

            switch configuration {
            case .local:
                localOllamaSection
            case .cloud:
                cloudSection
            case .openRouter:
                openRouterSection
            case .onDevice:
                onDeviceSection
            case .appleIntelligence:
                appleIntelligenceSection
            }

            Section {
                Button {
                    Task { await testConnection() }
                } label: {
                    HStack {
                        Text("Test Connection")
                        Spacer()
                        if isTesting {
                            ProgressView()
                        } else if let result = testResult {
                            switch result {
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            case .failure:
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
                .disabled(isTesting)

                if case .failure(let message) = testResult {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Default model section (not for on-device or Apple Intelligence)
            if configuration.type != .onDevice && configuration.type != .appleIntelligence {
                Section {
                    Button {
                        Task { await loadAvailableModels() }
                    } label: {
                        HStack {
                            Text("Load Models")
                            Spacer()
                            if isLoadingModels {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLoadingModels)

                    if !availableModels.isEmpty {
                        let freeModels = availableModels.filter { $0.isFree }
                        let paidModels = availableModels.filter { !$0.isFree }

                        Picker("Default Model", selection: $selectedDefaultModelId) {
                            Text("None").tag(nil as String?)

                            if !freeModels.isEmpty {
                                Section("Free Models") {
                                    ForEach(freeModels) { model in
                                        Text(model.name).tag(model.id as String?)
                                    }
                                }
                            }

                            if !paidModels.isEmpty {
                                Section("Paid Models") {
                                    ForEach(paidModels) { model in
                                        Text(model.name).tag(model.id as String?)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Default Model")
                } footer: {
                    Text("Loading models may take a few seconds depending on your connection. Set a default model to use when switching to this provider.")
                }
            }
        }
        .navigationTitle(configuration.type.displayName)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(isSaving)
            }
        }
        .onAppear {
            loadConfiguration()
        }
    }

    @ViewBuilder
    private var localOllamaSection: some View {
        Section("Connection") {
            TextField("Host", text: $host)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)

            TextField("Port", text: $port)
                .keyboardType(.numberPad)
        }
    }

    @ViewBuilder
    private var cloudSection: some View {
        Section("Authentication") {
            HStack {
                if isApiKeyVisible {
                    TextField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Button {
                    isApiKeyVisible.toggle()
                } label: {
                    Image(systemName: isApiKeyVisible ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }

        Section {
            Link(destination: URL(string: "https://ollama.com/settings/keys")!) {
                HStack {
                    Text("Get API Key")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
            }
        }
    }

    @ViewBuilder
    private var openRouterSection: some View {
        Section("Authentication") {
            HStack {
                if isApiKeyVisible {
                    TextField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Button {
                    isApiKeyVisible.toggle()
                } label: {
                    Image(systemName: isApiKeyVisible ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }

        Section("Options") {
            Toggle("Prefer Free Models", isOn: $preferFreeModels)
        }

        Section {
            Link(destination: URL(string: "https://openrouter.ai/keys")!) {
                HStack {
                    Text("Get API Key")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
            }
            Link(destination: URL(string: "https://openrouter.ai")!) {
                HStack {
                    Text("Visit OpenRouter")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
            }
        } footer: {
            Text("OpenRouter offers free LLMs when you sign up for an API key.")
        }
    }

    @ViewBuilder
    private var onDeviceSection: some View {
        Section {
            NavigationLink {
                LocalModelsView()
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.tint)
                    Text("Manage Local Models")
                    Spacer()
                    Text("\(LocalModelManager.shared.downloadedModels.count)")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Models")
        } footer: {
            Text("Download models to run completely offline using MLX.")
        }

        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("MLX Powered", systemImage: "bolt.fill")
                    .font(.subheadline)
                    .foregroundStyle(.tint)

                Text("MLX models run on Apple Silicon for efficient inference. Download models for offline use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var appleIntelligenceSection: some View {
        Section {
            HStack {
                Image(systemName: AppleIntelligenceProvider.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(AppleIntelligenceProvider.isAvailable ? .green : .red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Status")
                    Text(AppleIntelligenceProvider.isAvailable ? "Available" : "Not Available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let reason = AppleIntelligenceProvider.unavailabilityReason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Availability")
        } footer: {
            Text("Apple Intelligence is built into iOS 26 and requires no additional setup or downloads.")
        }

        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("On-Device Processing", systemImage: "cpu")
                    .font(.subheadline)
                    .foregroundStyle(.tint)

                Text("Apple Intelligence runs entirely on your device using Apple's 3B parameter model. No data is sent to external servers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func loadConfiguration() {
        displayName = configuration.displayName
        isEnabled = configuration.isEnabled
        selectedDefaultModelId = appState.getDefaultModel(for: configuration.id)

        switch configuration {
        case .local(let config):
            host = config.host
            port = String(config.port)
        case .cloud:
            Task {
                if let key = try? await KeychainService.shared.retrieve(key: configuration.apiKeyReference ?? "") {
                    apiKey = key
                }
            }
        case .openRouter(let config):
            preferFreeModels = config.preferFreeModels
            Task {
                if let key = try? await KeychainService.shared.retrieve(key: configuration.apiKeyReference ?? "") {
                    apiKey = key
                }
            }
        case .onDevice:
            break // No additional configuration needed
        case .appleIntelligence:
            break // No additional configuration needed
        }
    }

    private func loadAvailableModels() async {
        isLoadingModels = true

        // Build config from current form values for accurate test
        var testConfig: AnyProviderConfiguration
        switch configuration {
        case .local(var config):
            config.host = host
            config.port = Int(port) ?? 11434
            testConfig = .local(config)

        case .cloud(let config):
            if !apiKey.isEmpty {
                try? await KeychainService.shared.store(key: config.apiKeyReference, value: apiKey)
            }
            testConfig = .cloud(config)

        case .openRouter(let config):
            if !apiKey.isEmpty {
                try? await KeychainService.shared.store(key: config.apiKeyReference, value: apiKey)
            }
            testConfig = .openRouter(config)

        case .onDevice:
            testConfig = configuration

        case .appleIntelligence:
            testConfig = configuration
        }

        ProviderFactory.shared.clearCache()
        let provider = ProviderFactory.shared.provider(for: testConfig)

        do {
            availableModels = try await provider.fetchModels()
        } catch {
            availableModels = []
        }

        isLoadingModels = false
    }

    private func save() {
        var updatedConfig: AnyProviderConfiguration

        switch configuration {
        case .local(var config):
            config.displayName = displayName
            config.isEnabled = isEnabled
            config.host = host
            config.port = Int(port) ?? 11434
            updatedConfig = .local(config)

        case .cloud(var config):
            config.displayName = displayName
            config.isEnabled = isEnabled
            updatedConfig = .cloud(config)
            Task {
                try? await KeychainService.shared.store(key: config.apiKeyReference, value: apiKey)
                // Mark as configured if API key is set
                if !apiKey.isEmpty {
                    await MainActor.run { appState.markProviderConfigured(config.id) }
                } else {
                    await MainActor.run { appState.markProviderUnconfigured(config.id) }
                }
            }

        case .openRouter(var config):
            config.displayName = displayName
            config.isEnabled = isEnabled
            config.preferFreeModels = preferFreeModels
            updatedConfig = .openRouter(config)
            Task {
                try? await KeychainService.shared.store(key: config.apiKeyReference, value: apiKey)
                // Mark as configured if API key is set
                if !apiKey.isEmpty {
                    await MainActor.run { appState.markProviderConfigured(config.id) }
                } else {
                    await MainActor.run { appState.markProviderUnconfigured(config.id) }
                }
            }

        case .onDevice(var config):
            config.displayName = displayName
            config.isEnabled = isEnabled
            updatedConfig = .onDevice(config)

        case .appleIntelligence(var config):
            config.displayName = displayName
            config.isEnabled = isEnabled
            updatedConfig = .appleIntelligence(config)
        }

        appState.updateProviderConfiguration(updatedConfig)

        // Save default model selection
        appState.setDefaultModel(selectedDefaultModelId, for: configuration.id)

        dismiss()
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil

        // Build config from current form values
        let testConfig: AnyProviderConfiguration
        switch configuration {
        case .local(var config):
            config.host = host
            config.port = Int(port) ?? 11434
            testConfig = .local(config)

        case .cloud(let config):
            // Save API key to keychain first
            if !apiKey.isEmpty {
                try? await KeychainService.shared.store(key: config.apiKeyReference, value: apiKey)
            }
            testConfig = .cloud(config)

        case .openRouter(let config):
            // Save API key to keychain first
            if !apiKey.isEmpty {
                try? await KeychainService.shared.store(key: config.apiKeyReference, value: apiKey)
            }
            testConfig = .openRouter(config)

        case .onDevice:
            testConfig = configuration

        case .appleIntelligence:
            testConfig = configuration
        }

        // Clear cache to ensure fresh provider with new credentials
        ProviderFactory.shared.clearCache()

        let provider = ProviderFactory.shared.provider(for: testConfig)
        do {
            _ = try await provider.testConnection()
            testResult = .success
        } catch {
            testResult = .failure(error.localizedDescription)
        }

        isTesting = false
    }
}
