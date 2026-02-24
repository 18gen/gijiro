import SwiftUI
import SwiftData

struct TranscriptPanelView: View {
    @Bindable var meeting: Meeting
    @Binding var isExpanded: Bool

    @State private var coordinator = RecordingCoordinator.shared

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    // Copy transcript
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(meeting.rawTranscript, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    isExpanded = false
                } label: {
                    Image(systemName: "minus")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .font(.caption)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Transcript content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        Text("Always get consent when transcribing others.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 16)

                        if meeting.segments.isEmpty && meeting.rawTranscript.isEmpty && coordinator.currentPartial.isEmpty {
                            Text("Transcript will appear here during recording...")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 30)
                        } else if !meeting.segments.isEmpty {
                            let sortedSegments = meeting.segments.sorted { $0.startTime < $1.startTime }

                            // Committed transcript bubbles with timestamps at source transitions
                            ForEach(Array(sortedSegments.enumerated()), id: \.element.id) { index, segment in
                                let isFirstOrSourceChanged = index == 0 ||
                                    sortedSegments[index - 1].source != segment.source

                                if isFirstOrSourceChanged {
                                    Text(formatTime(segment.startTime))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .padding(.top, index == 0 ? 8 : 4)
                                }

                                TranscriptBubble(text: segment.text, isPartial: false, source: segment.source ?? "system")
                                    .id(segment.id)
                            }

                            // Current partial (dimmed, still refining)
                            if !coordinator.currentPartial.isEmpty {
                                TranscriptBubble(text: coordinator.currentPartial, isPartial: true, source: "microphone")
                                    .id("partial")
                            }
                        } else if !meeting.rawTranscript.isEmpty || !coordinator.currentPartial.isEmpty {
                            // Fallback: show raw transcript text
                            Text(meeting.rawTranscript)
                                .font(.callout)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                    // Anchor for auto-scroll
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .onChange(of: meeting.segments.count) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: coordinator.currentPartial) {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.bottom, 4)
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

private struct TranscriptBubble: View {
    let text: String
    let isPartial: Bool
    var source: String = "system"

    private var isSystem: Bool { source == "system" }

    private var bubbleColor: Color {
        if isPartial { return Color.secondary.opacity(0.06) }
        return isSystem
            ? Theme.accent.opacity(0.10)
            : Theme.accent.opacity(0.10)
    }

    var body: some View {
        HStack {
            if !isSystem {
                Spacer(minLength: 40)
            }
            Text(text)
                .font(.callout)
                .foregroundStyle(isPartial ? .secondary : .primary)
                .italic(isPartial)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if isSystem {
                Spacer(minLength: 40)
            }
        }
    }
}
