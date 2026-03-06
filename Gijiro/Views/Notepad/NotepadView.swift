import SwiftUI
import SwiftData

struct NotepadView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var meeting: Meeting
    var onClose: () -> Void

    @State private var showTranscriptPanel = false
    @State private var isAugmenting = false
    @State private var augmentError: String?
    @State private var opacityIndex = 0

    private let claudeService = ClaudeService.shared
    private static let opacityLevels: [Double] = [1.0, 0.80, 0.40]

    var body: some View {
        ZStack(alignment: .bottom) {
            content
            overlay
        }
        .padding(.horizontal, 30)
        .toolbar { toolbar }
        .onDisappear(perform: resetOpacity)
    }
}

// MARK: - Subviews
private extension NotepadView {
    var content: some View {
        VStack(spacing: 5) {
            metadataRow
                .padding(.horizontal, 4)
                .padding(.top, 10)
                .padding(.bottom, 24)

            TextEditor(text: $meeting.userNotes)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let augmentError {
                Text(augmentError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: 800)
    }

    var metadataRow: some View {
        VStack(spacing: 10) {
            TextField("New Note", text: $meeting.title)
                .textFieldStyle(.plain)
                .font(.system(.title, design: .serif))
                .foregroundStyle(.primary)
            
            HStack(spacing: 4) {
                Label(dateBadgeText, systemImage: "calendar")
                    .metadataButtonStyle()

                if let attendeesLabelText {
                    Label(attendeesLabelText, systemImage: "person.2")
                        .metadataButtonStyle()
                }

                Spacer()
            }
        }
    }

    var overlay: some View {
        VStack(spacing: 8) {
            if showTranscriptPanel {
                TranscriptPanelView(meeting: meeting, isExpanded: $showTranscriptPanel)
                    .frame(minHeight: 200, maxHeight: 350)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            NotepadBottomBar(meeting: meeting, showTranscriptPanel: $showTranscriptPanel)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: onClose) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                    Image(systemName: "house")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }

        ToolbarItem(placement: .automatic) {
            Button(action: cycleOpacity) {
                let level = Self.opacityLevels[opacityIndex]
                Image(systemName: opacityIcon(for: level))
                    .foregroundStyle(level < 1.0 ? Color.accentColor : Color.secondary)
            }
            .help("Background opacity: \(Int(Self.opacityLevels[opacityIndex] * 100))%")
        }
    }
}

// MARK: - Computed helpers
private extension NotepadView {
    var isGenerateDisabled: Bool {
        meeting.rawTranscript.isEmpty && meeting.userNotes.isEmpty
    }

    var dateBadgeText: String {
        let cal = Calendar.current
        if cal.isDateInToday(meeting.startDate) { return "Today" }
        if cal.isDateInTomorrow(meeting.startDate) { return "Tomorrow" }
        return meeting.startDate.formatted(date: .abbreviated, time: .shortened)
    }

    var event: CalendarEvent? {
        guard let id = meeting.calendarEventID else { return nil }
        return GoogleCalendarService.shared.upcomingEvents.first { $0.id == id }
    }

    var attendeesLabelText: String? {
        guard let attendees = event?.attendees, !attendees.isEmpty else { return nil }
        return attendees.count == 1 ? attendees[0] : "\(attendees.count) attendees"
    }
}

// MARK: - Opacity
private extension NotepadView {
    func cycleOpacity() {
        opacityIndex = (opacityIndex + 1) % Self.opacityLevels.count
        applyWindowOpacity()
    }

    func resetOpacity() {
        opacityIndex = 0
        applyWindowOpacity()
    }

    func applyWindowOpacity() {
        guard let window = (NSApp.windows.first { $0.isKeyWindow } ?? NSApp.windows.first) else { return }
        let bgColor = AppTheme.backgroundNS
        let level = Self.opacityLevels[opacityIndex]
        if level >= 1 {
            window.isOpaque = true
            window.backgroundColor = bgColor
        } else {
            window.isOpaque = false
            window.backgroundColor = bgColor.withAlphaComponent(level)
        }
    }

    func opacityIcon(for level: Double) -> String {
        if level >= 1.0 { return "circle.fill" }
        if level >= 0.80 { return "circle.bottomhalf.filled" }
        if level >= 0.40 { return "circle.dotted.circle" }
        return "circle.dashed"
    }
}

// MARK: - Actions
private extension NotepadView {
    func augment() async {
        isAugmenting = true
        augmentError = nil
        meeting.status = "augmenting"

        do {
            meeting.augmentedNotes = try await claudeService.augmentNotes(
                userNotes: meeting.userNotes,
                transcript: meeting.rawTranscript,
                toneMode: meeting.toneMode
            )
            meeting.status = "done"
        } catch {
            augmentError = error.localizedDescription
            meeting.status = meeting.rawTranscript.isEmpty ? "idle" : "done"
        }

        isAugmenting = false
    }
}
