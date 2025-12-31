import SwiftUI

public struct SettingsView: View {
    @Environment(AppState.self) private var appState

    public init() {}

    public var body: some View {
        List {
            Section("Providers") {
                ForEach(appState.providerConfigurations) { config in
                    NavigationLink {
                        ProviderSettingsView(configuration: config)
                    } label: {
                        HStack {
                            Image(systemName: config.type.iconName)
                                .foregroundStyle(config.isEnabled ? .primary : .secondary)
                            Text(config.displayName)
                            Spacer()
                            if !config.isEnabled {
                                Text("Disabled")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://github.com")!) {
                    HStack {
                        Text("Source Code")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
}
