import Foundation
import SwiftData
import Observation
import AppKit

@Observable
@MainActor
final class RecordingCoordinator {
    static let shared = RecordingCoordinator()

    private let audioCaptureService = AudioCaptureService()
    private let whisperService = WhisperService()

    var isRecording = false
    var currentMeeting: Meeting?
    var recordingError: String?

    /// Current partial (unstable) transcript text — shown dimmed in the UI.
    var currentPartial: String = ""

    /// Current audio level for waveform display [0.0, 1.0].
    var currentAudioLevel: Float = 0.0

    /// Accumulated committed (final) transcript text.
    private var committedText: String = ""

    /// Elapsed time offset for segment timestamps (seconds since recording started).
    private var recordingStartDate: Date = .now

    /// Timer that polls audio capture service for level updates (~30 FPS).
    private var levelPollTimer: Timer?

    private init() {}

    func startRecording(meeting: Meeting, modelContext: ModelContext) async {
        recordingError = nil
        currentMeeting = meeting
        meeting.status = "recording"
        committedText = ""
        currentPartial = ""
        recordingStartDate = .now

        let apiKey = AppSettings.whisperKey
        print("[Recording] Starting... Whisper API key present: \(!apiKey.isEmpty)")

        guard !apiKey.isEmpty else {
            recordingError = "OpenAI API key not configured. Add it in Settings."
            print("[Recording] ERROR: \(recordingError!)")
            meeting.status = "idle"
            return
        }

        // Wire 3-second WAV chunks → Whisper transcription (separate per source)
        audioCaptureService.onAudioChunkReady = { [weak self] wavData, source in
            guard let self else { return }
            let sourceLabel: String
            switch source {
            case .system:
                sourceLabel = "system"
            case .microphone:
                sourceLabel = "microphone"
            }
            print("[Recording] Audio chunk ready (\(sourceLabel)): \(wavData.count) bytes")
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentPartial = "..."
            }
            Task {
                await self.transcribeChunk(wavData, source: source)
            }
        }

        // Disable streaming (not using Deepgram)
        audioCaptureService.onAudioBuffer = nil

        do {
            try await audioCaptureService.startCapture()
            isRecording = true
            print("[Recording] Audio capture started successfully")

            // Start polling audio level for waveform visualization
            levelPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.currentAudioLevel = self.audioCaptureService.currentAudioLevel
                    // Clear the "listening" warning once audio is detected
                    if self.recordingError != nil && self.audioCaptureService.hasReceivedNonSilence {
                        self.recordingError = nil
                    }
                }
            }

            // Silence detection: warn user after 5 seconds if no audio arrives
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard let self, self.isRecording else { return }
                if !self.audioCaptureService.hasReceivedNonSilence {
                    self.recordingError = "Listening for audio... If nothing appears, check System Settings > Privacy > Screen & System Audio Recording."
                    print("[Recording] WARNING: No non-silent audio after 5 seconds")
                }
            }
        } catch {
            recordingError = "Failed to start: \(error.localizedDescription)"
            print("[Recording] ERROR: \(recordingError!)")
            meeting.status = "idle"
        }
    }

    func stopRecording() async {
        levelPollTimer?.invalidate()
        levelPollTimer = nil
        currentAudioLevel = 0.0

        await audioCaptureService.stopCapture()

        currentPartial = ""
        isRecording = false
        currentMeeting?.status = "done"
        currentMeeting?.endDate = .now
        currentMeeting = nil
        committedText = ""
    }

    /// Opens System Settings to Privacy & Security > Screen & System Audio Recording.
    static func openSystemAudioSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Whisper Micro-Batch

    /// Known Whisper hallucination strings that appear when processing silence.
    nonisolated private static let whisperHallucinations: Set<String> = [
        "ご清聴ありがとうございました。",
        "ご清聴ありがとうございました",
        "ご視聴ありがとうございました。",
        "ご視聴ありがとうございました",
        "お疲れ様でした。",
        "お疲れ様でした",
        "ありがとうございました。",
        "ありがとうございました",
        "Thank you.",
        "Thank you for watching.",
        "Thanks for watching.",
        "Thank you for listening.",
        "Bye.",
        "Bye bye.",
        "...",
        "。",
    ]

    private nonisolated func transcribeChunk(_ wavData: Data, source: AudioSource) async {
        do {
            let result = try await whisperService.transcribe(audioData: wavData)
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }

            // Filter out known Whisper hallucinations on silence
            if Self.whisperHallucinations.contains(text) {
                print("[Recording] Filtered Whisper hallucination: \(text)")
                await MainActor.run { [weak self] in
                    self?.currentPartial = ""
                }
                return
            }

            let sourceString: String
            switch source {
            case .system:
                sourceString = "system"
            case .microphone:
                sourceString = "microphone"
            }

            await MainActor.run { [weak self] in
                guard let self, let meeting = self.currentMeeting else { return }

                let elapsedSeconds = Date.now.timeIntervalSince(self.recordingStartDate)

                // Append to committed text
                if !self.committedText.isEmpty {
                    self.committedText += "\n"
                }
                self.committedText += text

                // Clear partial indicator
                self.currentPartial = ""

                // Update rawTranscript
                meeting.rawTranscript = self.committedText

                // Group consecutive chunks from the same source into one segment
                if let lastSegment = meeting.segments.last, lastSegment.source == sourceString {
                    lastSegment.text += " " + text
                    lastSegment.endTime = elapsedSeconds
                } else {
                    let segment = TranscriptSegment(
                        text: text,
                        startTime: max(0, elapsedSeconds - 3),
                        endTime: elapsedSeconds,
                        source: sourceString
                    )
                    meeting.segments.append(segment)
                }
            }
        } catch {
            await MainActor.run { [weak self] in
                guard let self else { return }
                print("[Recording] Whisper error: \(error)")
                self.currentPartial = ""
                if case WhisperService.WhisperError.noAPIKey = error {
                    self.recordingError = error.localizedDescription
                }
            }
        }
    }
}
