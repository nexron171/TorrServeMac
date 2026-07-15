import AppKit
import UniformTypeIdentifiers

struct PlayerApp: Identifiable, Hashable {
    let url: URL

    var id: String { url.path }

    var name: String {
        Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
    }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    static func == (lhs: PlayerApp, rhs: PlayerApp) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }
}

enum PlayerFinder {
    private static let excludedBundleIDs: Set<String> = [
        "com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox",
        "com.microsoft.edgemac", "com.brave.Browser", "com.operasoftware.Opera",
        "com.apple.dt.Xcode", "com.apple.Preview", "com.apple.Photos",
        "com.apple.TextEdit", "com.apple.finder", "com.apple.iWork.Keynote",
        "com.apple.iWork.Pages", "com.apple.iWork.Numbers"
    ]

    static func findVideoPlayers() -> [PlayerApp] {
        // Query by content type rather than by a sample file URL: the previous
        // approach pointed at a non-existent temp file, and LaunchServices returns
        // no handlers for a path that doesn't exist on disk — so the list came back
        // empty and only "System Default" was ever shown.
        let types: [UTType] = [
            .movie, .video, .mpeg4Movie, .quickTimeMovie, .avi, .mpeg2TransportStream,
            UTType(filenameExtension: "mkv"), UTType(filenameExtension: "m4v")
        ].compactMap { $0 }

        var seen = Set<String>()
        var result: [PlayerApp] = []

        for type in types {
            for appURL in NSWorkspace.shared.urlsForApplications(toOpen: type) {
                let path = appURL.path
                guard !seen.contains(path) else { continue }
                seen.insert(path)

                if let bundle = Bundle(url: appURL),
                   let bid = bundle.bundleIdentifier,
                   excludedBundleIDs.contains(bid) { continue }

                result.append(PlayerApp(url: appURL))
            }
        }

        return result.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}
