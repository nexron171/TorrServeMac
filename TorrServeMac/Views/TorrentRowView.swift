import SwiftUI

struct TorrentRowView: View {
    let torrent: Torrent

    var body: some View {
        HStack(spacing: 12) {
            posterView
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(torrent.displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    categoryBadge
                    Text(torrent.hash.prefix(8))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fontDesign(.monospaced)

                    if let size = torrent.torrentSize {
                        Text(formatBytes(size))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    statLabel

                    if let dl = torrent.downloadSpeed, dl > 0 {
                        Label(formatSpeed(dl), systemImage: "arrow.down")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    if let ul = torrent.uploadSpeed, ul > 0 {
                        Label(formatSpeed(ul), systemImage: "arrow.up")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    if let peers = torrent.totalPeers, peers > 0 {
                        Label("\(peers)", systemImage: "person.2")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            progressView
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var posterView: some View {
        if let posterStr = torrent.poster, let url = URL(string: posterStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    defaultPoster
                }
            }
        } else {
            defaultPoster
        }
    }

    private var defaultPoster: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.2))
            .overlay(
                Image(systemName: torrent.categoryKind.systemImage)
                    .foregroundStyle(.secondary)
            )
    }

    @ViewBuilder
    private var categoryBadge: some View {
        if torrent.category != nil && !torrent.categoryKind.rawValue.isEmpty {
            Label(torrent.categoryKind.displayName, systemImage: torrent.categoryKind.systemImage)
                .font(.caption2)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.secondary.opacity(0.15), in: Capsule())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statLabel: some View {
        if let statStr = torrent.statString, !statStr.isEmpty {
            Text(statStr)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var progressView: some View {
        let p = torrent.progress
        if p > 0 && p < 1 {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: p)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(p * 100))%")
                    .font(.system(size: 7, weight: .bold))
            }
            .frame(width: 32, height: 32)
        } else if p >= 1 {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .imageScale(.large)
        }
    }
}

private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

private func formatSpeed(_ bytesPerSec: Double) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return "\(formatter.string(fromByteCount: Int64(bytesPerSec)))/s"
}
