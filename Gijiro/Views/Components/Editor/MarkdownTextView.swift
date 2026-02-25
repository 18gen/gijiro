import SwiftUI
import AppKit

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()

        let tv = NSTextView()
        tv.isEditable = true
        tv.isSelectable = true
        tv.isRichText = true
        tv.drawsBackground = false

        tv.font = .systemFont(ofSize: 14)
        tv.textColor = .labelColor

        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false

        tv.delegate = context.coordinator
        scroll.documentView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? NSTextView else { return }
        guard tv.markedRange().location == NSNotFound else { return } // IME-safe

        if tv.string != text {
            tv.string = text
            MarkdownFormatter.apply(to: tv)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        private var isInternalEdit = false

        init(text: Binding<String>) { _text = text }

        func textDidChange(_ notification: Notification) {
            guard !isInternalEdit, let tv = notification.object as? NSTextView else { return }

            // IME-safe
            if tv.markedRange().location != NSNotFound {
                text = tv.string
                return
            }

            isInternalEdit = true
            defer { isInternalEdit = false }

            MarkdownShortcuts.apply(to: tv)
            text = tv.string
            MarkdownFormatter.apply(to: tv)
        }
    }
}
