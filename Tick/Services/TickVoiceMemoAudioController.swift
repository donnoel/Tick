import AVFoundation
import Foundation

@MainActor
final class TickVoiceMemoAudioController: NSObject, AVAudioPlayerDelegate {
    enum AudioError: LocalizedError {
        case microphonePermissionDenied
        case recordingDidNotStart
        case noActiveRecording

        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                "Microphone permission is needed before Tick can record voice memos."
            case .recordingDidNotStart:
                "Tick could not start recording that voice memo."
            case .noActiveRecording:
                "There is no active voice memo recording to stop."
            }
        }
    }

    var playbackDidFinish: ((VoiceMemo.ID) -> Void)?

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var playingVoiceMemoID: VoiceMemo.ID?

    var isRecording: Bool {
        recorder != nil
    }

    func startRecording(to fileURL: URL) async throws {
        guard await microphonePermissionGranted() else {
            throw AudioError.microphonePermissionDenied
        }

        stopPlaying()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)

        guard recorder.record() else {
            throw AudioError.recordingDidNotStart
        }

        self.recorder = recorder
    }

    func stopRecording() throws -> TimeInterval {
        guard let recorder else {
            throw AudioError.noActiveRecording
        }

        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return duration
    }

    func playVoiceMemo(id: VoiceMemo.ID, fileURL: URL) throws {
        if playingVoiceMemoID == id {
            stopPlaying()
            return
        }

        stopPlaying()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)

        let player = try AVAudioPlayer(contentsOf: fileURL)
        player.delegate = self
        player.prepareToPlay()
        player.play()

        self.player = player
        playingVoiceMemoID = id
    }

    func stopPlaying() {
        player?.stop()
        player = nil
        playingVoiceMemoID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.finishPlayback()
        }
    }

    private func finishPlayback() {
        guard let playingVoiceMemoID else {
            return
        }

        player = nil
        self.playingVoiceMemoID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        playbackDidFinish?(playingVoiceMemoID)
    }

    private func microphonePermissionGranted() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }
}
