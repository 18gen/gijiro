import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.startDate, order: .reverse) private var meetings: [Meeting]
    @Binding var selectedMeeting: Meeting?

    @State private var calendarService = GoogleCalendarService.shared
    @State private var askText = ""
    @State private var isAsking = false
    @State private var askAnswer = ""
    @State private var showAskResult = false

    private let claudeService = ClaudeService()

    var body: some View {
        VStack(spacing: 0) {
            // Content
            ScrollView {
                HStack(alignment: .firstTextBaseline) {
                    Text("Coming up")
                        .font(.system(size: 28, weight: .light))
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                }
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Calendar events
                    if GoogleAuthService.shared.isAuthenticated {
                        calendarEventsSection
                    }

                    // Past notes
                    pastNotesSection
                }
            }

            Divider()

            // Bottom ask bar
            bottomBar
        }
        .task {
            if GoogleAuthService.shared.isAuthenticated {
                await calendarService.refreshEvents()
                calendarService.startRefreshTimer()
            }
        }
    }

    // MARK: - Calendar Events

    @ViewBuilder
    private var calendarEventsSection: some View {
        let allEvents = calendarService.upcomingEvents

        if !allEvents.isEmpty {
            ForEach(allEvents) { event in
                eventRow(event)
            }

            Divider()
                .padding(.vertical, 8)
        }

        if allEvents.isEmpty && !calendarService.isLoading {
            HStack {
                Image(systemName: "calendar.badge.questionmark")
                    .foregroundStyle(.secondary)
                Text("Don't see the events you need? Check your visible calendars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }

    private func eventRow(_ event: CalendarEvent) -> some View {
        let isNow = calendarService.currentEvent?.id == event.id

        return Button {
            openOrCreateMeeting(for: event)
        } label: {
            HStack(spacing: 14) {
                // Date badge
                DateBadge(date: event.startDate)

                // Event info
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 17, weight: .medium))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if isNow {
                            Text("Now")
                                .font(.system(size: 14))
                                .foregroundStyle(.green)
                                .fontWeight(.medium)
                            Text("\u{00B7}")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        Text(eventTimeText(event))
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(isNow ? Color.green.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Past Notes

    @ViewBuilder
    private var pastNotesSection: some View {
        let pastMeetings = meetings.filter { $0.status != "recording" }

        if !pastMeetings.isEmpty {
            let grouped = Dictionary(grouping: pastMeetings) { meeting in
                Calendar.current.startOfDay(for: meeting.startDate)
            }
            let sortedDates = grouped.keys.sorted(by: >)

            ForEach(sortedDates, id: \.self) { date in
                Text(dateHeader(date))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 6)

                if let dayMeetings = grouped[date] {
                    ForEach(dayMeetings) { meeting in
                        noteRow(meeting)
                    }
                }
            }
        }
    }

    private func noteRow(_ meeting: Meeting) -> some View {
        Button {
            selectedMeeting = meeting
        } label: {
            HStack(spacing: 14) {
                // Document icon badge
                Image(systemName: "doc.text")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Two-line layout: title + author
                VStack(alignment: .leading, spacing: 2) {
                    Text(meeting.title)
                        .font(.system(size: 16))
                        .lineLimit(1)

                    Text("Me")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Lock + time
                HStack(spacing: 8) {
                    Image(systemName: "lock")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(meeting.startDate.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .foregroundStyle(.purple)
                .font(.caption)

            TextField("Ask anything...", text: $askText)
                .textFieldStyle(.plain)
                .font(.callout)
                .onSubmit {
                    Task { await askQuestion() }
                }

            if isAsking {
                ProgressView()
                    .controlSize(.small)
            }

            Button("List recent todos") {
                Task { await listTodos() }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .popover(isPresented: $showAskResult) {
            ScrollView {
                Text(askAnswer)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(width: 400, height: 300)
        }
    }

    // MARK: - Helpers

    private func eventTimeText(_ event: CalendarEvent) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeRange = "\(formatter.string(from: event.startDate)) \u{2013} \(formatter.string(from: event.endDate))"

        if Calendar.current.isDateInToday(event.startDate) {
            return timeRange
        } else if Calendar.current.isDateInTomorrow(event.startDate) {
            return "Tomorrow \(formatter.string(from: event.startDate))"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE h:mm a"
            return dayFormatter.string(from: event.startDate)
        }
    }

    private func dateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func openOrCreateMeeting(for event: CalendarEvent) {
        if let existing = meetings.first(where: { $0.calendarEventID == event.id }) {
            selectedMeeting = existing
            return
        }
        let meeting = Meeting(title: event.title)
        meeting.calendarEventID = event.id
        modelContext.insert(meeting)
        try? modelContext.save()
        selectedMeeting = meeting
    }

    private func createQuickNote() {
        let meeting = Meeting(title: "Quick Note")
        modelContext.insert(meeting)
        try? modelContext.save()
        selectedMeeting = meeting
    }

    private func askQuestion() async {
        let question = askText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        isAsking = true

        let recentContext = meetings.prefix(5).map {
            "Meeting: \($0.title)\nNotes: \($0.userNotes)\nTranscript: \($0.rawTranscript)"
        }.joined(separator: "\n---\n")

        do {
            let answer = try await claudeService.askQuestion(
                question: question,
                userNotes: recentContext,
                transcript: ""
            )
            askAnswer = answer
            showAskResult = true
        } catch {
            askAnswer = "Error: \(error.localizedDescription)"
            showAskResult = true
        }

        isAsking = false
    }

    private func listTodos() async {
        isAsking = true
        askText = "List recent todos"

        let recentContext = meetings.prefix(5).map {
            "Meeting: \($0.title)\nNotes: \($0.userNotes)\nAugmented: \($0.augmentedNotes)"
        }.joined(separator: "\n---\n")

        do {
            let answer = try await claudeService.askQuestion(
                question: "Please list all action items and todos from these recent meetings",
                userNotes: recentContext,
                transcript: ""
            )
            askAnswer = answer
            showAskResult = true
        } catch {
            askAnswer = "Error: \(error.localizedDescription)"
            showAskResult = true
        }

        isAsking = false
        askText = ""
    }
}

// MARK: - Date Badge Component

private struct DateBadge: View {
    let date: Date

    var body: some View {
        VStack(spacing: 1) {
            Text(monthAbbreviation)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.green)
                .textCase(.uppercase)
            Text(dayNumber)
                .font(.system(size: 22, weight: .bold))
        }
        .frame(width: 44, height: 48)
        .background(Color(.systemGray).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var monthAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}
