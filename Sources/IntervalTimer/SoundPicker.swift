import SwiftUI
import UniformTypeIdentifiers

/// Picks the cue sound for a timer (or the app default). Tapping a sound selects and previews it.
struct SoundPicker: View {
    /// A `CueSound` id; nil means "use the default from Settings".
    @Binding var selection: String?
    var allowsDefault: Bool

    @EnvironmentObject private var library: SoundLibrary
    @State private var importing = false
    @State private var importError: String?
    @State private var renaming: CustomSound?
    @State private var newName = ""

    var body: some View {
        List {
            if allowsDefault {
                Section {
                    row(title: "Default", subtitle: library.name(for: SettingsKey.defaultCueSound), id: nil)
                }
            }

            Section("Built-in") {
                ForEach(TonePack.allCases) { pack in
                    row(title: pack.title, id: CueSound.tone(pack).id)
                }
                row(title: "Voice", subtitle: "Says each interval's name, like “Work” or “Rest”",
                    id: CueSound.voice.id)
            }

            Section {
                ForEach(library.sounds) { sound in
                    row(title: sound.name, id: CueSound.custom(sound.id).id)
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") {
                                newName = sound.name
                                renaming = sound
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                delete(sound)
                            }
                        }
                }
                .onDelete { offsets in
                    offsets.map { library.sounds[$0] }.forEach(delete)
                }

                Button {
                    importing = true
                } label: {
                    Label("Import Audio File…", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Your sounds")
            } footer: {
                Text("Add a sound from Files (MP3, M4A, WAV and more). It plays when each interval starts, so short clips work best. Hold a sound to rename it.")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            do {
                let sound = try library.importFile(at: result.get())
                select(CueSound.custom(sound.id).id)
            } catch {
                importError = "That file couldn't be used as a sound. Try an MP3, M4A or WAV file."
            }
        }
        .alert("Couldn't Import", isPresented: Binding(get: { importError != nil },
                                                       set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .alert("Rename Sound", isPresented: Binding(get: { renaming != nil },
                                                    set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let renaming { library.rename(renaming.id, to: newName) }
            }
        }
    }

    private func row(title: String, subtitle: String? = nil, id: String?) -> some View {
        Button {
            select(id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selection == id {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
    }

    private func select(_ id: String?) {
        selection = id
        let sound = id.flatMap(CueSound.init(id:)) ?? SettingsKey.defaultCueSound
        AudioCues.previewer.preview(sound)
    }

    private func delete(_ sound: CustomSound) {
        if selection == CueSound.custom(sound.id).id {
            selection = allowsDefault ? nil : CueSound.default.id
        }
        library.delete(sound.id)
    }
}
