import AVFoundation
import Foundation

/// Built-in cue sets, synthesized by `ToneGenerator`.
enum TonePack: String, CaseIterable, Identifiable, Sendable {
    case classic, bell, digital, soft

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Classic Beep"
        case .bell: "Bell"
        case .digital: "Digital"
        case .soft: "Soft Chime"
        }
    }

    /// Each of the 3-2-1 beeps before an interval ends.
    var countdown: [ToneSpec] {
        switch self {
        case .classic: [ToneSpec(frequency: 880, duration: 0.12)]
        case .bell: [ToneSpec(frequency: 1568, duration: 0.3, shape: .bell, decay: 12, volume: 0.5)]
        case .digital: [ToneSpec(frequency: 2000, duration: 0.05, shape: .square, volume: 0.35)]
        case .soft: [ToneSpec(frequency: 523, duration: 0.15, volume: 0.4)]
        }
    }

    /// When the next interval starts.
    var transition: [ToneSpec] {
        switch self {
        case .classic: [ToneSpec(frequency: 1320, duration: 0.45)]
        case .bell: [ToneSpec(frequency: 784, duration: 1.6, shape: .bell, decay: 2.5, volume: 0.7)]
        case .digital: [
            ToneSpec(frequency: 2000, duration: 0.07, shape: .square, volume: 0.35),
            ToneSpec(frequency: 2000, duration: 0.07, gapBefore: 0.05, shape: .square, volume: 0.35),
            ToneSpec(frequency: 2400, duration: 0.14, gapBefore: 0.05, shape: .square, volume: 0.35),
        ]
        case .soft: [
            ToneSpec(frequency: 659, duration: 0.18, volume: 0.45),
            ToneSpec(frequency: 880, duration: 0.35, gapBefore: 0.02, volume: 0.45),
        ]
        }
    }

    /// When the whole run is done.
    var finished: [ToneSpec] {
        switch self {
        case .classic:
            (0..<3).map { _ in ToneSpec(frequency: 1320, duration: 0.16, gapBefore: 0.08) }
        case .bell:
            [523.0, 659, 784].map { ToneSpec(frequency: $0, duration: 0.35, shape: .bell, decay: 4, volume: 0.6) }
                + [ToneSpec(frequency: 1046, duration: 1.5, shape: .bell, decay: 2.5, volume: 0.7)]
        case .digital:
            (0..<4).map { _ in ToneSpec(frequency: 2400, duration: 0.08, gapBefore: 0.06, shape: .square, volume: 0.35) }
        case .soft:
            [523.0, 659, 784].map { ToneSpec(frequency: $0, duration: 0.18, volume: 0.45) }
                + [ToneSpec(frequency: 1046, duration: 0.5, volume: 0.45)]
        }
    }
}

/// What plays at each interval change. Saved as a string id ("tone.bell", "voice",
/// "custom.<uuid>") on workouts and in settings.
enum CueSound: Hashable, Sendable {
    case tone(TonePack)
    /// Speaks the interval's name.
    case voice
    /// An audio file the user imported.
    case custom(UUID)

    static let `default` = CueSound.tone(.classic)

    init?(id: String) {
        if id == "voice" {
            self = .voice
        } else if id.hasPrefix("tone."), let pack = TonePack(rawValue: String(id.dropFirst(5))) {
            self = .tone(pack)
        } else if id.hasPrefix("custom."), let uuid = UUID(uuidString: String(id.dropFirst(7))) {
            self = .custom(uuid)
        } else {
            return nil
        }
    }

    var id: String {
        switch self {
        case .tone(let pack): "tone.\(pack.rawValue)"
        case .voice: "voice"
        case .custom(let uuid): "custom.\(uuid.uuidString)"
        }
    }
}

struct CustomSound: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var fileName: String
}

/// Audio files the user imported, copied into Documents/Sounds so they stay available.
@MainActor
final class SoundLibrary: ObservableObject {
    private nonisolated static let key = "customSounds.v1"

    @Published private(set) var sounds: [CustomSound]

    init() {
        sounds = Self.load()
    }

    nonisolated static var directory: URL {
        URL.documentsDirectory.appending(path: "Sounds", directoryHint: .isDirectory)
    }

    nonisolated static func load() -> [CustomSound] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([CustomSound].self, from: data) else { return [] }
        return saved
    }

    /// The file for an imported sound, or nil if it has been deleted.
    nonisolated static func fileURL(for id: UUID) -> URL? {
        guard let sound = load().first(where: { $0.id == id }) else { return nil }
        let url = directory.appending(path: sound.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func name(for sound: CueSound) -> String {
        switch sound {
        case .tone(let pack): pack.title
        case .voice: "Voice"
        case .custom(let id): sounds.first { $0.id == id }?.name ?? "Missing sound"
        }
    }

    /// Copies a file picked in Files into the app. Throws if it can't be played.
    func importFile(at source: URL) throws -> CustomSound {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        try fm.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        let id = UUID()
        let ext = source.pathExtension.isEmpty ? "m4a" : source.pathExtension
        let destination = Self.directory.appending(path: "\(id.uuidString).\(ext)")
        try fm.copyItem(at: source, to: destination)
        do {
            _ = try AVAudioPlayer(contentsOf: destination)
        } catch {
            try? fm.removeItem(at: destination)
            throw error
        }

        let sound = CustomSound(id: id, name: source.deletingPathExtension().lastPathComponent,
                                fileName: destination.lastPathComponent)
        sounds.append(sound)
        save()
        return sound
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = sounds.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        sounds[i].name = trimmed.isEmpty ? "Sound" : trimmed
        save()
    }

    func delete(_ id: UUID) {
        guard let sound = sounds.first(where: { $0.id == id }) else { return }
        try? FileManager.default.removeItem(at: Self.directory.appending(path: sound.fileName))
        sounds.removeAll { $0.id == id }
        save()
        if SettingsKey.defaultCueSound == .custom(id) {
            UserDefaults.standard.removeObject(forKey: SettingsKey.defaultSound)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sounds) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
