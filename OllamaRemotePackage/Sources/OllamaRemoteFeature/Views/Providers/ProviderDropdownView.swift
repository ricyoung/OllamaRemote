import SwiftUI

public struct ProviderDropdownView: View {
    @Environment(AppState.self) private var appState
    @State private var isPressed = false

    public init() {}

    private var providerColor: Color {
        guard let provider = appState.activeProvider else { return .gray }
        switch provider.type {
        case .appleIntelligence: return .indigo
        case .onDevice: return .purple
        case .localOllama: return .blue
        case .ollamaCloud: return .cyan
        case .openRouter: return .orange
        }
    }

    public var body: some View {
        Menu {
            ForEach(appState.readyProviders) { config in
                Button {
                    appState.selectProvider(config.id)
                    if appState.hapticsEnabled {
                        HapticService.shared.lightTap()
                    }
                } label: {
                    HStack {
                        Label(config.displayName, systemImage: config.type.iconName)
                        if config.id == appState.selectedProviderId {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let provider = appState.activeProvider {
                    // Provider icon with gradient
                    ZStack {
                        Circle()
                            .fill(providerColor.gradient)
                            .frame(width: 24, height: 24)

                        Image(systemName: provider.type.iconName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Text(provider.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                } else {
                    Text("Select Provider")
                        .font(.subheadline)
                }

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [providerColor.opacity(0.3), providerColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: providerColor.opacity(0.15), radius: 8, y: 4)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .hoverEffect(.lift)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
