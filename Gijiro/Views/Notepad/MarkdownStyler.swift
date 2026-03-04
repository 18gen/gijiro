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
        let fullRange = NSRange(location: 0, length: string.length)

        // Expand to paragraph boundaries
        let paragraphRange = string.paragraphRange(for: editedRange)
        // For code blocks we may need the full document, but start with paragraph scope
        let workRange = paragraphRange

        guard workRange.length > 0 else { return }

        // Reset to body style
        let bodyAttributes = baseAttributes()
        textStorage.setAttributes(bodyAttributes, range: workRange)

        // Apply each rule in priority order
        for rule in rules {
            rule.apply(to: textStorage, in: workRange)
        }

        // Handle fenced code blocks across full document (they span paragraphs)
        applyCodeBlocks(to: textStorage, in: fullRange)
    }

    func applyFullDocument(_ textStorage: NSTextStorage) {
        let fullRange = NSRange(location: 0, length: (textStorage.string as NSString).length)
        guard fullRange.length > 0 else { return }
        let bodyAttributes = baseAttributes()
        textStorage.setAttributes(bodyAttributes, range: fullRange)
        for rule in rules {
            rule.apply(to: textStorage, in: fullRange)
        }
        applyCodeBlocks(to: textStorage, in: fullRange)
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

    // MARK: - Fenced Code Blocks (multi-line)

    private func applyCodeBlocks(to textStorage: NSTextStorage, in range: NSRange) {
        guard let regex = try? NSRegularExpression(
            pattern: "^(```\\w*)(\\n[\\s\\S]*?\\n)(```)$",
            options: [.anchorsMatchLines]
        ) else { return }

        regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
            guard let match else { return }

            // Opening fence
            let openRange = match.range(at: 1)
            if openRange.location != NSNotFound {
                textStorage.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: openRange)
                textStorage.addAttribute(.font, value: theme.codeFont, range: openRange)
            }

            // Code content
            let contentRange = match.range(at: 2)
            if contentRange.location != NSNotFound {
                textStorage.addAttributes([
                    .font: theme.codeFont,
                    .backgroundColor: theme.codeBackground
                ], range: contentRange)
            }

            // Closing fence
            let closeRange = match.range(at: 3)
            if closeRange.location != NSNotFound {
                textStorage.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: closeRange)
                textStorage.addAttribute(.font, value: theme.codeFont, range: closeRange)
            }
        }
    }

    // MARK: - Rule Builder

    private static func buildRules(theme: MarkdownTheme) -> [MarkdownRule] {
        var rules: [MarkdownRule] = []

        // --- Headings ---

        let headingParagraphStyle = NSMutableParagraphStyle()
        headingParagraphStyle.lineSpacing = theme.headingLineSpacing

        // H1: # text
        if let regex = try? NSRegularExpression(pattern: "^(#{1} )(.*)$", options: .anchorsMatchLines) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                // Apply heading style to the whole line (prefix + content)
                ts.addAttributes([
                    .font: theme.heading1Font,
                    .paragraphStyle: headingParagraphStyle
                ], range: match.range)
                ts.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: match.range(at: 1))
            })
        }

        // H2: ## text
        if let regex = try? NSRegularExpression(pattern: "^(#{2} )(.*)$", options: .anchorsMatchLines) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                ts.addAttributes([
                    .font: theme.heading2Font,
                    .paragraphStyle: headingParagraphStyle
                ], range: match.range)
                ts.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: match.range(at: 1))
            })
        }

        // H3: ### text
        if let regex = try? NSRegularExpression(pattern: "^(#{3} )(.*)$", options: .anchorsMatchLines) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                ts.addAttributes([
                    .font: theme.heading3Font,
                    .paragraphStyle: headingParagraphStyle
                ], range: match.range)
                ts.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: match.range(at: 1))
            })
        }

        // --- Emphasis ---

        // Bold+Italic: ***text***
        if let regex = try? NSRegularExpression(pattern: "(\\*{3})(.+?)(\\*{3})", options: []) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                ts.addAttribute(.font, value: theme.boldItalicFont, range: match.range(at: 2))
                ts.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: match.range(at: 1))
                ts.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: match.range(at: 3))
            })
        }

        // Bold: **text**
        if let regex = try? NSRegularExpression(pattern: "(\\*{2})(.+?)(\\*{2})", options: []) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                ts.addAttribute(.font, value: theme.boldFont, range: match.range(at: 2))
                ts.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: match.range(at: 1))
                ts.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: match.range(at: 3))
            })
        }

        // Italic: *text*
        if let regex = try? NSRegularExpression(pattern: "(?<!\\*)(\\*)(.+?)(\\*)(?!\\*)", options: []) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                ts.addAttribute(.font, value: theme.italicFont, range: match.range(at: 2))
                ts.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: match.range(at: 1))
                ts.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: match.range(at: 3))
            })
        }

        // Strikethrough: ~~text~~
        if let regex = try? NSRegularExpression(pattern: "(~~)(.+?)(~~)", options: []) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                ts.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: match.range(at: 2))
                ts.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: match.range(at: 1))
                ts.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: match.range(at: 3))
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
                ts.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: match.range(at: 1))
                ts.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: match.range(at: 3))
            })
        }

        // --- Blockquote ---

        // > text
        if let regex = try? NSRegularExpression(pattern: "^(> )(.*)$", options: .anchorsMatchLines) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                let paraStyle = NSMutableParagraphStyle()
                paraStyle.lineSpacing = theme.bodyLineSpacing
                paraStyle.headIndent = theme.listIndent
                paraStyle.firstLineHeadIndent = theme.listIndent
                ts.addAttributes([
                    .foregroundColor: theme.blockquoteColor,
                    .font: theme.italicFont,
                    .paragraphStyle: paraStyle
                ], range: match.range(at: 2))
                ts.addAttribute(.foregroundColor, value: theme.linkColor, range: match.range(at: 1))
            })
        }

        // --- Lists ---

        // To-Do: - [ ] item, - [x] item
        if let regex = try? NSRegularExpression(pattern: "^([ \\t]*)([-*+] \\[[ x]\\] )(.*)$", options: .anchorsMatchLines) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                let paraStyle = NSMutableParagraphStyle()
                paraStyle.lineSpacing = theme.bodyLineSpacing
                paraStyle.headIndent = theme.listIndent
                paraStyle.firstLineHeadIndent = 0
                ts.addAttribute(.paragraphStyle, value: paraStyle, range: match.range)
                ts.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: match.range(at: 2))
            })
        }

        // Unordered: - item, * item, + item
        if let regex = try? NSRegularExpression(pattern: "^([ \\t]*)([-*+] )(.*)$", options: .anchorsMatchLines) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                let paraStyle = NSMutableParagraphStyle()
                paraStyle.lineSpacing = theme.bodyLineSpacing
                paraStyle.headIndent = theme.listIndent
                paraStyle.firstLineHeadIndent = 0
                ts.addAttribute(.paragraphStyle, value: paraStyle, range: match.range)
            })
        }

        // Ordered: 1. item
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
                // Dim syntax characters
                for group in [1, 3, 4, 5] {
                    let r = match.range(at: group)
                    if r.location != NSNotFound {
                        ts.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: r)
                    }
                }
            })
        }

        // --- Horizontal Rule ---

        // --- or ___ or ***
        if let regex = try? NSRegularExpression(pattern: "^(---|___|\\*\\*\\*)$", options: .anchorsMatchLines) {
            rules.append(MarkdownRule(regex: regex) { match, ts in
                ts.addAttribute(.foregroundColor, value: theme.syntaxDimColor, range: match.range)
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
