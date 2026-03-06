//
//  TextTransformer.swift
//  Gijiro
//

import AppKit

struct TextTransformer {
    weak var textView: NSTextView?
    var onTransform: (() -> Void)?

    func applyBlockCommand(_ command: BlockCommand) {
        guard let textView, let textStorage = textView.textStorage else { return }

        let string = textStorage.string as NSString
        let cursorRange = textView.selectedRange()
        let lineRange = string.lineRange(for: cursorRange)
        let lineContent = string.substring(with: lineRange)

        // Strip existing block prefix
        var stripped = lineContent
        if let match = BlockCommand.prefixPattern.firstMatch(
            in: lineContent, range: NSRange(location: 0, length: lineContent.utf16.count)
        ) {
            stripped = String((lineContent as NSString).substring(from: match.range.upperBound))
        }

        // Build new line (use visual prefix for display)
        let newLine = command.visualPrefix + stripped

        if textView.shouldChangeText(in: lineRange, replacementString: newLine) {
            textStorage.replaceCharacters(in: lineRange, with: newLine)
            textView.didChangeText()
        }

        // Position cursor at end of content
        let cursorPos = lineRange.location + newLine.count - (newLine.hasSuffix("\n") ? 1 : 0)
        textView.setSelectedRange(NSRange(location: cursorPos, length: 0))

        onTransform?()
    }

    func applyInlineFormat(_ format: InlineFormat) {
        guard let textView, let textStorage = textView.textStorage else { return }

        let selectedRange = textView.selectedRange()
        guard selectedRange.length > 0 else { return }

        let selectedText = (textStorage.string as NSString).substring(with: selectedRange)
        let (prefix, suffix) = format.wrapper
        let replacement = prefix + selectedText + suffix

        if textView.shouldChangeText(in: selectedRange, replacementString: replacement) {
            textStorage.replaceCharacters(in: selectedRange, with: replacement)
            textView.didChangeText()
        }

        // Re-select the wrapped text (excluding syntax markers)
        let newStart = selectedRange.location + prefix.utf16.count
        textView.setSelectedRange(NSRange(location: newStart, length: selectedText.utf16.count))

        onTransform?()
    }
}
