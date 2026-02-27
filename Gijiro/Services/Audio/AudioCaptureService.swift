import Foundation
import CoreAudio
import AVFoundation
import Accelerate

enum AudioSource: Sendable { case system, microphone }

/// Captures system audio via CoreAudio Taps API (macOS 14.2+).
/// Optionally captures microphone audio via AVAudioEngine when enabled.
/// System and microphone audio are delivered as separate streams.
final class AudioCaptureService: NSObject, @unchecked Sendable {
    private let lock = NSLock()

    // CoreAudio Tap state
    private var processTapID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
    private var deviceProcID: AudioDeviceIOProcID?

    // Microphone capture (enabled by default)
    private var micEngine: AVAudioEngine?
    private var micSamples: [Float] = []
    var micEnabled = true

    // Audio accumulation — store pre-converted 16kHz mono float samples
    // (NOT raw AVAudioPCMBuffer references, which become stale after IO proc returns)
    private var systemSamples: [Float] = []
    private var chunkStartTime: Date = .now
    private let chunkDuration: TimeInterval = 3
    private let sampleRate: Double = 16000

    /// Minimum RMS threshold to consider a chunk as non-silent.
    /// Chunks below this are skipped to prevent Whisper hallucinations.
    private let silenceThreshold: Float = 0.005

    private var _isCapturing = false
    var isCapturing: Bool {
        lock.withLock { _isCapturing }
    }

    var onAudioChunkReady: ((Data, AudioSource) -> Void)?

    /// Called for every IO proc frame with raw int16 PCM (16kHz mono).
    var onAudioBuffer: ((Data) -> Void)?

    // Target format for all conversions
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

    // Cached converters (created once per capture session)
    private var cachedSystemConverter: AVAudioConverter?
    private var cachedMicConverter: AVAudioConverter?

    // Audio level metering for waveform visualization
    private var _currentAudioLevel: Float = 0.0
    var currentAudioLevel: Float {
        lock.withLock { _currentAudioLevel }
    }

    // Silence detection
    private var _hasReceivedNonSilence = false
    var hasReceivedNonSilence: Bool {
        lock.withLock { _hasReceivedNonSilence }
    }

    private var ioProcCallCount = 0

    func startCapture() async throws {
        lock.withLock {
            _hasReceivedNonSilence = false
            _currentAudioLevel = 0.0
            ioProcCallCount = 0
            systemSamples = []
            micSamples = []
        }

        // 1. Create a global tap that captures all system audio
        let tapDescription = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        tapDescription.uuid = UUID()
        tapDescription.muteBehavior = .unmuted
        tapDescription.name = "GijiroTap"

        print("[AudioCapture] Creating process tap...")
        var tapID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
        var err = AudioHardwareCreateProcessTap(tapDescription, &tapID)
        print("[AudioCapture] AudioHardwareCreateProcessTap -> \(Self.describeOSStatus(err)), tapID=\(tapID)")
        guard err == noErr else {
            throw CaptureError.tapCreationFailed(err)
        }

        // 2. Read the tap's audio stream format
        var formatAddress = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var streamDesc = AudioStreamBasicDescription()
        var descSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        err = AudioObjectGetPropertyData(tapID, &formatAddress, 0, nil, &descSize, &streamDesc)
        print("[AudioCapture] AudioObjectGetPropertyData (format) -> \(Self.describeOSStatus(err)), sampleRate=\(streamDesc.mSampleRate), channels=\(streamDesc.mChannelsPerFrame)")
        guard err == noErr else {
            AudioHardwareDestroyProcessTap(tapID)
            throw CaptureError.formatReadFailed(err)
        }

        guard let tapFormat = AVAudioFormat(streamDescription: &streamDesc) else {
            AudioHardwareDestroyProcessTap(tapID)
            throw CaptureError.formatReadFailed(0)
        }
        print("[AudioCapture] Tap format: \(tapFormat)")

        // 3. Get default output device UID for aggregate device binding
        var defaultOutputID = AudioObjectID(kAudioObjectUnknown)
        var outputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var propSize = UInt32(MemoryLayout<AudioObjectID>.size)
        err = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &outputAddress, 0, nil, &propSize, &defaultOutputID
        )
        print("[AudioCapture] Default output device ID: \(defaultOutputID), err=\(Self.describeOSStatus(err))")

        var outputUIDCF: CFString?
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        propSize = UInt32(MemoryLayout<CFString?>.size)
        err = withUnsafeMutablePointer(to: &outputUIDCF) { uidPtr in
            AudioObjectGetPropertyData(defaultOutputID, &uidAddress, 0, nil, &propSize, uidPtr)
        }
        let outputUID = outputUIDCF as String? ?? ""
        print("[AudioCapture] Default output device UID: \(outputUID), err=\(Self.describeOSStatus(err))")

        // 4. Create aggregate device with the tap bound to the output device
        let tapUID = tapDescription.uuid.uuidString
        let aggregateUID = UUID().uuidString

        let taps: [[String: Any]] = [
            [
                kAudioSubTapUIDKey: tapUID,
                kAudioSubTapDriftCompensationKey: true
            ]
        ]

        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "GijiroTap",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapListKey: taps,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputUID]
            ]
        ]

        print("[AudioCapture] Creating aggregate device...")
        var aggDeviceID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
        err = AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggDeviceID)
        print("[AudioCapture] AudioHardwareCreateAggregateDevice -> \(Self.describeOSStatus(err)), aggDeviceID=\(aggDeviceID)")
        guard err == noErr else {
            AudioHardwareDestroyProcessTap(tapID)
            throw CaptureError.aggregateDeviceFailed(err)
        }

        // 4. Store state
        lock.withLock {
            processTapID = tapID
            aggregateDeviceID = aggDeviceID
            systemSamples = []
            micSamples = []
            chunkStartTime = .now
            _isCapturing = true
        }

        // 5. Optionally start microphone capture via AVAudioEngine
        if micEnabled {
            startMicCapture()
        }

        // 6. Create IO proc and start system audio processing
        let queue = DispatchQueue(label: "com.gijiro.audiotap", qos: .userInitiated)
        var procID: AudioDeviceIOProcID?

        print("[AudioCapture] Creating IO proc...")
        err = AudioDeviceCreateIOProcIDWithBlock(&procID, aggDeviceID, queue) {
            [weak self] _, inInputData, _, _, _ in
            guard let self else { return }

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: tapFormat,
                bufferListNoCopy: inInputData,
                deallocator: nil
            ) else { return }

            // Log first few IO proc calls
            let callCount = self.lock.withLock {
                self.ioProcCallCount += 1
                return self.ioProcCallCount
            }
            if callCount <= 3 {
                print("[AudioCapture] IO proc called #\(callCount), frameLength=\(buffer.frameLength), channels=\(buffer.format.channelCount)")
            }

            // Convert to 16kHz mono float IMMEDIATELY (buffer memory is only valid during this callback)
            if let converted = self.convertBuffer(buffer, to: self.targetFormat, converterKey: .system) {
                let frameCount = Int(converted.frameLength)
                if frameCount > 0, let ptr = converted.floatChannelData?[0] {
                    let samples = Array(UnsafeBufferPointer(start: ptr, count: frameCount))

                    // Compute RMS from converted (non-interleaved float) samples
                    var rms: Float = 0.0
                    vDSP_rmsqv(ptr, 1, &rms, vDSP_Length(frameCount))
                    let normalizedLevel = min(rms * 3.0, 1.0)

                    self.lock.withLock {
                        self._currentAudioLevel = normalizedLevel

                        if !self._hasReceivedNonSilence && rms > 0.0001 {
                            self._hasReceivedNonSilence = true
                            print("[AudioCapture] Non-silent audio detected (RMS=\(rms))")
                        }
                    }

                    self.accumulateSystemSamples(samples)
                }
            } else if callCount <= 5 {
                print("[AudioCapture] WARNING: convertBuffer returned nil for frame #\(callCount)")
            }

            // Streaming: convert to 16kHz mono int16 PCM and emit
            if let onAudioBuffer = self.onAudioBuffer {
                self.emitStreamingPCM(buffer, callback: onAudioBuffer)
            }
        }
        print("[AudioCapture] AudioDeviceCreateIOProcIDWithBlock -> \(Self.describeOSStatus(err))")
        guard err == noErr else {
            AudioHardwareDestroyAggregateDevice(aggDeviceID)
            AudioHardwareDestroyProcessTap(tapID)
            throw CaptureError.ioProcFailed(err)
        }

        lock.withLock {
            deviceProcID = procID
        }

        print("[AudioCapture] Starting audio device (TCC permission dialog may appear here)...")
        err = AudioDeviceStart(aggDeviceID, procID)
        print("[AudioCapture] AudioDeviceStart -> \(Self.describeOSStatus(err))")
        guard err == noErr else {
            if let procID {
                AudioDeviceDestroyIOProcID(aggDeviceID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggDeviceID)
            AudioHardwareDestroyProcessTap(tapID)
            lock.withLock {
                _isCapturing = false
                self.processTapID = AudioObjectID(kAudioObjectUnknown)
                self.aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
                self.deviceProcID = nil
            }
            throw CaptureError.deviceStartFailed(err)
        }

        print("[AudioCapture] Audio capture started successfully")
    }

    func stopCapture() async {
        let (aggID, tapID, procID) = lock.withLock {
            (aggregateDeviceID, processTapID, deviceProcID)
        }

        // Stop microphone
        stopMicCapture()

        // Stop and clean up CoreAudio resources
        if aggID != AudioObjectID(kAudioObjectUnknown) {
            if let procID {
                AudioDeviceStop(aggID, procID)
                AudioDeviceDestroyIOProcID(aggID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggID)
        }

        if tapID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyProcessTap(tapID)
        }

        // Flush remaining samples as separate final chunks per source
        let (remainingSystem, remainingMic) = lock.withLock {
            let sys = systemSamples
            let mic = micSamples
            systemSamples = []
            micSamples = []
            _isCapturing = false
            processTapID = AudioObjectID(kAudioObjectUnknown)
            aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
            deviceProcID = nil
            _currentAudioLevel = 0.0
            _hasReceivedNonSilence = false
            cachedSystemConverter = nil
            cachedMicConverter = nil
            return (sys, mic)
        }

        if !remainingSystem.isEmpty {
            if let wavData = createWAV(from: remainingSystem) {
                onAudioChunkReady?(wavData, .system)
            }
        }
        if !remainingMic.isEmpty {
            if let wavData = createWAV(from: remainingMic) {
                onAudioChunkReady?(wavData, .microphone)
            }
        }

        print("[AudioCapture] Stopped")
    }

    // MARK: - Microphone Capture

    private func startMicCapture() {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        print("[AudioCapture] Mic input format: \(inputFormat)")

        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            print("[AudioCapture] No microphone available")
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            if let converted = self.convertBuffer(buffer, to: self.targetFormat, converterKey: .microphone) {
                let frameCount = Int(converted.frameLength)
                if frameCount > 0, let ptr = converted.floatChannelData?[0] {
                    let samples = Array(UnsafeBufferPointer(start: ptr, count: frameCount))
                    self.accumulateMicSamples(samples)
                }
            }
        }

        do {
            try engine.start()
            lock.withLock { micEngine = engine }
            print("[AudioCapture] Microphone capture started")
        } catch {
            print("[AudioCapture] Failed to start microphone: \(error)")
        }
    }

    private func stopMicCapture() {
        let engine = lock.withLock {
            let e = micEngine
            micEngine = nil
            return e
        }
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
    }

    // MARK: - Sample Accumulation & Chunking

    /// Called from the IO proc to accumulate system audio samples and trigger chunk flush.
    private func accumulateSystemSamples(_ samples: [Float]) {
        let (shouldFlush, systemChunk, micChunk) = lock.withLock {
            systemSamples.append(contentsOf: samples)
            let elapsed = Date.now.timeIntervalSince(chunkStartTime)
            if elapsed >= chunkDuration {
                let sys = systemSamples
                let mic = micSamples
                systemSamples = []
                micSamples = []
                chunkStartTime = .now
                return (true, sys, mic)
            }
            return (false, [Float](), [Float]())
        }

        if shouldFlush {
            if !systemChunk.isEmpty, let wavData = createWAV(from: systemChunk) {
                onAudioChunkReady?(wavData, .system)
            }
            if !micChunk.isEmpty, let wavData = createWAV(from: micChunk) {
                onAudioChunkReady?(wavData, .microphone)
            }
        }
    }

    /// Called from the mic tap to accumulate microphone samples.
    private func accumulateMicSamples(_ samples: [Float]) {
        lock.withLock {
            micSamples.append(contentsOf: samples)
        }
    }

    // MARK: - Streaming PCM Output

    /// Convert a tap buffer to 16kHz mono int16 PCM and emit via callback.
    private func emitStreamingPCM(_ buffer: AVAudioPCMBuffer, callback: @escaping (Data) -> Void) {
        guard let converted = convertBuffer(buffer, to: targetFormat, converterKey: .system) else { return }

        let frameCount = Int(converted.frameLength)
        guard frameCount > 0, let floatData = converted.floatChannelData?[0] else { return }

        // Convert float32 [-1.0, 1.0] → int16 [-32767, 32767]
        var int16Samples = [Int16](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            let clamped = max(-1.0, min(1.0, floatData[i]))
            int16Samples[i] = Int16(clamped * 32767)
        }

        let data = int16Samples.withUnsafeBufferPointer { ptr in
            Data(buffer: ptr)
        }
        callback(data)
    }

    // MARK: - WAV Creation

    /// Create WAV data from pre-converted 16kHz mono float samples.
    /// Returns nil if the chunk is silent (below threshold).
    private func createWAV(from samples: [Float]) -> Data? {
        guard !samples.isEmpty else { return nil }

        // Check RMS — skip silent chunks to prevent Whisper hallucination
        var rms: Float = 0.0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        if rms < silenceThreshold {
            print("[AudioCapture] Skipping silent chunk (RMS=\(rms) < threshold=\(silenceThreshold))")
            return nil
        }

        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        do {
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
                return nil
            }
            outputBuffer.frameLength = AVAudioFrameCount(samples.count)
            let dst = outputBuffer.floatChannelData![0]
            samples.withUnsafeBufferPointer { src in
                dst.update(from: src.baseAddress!, count: samples.count)
            }

            let file = try AVAudioFile(forWriting: tempURL, settings: format.settings)
            try file.write(from: outputBuffer)
            return try Data(contentsOf: tempURL)
        } catch {
            print("[AudioCapture] WAV creation error: \(error)")
            return nil
        }
    }

    // MARK: - Audio Conversion

    private enum ConverterKey { case system, microphone }

    /// Get or create a cached converter for the given input format and source.
    private func getConverter(from inputFormat: AVAudioFormat, key: ConverterKey) -> AVAudioConverter? {
        let cached: AVAudioConverter? = lock.withLock {
            switch key {
            case .system: return cachedSystemConverter
            case .microphone: return cachedMicConverter
            }
        }
        if let cached, cached.inputFormat == inputFormat {
            return cached
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            print("[AudioCapture] ERROR: AVAudioConverter creation failed from \(inputFormat) to \(targetFormat)")
            return nil
        }
        lock.withLock {
            switch key {
            case .system: cachedSystemConverter = converter
            case .microphone: cachedMicConverter = converter
            }
        }
        print("[AudioCapture] Created new AVAudioConverter (\(key)): \(inputFormat) -> \(targetFormat)")
        return converter
    }

    private func convertBuffer(_ buffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat, converterKey: ConverterKey) -> AVAudioPCMBuffer? {
        guard buffer.frameLength > 0 else { return nil }
        guard let converter = getConverter(from: buffer.format, key: converterKey) else {
            return nil
        }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard outputFrameCount > 0 else { return nil }
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
            print("[AudioCapture] ERROR: Failed to create output buffer (capacity=\(outputFrameCount))")
            return nil
        }

        var error: NSError?
        var hasData = true
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if hasData {
                outStatus.pointee = .haveData
                hasData = false
                return buffer
            }
            outStatus.pointee = .noDataNow
            return nil
        }

        if let error {
            print("[AudioCapture] Audio conversion error: \(error)")
            return nil
        }

        return outputBuffer
    }

    // MARK: - Helpers

    /// Decode an OSStatus into its 4-char code string or decimal.
    static func describeOSStatus(_ status: OSStatus) -> String {
        if status == noErr { return "noErr (0)" }
        let bytes: [UInt8] = [
            UInt8((status >> 24) & 0xFF),
            UInt8((status >> 16) & 0xFF),
            UInt8((status >> 8) & 0xFF),
            UInt8(status & 0xFF),
        ]
        if bytes.allSatisfy({ $0 >= 0x20 && $0 <= 0x7E }) {
            let chars = bytes.map { Character(UnicodeScalar($0)) }
            return "'\(String(chars))' (\(status))"
        }
        return "\(status)"
    }

    // MARK: - Errors

    enum CaptureError: LocalizedError {
        case tapCreationFailed(OSStatus)
        case formatReadFailed(OSStatus)
        case aggregateDeviceFailed(OSStatus)
        case ioProcFailed(OSStatus)
        case deviceStartFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .tapCreationFailed(let s): return "Failed to create audio tap (\(AudioCaptureService.describeOSStatus(s)))"
            case .formatReadFailed(let s): return "Failed to read tap format (\(AudioCaptureService.describeOSStatus(s)))"
            case .aggregateDeviceFailed(let s): return "Failed to create aggregate device (\(AudioCaptureService.describeOSStatus(s)))"
            case .ioProcFailed(let s): return "Failed to create IO proc (\(AudioCaptureService.describeOSStatus(s)))"
            case .deviceStartFailed(let s): return "Failed to start audio device (\(AudioCaptureService.describeOSStatus(s)))"
            }
        }
    }
}
