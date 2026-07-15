import Foundation

struct Torrent: Codable, Identifiable {
    var id: String { hash }

    let hash: String
    let title: String
    let name: String?
    let poster: String?
    let category: String?
    let data: String?
    let timestamp: Int?

    let torrentSize: Int64?
    let loadedSize: Int64?
    let preloadedBytes: Int64?
    let preloadSize: Int64?

    let downloadSpeed: Double?
    let uploadSpeed: Double?

    let totalPeers: Int?
    let pendingPeers: Int?
    let activePeers: Int?
    let connectedSeeders: Int?

    let stat: Int?
    let statString: String?
    let bitRate: Int?

    let fileStats: [FileStat]?

    enum CodingKeys: String, CodingKey {
        case hash, title, name, poster, category, data, timestamp
        case torrentSize = "torrent_size"
        case loadedSize = "loaded_size"
        case preloadedBytes = "preloaded_bytes"
        case preloadSize = "preload_size"
        case downloadSpeed = "download_speed"
        case uploadSpeed = "upload_speed"
        case totalPeers = "total_peers"
        case pendingPeers = "pending_peers"
        case activePeers = "active_peers"
        case connectedSeeders = "connected_seeders"
        case stat
        case statString = "stat_string"
        case bitRate = "bit_rate"
        case fileStats = "file_stats"
    }

    var displayTitle: String {
        !title.isEmpty ? title : (name ?? hash)
    }

    var progress: Double {
        guard let total = torrentSize, let loaded = loadedSize, total > 0 else { return 0 }
        return Double(loaded) / Double(total)
    }

    var categoryKind: TorrentCategory {
        TorrentCategory(rawValue: category ?? "") ?? .other
    }
}

struct FileStat: Codable, Identifiable {
    let id: Int
    let path: String
    let length: Int64

    var filename: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var isPlayable: Bool {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return Self.playableExtensions.contains(ext)
    }

    private static let playableExtensions: Set<String> = [
        "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "ts", "m2ts", "mpg", "mpeg",
        "mp3", "flac", "aac", "ogg", "wav", "m4a", "opus", "wma",
        "m3u", "m3u8"
    ]
}

enum TorrentCategory: String, CaseIterable {
    case movie
    case tv
    case music
    case other = ""

    var displayName: String {
        switch self {
        case .movie: return "Movies"
        case .tv: return "TV Shows"
        case .music: return "Music"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .movie: return "film"
        case .tv: return "tv"
        case .music: return "music.note"
        case .other: return "folder"
        }
    }
}

extension Torrent: Equatable {
    static func == (lhs: Torrent, rhs: Torrent) -> Bool { lhs.hash == rhs.hash }
}

extension Torrent: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(self.hash) }
}

enum TorrentStat: Int {
    case unknown = 0
    case preload = 1
    case getInfo = 2
    case closed = 3
    case torrent = 4
    case seeding = 5
    case checkHash = 6

    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .preload: return "Preloading"
        case .getInfo: return "Getting info"
        case .closed: return "Closed"
        case .torrent: return "Downloading"
        case .seeding: return "Seeding"
        case .checkHash: return "Checking"
        }
    }
}
