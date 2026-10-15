import AVFoundation
import Foundation
import Synchronization

/// Cues for interval changes: synthesized tones, a spoken interval name, or an imported file.
///
/// While a workout runs, the audio engine keeps playing (silence between beeps). With the
/// `audio` background mode, that keeps the app running when the phone is locked, so it can
/// keep the Live Activity on the current interval. Mixes with music rather than pausing it.
@MainActor
final class AudioCues {
    private static let sampleRate = 44_100.0
    /// Used by the sound picker, which is never open while a workout runs.
    static let previewer = AudioCues()

    private let engine = AVAudioEngine()
    private let tones = ToneGenerator(sampleRate: AudioCues.sampleRate)
    private let speech = AVSpeechSynthesizer()
    private var filePlayer: AVAudioPlayer?
    private var node: AVAudioSourceNode?
    private var active = false
    private var stopTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    func start() {
        stopTask?.cancel()
        stopTask = nil
        guard !active else { return }
        active = true

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        if node == nil {
            let source = Self.makeSourceNode(tones: tones, sampleRate: Self.sampleRate)
            engine.attach(source)
            engine.connect(source, to: engine.mainMixerNode,
                           format: AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1))
            node = source
            observeRestarts()
        }
        try? engine.start()
    }

    /// Stops after `delay`, so a final cue can finish playing.
    func stop(after delay: TimeInterval = 0) {
        guard active else { return }
        stopTask?.cancel()
        stopTask = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled, let self else { return }
            self.silence()
            self.engine.stop()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            self.active = false
        }
    }

    func countdownBeep(_ sound: CueSound) {
        // Voice and imported sounds only replace the interval-change cue; the countdown stays a beep.
        let pack = if case .tone(let pack) = sound { pack } else { TonePack.classic }
        tones.play(pack.countdown)
    }

    /// Plays the cue for an interval starting. Returns roughly how long it lasts.
    @discardableResult
    func transitionCue(_ sound: CueSound, name: String) -> TimeInterval {
        silence()
        switch sound {
        case .tone(let pack):
            return tones.play(pack.transition)
        case .voice:
            return speak(name)
        case .custom(let id):
            return playFile(id) ?? tones.play(TonePack.classic.transition)
        }
    }

    /// Plays the cue for the run finishing. Returns roughly how long it lasts.
    @discardableResult
    func finishedCue(_ sound: CueSound) -> TimeInterval {
        silence()
        switch sound {
        case .tone(let pack):
            return tones.play(pack.finished)
        case .voice:
            tones.play(TonePack.classic.finished)
            return max(1.5, speak("Workout complete"))
        case .custom(let id):
            return playFile(id) ?? tones.play(TonePack.classic.finished)
        }
    }

    /// Plays a sound once on its own, for the sound picker.
    func preview(_ sound: CueSound) {
        start()
        let length = transitionCue(sound, name: "Work")
        stop(after: min(length, 6) + 0.3)
    }

    /// Cuts off whatever is still playing, so cues don't pile up.
    private func silence() {
        tones.clear()
        filePlayer?.stop()
        filePlayer = nil
        if speech.isSpeaking { speech.stopSpeaking(at: .immediate) }
    }

    private func speak(_ text: String) -> TimeInterval {
        let utterance = AVSpeechUtterance(string: text)
        utterance.volume = 1
        speech.speak(utterance)
        return 0.6 + Double(text.count) * 0.07
    }

    private func playFile(_ id: UUID) -> TimeInterval? {
        guard let url = SoundLibrary.fileURL(for: id),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.play()
        filePlayer = player
        return player.duration
    }

    /// Phone calls, Siri and route changes stop the engine; start it again afterwards.
    private func observeRestarts() {
        let names = [AVAudioSession.interruptionNotification, .AVAudioEngineConfigurationChange]
        for name in names {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.restartIfNeeded() }
            })
        }
    }

    private func restartIfNeeded() {
        guard active, stopTask == nil, !engine.isRunning else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()
    }

    /// Built outside the main actor: the render block runs on the real-time audio thread.
    private nonisolated static func makeSourceNode(tones: ToneGenerator, sampleRate: Double) -> AVAudioSourceNode {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        // Silence is written as real zero samples (not flagged as silent) so output never idles.
        return AVAudioSourceNode(format: format) { _, _, frameCount, bufferList in
            tones.render(into: UnsafeMutableAudioBufferListPointer(bufferList), frames: Int(frameCount))
            return noErr
        }
    }
}

/// One synthesized beep.
struct ToneSpec: Sendable {
    enum Shape: Sendable {
        case sine
        /// Inharmonic partials, like a struck bell. Pair with `decay`.
        case bell
        /// Band-limited square: buzzy, digital-watch style.
        case square
    }

    var frequency: Double
    var duration: TimeInterval
    var gapBefore: TimeInterval = 0
    var shape: Shape = .sine
    /// Exponential fade per second (0 = flat).
    var decay: Double = 0
    var volume: Double = 0.6
}

/// Queue of beeps rendered on the audio thread.
final class ToneGenerator: Sendable {
    private struct Tone {
        var spec: ToneSpec
        var delay: Int
        var played: Int
        var total: Int
    }

    private let sampleRate: Double
    private let state = Mutex([Tone]())

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    /// Queues the tones to play one after another. Returns their total length in seconds.
    @discardableResult
    func play(_ specs: [ToneSpec]) -> TimeInterval {
        let queued = specs.map {
            Tone(spec: $0, delay: Int($0.gapBefore * sampleRate), played: 0, total: Int($0.duration * sampleRate))
        }
        state.withLock { $0.append(contentsOf: queued) }
        return specs.reduce(0) { $0 + $1.gapBefore + $1.duration }
    }

    func clear() {
        state.withLock { $0.removeAll() }
    }

    func render(into buffers: UnsafeMutableAudioBufferListPointer, frames: Int) {
        state.withLock { tones in
            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for i in 0..<frames { data[i] = 0 }
            }
            guard !tones.isEmpty, let out = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else {
                return
            }
            let attack = 0.005 * sampleRate, release = 0.03 * sampleRate
            for i in 0..<frames {
                guard var tone = tones.first else { break }
                if tone.delay > 0 {
                    tone.delay -= 1
                } else {
                    let spec = tone.spec
                    let t = Double(tone.played) / sampleRate
                    var envelope = min(1, Double(tone.played) / attack) * min(1, Double(tone.total - tone.played) / release)
                    if spec.decay > 0 { envelope *= exp(-t * spec.decay) }
                    let phase = 2 * .pi * spec.frequency * t
                    out[i] = Float(Self.wave(spec.shape, phase) * envelope * spec.volume)
                    tone.played += 1
                }
                if tone.delay == 0 && tone.played >= tone.total {
                    tones.removeFirst()
                } else {
                    tones[0] = tone
                }
            }
        }
    }

    private static func wave(_ shape: ToneSpec.Shape, _ p: Double) -> Double {
        switch shape {
        case .sine:
            sin(p)
        case .bell:
            (sin(p) + 0.5 * sin(2.76 * p) + 0.25 * sin(5.4 * p) + 0.12 * sin(8.93 * p)) / 1.87
        case .square:
            (sin(p) + sin(3 * p) / 3 + sin(5 * p) / 5) * 0.85
        }
    }
}
