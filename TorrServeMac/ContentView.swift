import SwiftUI
import AppKit

struct ContentView: View {
    @State private var vm = TorrentsViewModel()
    @Environment(\.openSettings) private var openSettings
    @State private var selectedTorrent: Torrent?
    @State private var showAddSheet = false

    var body: some View {
        NavigationSplitView {
            SidebarView(vm: vm)
        } content: {
            torrentList
        } detail: {
            if let torrent = selectedTorrent {
                TorrentDetailView(torrent: torrent, vm: vm)
            } else {
                ContentUnavailableView(
                    "Select a torrent",
                    systemImage: "arrow.down.circle",
                    description: Text("Pick a torrent from the list to see details and stream files")
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Torrent", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("Add torrent (⌘N)")

                Picker("Sort", selection: $vm.sortOption) {
                    ForEach(TorrentsViewModel.SortOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .help("Sort order")

                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .help("Settings (⌘,)")

                if !vm.isConnected {
                    Button {
                        Task { await vm.checkConnection() }
                    } label: {
                        Label("Reconnect", systemImage: "wifi.exclamationmark")
                            .foregroundStyle(.orange)
                    }
                    .help("Cannot reach server — click to retry")
                }
            }
        }
        .searchable(text: $vm.searchText, placement: .toolbar, prompt: "Search torrents")
        .sheet(isPresented: $showAddSheet) {
            AddTorrentView(vm: vm)
        }
        .onAppear {
            vm.startPolling()
        }
        .onDisappear {
            vm.stopPolling()
        }
        .onReceive(NotificationCenter.default.publisher(for: .addTorrent)) { _ in
            showAddSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshTorrents)) { _ in
            Task { await vm.refresh() }
        }
    }

    @ViewBuilder
    private var torrentList: some View {
        List(vm.filteredTorrents, selection: $selectedTorrent) { torrent in
            TorrentRowView(torrent: torrent)
                .tag(torrent)
                .contextMenu {
                    contextMenuItems(for: torrent)
                }
        }
        .listStyle(.inset)
        .navigationTitle(navTitle)
        .overlay {
            if vm.torrents.isEmpty && !vm.isConnected {
                noConnectionOverlay
            } else if vm.filteredTorrents.isEmpty && !vm.searchText.isEmpty {
                ContentUnavailableView.search(text: vm.searchText)
            } else if vm.filteredTorrents.isEmpty {
                ContentUnavailableView(
                    "No torrents",
                    systemImage: "tray",
                    description: Text("Add a torrent with the + button")
                )
            }
        }
    }

    private var navTitle: String {
        if let cat = vm.selectedCategory {
            return cat.displayName
        }
        return "All Torrents (\(vm.torrents.count))"
    }

    @ViewBuilder
    private func contextMenuItems(for torrent: Torrent) -> some View {
        if let url = TorrAPI.shared.m3uURL(hash: torrent.hash, name: torrent.displayTitle) {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Label("Open Playlist", systemImage: "play.circle")
            }
        }

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(torrent.hash, forType: .string)
        } label: {
            Label("Copy Hash", systemImage: "doc.on.doc")
        }

        Divider()

        Button(role: .destructive) {
            Task { await vm.remove(torrent) }
        } label: {
            Label("Remove", systemImage: "trash")
        }
    }

    private var noConnectionOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Cannot connect to TorrServe")
                .font(.headline)

            Text("\(AppSettings.shared.host):\(AppSettings.shared.port)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Settings") { openSettings() }
                Button("Retry") { Task { await vm.checkConnection() } }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
    }
}
