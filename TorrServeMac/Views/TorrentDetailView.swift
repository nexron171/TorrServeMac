import SwiftUI
import AppKit

struct TorrentDetailView: View {
    let torrent: Torrent
    var vm: TorrentsViewModel
    @State private var liveData: Torrent?
    @State private var knownFiles: [FileStat]?   // накапливается, никогда не теряется
    @State private var showRemoveConfirm = false
    @State private var errorMessage: String?

    private var current: Torrent { liveData ?? torrent }
    // Файлы берём из лучшего доступного источника
    private var effectiveFiles: [FileStat]? {
        let files = knownFiles ?? current.fileStats
        return files?.isEmpty == false ? files : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                statsSection
                filesSection
                actionsSection
            }
            .padding(20)
        }
        .frame(minWidth: 380)
        .navigationTitle(current.displayTitle)
        .task(id: torrent.hash) {
            await startLiveUpdates()
        }
        .alert("Remove Torrent", isPresented: $showRemoveConfirm) {
            Button("Remove", role: .destructive) {
                Task { await vm.remove(torrent) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove \"\(current.displayTitle)\" from the server? Downloaded data will not be deleted.")
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            posterView
                .frame(width: 90, height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(current.displayTitle)
                    .font(.title2.bold())
                    .lineLimit(3)

                if let cat = current.category, !cat.isEmpty {
                    Label(current.categoryKind.displayName, systemImage: current.categoryKind.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(current.hash)
                    .font(.caption2)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                if let ts = current.timestamp {
                    let date = Date(timeIntervalSince1970: TimeInterval(ts))
                    Text("Added \(date.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var posterView: some View {
        if let posterStr = current.poster, let url = URL(string: posterStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: defaultPoster
                }
            }
        } else {
            defaultPoster
        }
    }

    private var defaultPoster: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.15))
            .overlay(Image(systemName: current.categoryKind.systemImage).font(.largeTitle).foregroundStyle(.secondary))
    }

    // MARK: - Stats

    private var statsSection: some View {
        GroupBox("Statistics") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                if let total = current.torrentSize {
                    GridRow {
                        Text("Size").foregroundStyle(.secondary)
                        Text(formatBytes(total))
                    }
                }
                if let loaded = current.loadedSize, let total = current.torrentSize {
                    GridRow {
                        Text("Downloaded").foregroundStyle(.secondary)
                        HStack {
                            Text(formatBytes(loaded))
                            ProgressView(value: current.progress)
                                .frame(width: 80)
                            Text("\(Int(current.progress * 100))%")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let statStr = current.statString, !statStr.isEmpty {
                    GridRow {
                        Text("Status").foregroundStyle(.secondary)
                        Text(statStr)
                    }
                }
                if let dl = current.downloadSpeed, dl > 0 {
                    GridRow {
                        Text("Download").foregroundStyle(.secondary)
                        Label(formatSpeed(dl), systemImage: "arrow.down").foregroundStyle(.blue)
                    }
                }
                if let ul = current.uploadSpeed, ul > 0 {
                    GridRow {
                        Text("Upload").foregroundStyle(.secondary)
                        Label(formatSpeed(ul), systemImage: "arrow.up").foregroundStyle(.green)
                    }
                }
                if let peers = current.totalPeers {
                    GridRow {
                        Text("Peers").foregroundStyle(.secondary)
                        HStack {
                            Text("\(peers) total")
                            if let active = current.activePeers { Text("· \(active) active").foregroundStyle(.secondary) }
                            if let seeds = current.connectedSeeders { Text("· \(seeds) seeds").foregroundStyle(.secondary) }
                        }
                    }
                }
                if let br = current.bitRate, br > 0 {
                    GridRow {
                        Text("Bit rate").foregroundStyle(.secondary)
                        Text(formatSpeed(Double(br)))
                    }
                }
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Files

    private var filesSection: some View {
        GroupBox {
            filesContent
        } label: {
            filesHeader
        }
    }

    private var filesHeader: some View {
        HStack(spacing: 8) {
            Text("Files")
                .font(.headline)

            if let files = effectiveFiles {
                Text("(\(files.count))")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            Spacer()

            torrentStateBadge
        }
    }

    @ViewBuilder
    private var torrentStateBadge: some View {
        let stat = current.stat ?? 0
        switch stat {
        case 1:
            statusBadge("Preloading", color: .orange, spinning: true)
        case 2:
            statusBadge("Getting info", color: .blue, spinning: true)
        case 4:
            let pct = Int(current.progress * 100)
            statusBadge("↓ \(pct)%", color: .blue, spinning: false)
        case 5:
            statusBadge("Seeding", color: .green, spinning: false)
        case 6:
            statusBadge("Checking", color: .orange, spinning: true)
        default:
            EmptyView()
        }
    }

    private func statusBadge(_ label: String, color: Color, spinning: Bool) -> some View {
        HStack(spacing: 4) {
            if spinning {
                ProgressView().controlSize(.mini).tint(color)
            }
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private var filesContent: some View {
        // Still waiting for first live poll
        if liveData == nil {
            fileStatusRow {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading…").foregroundStyle(.secondary)
                }
            }
        }
        // Server is fetching torrent metadata (no file list yet)
        else if current.stat == 2 {
            fileStatusRow {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Getting file list from peers…").foregroundStyle(.secondary)
                    }
                    if current.progress > 0 {
                        ProgressView(value: current.progress)
                    }
                }
            }
        }
        // Preloading
        else if current.stat == 1 {
            fileStatusRow {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Preloading…").foregroundStyle(.secondary)
                }
            }
        }
        // Files available
        else if let files = effectiveFiles {
            // Overall progress bar at the top when actively downloading
            if current.progress > 0 && current.progress < 1,
               let loaded = current.loadedSize, let total = current.torrentSize {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(formatBytes(loaded)) of \(formatBytes(total))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let dl = current.downloadSpeed, dl > 0 {
                            Label(formatSpeed(dl), systemImage: "arrow.down")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    ProgressView(value: current.progress)
                        .tint(.blue)
                }
                .padding(.bottom, 6)

                Divider()
            }

            VStack(spacing: 0) {
                ForEach(files) { file in
                    FileRowView(torrent: current, file: file)
                    if file.id != files.last?.id {
                        Divider()
                    }
                }
            }

            let watchedCount = ViewedStore.shared.viewedCount(hash: current.hash)
            if watchedCount > 0 {
                Divider().padding(.top, 4)
                HStack {
                    Text("\(watchedCount) of \(files.count) watched")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        ViewedStore.shared.resetAll(hash: current.hash)
                    } label: {
                        Label("Reset viewed", systemImage: "eye.slash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
        }
        // No files yet — check if we should still be waiting
        else {
            let stat = current.stat ?? 0
            // Torrent is active (downloading/seeding) but file list hasn't arrived yet
            if stat == 4 || stat == 5 || (liveData != nil && stat == 0) {
                fileStatusRow {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading file list…").foregroundStyle(.secondary)
                    }
                }
            } else {
                fileStatusRow {
                    Text(stat == 3 ? "Torrent closed" : "No files available")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func fileStatusRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        HStack {
            Button(role: .destructive) {
                showRemoveConfirm = true
            } label: {
                Label("Remove Torrent", systemImage: "trash")
            }

            Spacer()

            if let m3u = TorrAPI.shared.m3uURL(hash: current.hash, name: current.displayTitle) {
                Button {
                    NSWorkspace.shared.open(m3u)
                } label: {
                    Label("Open Playlist", systemImage: "play.circle")
                }
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(current.hash, forType: .string)
            } label: {
                Label("Copy Hash", systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: - Live updates

    private func startLiveUpdates() async {
        liveData = nil
        knownFiles = torrent.fileStats?.isEmpty == false ? torrent.fileStats : nil

        while !Task.isCancelled {
            do {
                let fresh = try await TorrAPI.shared.getTorrent(hash: torrent.hash)
                liveData = fresh
                if let files = fresh.fileStats, !files.isEmpty {
                    knownFiles = files
                }
            } catch {}

            // Пока файлы не получены — опрашиваем чаще
            let delay: Duration = knownFiles == nil ? .milliseconds(500) : .seconds(2)
            try? await Task.sleep(for: delay)
        }
    }
}

// MARK: - File row

struct FileRowView: View {
    let torrent: Torrent
    let file: FileStat
    @State private var showCopied = false
    private var viewed: ViewedStore { ViewedStore.shared }

    private var torrentStat: Int { torrent.stat ?? 0 }

    // Approximate per-file availability based on torrent progress and file order
    private var fileReadiness: FileReadiness {
        switch torrentStat {
        case 5: return .ready           // seeding — all done
        case 1, 2: return .loading      // preload / getInfo
        case 4:                         // downloading
            guard let total = torrent.torrentSize, total > 0,
                  let loaded = torrent.loadedSize else { return .streaming }
            // Estimate: files at the start of the torrent are more likely downloaded
            // Use file index relative to total files count as rough approximation
            let fileCount = torrent.fileStats?.count ?? 1
            let fileFraction = fileCount > 1 ? Double(file.id) / Double(fileCount - 1) : 0
            return fileFraction <= torrent.progress ? .ready : .streaming
        default: return .streaming
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: file.isPlayable ? "play.fill" : "doc")
                .foregroundStyle(file.isPlayable ? Color.accentColor : Color.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(file.filename)
                    .font(.callout)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(formatBytes(file.length))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    fileReadinessBadge
                }
            }

            Spacer()

            if file.isPlayable {
                HStack(spacing: 2) {
                    Button {
                        openInPlayer()
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                    .help("Open in player")

                    eyeButton

                    Button {
                        copyURL()
                    } label: {
                        Image(systemName: showCopied ? "checkmark" : "link")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy stream URL")
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    private var eyeButton: some View {
        let isViewed = viewed.isViewed(hash: torrent.hash, fileIndex: file.id)
        return Button {
            viewed.toggle(hash: torrent.hash, fileIndex: file.id)
        } label: {
            Image(systemName: isViewed ? "eye.fill" : "eye")
                .imageScale(.medium)
                .foregroundStyle(isViewed ? Color.primary : Color.secondary.opacity(0.5))
        }
        .buttonStyle(.borderless)
        .help(isViewed ? "Mark as unwatched" : "Mark as watched")
    }

    private func openInPlayer() {
        guard let url = TorrAPI.shared.streamURL(hash: torrent.hash, fileID: file.id, filename: file.filename) else { return }

        viewed.markViewed(hash: torrent.hash, fileIndex: file.id)

        let playerPath = AppSettings.shared.preferredPlayerPath
        if !playerPath.isEmpty && FileManager.default.fileExists(atPath: playerPath) {
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: URL(fileURLWithPath: playerPath),
                configuration: NSWorkspace.OpenConfiguration()
            )
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    @ViewBuilder
    private var fileReadinessBadge: some View {
        switch fileReadiness {
        case .ready:
            Label("Ready", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .streaming:
            Label("Streaming", systemImage: "play.circle")
                .font(.caption2)
                .foregroundStyle(.blue)
        case .loading:
            EmptyView()
        }
    }

    private func copyURL() {
        guard let url = TorrAPI.shared.streamURL(hash: torrent.hash, fileID: file.id, filename: file.filename) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        showCopied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showCopied = false
        }
    }
}

enum FileReadiness {
    case ready      // fully downloaded
    case streaming  // available via stream (downloading)
    case loading    // torrent still getting info
}

private func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

private func formatSpeed(_ bps: Double) -> String {
    "\(ByteCountFormatter.string(fromByteCount: Int64(bps), countStyle: .file))/s"
}
