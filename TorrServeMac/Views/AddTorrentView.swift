import SwiftUI
import UniformTypeIdentifiers

struct AddTorrentView: View {
    var vm: TorrentsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var link = ""
    @State private var title = ""
    @State private var poster = ""
    @State private var category = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isDroppingFile = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Add Torrent")
                    .font(.title2.bold())
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Drag & Drop zone
                    dropZone

                    // Divider with OR label
                    HStack {
                        Rectangle().fill(.secondary.opacity(0.3)).frame(height: 1)
                        Text("OR").font(.caption).foregroundStyle(.secondary)
                        Rectangle().fill(.secondary.opacity(0.3)).frame(height: 1)
                    }

                    // Magnet / URL field
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Magnet link or URL", systemImage: "link")
                            .font(.callout.bold())
                        TextField("magnet:?xt=urn:btih:... or https://...", text: $link, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }

                    // Optional metadata
                    GroupBox("Optional metadata") {
                        VStack(alignment: .leading, spacing: 10) {
                            LabeledField("Title", text: $title, placeholder: "Auto-detect")
                            LabeledField("Poster URL", text: $poster, placeholder: "https://...")
                            categoryPicker
                        }
                    }

                    if let err = errorMessage {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
                .padding()
            }

            Divider()

            // Footer buttons
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button {
                    Task { await addViaFile() }
                } label: {
                    Label("Choose File…", systemImage: "doc.badge.plus")
                }

                Button {
                    Task { await addViaLink() }
                } label: {
                    if isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Add", systemImage: "plus")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(link.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
        }
        .frame(width: 480)
        .onDrop(of: [.fileURL, .url], isTargeted: $isDroppingFile) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Drop zone

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                isDroppingFile ? Color.accentColor : Color.secondary.opacity(0.3),
                style: StrokeStyle(lineWidth: 2, dash: [6])
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDroppingFile ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .frame(height: 90)
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc")
                        .font(.title2)
                        .foregroundStyle(isDroppingFile ? Color.accentColor : Color.secondary)
                    Text("Drop .torrent file here")
                        .font(.callout)
                        .foregroundStyle(isDroppingFile ? Color.accentColor : Color.secondary)
                }
            )
    }

    // MARK: - Category picker

    private var categoryPicker: some View {
        HStack {
            Label("Category", systemImage: "folder")
                .font(.callout)
                .frame(width: 90, alignment: .leading)
            Picker("", selection: $category) {
                Text("None").tag("")
                ForEach(TorrentCategory.allCases.filter { !$0.rawValue.isEmpty }, id: \.self) { cat in
                    Label(cat.displayName, systemImage: cat.systemImage).tag(cat.rawValue)
                }
            }
            .labelsHidden()
        }
    }

    // MARK: - Actions

    private func addViaLink() async {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await vm.addTorrent(link: trimmed, title: title, poster: poster, category: category)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func addViaFile() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "torrent") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a .torrent file"

        let response = await withCheckedContinuation { continuation in
            panel.begin { continuation.resume(returning: $0) }
        }
        guard response == .OK, let url = panel.url else { return }

        isLoading = true
        errorMessage = nil
        do {
            try await vm.uploadTorrent(fileURL: url, title: title, poster: poster, category: category)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    isLoading = true
                    errorMessage = nil
                    do {
                        try await vm.uploadTorrent(fileURL: url, title: title, poster: poster, category: category)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    isLoading = false
                }
            }
            return true
        }
        return false
    }
}

// MARK: - Helpers

struct LabeledField: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    init(_ label: String, text: Binding<String>, placeholder: String = "") {
        self.label = label
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}
