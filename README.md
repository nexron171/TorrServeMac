# TorrServeMac

A native macOS client for [TorrServer](https://github.com/YouROK/TorrServer), built with SwiftUI. Manage your torrents and stream media straight into your favourite player — VLC, IINA, QuickTime, or anything else on your Mac.

This project is a **macOS reimplementation of the [TorrServe](https://github.com/YouROK/TorrServe) Android client** by YouROK — the same feature set and workflow, rebuilt as a native Mac app. It talks to the same [TorrServer](https://github.com/YouROK/TorrServer) backend.

> **Note:** TorrServeMac is a *client* for a running TorrServer instance. It does not download or seed torrents itself — a reachable TorrServer server (local or remote) is required.

## Features

- **Torrent management** — add via magnet link, HTTP URL, or a local `.torrent` file (with drag-and-drop), and remove or drop torrents.
- **Streaming** — open any file in your preferred media player, or hand a whole torrent (or every torrent) to the player as an `.m3u` playlist.
- **Choose your player** — pick any installed video app (VLC, IINA, QuickTime, …) in Settings, or fall back to the system default.
- **Live stats** — real-time download/upload speeds, peers, seeders, and preload/buffer progress with automatic polling.
- **Categories** — organize torrents into Movies, TV Shows, Music, or Other, with poster artwork.
- **Watched tracking** — mark files as viewed and reset the state per torrent.
- **Server settings** — read and edit the TorrServe backend configuration (cache size, rate limits, DLNA, storage path, and more) directly from the app.
- **Authentication** — optional HTTP Basic auth for password-protected servers.

## Requirements

- macOS 26.2 (Tahoe) or later
- Xcode 16 or later (Swift 5)
- A running [TorrServer](https://github.com/YouROK/TorrServer) instance (defaults to `http://127.0.0.1:8090`)

## Building

```bash
git clone https://github.com/nexron171/TorrServeMac.git
cd TorrServeMac
open TorrServeMac.xcodeproj
```

Then build and run (`⌘R`) from Xcode, selecting the **TorrServeMac** scheme.

The project uses only Apple frameworks (SwiftUI, AppKit) — there are no third-party dependencies to fetch.

## Usage

1. Start your TorrServer server.
2. Launch TorrServeMac and open **Settings** (`⌘,`) → **Connection**.
3. Enter the server host and port (and credentials, if the server requires them), then hit **Test Connection**.
4. Optionally choose a preferred **Media Player** under Playback.
5. Add a torrent with **⌘N** (magnet, URL, or `.torrent` file) and start streaming.

### Keyboard shortcuts

| Shortcut | Action           |
| -------- | ---------------- |
| `⌘N`     | Add torrent      |
| `⌘R`     | Refresh          |
| `⌘,`     | Settings         |

## Project structure

```
TorrServeMac/
├── API/           # TorrServe REST API client
├── Models/        # Torrent and server-settings data models
├── ViewModels/    # Torrent list state and polling
├── Views/         # SwiftUI screens (sidebar, detail, add, settings)
├── Settings/      # Persisted app settings (UserDefaults)
└── Utilities/     # Player discovery, watched-file store
```

## License

Released under the [MIT License](LICENSE).

## Acknowledgements

- [TorrServe](https://github.com/YouROK/TorrServe) (Android client) by YouROK — the original app this project reimplements for macOS.
- [TorrServer](https://github.com/YouROK/TorrServer) by YouROK — the backend this client talks to.
