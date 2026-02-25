//
//  HistorySection.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-24.
//

import SwiftUI

struct HistorySection: View {
    let meetings: [Meeting]
    let onSelect: (Meeting) -> Void

    var body: some View {
        let pastMeetings = meetings.filter { $0.status != "recording" }
        let grouped = Dictionary(grouping: pastMeetings) { Calendar.current.startOfDay(for: $0.startDate) }
        let dates = grouped.keys.sorted(by: >)

        VStack(alignment: .leading, spacing: 3) {
            Text("History")
                .font(.system(size: 24, weight: .light, design: .serif))

            ForEach(dates, id: \.self) { date in
                Text(DateHeaderFormatter.string(date))
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
                    .padding(.bottom, 6)

                ForEach(grouped[date] ?? []) { meeting in
                    row(meeting)
                }
            }
        }
    }

    private func row(_ meeting: Meeting) -> some View {
        HoverRow(action: { onSelect(meeting) }) { hovering in
            HStack(spacing: 14) {
                IconBadge()

                VStack(alignment: .leading, spacing: 1) {
                    Text(meeting.title)
                        .font(.system(size: 14))
                        .lineLimit(1)

                    Text("Me")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "lock")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(meeting.startDate.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
