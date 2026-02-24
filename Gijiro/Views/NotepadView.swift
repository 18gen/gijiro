import SwiftUI
import SwiftData
import AppKit

struct NotepadView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var meeting: Meeting
    var onClose: () -> Void
    @State private var coordinator = RecordingCoordinator.shared
    @State private var showTranscriptPanel = false
    @State private var isAugmenting = false
    @State private var augmentError: String?
    /// Background opacity levels: 100% → 80% → 40% → 0% (fully transparent)
    private static let opacityLevels: [Double] = [1.0, 0.80, 0.40]
    @State private var opacityIndex = 0

    private let claudeService = ClaudeService()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content layer
            VStack(spacing: 0) {
                // Title
                TextField("Meeting Title", text: $meeting.title)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                // Metadata chips
                HStack(spacing: 8) {
                    Label(dateBadgeText, systemImage: "calendar")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())

                    if let eventID = meeting.calendarEventID,
                       let event = GoogleCalendarService.shared.upcomingEvents.first(where: { $0.id == eventID }),
                       !event.attendees.isEmpty {
                        Label(attendeesText(event), systemImage: "person.2")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 8)

                Divider()

                // Notes area with bottom padding for floating bar clearance
                MarkdownNotesEditor(text: $meeting.userNotes)
                    .frame(maxHeight: .infinity)
                    .padding(.bottom, 120)

                // Augment error
                if let augmentError {
                    Text(augmentError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }
            }

            // Floating overlay layer
            VStack(spacing: 8) {
                // Transcript panel sits above the floating bar
                if showTranscriptPanel {
                    TranscriptPanelView(meeting: meeting, isExpanded: $showTranscriptPanel)
                        .frame(minHeight: 200, maxHeight: 350)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Generate notes button
                Button {
                    Task { await augment() }
                } label: {
                    HStack(spacing: 6) {
                        if isAugmenting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isAugmenting ? "Generating..." : "Generate notes")
                            .fontWeight(.medium)
                    }
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.55, green: 0.55, blue: 0.15))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isAugmenting || (meeting.rawTranscript.isEmpty && meeting.userNotes.isEmpty))
                .opacity((meeting.rawTranscript.isEmpty && meeting.userNotes.isEmpty) ? 0.4 : 1.0)

                // Floating bottom bar
                NotepadBottomBar(
                    meeting: meeting,
                    showTranscriptPanel: $showTranscriptPanel
                )
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(minWidth: 500, minHeight: 450)
        .animation(.easeInOut(duration: 0.25), value: showTranscriptPanel)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    onClose()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Image(systemName: "house")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    opacityIndex = (opacityIndex + 1) % Self.opacityLevels.count
                    applyWindowOpacity()
                } label: {
                    let level = Self.opacityLevels[opacityIndex]
                    Image(systemName: opacityIcon(for: level))
                        .foregroundStyle(level < 1.0 ? Color.accentColor : Color.secondary)
                }
                .help("Background opacity: \(Int(Self.opacityLevels[opacityIndex] * 100))%")
            }
        }
        .onDisappear {
            // Restore opaque window when leaving notepad
            opacityIndex = 0
            applyWindowOpacity()
        }
    }

    private var dateBadgeText: String {
        if Calendar.current.isDateInToday(meeting.startDate) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(meeting.startDate) {
            return "Tomorrow"
        }
        return meeting.startDate.formatted(date: .abbreviated, time: .shortened)
    }

    private func attendeesText(_ event: CalendarEvent) -> String {
        if event.attendees.count == 1 {
            return event.attendees[0]
        }
        return "\(event.attendees.count) attendees"
    }

    private func applyWindowOpacity() {
        guard let window = NSApp.windows.first(where: { $0.isKeyWindow }) ?? NSApp.windows.first else { return }
        let opacity = Self.opacityLevels[opacityIndex]
        if opacity >= 1.0 {
            window.isOpaque = true
            window.backgroundColor = NSColor.windowBackgroundColor
        } else {
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(opacity)
        }
    }

    private func opacityIcon(for level: Double) -> String {
        if level >= 1.0 { return "circle.fill" }
        if level >= 0.80 { return "circle.bottomhalf.filled" }
        if level >= 0.40 { return "circle.dotted.circle" }
        return "circle.dashed" // 0%
    }

    private func augment() async {
        isAugmenting = true
        augmentError = nil
        meeting.status = "augmenting"

        do {
            let result = try await claudeService.augmentNotes(
                userNotes: meeting.userNotes,
                transcript: meeting.rawTranscript,
                toneMode: meeting.toneMode
            )
            meeting.augmentedNotes = result
            meeting.status = "done"
        } catch {
            augmentError = error.localizedDescription
            meeting.status = meeting.rawTranscript.isEmpty ? "idle" : "done"
        }

        isAugmenting = false
    }
}
