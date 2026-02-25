//
//  HoverRowButton.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-24.
//

import SwiftUI

/// Hover-only row container (macOS): subtle hover background + optional trailing chevron.
struct HoverRow<Content: View>: View {
    var cornerRadius: CGFloat = 10
    var verticalPadding: CGFloat = 6
    var horizontalPadding: CGFloat = 8
    var showsChevronOnHover: Bool = true

    let action: () -> Void
    @ViewBuilder let content: (_ isHovering: Bool) -> Content

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                content(isHovering)

                if showsChevronOnHover {
                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .opacity(isHovering ? 1 : 0)
                }
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(hoverBackground)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }

    private var hoverBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(isHovering
                  ? Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06)
                  : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isHovering
                            ? Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08)
                            : Color.clear, lineWidth: 1)
            )
    }
}
