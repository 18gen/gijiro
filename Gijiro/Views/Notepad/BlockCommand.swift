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
        }
    }

    var visualPrefix: String {
        switch self {
        case .bulletList:   return "\(Symbols.bullet) "
        case .numberedList: return "1. "
        case .todoList:     return "\(Symbols.todoUnchecked) "
        default:            return prefix
        }
    }

    // Canonical visual symbols for list indicators
    enum Symbols {
        static let bullet = "•"
        static let todoUnchecked = "☐"
        static let todoChecked = "☑"
    }

    // Regex to detect any existing block prefix at line start (visual prefixes)
    static let prefixPattern = try! NSRegularExpression(
        pattern: "^(#{1,3} |\(Symbols.todoUnchecked) |\(Symbols.todoChecked) |\(Symbols.bullet) |\\d+\\. )",
        options: .anchorsMatchLines
    )
}
