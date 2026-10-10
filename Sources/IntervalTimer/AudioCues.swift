import AVFoundation
import Foundation
import Synchronization

/// Beeps for interval changes, synthesized on the fly (no sound files).
///
/// While a workout runs, the audio engine keeps playing (silence between beeps). With the
/// `audio` background mode, that keeps the app running when the phone is locked, so it can
/// keep the Live Activity on the current interval. Mixes with music rather than pausing it.
@MainActor
final class AudioCues {
    private static let sampleRate = 44_100.0

    private let engine = AVAudioEngine()
    private let tones = ToneGenerator(sampleRate: AudioCues.sampleRate)
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

    /// Stops after `delay`, so a final beep can finish playing.
    func stop(after delay: TimeInterval = 0) {
        guard active else { return }
        stopTask?.cancel()
        stopTask = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled, let self else { return }
            self.engine.stop()
            self.tones.clear()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            self.active = false
        }
    }

    func countdownBeep() {
        tones.play(frequency: 880, duration: 0.12)
    }

    func transitionBeep() {
        tones.play(frequency: 1320, duration: 0.45)
    }

    func finishedBeeps() {
        for _ in 0..<3 {
            tones.play(frequency: 1320, duration: 0.16, gapBefore: 0.08)
        }
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

/// Queue of sine-wave beeps rendered on the audio thread.
final class ToneGenerator: Sendable {
    private struct Tone {
        var frequency: Double
        var delay: Int
        var remaining: Int
        var total: Int
    }

    private struct State {
        var tones: [Tone] = []
        var phase = 0.0
    }

    private let sampleRate: Double
    private let state = Mutex(State())

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func play(frequency: Double, duration: TimeInterval, gapBefore: TimeInterval = 0) {
        let samples = Int(duration * sampleRate)
        let tone = Tone(frequency: frequency, delay: Int(gapBefore * sampleRate), remaining: samples, total: samples)
        state.withLock { $0.tones.append(tone) }
    }

    func clear() {
        state.withLock { $0.tones.removeAll() }
    }

    func render(into buffers: UnsafeMutableAudioBufferListPointer, frames: Int) {
        state.withLock { s in
            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for i in 0..<frames { data[i] = 0 }
            }
            guard !s.tones.isEmpty, let out = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else {
                return
            }
            let attack = 0.005 * sampleRate, release = 0.03 * sampleRate
            for i in 0..<frames {
                guard var tone = s.tones.first else { break }
                if tone.delay > 0 {
                    tone.delay -= 1
                } else {
                    let played = Double(tone.total - tone.remaining)
                    let envelope = min(1, played / attack) * min(1, Double(tone.remaining) / release)
                    out[i] = Float(sin(s.phase) * envelope * 0.6)
                    s.phase += 2 * .pi * tone.frequency / sampleRate
                    if s.phase > 2 * .pi { s.phase -= 2 * .pi }
                    tone.remaining -= 1
                }
                if tone.remaining <= 0 {
                    s.tones.removeFirst()
                    s.phase = 0
                } else {
                    s.tones[0] = tone
                }
            }
        }
    }
}
