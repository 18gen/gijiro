//
//  AppTheme.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-25.
//

import SwiftUI
import AppKit

enum AppTheme {
    // primary accent (blue)
    static let primary = Color.accentColor // set Accent Color in Assets to your blue

    // brand accent (muted slate blue)
    static let accentNS = NSColor(red: 0.40, green: 0.55, blue: 0.68, alpha: 1.0)
    static let accent = Color(nsColor: accentNS)

    // background
    static let backgroundNS = NSColor(red: 33/255, green: 33/255, blue: 33/255, alpha: 1)
    static let background = Color(nsColor: backgroundNS)

    // surfaces
    static let surfaceFill = Color.primary.opacity(0.06)
    static let surfaceStroke = Color.white.opacity(0.10)
    static let surfaceStrokeStrong = Color.white.opacity(0.16)

    // text
    static let textPrimary: Color = .primary
    static let textSecondary: Color = .secondary
    static let textTertiary: Color = .primary.opacity(0.45)

    // sizing
    static let barCorner: CGFloat = 26
    static let pillCorner: CGFloat = 999
}
