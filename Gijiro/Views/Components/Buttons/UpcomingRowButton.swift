//
//  UpcomingRowButton.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-26.
//

import SwiftUI

// MARK: - Generic Hover Row Container (macOS)

/// Hover-only row button (macOS): subtle hover background + optional trailing chevron.
struct UpcomingRowButton<Content: View>: View {
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

// MARK: - CalendarEvent Convenience Row

extension UpcomingRowButton where Content == UpcomingRowButtonEventContent {
    /// Prebuilt Upcoming row for a CalendarEvent: vertical color bar + title + time (with optional "Now").
    init(
        event: CalendarEvent,
        isNow: Bool,
        action: @escaping () -> Void
    ) {
        self.action = action
        self.content = { _ in
            UpcomingRowButtonEventContent(event: event, isNow: isNow)
        }
    }
}

struct UpcomingRowButtonEventContent: View {
    let event: CalendarEvent
    let isNow: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(isNow ? AppTheme.accent : Color.cyan.opacity(0.75))
                .frame(width: 3)
                .padding(.vertical, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 14))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if isNow {
                        Text("Now")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.accent)
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.accent)
                    }

                    Text(EventTimeFormatter.string(for: event))
                        .font(.system(size: 12))
                        .foregroundStyle(isNow ? AppTheme.accent : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
