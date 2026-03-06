//
//  MarkdownVisualizer.swift
//  Gijiro
//

import Foundation

enum MarkdownVisualizer {
    private typealias S = BlockCommand.Symbols

    // Patterns for markdown → visual conversion (order matters: todos before bullets)
    private static let mdToVisualRules: [(NSRegularExpression, String)] = [
        (try! NSRegularExpression(pattern: #"^([ \t]*)[-*+] \[ \] "#, options: .anchorsMatchLines), "$1\(S.todoUnchecked) "),
        (try! NSRegularExpression(pattern: #"^([ \t]*)[-*+] \[x\] "#, options: .anchorsMatchLines), "$1\(S.todoChecked) "),
        (try! NSRegularExpression(pattern: #"^([ \t]*)[-*+] "#, options: .anchorsMatchLines), "$1\(S.bullet) "),
    ]

    // Patterns for visual → markdown conversion
    private static let visualToMdRules: [(NSRegularExpression, String)] = [
        (try! NSRegularExpression(pattern: "^([ \\t]*)\(S.todoUnchecked) ", options: .anchorsMatchLines), "$1- [ ] "),
        (try! NSRegularExpression(pattern: "^([ \\t]*)\(S.todoChecked) ", options: .anchorsMatchLines), "$1- [x] "),
        (try! NSRegularExpression(pattern: "^([ \\t]*)\(S.bullet) ", options: .anchorsMatchLines), "$1- "),
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
