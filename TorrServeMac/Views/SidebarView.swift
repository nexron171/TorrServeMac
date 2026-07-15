import SwiftUI

struct SidebarView: View {
    @Bindable var vm: TorrentsViewModel

    var body: some View {
        List(selection: $vm.selectedCategory) {
            Section("Library") {
                Label("All Torrents", systemImage: "arrow.down.circle")
                    .tag(Optional<TorrentCategory>.none)
                    .badge(vm.torrents.count)

                ForEach(TorrentCategory.allCases, id: \.self) { cat in
                    let count = vm.count(for: cat)
                    if count > 0 {
                        Label(cat.displayName, systemImage: cat.systemImage)
                            .tag(Optional(cat))
                            .badge(count)
                    }
                }
            }

            Section("Status") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(vm.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(vm.isConnected ? "Connected" : "Disconnected")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))

                if !vm.serverVersion.isEmpty {
                    Text(vm.serverVersion)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                let host = AppSettings.shared.host
                let port = AppSettings.shared.port
                Text("\(host):\(port)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 160)
    }
}
