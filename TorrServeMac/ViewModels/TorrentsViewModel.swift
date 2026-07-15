import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
class TorrentsViewModel {
    var torrents: [Torrent] = []
    var isConnected = false
    var serverVersion = ""
    var errorMessage: String?
    var selectedCategory: TorrentCategory?
    var searchText = ""
    var sortOption: SortOption = .dateDesc

    private var pollingTask: Task<Void, Never>?

    enum SortOption: String, CaseIterable, Identifiable {
        case nameAsc  = "Name A→Z"
        case nameDesc = "Name Z→A"
        case dateAsc  = "Oldest first"
        case dateDesc = "Newest first"
        case sizeAsc  = "Smallest first"
        case sizeDesc = "Largest first"

        var id: String { rawValue }
    }

    var filteredTorrents: [Torrent] {
        var result = torrents

        if let cat = selectedCategory {
            result = result.filter { $0.categoryKind == cat }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.displayTitle.localizedCaseInsensitiveContains(searchText) }
        }

        switch sortOption {
        case .nameAsc:  result.sort { $0.displayTitle.localizedCompare($1.displayTitle) == .orderedAscending }
        case .nameDesc: result.sort { $0.displayTitle.localizedCompare($1.displayTitle) == .orderedDescending }
        case .dateAsc:  result.sort { ($0.timestamp ?? 0) < ($1.timestamp ?? 0) }
        case .dateDesc: result.sort { ($0.timestamp ?? 0) > ($1.timestamp ?? 0) }
        case .sizeAsc:  result.sort { ($0.torrentSize ?? 0) < ($1.torrentSize ?? 0) }
        case .sizeDesc: result.sort { ($0.torrentSize ?? 0) > ($1.torrentSize ?? 0) }
        }
        return result
    }

    func count(for category: TorrentCategory) -> Int {
        torrents.filter { $0.categoryKind == category }.count
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }
                await refresh()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() async {
        do {
            torrents = try await TorrAPI.shared.listTorrents()
            if !isConnected {
                serverVersion = (try? await TorrAPI.shared.echo()) ?? ""
            }
            isConnected = true
            errorMessage = nil
        } catch {
            isConnected = false
            errorMessage = error.localizedDescription
        }
    }

    func checkConnection() async {
        do {
            serverVersion = try await TorrAPI.shared.echo()
            isConnected = true
            errorMessage = nil
        } catch {
            isConnected = false
            serverVersion = ""
            errorMessage = error.localizedDescription
        }
    }

    func addTorrent(link: String, title: String, poster: String, category: String) async throws {
        let torrent = try await TorrAPI.shared.addTorrent(link: link, title: title, poster: poster, category: category)
        if !torrents.contains(where: { $0.hash == torrent.hash }) {
            torrents.insert(torrent, at: 0)
        }
    }

    func uploadTorrent(fileURL: URL, title: String, poster: String, category: String) async throws {
        let torrent = try await TorrAPI.shared.uploadTorrent(fileURL: fileURL, title: title, poster: poster, category: category)
        if !torrents.contains(where: { $0.hash == torrent.hash }) {
            torrents.insert(torrent, at: 0)
        }
    }

    func remove(_ torrent: Torrent) async {
        do {
            try await TorrAPI.shared.removeTorrent(hash: torrent.hash)
            torrents.removeAll { $0.hash == torrent.hash }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func drop(_ torrent: Torrent) async {
        do {
            try await TorrAPI.shared.dropTorrent(hash: torrent.hash)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
