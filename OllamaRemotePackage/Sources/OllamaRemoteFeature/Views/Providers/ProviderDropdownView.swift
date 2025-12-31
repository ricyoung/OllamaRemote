import SwiftUI

public struct ProviderDropdownView: View {
    @Environment(AppState.self) private var appState

    public init() {}

    private var enabledProviders: [AnyProviderConfiguration] {
        appState.providerConfigurations.filter { $0.isEnabled }
    }

    public var body: some View {
        Menu {
            ForEach(enabledProviders) { config in
                Button {
                    appState.selectProvider(config.id)
                } label: {
                    Label(config.displayName, systemImage: config.type.iconName)
                    if config.id == appState.selectedProviderId {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let provider = appState.activeProvider {
                    Image(systemName: provider.type.iconName)
                        .symbolRenderingMode(.hierarchical)
                    Text(provider.displayName)
                        .lineLimit(1)
                } else {
                    Text("Select Provider")
                }
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            }
        }
    }
}
