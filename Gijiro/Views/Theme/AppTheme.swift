//
//  AppTheme.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-25.
//

import SwiftUI

enum AppTheme {
    // primary accent (blue)
    static let primary = Color.accentColor // set Accent Color in Assets to your blue

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
