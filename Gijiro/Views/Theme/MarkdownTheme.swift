//
//  MarkdownTheme.swift
//  Gijiro
//

import AppKit

struct MarkdownTheme {
    let heading1Font: NSFont
    let heading2Font: NSFont
    let heading3Font: NSFont
    let bodyFont: NSFont
    let boldFont: NSFont
    let italicFont: NSFont
    let boldItalicFont: NSFont
    let codeFont: NSFont
    let codeBackground: NSColor
    let textColor: NSColor
    let syntaxDimColor: NSColor
    let linkColor: NSColor
    let hiddenFont: NSFont
    let hiddenColor: NSColor
    let bodyLineSpacing: CGFloat
    let headingLineSpacing: CGFloat
    let listIndent: CGFloat

    static let `default` = MarkdownTheme(
        heading1Font: serifFont(size: 28, weight: .bold),
        heading2Font: serifFont(size: 22, weight: .semibold),
        heading3Font: serifFont(size: 18, weight: .medium),
        bodyFont: .systemFont(ofSize: 16, weight: .light),
        boldFont: .systemFont(ofSize: 16, weight: .semibold),
        italicFont: italicSystemFont(size: 16, weight: .light),
        boldItalicFont: italicSystemFont(size: 16, weight: .semibold),
        codeFont: .monospacedSystemFont(ofSize: 14, weight: .regular),
        codeBackground: NSColor.white.withAlphaComponent(0.06),
        textColor: NSColor.white.withAlphaComponent(0.85),
        syntaxDimColor: NSColor.white.withAlphaComponent(0.25),
        linkColor: NSColor(red: 0.40, green: 0.55, blue: 0.68, alpha: 1.0),
        hiddenFont: .systemFont(ofSize: 0.01),
        hiddenColor: .clear,
        bodyLineSpacing: 3,
        headingLineSpacing: 6,
        listIndent: 20
    )

    private static func serifFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let systemFont = NSFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = systemFont.fontDescriptor.withDesign(.serif) else {
            return systemFont
        }
        return NSFont(descriptor: descriptor, size: size) ?? systemFont
    }

    private static func italicSystemFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: size) ?? base
    }
}
