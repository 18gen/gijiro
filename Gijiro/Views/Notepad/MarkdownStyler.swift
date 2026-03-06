//
//  MarkdownStyler.swift
//  Gijiro
//

import AppKit

struct MarkdownStyler {
    let theme: MarkdownTheme
    private let rules: [MarkdownRule]

    init(theme: MarkdownTheme = .default) {
        self.theme = theme
        self.rules = Self.buildRules(theme: theme)
    }

    // MARK: - Public API

    func applyStyles(to textStorage: NSTextStorage, in editedRange: NSRange) {
        let string = textStorage.string as NSString

        // Expand to paragraph boundaries
        let paragraphRange = string.paragraphRange(for: editedRange)
        let workRange = paragraphRange

        guard workRange.length > 0 else { return }

        // Reset to body style
        let bodyAttributes = baseAttributes()
        textStorage.setAttributes(bodyAttributes, range: workRange)

        // Apply each rule in priority order
        for rule in rules {
            rule.apply(to: textStorage, in: workRange)
        }
    }

    func applyFullDocument(_ textStorage: NSTextStorage) {
        let fullRange = NSRange(location: 0, length: (textStorage.string as NSString).length)
        guard fullRange.length > 0 else { return }
        let bodyAttributes = baseAttributes()
        textStorage.setAttributes(bodyAttributes, range: fullRange)
        for rule in rules {
            rule.apply(to: textStorage, in: fullRange)
        }
    }

    // MARK: - Base Attributes

    private func baseAttributes() -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = theme.bodyLineSpacing
        return [
            .font: theme.bodyFont,
            .foregroundColor: theme.textColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    // MARK: - Rule Builder

    /// Helper to apply hidden attributes (clear color + tiny font) to a syntax marker range
    private static func hideSyntax(_ ts: NSMutableAttributedString, range: NSRange, theme: MarkdownTheme) {
        ts.addAttributes([
            .foregroundColor: theme.hiddenColor,
            .font: theme.hiddenFont
        ], range: range)
    }

    private static func buildRules(theme: MarkdownTheme) -> [MarkdownRule] {
        var rules: [MarkdownRule] = []

        // --- Headings ---

        let headingParagraphStyle = NSMutableParagraphStyle()
        headingParagraphStyle.lineSpacing = theme.headingLineSpacing

        // H1: # text
        if let regex = try? NSRegularExpression(pattern: "^(#{1} )(.*)$", options: .anchorsMatchLines) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                ts.addAttributes([
                    .font: theme.heading1Font,
                    .paragraphStyle: headingParagraphStyle
                ], range: match.range)
                hideSyntax(ts, range: match.range(at: 1), theme: theme)
            })
        }

        // H2: ## text
        if let regex = try? NSRegularExpression(pattern: "^(#{2} )(.*)$", options: .anchorsMatchLines) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                ts.addAttributes([
                    .font: theme.heading2Font,
                    .paragraphStyle: headingParagraphStyle
                ], range: match.range)
                hideSyntax(ts, range: match.range(at: 1), theme: theme)
            })
        }

        // H3: ### text
        if let regex = try? NSRegularExpression(pattern: "^(#{3} )(.*)$", options: .anchorsMatchLines) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                ts.addAttributes([
                    .font: theme.heading3Font,
                    .paragraphStyle: headingParagraphStyle
                ], range: match.range)
                hideSyntax(ts, range: match.range(at: 1), theme: theme)
            })
        }

        // --- Emphasis ---

        // Bold+Italic: ***text***
        if let regex = try? NSRegularExpression(pattern: "(\\*{3})(.+?)(\\*{3})", options: []) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                ts.addAttribute(.font, value: theme.boldItalicFont, range: match.range(at: 2))
                hideSyntax(ts, range: match.range(at: 1), theme: theme)
                hideSyntax(ts, range: match.range(at: 3), theme: theme)
            })
        }

        // Bold: **text**
        if let regex = try? NSRegularExpression(pattern: "(\\*{2})(.+?)(\\*{2})", options: []) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                ts.addAttribute(.font, value: theme.boldFont, range: match.range(at: 2))
                hideSyntax(ts, range: match.range(at: 1), theme: theme)
                hideSyntax(ts, range: match.range(at: 3), theme: theme)
            })
        }

        // Italic: *text*
        if let regex = try? NSRegularExpression(pattern: "(?<!\\*)(\\*)(.+?)(\\*)(?!\\*)", options: []) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                ts.addAttribute(.font, value: theme.italicFont, range: match.range(at: 2))
                hideSyntax(ts, range: match.range(at: 1), theme: theme)
                hideSyntax(ts, range: match.range(at: 3), theme: theme)
            })
        }

        // Strikethrough: ~~text~~
        if let regex = try? NSRegularExpression(pattern: "(~~)(.+?)(~~)", options: []) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                ts.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: match.range(at: 2))
                hideSyntax(ts, range: match.range(at: 1), theme: theme)
                hideSyntax(ts, range: match.range(at: 3), theme: theme)
            })
        }

        // --- Inline Code ---

        // `code`
        if let regex = try? NSRegularExpression(pattern: "(?<!`)(`)([^`]+)(`)(?!`)", options: []) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                ts.addAttributes([
                    .font: theme.codeFont,
                    .backgroundColor: theme.codeBackground
                ], range: match.range(at: 2))
                hideSyntax(ts, range: match.range(at: 1), theme: theme)
                hideSyntax(ts, range: match.range(at: 3), theme: theme)
            })
        }

        // --- Lists (matching visual prefixes) ---

        let S = BlockCommand.Symbols.self
        // To-Do: ☐ item, ☑ item
        if let regex = try? NSRegularExpression(pattern: "^([ \\t]*)(\(S.todoUnchecked) |\(S.todoChecked) )(.*)$", options: .anchorsMatchLines) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                let paraStyle = NSMutableParagraphStyle()
                paraStyle.lineSpacing = theme.bodyLineSpacing
                paraStyle.headIndent = theme.listIndent
                paraStyle.firstLineHeadIndent = 0
                ts.addAttribute(.paragraphStyle, value: paraStyle, range: match.range)
            })
        }

        // Unordered: • item
        if let regex = try? NSRegularExpression(pattern: "^([ \\t]*)(\(S.bullet) )(.*)$", options: .anchorsMatchLines) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                let paraStyle = NSMutableParagraphStyle()
                paraStyle.lineSpacing = theme.bodyLineSpacing
                paraStyle.headIndent = theme.listIndent
                paraStyle.firstLineHeadIndent = 0
                ts.addAttribute(.paragraphStyle, value: paraStyle, range: match.range)
            })
        }

        // Ordered: 1. item (numbers stay visible as the indicator)
        if let regex = try? NSRegularExpression(pattern: "^([ \\t]*)(\\d+\\. )(.*)$", options: .anchorsMatchLines) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                let paraStyle = NSMutableParagraphStyle()
                paraStyle.lineSpacing = theme.bodyLineSpacing
                paraStyle.headIndent = theme.listIndent
                paraStyle.firstLineHeadIndent = 0
                ts.addAttribute(.paragraphStyle, value: paraStyle, range: match.range)
            })
        }

        // --- Links ---

        // [text](url)
        if let regex = try? NSRegularExpression(pattern: "(\\[)(.+?)(\\]\\()(.+?)(\\))", options: []) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                ts.addAttributes([
                    .foregroundColor: theme.linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ], range: match.range(at: 2))
                // Hide syntax characters
                for group in [1, 3, 4, 5] {
                    let r = match.range(at: group)
                    if r.location != NSNotFound {
                        hideSyntax(ts, range: r, theme: theme)
                    }
                }
            })
        }

        return rules
    }
}

// MARK: - MarkdownRule

private struct MarkdownRule {
    let regex: NSRegularExpression
    let applier: (NSTextCheckingResult, NSMutableAttributedString) -> Void

    init(regex: NSRegularExpression, applier: @escaping (NSTextCheckingResult, NSMutableAttributedString) -> Void) {
        self.regex = regex
        self.applier = applier
    }

    func apply(to textStorage: NSTextStorage, in range: NSRange) {
        regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
            guard let match else { return }
            applier(match, textStorage)
        }
    }
}
