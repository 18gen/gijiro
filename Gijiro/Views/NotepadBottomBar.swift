import SwiftUI
import SwiftData

struct NotepadBottomBar: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var meeting: Meeting
    @Binding var showTranscriptPanel: Bool

    @State private var coordinator = RecordingCoordinator.shared
    @State private var askText = ""
    @State private var askAnswer = ""
    @State private var isAsking = false
    @State private var isSuggesting = false
    @State private var showAskPopover = false
    @State private var showSuggestPopover = false
    @State private var suggestResult = ""
    @State private var askError: String?

    private let claudeService = ClaudeService()

    var body: some View {
        VStack(spacing: 4) {
            // Recording error (above the bar if present)
            if let error = coordinator.recordingError {
                Button {
                    RecordingCoordinator.openSystemAudioSettings()
                } label: {
                    HStack(spacing: 2) {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                        Image(systemName: "arrow.up.forward.square")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                // Left: audio waveform + chevron + Resume/Pause
                HStack(spacing: 6) {
                    AudioWaveformBars(
                        audioLevel: coordinator.currentAudioLevel,
                        isRecording: coordinator.isRecording
                    )

                    // Expand/collapse transcript panel
                    Button {
                        showTranscriptPanel.toggle()
                    } label: {
                        Image(systemName: showTranscriptPanel ? "chevron.down" : "chevron.up")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    // Start/Stop text button
                    Button {
                        Task {
                            if coordinator.isRecording {
                                await coordinator.stopRecording()
                            } else {
                                await coordinator.startRecording(meeting: meeting, modelContext: modelContext)
                            }
                        }
                    } label: {
                        Text(coordinator.isRecording ? "Pause" : "Resume")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(coordinator.isRecording ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.08))
                .clipShape(Capsule())

                // Center: Ask anything
                HStack(spacing: 4) {
                    TextField("Ask anything", text: $askText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .onSubmit {
                            Task { await askQuestion() }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .overlay(
                    Capsule()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .clipShape(Capsule())
                .popover(isPresented: $showAskPopover) {
                    askPopoverContent
                }

                // Right: Suggest topics
                Button {
                    Task { await suggestTopics() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.purple)
                        Text("Suggest topics")
                            .font(.callout)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .overlay(
                        Capsule()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSuggesting || (meeting.rawTranscript.isEmpty && meeting.userNotes.isEmpty))
                .popover(isPresented: $showSuggestPopover) {
                    suggestPopoverContent
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Ask Popover

    private var askPopoverContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Answer")
                .font(.headline)

            if isAsking {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let error = askError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            } else {
                ScrollView {
                    Text(askAnswer)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }

    // MARK: - Suggest Popover

    private var suggestPopoverContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested Topics")
                .font(.headline)

            if isSuggesting {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView {
                    Text(suggestResult)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }

    // MARK: - Actions

    private func askQuestion() async {
        let question = askText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        isAsking = true
        askError = nil
        showAskPopover = true

        do {
            let answer = try await claudeService.askQuestion(
                question: question,
                userNotes: meeting.userNotes,
                transcript: meeting.rawTranscript
            )
            askAnswer = answer
        } catch {
            askError = error.localizedDescription
        }

        isAsking = false
    }

    private func suggestTopics() async {
        isSuggesting = true
        showSuggestPopover = true

        do {
            let result = try await claudeService.suggestTopics(
                userNotes: meeting.userNotes,
                transcript: meeting.rawTranscript
            )
            suggestResult = result
        } catch {
            suggestResult = "Error: \(error.localizedDescription)"
        }

        isSuggesting = false
    }
}

// MARK: - Audio Waveform Bars

struct AudioWaveformBars: View {
    let audioLevel: Float
    let isRecording: Bool

    private let barCount = 4
    private let barScales: [Float] = [0.6, 1.0, 0.8, 0.5]
    private let minBarHeight: CGFloat = 0.2
    private let maxBarHeight: CGFloat = 16

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isRecording ? Color.green : Color.secondary.opacity(0.3))
                    .frame(
                        width: 3,
                        height: barHeight(for: index)
                    )
                    .animation(
                        .easeInOut(duration: 0.08),
                        value: audioLevel
                    )
            }
        }
        .frame(width: 20, height: maxBarHeight)
    }

    private func barHeight(for index: Int) -> CGFloat {
        if !isRecording {
            return maxBarHeight * minBarHeight * CGFloat(barScales[index])
        }

        let scale = CGFloat(barScales[index])
        let level = CGFloat(audioLevel)
        let height = max(minBarHeight, level * scale) * maxBarHeight
        return min(height, maxBarHeight)
    }
}
