import SwiftUI

public struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let activities: [UIActivity]?

    public init(items: [Any], activities: [UIActivity]? = nil) {
        self.items = items
        self.activities = activities
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: activities)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
