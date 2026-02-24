import SwiftUI
import SwiftData

struct MeetingHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.startDate, order: .reverse) private var meetings: [Meeting]
    @Binding var selectedMeeting: Meeting?

    var body: some View {
        List {
            if meetings.isEmpty {
                Text("No meetings yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(meetings) { meeting in
                    MeetingRow(meeting: meeting)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedMeeting = meeting
                        }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        modelContext.delete(meetings[index])
                    }
                }
            }
        }
        .frame(minWidth: 350, minHeight: 300)
    }
}

private struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(meeting.startDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(status: meeting.status)
        }
        .padding(.vertical, 2)
    }
}

private struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(status.capitalized)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case "recording": .red
        case "transcribing": .orange
        case "augmenting": .purple
        case "done": .green
        default: .secondary
        }
    }
}
