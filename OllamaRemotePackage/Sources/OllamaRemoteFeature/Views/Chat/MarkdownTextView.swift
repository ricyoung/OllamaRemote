import SwiftUI

public struct MarkdownTextView: View {
    let content: String
    @Environment(AppState.self) private var appState

    public init(content: String) {
        self.content = content
    }

    public var body: some View {
        Text(attributedContent)
            .font(.system(size: baseFontSize + CGFloat(appState.fontSizeOffset * 2)))
            .textSelection(.enabled)
    }

    private var baseFontSize: CGFloat {
        17 // Default iOS body font size
    }

    private var attributedContent: AttributedString {
        (try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(content)
    }
}
