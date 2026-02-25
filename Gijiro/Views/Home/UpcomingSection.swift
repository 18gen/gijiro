//
//  UpcomingSection.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-24.
//

import SwiftUI

struct UpcomingSection: View {
    let events: [CalendarEvent]
    let isLoading: Bool
    let currentEventID: String?
    let onSelect: (CalendarEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if GoogleAuthService.shared.isAuthenticated {
                VStack(spacing: 3) {
                    if !events.isEmpty {
                        ForEach(events) { event in
                            row(event)
                        }
                    } else if !isLoading {
                        emptyHint
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Upcoming")
                .font(.system(size: 24, weight: .light, design: .serif))
            Spacer()
            Button("Show more") {}
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
        }
        .padding(.bottom, 4)
    }
    
    private func row(_ event: CalendarEvent) -> some View {
        let isNow = (currentEventID == event.id)

        return HoverRow(action: { onSelect(event) }) { hovering in
            HStack(spacing: 14) {
                DateBadge(date: event.startDate)

                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .light))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if isNow {
                            Text("Now")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.accent)
                                .fontWeight(.medium)
                            Text("·").foregroundStyle(.secondary)
                        }
                        Text(EventTimeFormatter.string(for: event))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var emptyHint: some View {
        HStack {
            Image(systemName: "calendar.badge.questionmark")
                .foregroundStyle(.secondary)
            Text("Don't see the events you need? Check your visible calendars")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }
}
