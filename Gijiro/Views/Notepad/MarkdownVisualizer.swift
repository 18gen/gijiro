//
//  MarkdownVisualizer.swift
//  Gijiro
//

import Foundation

enum MarkdownVisualizer {
    // Patterns for markdown → visual conversion (order matters: todos before bullets)
    private static let mdToVisualRules: [(NSRegularExpression, String)] = [
        (try! NSRegularExpression(pattern: #"^([ \t]*)[-*+] \[ \] "#, options: .anchorsMatchLines), "$1☐ "),
        (try! NSRegularExpression(pattern: #"^([ \t]*)[-*+] \[x\] "#, options: .anchorsMatchLines), "$1☑ "),
        (try! NSRegularExpression(pattern: #"^([ \t]*)[-*+] "#, options: .anchorsMatchLines), "$1• "),
    ]

    // Patterns for visual → markdown conversion
    private static let visualToMdRules: [(NSRegularExpression, String)] = [
        (try! NSRegularExpression(pattern: #"^([ \t]*)☐ "#, options: .anchorsMatchLines), "$1- [ ] "),
        (try! NSRegularExpression(pattern: #"^([ \t]*)☑ "#, options: .anchorsMatchLines), "$1- [x] "),
        (try! NSRegularExpression(pattern: #"^([ \t]*)• "#, options: .anchorsMatchLines), "$1- "),
    ]

    /// Convert markdown list prefixes to visual equivalents for display
    static func markdownToVisual(_ text: String) -> String {
        applyRules(mdToVisualRules, to: text)
    }

    /// Convert visual prefixes back to markdown for storage
    static func visualToMarkdown(_ text: String) -> String {
        applyRules(visualToMdRules, to: text)
    }

    private static func applyRules(_ rules: [(NSRegularExpression, String)], to text: String) -> String {
        var result = text
        for (regex, template) in rules {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: template
            )
        }
        return result
    }
}
