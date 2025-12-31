import SwiftUI
import MarkdownView

public struct MarkdownTextView: View {
    let content: String
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    public init(content: String) {
        self.content = content
    }

    public var body: some View {
        MarkdownView(content)
            .font(.system(size: baseFontSize + CGFloat(appState.fontSizeOffset * 2)))
            .tint(.accentColor)
            .textSelection(.enabled)
    }

    private var baseFontSize: CGFloat {
        17 // Default iOS body font size
    }
}
