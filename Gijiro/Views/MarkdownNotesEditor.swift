import SwiftUI
import AppKit

struct MarkdownNotesEditor: View {
    @Binding var text: String
    @State private var editorHasContent = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            IMETextEditor(text: $text, hasContent: $editorHasContent)

            if !editorHasContent {
                Text("Write notes...")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - NSTextView wrapper with IME support and live markdown styling

struct IMETextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var hasContent: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = IMEFriendlyTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 12, height: 12)

        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        textView.delegate = context.coordinator
        scrollView.documentView = textView
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.markedRange().location == NSNotFound {
            if textView.string != text {
                let selectedRanges = textView.selectedRanges
                textView.string = text
                textView.selectedRanges = selectedRanges
                context.coordinator.applyMarkdownStyling(textView)
            }
        }

        hasContent = !textView.string.isEmpty
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: IMETextEditor
        weak var textView: NSTextView?
        private var isStyling = false

        init(parent: IMETextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isStyling else { return }
            guard let textView = notification.object as? NSTextView else { return }

            parent.hasContent = !textView.string.isEmpty

            if textView.markedRange().location == NSNotFound {
                parent.text = textView.string
                applyMarkdownStyling(textView)
            }
        }

        func applyMarkdownStyling(_ textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let text = textView.string
            guard !text.isEmpty else { return }

            isStyling = true
            defer { isStyling = false }

            let selectedRanges = textView.selectedRanges
            let fullRange = NSRange(location: 0, length: textStorage.length)

            let bodyFont = NSFont.systemFont(ofSize: 14)

            textStorage.beginEditing()

            // Reset to defaults
            textStorage.setAttributes([
                .font: bodyFont,
                .foregroundColor: NSColor.labelColor,
            ], range: fullRange)

            let nsText = text as NSString

            // Line-level formatting (headers, list bullets)
            nsText.enumerateSubstrings(in: fullRange, options: .byLines) { line, lineRange, _, _ in
                guard let line else { return }

                if line.hasPrefix("### ") {
                    textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 16, weight: .semibold), range: lineRange)
                    let prefixLen = min(4, lineRange.length)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: NSRange(location: lineRange.location, length: prefixLen))
                } else if line.hasPrefix("## ") {
                    textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 18, weight: .semibold), range: lineRange)
                    let prefixLen = min(3, lineRange.length)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: NSRange(location: lineRange.location, length: prefixLen))
                } else if line.hasPrefix("# ") {
                    textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 22, weight: .bold), range: lineRange)
                    let prefixLen = min(2, lineRange.length)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: NSRange(location: lineRange.location, length: prefixLen))
                }

                // List bullets: dim prefix
                if line.hasPrefix("- ") || line.hasPrefix("* ") {
                    let prefixLen = min(2, lineRange.length)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: NSRange(location: lineRange.location, length: prefixLen))
                }

                // Numbered lists: dim prefix (e.g. "1. ")
                if let match = try? NSRegularExpression(pattern: "^\\d+\\.\\s").firstMatch(in: text, range: lineRange) {
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: match.range)
                }
            }

            // Bold: **text**
            if let regex = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*") {
                regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                    guard let matchRange = match?.range, let contentRange = match?.range(at: 1) else { return }
                    let currentFont = textStorage.attribute(.font, at: contentRange.location, effectiveRange: nil) as? NSFont ?? bodyFont
                    textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: currentFont.pointSize, weight: .bold), range: contentRange)
                    // Dim ** markers
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor,
                                             range: NSRange(location: matchRange.location, length: 2))
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor,
                                             range: NSRange(location: matchRange.location + matchRange.length - 2, length: 2))
                }
            }

            // Italic: *text* (not part of **)
            if let regex = try? NSRegularExpression(pattern: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)") {
                regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                    guard let matchRange = match?.range, let contentRange = match?.range(at: 1) else { return }
                    let currentFont = textStorage.attribute(.font, at: contentRange.location, effectiveRange: nil) as? NSFont ?? bodyFont
                    let italic = NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
                    textStorage.addAttribute(.font, value: italic, range: contentRange)
                    // Dim * markers
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor,
                                             range: NSRange(location: matchRange.location, length: 1))
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor,
                                             range: NSRange(location: matchRange.location + matchRange.length - 1, length: 1))
                }
            }

            // Inline code: `code`
            if let regex = try? NSRegularExpression(pattern: "`([^`]+)`") {
                regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                    guard let matchRange = match?.range else { return }
                    textStorage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: matchRange)
                    textStorage.addAttribute(.backgroundColor, value: NSColor.quaternaryLabelColor, range: matchRange)
                    // Dim backticks
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor,
                                             range: NSRange(location: matchRange.location, length: 1))
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor,
                                             range: NSRange(location: matchRange.location + matchRange.length - 1, length: 1))
                }
            }

            // Strikethrough: ~~text~~
            if let regex = try? NSRegularExpression(pattern: "~~(.+?)~~") {
                regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                    guard let matchRange = match?.range, let contentRange = match?.range(at: 1) else { return }
                    textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: matchRange)
                }
            }

            textStorage.endEditing()

            // Reset typing attributes so new text uses default font
            textView.typingAttributes = [
                .font: bodyFont,
                .foregroundColor: NSColor.labelColor,
            ]

            textView.selectedRanges = selectedRanges
        }
    }
}

// MARK: - NSTextView subclass for IME awareness

final class IMEFriendlyTextView: NSTextView {
    var onResignFirstResponder: (() -> Void)?

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            onResignFirstResponder?()
        }
        return result
    }
}
