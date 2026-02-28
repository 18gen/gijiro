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

    @State private var expandedDays: Set<Date> = []

    private let collapsedLimit = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if GoogleAuthService.shared.isAuthenticated {
                content
            }
        }
    }
}

// MARK: - Content

private extension UpcomingSection {
    var header: some View {
        HStack {
            Text("Upcoming")
                .font(.system(size: 28, weight: .light, design: .serif))

            Spacer()

            // Optional: global controls (filters/settings)
            // Button { } label: { Image(systemName: "slider.horizontal.3") }
            //     .buttonStyle(.plain)
            //     .foregroundStyle(.secondary)
        }
        .padding(.bottom, 2)
    }

    @ViewBuilder
    var content: some View {
        let grouped = groupByDay(events)

        if grouped.isEmpty {
            if !isLoading { emptyHint }
        } else {
            VStack(spacing: 0) {
                ForEach(Array(grouped.enumerated()), id: \.element.day) { index, group in
                    UpcomingDayBlock(
                        day: group.day,
                        events: group.events,
                        currentEventID: currentEventID,
                        collapsedLimit: collapsedLimit,
                        isExpanded: expandedDays.contains(group.day),
                        onToggleExpanded: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                toggleExpanded(for: group.day)
                            }
                        },
                        onSelect: onSelect
                    )
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)

                    if index != grouped.count - 1 {
                        DottedDivider()
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06))
                    )
            )
        }
    }

    func toggleExpanded(for day: Date) {
        if expandedDays.contains(day) {
            expandedDays.remove(day)
        } else {
            expandedDays.insert(day)
        }
    }

    func groupByDay(_ events: [CalendarEvent]) -> [(day: Date, events: [CalendarEvent])] {
        let cal = Calendar.current
        let byDay = Dictionary(grouping: events) { cal.startOfDay(for: $0.startDate) }

        return byDay
            .map { (day: $0.key, events: $0.value.sorted { $0.startDate < $1.startDate }) }
            .sorted { $0.day < $1.day }
    }

    var emptyHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.questionmark")
                .foregroundStyle(.secondary)

            Text("Don’t see the events you need? Check your visible calendars.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Day Block

private struct UpcomingDayBlock: View {
    let day: Date
    let events: [CalendarEvent]
    let currentEventID: String?
    let collapsedLimit: Int
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onSelect: (CalendarEvent) -> Void

    private var visibleEvents: [CalendarEvent] {
        guard !isExpanded else { return events }
        return Array(events.prefix(collapsedLimit))
    }

    private var hasMore: Bool { events.count > collapsedLimit }

    private var currentEvent: CalendarEvent? {
        guard let currentEventID else { return nil }
        return events.first(where: { $0.id == currentEventID })
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            DateColumn(day: day)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(visibleEvents) { event in
                    UpcomingRowButton(
                        event: event,
                        isNow: event.id == currentEventID,
                        action: { onSelect(event) }
                    )
                }
            }
        }
    }
}

// MARK: - Date Column

private struct DateColumn: View {
    let day: Date

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(dayNumber(day))
                .font(.system(size: 26, weight: .light, design: .serif))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 0) {
                Text(monthName(day))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary)

                Text(weekdayShort(day))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 128, alignment: .leading)
    }

    private func dayNumber(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private func monthName(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: date)
    }

    private func weekdayShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

// MARK: - Dotted Divider

private struct DottedDivider: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
            }
            .stroke(
                Color.white.opacity(0.10),
                style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1.5, 6])
            )
        }
        .frame(height: 1)
    }
}
