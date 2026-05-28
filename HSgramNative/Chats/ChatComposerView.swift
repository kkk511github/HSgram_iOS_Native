import SwiftUI
import UIKit
import AVFoundation

struct HSVoiceRecording {
    let data: Data
    let fileName: String
    let mimeType: String
    let duration: Double
    let waveform: Data?
}

struct ChatComposerView: View {
    @Binding var draft: String
    let isReplying: Bool
    let replyTitle: String
    let replyPreview: String
    let onClearReply: () -> Void
    let onAttachment: () -> Void
    let onVoiceRecorded: (HSVoiceRecording) -> Void
    let onVoiceError: (String) -> Void
    let onVoiceRecordingStateChanged: (Bool) -> Void
    let onSend: () -> Void

    @StateObject private var voiceRecorder = HSVoiceRecorder()

    var body: some View {
        VStack(spacing: 0) {
            if isReplying {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(HSTheme.accent)
                        .frame(width: 3)
                        .clipShape(Capsule())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(replyTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(HSTheme.accent)
                        Text(replyPreview)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(HSTheme.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        onClearReply()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(HSTheme.secondaryText)
                }
                .frame(height: 48)
                .padding(.horizontal, 12)
                .background(Color.white)
            }

            composerControls
            .padding(.horizontal, 8)
            .padding(.top, 7)
            .padding(.bottom, 7)
            .background(HSTheme.Chat.composerBackground)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(HSTheme.Chat.panelSeparatorColor)
                    .frame(height: 1 / UIScreen.main.scale)
            }
        }
    }

    @ViewBuilder
    private var composerControls: some View {
        if voiceRecorder.isRecording {
            VoiceRecordingBar(
                duration: voiceRecorder.duration,
                level: voiceRecorder.level,
                onCancel: cancelVoiceRecording,
                onSend: finishVoiceRecording
            )
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    onAttachment()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 29, weight: .regular))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(HSTheme.Chat.panelControlColor.opacity(0.72))
                .accessibilityLabel("添加附件")

                TextField("消息", text: $draft, axis: .vertical)
                    .font(.system(size: 17, weight: .regular))
                    .lineLimit(1...5)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(HSTheme.Chat.inputFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(HSTheme.Chat.composerStroke, lineWidth: 1)
                    )

                Button {
                    handlePrimaryAction()
                } label: {
                    Image(systemName: draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 31, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? HSTheme.Chat.panelControlColor.opacity(0.7) : HSTheme.accent)
                .accessibilityLabel(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "语音" : "发送")
            }
        }
    }

    private func handlePrimaryAction() {
        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task {
                await beginVoiceRecording()
            }
        } else {
            onSend()
        }
    }

    private func beginVoiceRecording() async {
        do {
            try await voiceRecorder.start()
            onVoiceRecordingStateChanged(true)
        } catch {
            onVoiceError(error.localizedDescription)
        }
    }

    private func finishVoiceRecording() {
        do {
            let recording = try voiceRecorder.finish()
            onVoiceRecordingStateChanged(false)
            onVoiceRecorded(recording)
        } catch {
            onVoiceRecordingStateChanged(false)
            onVoiceError(error.localizedDescription)
        }
    }

    private func cancelVoiceRecording() {
        voiceRecorder.cancel()
        onVoiceRecordingStateChanged(false)
    }
}

private struct VoiceRecordingBar: View {
    let duration: Double
    let level: Double
    let onCancel: () -> Void
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onCancel) {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .accessibilityLabel("取消录音")

            HStack(spacing: 10) {
                Circle()
                    .fill(.red)
                    .frame(width: 9, height: 9)
                Text(Self.durationFormatter.string(from: duration) ?? "0:00")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(HSTheme.primaryText)
                VoiceLevelMeter(level: level)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HSTheme.Chat.inputFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(HSTheme.Chat.composerStroke, lineWidth: 1)
            )

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 31, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(HSTheme.accent)
            .accessibilityLabel("发送语音")
        }
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}

private struct VoiceLevelMeter: View {
    let level: Double

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(indexLevel(index) <= level ? HSTheme.accent : HSTheme.secondaryText.opacity(0.25))
                    .frame(width: 3, height: height(for: index))
            }
        }
        .frame(height: 22)
        .accessibilityHidden(true)
    }

    private func indexLevel(_ index: Int) -> Double {
        Double(index + 1) / 12.0
    }

    private func height(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [8, 12, 16, 20, 13, 18, 10, 15, 21, 12, 17, 9]
        return pattern[index % pattern.count]
    }
}

@MainActor
private final class HSVoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var duration: Double = 0
    @Published var level: Double = 0.05

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var recordingURL: URL?
    private var meterSamples: [Double] = []

    func start() async throws {
        guard !isRecording else {
            return
        }
        let session = AVAudioSession.sharedInstance()
        let permission = await requestRecordPermission(session: session)
        guard permission else {
            throw HSAPIError.server(code: "MICROPHONE_PERMISSION_DENIED", message: "麦克风权限未开启。")
        }

        let url = Self.recordingURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            throw HSAPIError.server(code: "VOICE_RECORD_FAILED", message: "无法开始录音。")
        }
        self.recorder = recorder
        recordingURL = url
        duration = 0
        level = 0.05
        meterSamples = []
        isRecording = true
        startTimer()
    }

    func finish() throws -> HSVoiceRecording {
        guard let recorder, let recordingURL else {
            throw HSAPIError.server(code: "VOICE_RECORDING_MISSING", message: "没有可发送的录音。")
        }
        let recordedDuration = max(duration, recorder.currentTime)
        recorder.stop()
        stopTimer()
        isRecording = false
        self.recorder = nil
        self.recordingURL = nil
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        guard recordedDuration >= 0.5 else {
            try? FileManager.default.removeItem(at: recordingURL)
            throw HSAPIError.server(code: "VOICE_TOO_SHORT", message: "语音消息太短。")
        }
        let data = try Data(contentsOf: recordingURL)
        try? FileManager.default.removeItem(at: recordingURL)
        return HSVoiceRecording(
            data: data,
            fileName: "hsgram-voice-\(Int(Date().timeIntervalSince1970)).m4a",
            mimeType: "audio/mp4",
            duration: recordedDuration,
            waveform: HSVoiceWaveformCodec.encode(levels: meterSamples)
        )
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        stopTimer()
        isRecording = false
        duration = 0
        level = 0.05
        meterSamples = []
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            guard let self else {
                return
            }
            Task { @MainActor in
                self.updateMeter()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateMeter() {
        guard let recorder else {
            return
        }
        recorder.updateMeters()
        duration = recorder.currentTime
        let power = recorder.averagePower(forChannel: 0)
        level = min(1, max(0.05, (Double(power) + 55) / 55))
        meterSamples.append(level)
        if meterSamples.count > 320 {
            meterSamples.removeFirst(meterSamples.count - 320)
        }
    }

    private func requestRecordPermission(session: AVAudioSession) async -> Bool {
        switch session.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                session.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    private static func recordingURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("hsgram-voice-\(UUID().uuidString).m4a", isDirectory: false)
    }
}
