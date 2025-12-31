import UIKit

@MainActor
public final class HapticService {
    public static let shared = HapticService()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    private init() {
        // Prepare generators for faster response
        impactLight.prepare()
        impactMedium.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }

    /// Light tap feedback - for button taps, selections
    public func lightTap() {
        impactLight.impactOccurred()
    }

    /// Medium tap feedback - for sending messages, completing actions
    public func mediumTap() {
        impactMedium.impactOccurred()
    }

    /// Success feedback - for successful operations
    public func success() {
        notificationGenerator.notificationOccurred(.success)
    }

    /// Error feedback - for failed operations
    public func error() {
        notificationGenerator.notificationOccurred(.error)
    }

    /// Warning feedback - for warnings
    public func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }

    /// Selection changed feedback - for picker/toggle changes
    public func selection() {
        selectionGenerator.selectionChanged()
    }
}
