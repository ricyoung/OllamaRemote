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
            if isApiKeyVisible {
                TextField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                SecureField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Toggle("Show API Key", isOn: $isApiKeyVisible)
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
            if isApiKeyVisible {
                TextField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                SecureField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Toggle("Show API Key", isOn: $isApiKeyVisible)
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
            Text("Download models to run completely offline using the Neural Engine.")
        }

        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Neural Engine Powered", systemImage: "bolt.fill")
                    .font(.subheadline)
                    .foregroundStyle(.tint)

                Text("Core ML models run on Apple's Neural Engine for maximum efficiency and speed. No internet required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func loadConfiguration() {
        displayName = configuration.displayName
        isEnabled = configuration.isEnabled

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
        }
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
            }

        case .openRouter(var config):
            config.displayName = displayName
            config.isEnabled = isEnabled
            config.preferFreeModels = preferFreeModels
            updatedConfig = .openRouter(config)
            Task {
                try? await KeychainService.shared.store(key: config.apiKeyReference, value: apiKey)
            }

        case .onDevice(var config):
            config.displayName = displayName
            config.isEnabled = isEnabled
            updatedConfig = .onDevice(config)
        }

        appState.updateProviderConfiguration(updatedConfig)
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
