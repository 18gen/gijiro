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
    @FocusState private var isAskFieldFocused: Bool

    private let claudeService = ClaudeService()

    static let quickPrompts: [QuickPrompt] = [
        QuickPrompt(label: "List recent todos", icon: "pencil", prompt: "Please list all action items and todos from these recent meetings"),
        QuickPrompt(label: "Summarize meetings", icon: "doc.text", prompt: "Please summarize my recent meetings into key points"),
        QuickPrompt(label: "Write weekly recap", icon: "calendar", prompt: "Write a weekly recap based on my recent meetings"),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            // Scrollable content
            ScrollView {
                HStack {
                    Text("Upcoming")
                        .font(.system(size: 24, weight: .light, design: .serif))
                    Spacer()
                    Button("Show more") {
                        // TODO: expand to show more events
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 12)
                .padding(.horizontal, 36)
                .frame(maxWidth: 800)

                LazyVStack(alignment: .leading, spacing: 0) {
                    if GoogleAuthService.shared.isAuthenticated {
                        calendarEventsSection
                    }
                }
                .padding(.horizontal, 36)
                .frame(maxWidth: 800)
                
                Divider()
                    .padding(.vertical, 8)

                LazyVStack(alignment: .leading, spacing: 0) {
                    pastNotesSection
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
                .padding(.horizontal, 36)
                .frame(maxWidth: 800)
            }
            .onTapGesture {
                isAskFieldFocused = false
            }

            // Bottom area: quick prompts + full-width background bar
            bottomArea
        }
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .windowToolbar)
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
        }

        if allEvents.isEmpty && !calendarService.isLoading {
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

    private func eventRow(_ event: CalendarEvent) -> some View {
        let isNow = calendarService.currentEvent?.id == event.id

        return Button {
            openOrCreateMeeting(for: event)
        } label: {
            HStack(spacing: 14) {
                DateBadge(date: event.startDate)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .light))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if isNow {
                            Text("Now")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.accent)
                                .fontWeight(.medium)
                            Text("\u{00B7}")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Text(eventTimeText(event))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .background(isNow ? Theme.accent.opacity(0.05) : Color.clear)
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
            
            Text("History")
                .font(.system(size: 24, weight: .light, design: .serif))

            ForEach(sortedDates, id: \.self) { date in
                Text(dateHeader(date))
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(.secondary)
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
                Image(systemName: "doc.text")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(meeting.title)
                        .font(.system(size: 16))
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
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Area

    private var bottomArea: some View {
        VStack(spacing: 0) {
            // Quick prompts — expand upward above the bar
            if isAskFieldFocused {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(Self.quickPrompts.enumerated()), id: \.element.id) { index, prompt in
                            if index > 0 {
                                Divider()
                                    .frame(height: 20)
                                    .padding(.horizontal, 8)
                            }
                            QuickPromptButton(prompt: prompt) {
                                runQuickPrompt(prompt)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 12)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Full-width background bar
            VStack(spacing: 0) {
                // Frosted blur fade edge
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 30)

                // Text field pill
                HStack(spacing: 10) {
                    TextField("Ask anything", text: $askText)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($isAskFieldFocused)
                        .onSubmit {
                            Task { await askQuestion() }
                        }

                    if isAsking {
                        ProgressView()
                            .controlSize(.small)
                    } else if !askText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        SendButton(size: 32) {
                            Task { await askQuestion() }
                        }
                    }

                    // Collapsed: show first quick prompt inline
                    if !isAskFieldFocused {
                        QuickPromptPill(prompt: Self.quickPrompts[0]) {
                            runQuickPrompt(Self.quickPrompts[0])
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .animation(.easeInOut(duration: 0.2), value: isAskFieldFocused)
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

    // MARK: - Actions

    private func runQuickPrompt(_ prompt: QuickPrompt) {
        askText = prompt.label
        Task {
            isAsking = true
            let recentContext = meetings.prefix(5).map {
                "Meeting: \($0.title)\nNotes: \($0.userNotes)\nAugmented: \($0.augmentedNotes)"
            }.joined(separator: "\n---\n")

            do {
                let answer = try await claudeService.askQuestion(
                    question: prompt.prompt,
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
}
