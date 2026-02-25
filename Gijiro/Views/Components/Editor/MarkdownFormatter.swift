//
//  MarkdownFormatter.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-24.
//

import AppKit

enum MarkdownFormatter {
    static func apply(to tv: NSTextView) {
        guard let storage = tv.textStorage else { return }

        let text = tv.string
        let full = NSRange(location: 0, length: storage.length)

        let baseFont = NSFont.systemFont(ofSize: MarkdownTextViewStyle.fontSize)
        let selected = tv.selectedRanges

        storage.beginEditing()
        defer {
            storage.endEditing()
            tv.selectedRanges = selected
            tv.typingAttributes = [
                .font: baseFont,
                .foregroundColor: NSColor.labelColor
            ]
        }

        // reset
        storage.setAttributes([
            .font: baseFont,
            .foregroundColor: NSColor.labelColor
        ], range: full)

        let ns = text as NSString

        // headings + list prefixes
        ns.enumerateSubstrings(in: full, options: .byLines) { line, lineRange, _, _ in
            guard let line else { return }

            if line.hasPrefix("# ") {
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 22, weight: .bold), range: lineRange)
                dimPrefix(storage, lineRange: lineRange, prefixLength: 2)
            } else if line.hasPrefix("## ") {
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 18, weight: .semibold), range: lineRange)
                dimPrefix(storage, lineRange: lineRange, prefixLength: 3)
            } else if line.hasPrefix("### ") {
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 16, weight: .semibold), range: lineRange)
                dimPrefix(storage, lineRange: lineRange, prefixLength: 4)
            }

            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                dimPrefix(storage, lineRange: lineRange, prefixLength: 2)
            }
        }

        // bold **text**
        if let regex = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*") {
            regex.enumerateMatches(in: text, range: full) { match, _, _ in
                guard let m = match else { return }

                let content = m.range(at: 1)
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: baseFont.pointSize, weight: .bold), range: content)

                // dim markers
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor,
                                     range: NSRange(location: m.range.location, length: 2))
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor,
                                     range: NSRange(location: m.range.location + m.range.length - 2, length: 2))
            }
        }
    }

    private static func dimPrefix(_ storage: NSTextStorage, lineRange: NSRange, prefixLength: Int) {
        let len = min(prefixLength, lineRange.length)
        guard len > 0 else { return }
        storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor,
                             range: NSRange(location: lineRange.location, length: len))
    }
}
