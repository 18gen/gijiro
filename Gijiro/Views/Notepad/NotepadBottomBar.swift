//
//  NotepadBottomBar.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-25.
//

import SwiftUI
import SwiftData

struct NotepadBottomBar: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var meeting: Meeting
    @Binding var showTranscriptPanel: Bool

    @State private var coordinator = RecordingCoordinator.shared

    @State private var askText = ""
    @State private var askAnswer = ""
    @State private var askError: String?
    @State private var isAsking = false
    @State private var showAskPopover = false

    @FocusState private var askFocused: Bool

    private let claudeService = ClaudeService.shared

    // example receipts (you’ll replace these)
    private var receipts: [Receipt] {
        [
            .init(title: "Write follow up email", prompt: "Write a follow up email based on these notes.", style: .blue),
            .init(title: "List my todos", prompt: "List all action items and todos.", style: .green),
            .init(title: "Make notes longer", prompt: "Rewrite notes to be more detailed and structured.", style: .cyan),
        ]
    }

    var body: some View {
        VStack(spacing: 10) {
            if let error = coordinator.recordingError {
                Button { RecordingCoordinator.openSystemAudioSettings() } label: {
                    HStack(spacing: 6) {
                        Text(error).font(.caption2).foregroundStyle(.red).lineLimit(1)
                        Image(systemName: "arrow.up.forward.square").font(.caption2).foregroundStyle(.red.opacity(0.8))
                    }
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                if askFocused {
                    receiptsRow
                        .transition(
                            .asymmetric(
                                insertion: .push(from: .bottom).combined(with: .opacity),
                                removal:   .push(from: .top).combined(with: .opacity)
                            )
                        )
                }

                HStack(spacing: 10) {
                    if !askFocused {
                        recordingCapsule
                    }

                    AskBar(
                        text: $askText,
                        isAsking: $isAsking,
                        focus: $askFocused,
                        placeholder: askFocused ? "Type / for recipes" : "Ask anything",
                        onSend: { Task { await askQuestion() } }
                    ) {
                        if !askFocused, let first = receipts.first {
                            ReceiptPill(receipt: first) { applyReceipt(first) }
                                .transition(.opacity)
                        }
                    }
                }
            }
            .glassSurface(cornerRadius: AppTheme.barCorner, padding: 12)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.barCorner, style: .continuous)
                    .strokeBorder(
                        askFocused ? AppTheme.primary : Color.clear,
                        lineWidth: askFocused ? 1.5 : 0
                    )
            )
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: askFocused)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .popover(isPresented: $showAskPopover) { askPopoverContent }
    }

    // MARK: - Receipts Row

    private var receiptsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(receipts.prefix(3)) { r in
                    ReceiptPill(receipt: r) {
                        applyReceipt(r)
                    }
                }

                Divider()
                    .frame(height: 18)
                    .opacity(0.2)
                    .padding(.horizontal, 2)

                AllRecipesMenu(receipts: receipts, onPick: applyReceipt)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
        }
    }

    private func applyReceipt(_ r: Receipt) {
        // UX: insert prompt into field and focus it (or auto-run)
        askText = r.prompt
        askFocused = true
        // If you want “one click runs”, uncomment:
        // Task { await askQuestion() }
    }

    // MARK: - Left Recording Capsule

    private var recordingCapsule: some View {
        HStack(spacing: 10) {
            AudioWaveformBars(audioLevel: coordinator.currentAudioLevel, isRecording: coordinator.isRecording)

            Button { showTranscriptPanel.toggle() } label: {
                Image(systemName: showTranscriptPanel ? "chevron.down" : "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(coordinator.isRecording ? AppTheme.primary : AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1).blendMode(.overlay))
    }

    // MARK: - Popover

    private var askPopoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Answer").font(.headline)

            if isAsking {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let askError {
                Text(askError).foregroundStyle(.red).font(.caption)
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
        .frame(width: 440, height: 320)
    }

    // MARK: - Action

    private func askQuestion() async {
        let q = askText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        isAsking = true
        askError = nil
        showAskPopover = true

        do {
            askAnswer = try await claudeService.askQuestion(
                question: q,
                userNotes: meeting.userNotes,
                transcript: meeting.rawTranscript
            )
        } catch {
            askError = error.localizedDescription
        }

        isAsking = false
    }
}
