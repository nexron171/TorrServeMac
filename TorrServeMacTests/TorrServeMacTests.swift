//
//  TorrServeMacTests.swift
//  TorrServeMacTests
//
//  Created by Sergey Shirnin on 29.05.2026.
//

import Testing
import Foundation
@testable import TorrServeMac

// MARK: - Helpers

private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
}

// MARK: - Torrent model

@Suite struct TorrentModelTests {

    @Test func displayTitlePrefersTitle() throws {
        let t = try decode(Torrent.self, from: #"{"hash":"abc","title":"My Movie","name":"file.mkv"}"#)
        #expect(t.displayTitle == "My Movie")
    }

    @Test func displayTitleFallsBackToName() throws {
        let t = try decode(Torrent.self, from: #"{"hash":"abc","title":"","name":"file.mkv"}"#)
        #expect(t.displayTitle == "file.mkv")
    }

    @Test func displayTitleFallsBackToHash() throws {
        let t = try decode(Torrent.self, from: #"{"hash":"abc","title":""}"#)
        #expect(t.displayTitle == "abc")
    }

    @Test func progressComputesRatio() throws {
        let t = try decode(Torrent.self, from: #"{"hash":"h","title":"t","torrent_size":1000,"loaded_size":250}"#)
        #expect(t.progress == 0.25)
    }

    @Test func progressIsZeroWhenTotalMissingOrZero() throws {
        let noTotal = try decode(Torrent.self, from: #"{"hash":"h","title":"t","loaded_size":250}"#)
        #expect(noTotal.progress == 0)

        let zeroTotal = try decode(Torrent.self, from: #"{"hash":"h","title":"t","torrent_size":0,"loaded_size":250}"#)
        #expect(zeroTotal.progress == 0)
    }

    @Test(arguments: [
        ("movie", TorrentCategory.movie),
        ("tv", .tv),
        ("music", .music),
        ("", .other),
        ("nonsense", .other),
    ])
    func categoryKindMapsRawValue(raw: String, expected: TorrentCategory) throws {
        let t = try decode(Torrent.self, from: #"{"hash":"h","title":"t","category":"\#(raw)"}"#)
        #expect(t.categoryKind == expected)
    }

    @Test func categoryKindDefaultsToOtherWhenAbsent() throws {
        let t = try decode(Torrent.self, from: #"{"hash":"h","title":"t"}"#)
        #expect(t.categoryKind == .other)
    }

    @Test func decodesSnakeCaseFields() throws {
        let json = #"""
        {"hash":"h","title":"t","torrent_size":2048,"loaded_size":1024,
         "download_speed":123.5,"upload_speed":10,"total_peers":8,"active_peers":3,
         "connected_seeders":2,"stat":4,"stat_string":"Torrent","bit_rate":5000}
        """#
        let t = try decode(Torrent.self, from: json)
        #expect(t.torrentSize == 2048)
        #expect(t.loadedSize == 1024)
        #expect(t.downloadSpeed == 123.5)
        #expect(t.totalPeers == 8)
        #expect(t.connectedSeeders == 2)
        #expect(t.statString == "Torrent")
    }

    @Test func equatableAndHashableUseHashOnly() throws {
        let a = try decode(Torrent.self, from: #"{"hash":"same","title":"A"}"#)
        let b = try decode(Torrent.self, from: #"{"hash":"same","title":"B"}"#)
        let c = try decode(Torrent.self, from: #"{"hash":"other","title":"A"}"#)
        #expect(a == b)
        #expect(a != c)
        #expect(a.hashValue == b.hashValue)
    }
}

// MARK: - FileStat

@Suite struct FileStatTests {

    @Test func filenameIsLastPathComponent() throws {
        let f = try decode(FileStat.self, from: #"{"id":1,"path":"/downloads/Show/ep01.mkv","length":100}"#)
        #expect(f.filename == "ep01.mkv")
    }

    @Test(arguments: [
        ("/a/video.mkv", true),
        ("/a/video.MP4", true),      // case-insensitive
        ("/a/song.flac", true),
        ("/a/list.m3u", true),
        ("/a/readme.txt", false),
        ("/a/cover.jpg", false),
        ("/a/noext", false),
    ])
    func isPlayableChecksExtension(path: String, expected: Bool) throws {
        let f = try decode(FileStat.self, from: #"{"id":1,"path":"\#(path)","length":1}"#)
        #expect(f.isPlayable == expected)
    }
}

// MARK: - Enums

@Suite struct CategoryAndStatTests {

    @Test func allCategoriesHaveDistinctDisplayNamesAndImages() {
        let names = Set(TorrentCategory.allCases.map(\.displayName))
        let images = Set(TorrentCategory.allCases.map(\.systemImage))
        #expect(TorrentCategory.allCases.count == 4)
        #expect(names.count == 4)
        #expect(images.count == 4)
    }

    @Test func categoryRawValues() {
        #expect(TorrentCategory.movie.rawValue == "movie")
        #expect(TorrentCategory.other.rawValue == "")
        #expect(TorrentCategory(rawValue: "tv") == .tv)
    }

    @Test func torrentStatDisplayNames() {
        #expect(TorrentStat.seeding.displayName == "Seeding")
        #expect(TorrentStat.torrent.displayName == "Downloading")
        #expect(TorrentStat(rawValue: 0) == .unknown)
        #expect(TorrentStat(rawValue: 99) == nil)
    }
}

// MARK: - BTSets

@Suite struct BTSetsTests {

    @Test func decodesPascalCaseKeys() throws {
        let json = #"""
        {"CacheSize":104857600,"PreloadBuffer":true,"UseDisk":false,
         "TorrentsSavePath":"/tmp/ts","DownloadRateLimit":500,"EnableDLNA":true}
        """#
        let s = try decode(BTSets.self, from: json)
        #expect(s.cacheSize == 104_857_600)
        #expect(s.preloadBuffer == true)
        #expect(s.useDisk == false)
        #expect(s.torrentsSavePath == "/tmp/ts")
        #expect(s.downloadRateLimit == 500)
        #expect(s.enableDLNA == true)
    }

    @Test func encodeDecodeRoundTripPreservesValues() throws {
        var s = try decode(BTSets.self, from: #"{"CacheSize":2048,"ForceEncrypt":true}"#)
        s.uploadRateLimit = 42
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(BTSets.self, from: data)
        #expect(back.cacheSize == 2048)
        #expect(back.forceEncrypt == true)
        #expect(back.uploadRateLimit == 42)
    }

    @Test func encodesWithServerPascalCaseKeys() throws {
        let s = try decode(BTSets.self, from: #"{"CacheSize":2048}"#)
        let data = try JSONEncoder().encode(s)
        let dict = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(dict["CacheSize"] as? Int == 2048)
    }
}

// MARK: - ViewedStore

@Suite @MainActor struct ViewedStoreTests {

    // Unique hash per test keeps the shared store / UserDefaults isolated.
    private func freshHash() -> String { "test_\(UUID().uuidString)" }

    @Test func markAndQueryViewed() {
        let store = ViewedStore.shared
        let h = freshHash()
        #expect(store.isViewed(hash: h, fileIndex: 2) == false)
        store.markViewed(hash: h, fileIndex: 2)
        #expect(store.isViewed(hash: h, fileIndex: 2) == true)
        #expect(store.viewedCount(hash: h) == 1)
    }

    @Test func markViewedIsIdempotent() {
        let store = ViewedStore.shared
        let h = freshHash()
        store.markViewed(hash: h, fileIndex: 0)
        store.markViewed(hash: h, fileIndex: 0)
        #expect(store.viewedCount(hash: h) == 1)
    }

    @Test func toggleFlipsState() {
        let store = ViewedStore.shared
        let h = freshHash()
        store.toggle(hash: h, fileIndex: 5)
        #expect(store.isViewed(hash: h, fileIndex: 5) == true)
        store.toggle(hash: h, fileIndex: 5)
        #expect(store.isViewed(hash: h, fileIndex: 5) == false)
    }

    @Test func resetAllClearsTorrent() {
        let store = ViewedStore.shared
        let h = freshHash()
        store.markViewed(hash: h, fileIndex: 1)
        store.markViewed(hash: h, fileIndex: 2)
        #expect(store.viewedCount(hash: h) == 2)
        store.resetAll(hash: h)
        #expect(store.viewedCount(hash: h) == 0)
    }
}

// MARK: - AppSettings & TorrAPI URL building

@Suite @MainActor struct APIURLTests {

    /// Applies host/port for the duration of `body`, then restores the previous values.
    private func withServer(host: String, port: Int, _ body: () -> Void) {
        let s = AppSettings.shared
        let oldHost = s.host, oldPort = s.port
        s.host = host; s.port = port
        defer { s.host = oldHost; s.port = oldPort }
        body()
    }

    @Test func baseURLIsHostAndPort() {
        withServer(host: "10.0.0.5", port: 9090) {
            #expect(AppSettings.shared.baseURL == "http://10.0.0.5:9090")
        }
    }

    @Test func streamURLContainsEncodedFilenameAndQuery() {
        withServer(host: "127.0.0.1", port: 8090) {
            let url = TorrAPI.shared.streamURL(hash: "HASH1", fileID: 3, filename: "My Movie.mkv")
            #expect(url?.absoluteString == "http://127.0.0.1:8090/stream/My%20Movie.mkv?link=HASH1&index=3&play")
        }
    }

    @Test func m3uURLForTorrent() {
        withServer(host: "host", port: 80) {
            let url = TorrAPI.shared.m3uURL(hash: "H", name: "The Show")
            #expect(url?.absoluteString == "http://host:80/playlist/The%20Show.m3u?hash=H")
        }
    }

    @Test func allM3uURL() {
        withServer(host: "host", port: 80) {
            #expect(TorrAPI.shared.allM3uURL()?.absoluteString == "http://host:80/playlistall/all.m3u")
        }
    }
}
