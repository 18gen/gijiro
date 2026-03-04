//
//  InlineFormat.swift
//  Gijiro
//

import Foundation

enum InlineFormat: String, CaseIterable, Identifiable {
    case bold
    case italic
    case underline
    case strikethrough
    case code
    case link

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bold:          return "bold"
        case .italic:        return "italic"
        case .underline:     return "underline"
        case .strikethrough: return "strikethrough"
        case .code:          return "chevron.left.forwardslash.chevron.right"
        case .link:          return "link"
        }
    }

    var wrapper: (String, String) {
        switch self {
        case .bold:          return ("**", "**")
        case .italic:        return ("*", "*")
        case .underline:     return ("__", "__")
        case .strikethrough: return ("~~", "~~")
        case .code:          return ("`", "`")
        case .link:          return ("[", "](url)")
        }
    }
}
