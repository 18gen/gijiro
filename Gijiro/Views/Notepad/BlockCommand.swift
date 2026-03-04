//
//  BlockCommand.swift
//  Gijiro
//

import Foundation

enum BlockCommand: String, CaseIterable, Identifiable {
    case text
    case heading1
    case heading2
    case heading3
    case bulletList
    case numberedList
    case todoList
    case codeBlock
    case blockquote
    case divider

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text:         return "Text"
        case .heading1:     return "Heading 1"
        case .heading2:     return "Heading 2"
        case .heading3:     return "Heading 3"
        case .bulletList:   return "Bullet List"
        case .numberedList: return "Numbered List"
        case .todoList:     return "To-Do List"
        case .codeBlock:    return "Code Block"
        case .blockquote:   return "Blockquote"
        case .divider:      return "Divider"
        }
    }

    var icon: String {
        switch self {
        case .text:         return "text.alignleft"
        case .heading1:     return "textformat.size.larger"
        case .heading2:     return "textformat.size"
        case .heading3:     return "textformat.size.smaller"
        case .bulletList:   return "list.bullet"
        case .numberedList: return "list.number"
        case .todoList:     return "checklist"
        case .codeBlock:    return "chevron.left.forwardslash.chevron.right"
        case .blockquote:   return "text.quote"
        case .divider:      return "minus"
        }
    }

    var prefix: String {
        switch self {
        case .text:         return ""
        case .heading1:     return "# "
        case .heading2:     return "## "
        case .heading3:     return "### "
        case .bulletList:   return "- "
        case .numberedList: return "1. "
        case .todoList:     return "- [ ] "
        case .codeBlock:    return "```\n"
        case .blockquote:   return "> "
        case .divider:      return "---"
        }
    }

    // Regex to detect any existing block prefix at line start
    static let prefixPattern = try! NSRegularExpression(
        pattern: #"^(#{1,3} |[-*+] \[[ x]\] |[-*+] |\d+\. |> |```|---)"#,
        options: .anchorsMatchLines
    )
}
