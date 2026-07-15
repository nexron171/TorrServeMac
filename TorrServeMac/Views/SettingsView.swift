import SwiftUI

struct SettingsView: View {
    @Bindable private var appSettings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var players: [PlayerApp] = []
    @State private var serverSettings: BTSets?
    @State private var isLoadingServer = false
    @State private var isSavingServer = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            connectionTab
                .tabItem { Label("Connection", systemImage: "network") }
                .tag(0)

            serverTab
                .tabItem { Label("Server", systemImage: "server.rack") }
                .tag(1)
        }
        .padding()
        .frame(width: 500)
        .onAppear {
            players = PlayerFinder.findVideoPlayers()
        }
        .task(id: selectedTab) {
            if selectedTab == 1 && serverSettings == nil {
                await loadServerSettings()
            }
        }
    }

    // MARK: - Connection tab

    private var connectionTab: some View {
        Form {
            Section("TorrServe Address") {
                LabeledContent("Host") {
                    TextField("127.0.0.1", text: $appSettings.host)
                        .frame(width: 200)
                }
                LabeledContent("Port") {
                    TextField("8090", value: $appSettings.port, format: .number)
                        .frame(width: 80)
                }
            }

            Section("Authentication") {
                Toggle("Require login", isOn: $appSettings.useAuth)

                if appSettings.useAuth {
                    LabeledContent("Login") {
                        TextField("username", text: $appSettings.authLogin)
                            .frame(width: 200)
                    }
                    LabeledContent("Password") {
                        SecureField("password", text: $appSettings.authPassword)
                            .frame(width: 200)
                    }
                }
            }

            Section("Playback") {
                LabeledContent("Media Player") {
                    Picker("", selection: $appSettings.preferredPlayerPath) {
                        Label("System Default", systemImage: "globe")
                            .tag("")
                        if !players.isEmpty {
                            Divider()
                            ForEach(players) { player in
                                HStack(spacing: 6) {
                                    Image(nsImage: player.icon)
                                        .resizable()
                                        .frame(width: 16, height: 16)
                                    Text(player.name)
                                }
                                .tag(player.url.path)
                            }
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }

                if !appSettings.preferredPlayerPath.isEmpty {
                    let playerName = PlayerApp(url: URL(fileURLWithPath: appSettings.preferredPlayerPath)).name
                    Text("Streams will open in \(playerName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                if let success = successMessage {
                    Label(success, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green).font(.callout)
                }
                if let err = errorMessage {
                    Label(err, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red).font(.callout)
                }
                Button("Test Connection") {
                    Task { await testConnection() }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Server settings tab

    @ViewBuilder
    private var serverTab: some View {
        if isLoadingServer {
            ProgressView("Loading server settings…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if serverSettings != nil {
            Form {
                Section("Cache") {
                    LabeledContent("Cache size (MB)") {
                        TextField("0", value: cacheSizeMBBinding, format: .number)
                            .frame(width: 80)
                    }
                    Toggle("Preload buffer", isOn: boolBinding(\.preloadBuffer))
                }

                Section("Network limits") {
                    LabeledContent("Download (KB/s, 0=unlimited)") {
                        TextField("0", value: intBinding(\.downloadRateLimit), format: .number)
                            .frame(width: 80)
                    }
                    LabeledContent("Upload (KB/s, 0=unlimited)") {
                        TextField("0", value: intBinding(\.uploadRateLimit), format: .number)
                            .frame(width: 80)
                    }
                    LabeledContent("Connections limit") {
                        TextField("0", value: intBinding(\.connectionsLimit), format: .number)
                            .frame(width: 80)
                    }
                    Toggle("Force encryption", isOn: boolBinding(\.forceEncrypt))
                    Toggle("Disable upload", isOn: boolBinding(\.disableUpload))
                }

                Section("Storage") {
                    Toggle("Save to disk", isOn: boolBinding(\.useDisk))
                    if serverSettings?.useDisk == true {
                        LabeledContent("Save path") {
                            TextField("/tmp/torrserver", text: stringBinding(\.torrentsSavePath))
                                .frame(width: 200)
                        }
                    }
                }

                Section("Features") {
                    Toggle("Enable DLNA", isOn: boolBinding(\.enableDLNA))
                    Toggle("Responsive mode", isOn: boolBinding(\.responsiveMode))
                    Toggle("Enable debug log", isOn: boolBinding(\.enableDebug))
                }

                HStack {
                    if let err = errorMessage {
                        Text(err).foregroundStyle(.red).font(.callout)
                    }
                    Spacer()
                    Button("Reset Defaults") {
                        Task { await resetServerSettings() }
                    }
                    Button("Save") {
                        Task { await saveServerSettings() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSavingServer)
                }
            }
            .formStyle(.grouped)
        } else {
            VStack(spacing: 12) {
                if let err = errorMessage {
                    Text(err).foregroundStyle(.secondary)
                }
                Button("Load Server Settings") {
                    Task { await loadServerSettings() }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Binding helpers

    private var cacheSizeMBBinding: Binding<Int> {
        Binding(
            get: { Int((serverSettings?.cacheSize ?? 0) / 1024 / 1024) },
            set: { serverSettings?.cacheSize = Int64($0) * 1024 * 1024 }
        )
    }

    private func boolBinding(_ kp: WritableKeyPath<BTSets, Bool?>) -> Binding<Bool> {
        Binding(
            get: { serverSettings?[keyPath: kp] ?? false },
            set: { serverSettings?[keyPath: kp] = $0 }
        )
    }

    private func intBinding(_ kp: WritableKeyPath<BTSets, Int?>) -> Binding<Int> {
        Binding(
            get: { serverSettings?[keyPath: kp] ?? 0 },
            set: { serverSettings?[keyPath: kp] = $0 }
        )
    }

    private func stringBinding(_ kp: WritableKeyPath<BTSets, String?>) -> Binding<String> {
        Binding(
            get: { serverSettings?[keyPath: kp] ?? "" },
            set: { serverSettings?[keyPath: kp] = $0 }
        )
    }

    // MARK: - Actions

    private func testConnection() async {
        errorMessage = nil
        successMessage = nil
        do {
            let version = try await TorrAPI.shared.echo()
            successMessage = version.isEmpty ? "Connected" : version
        } catch {
            errorMessage = error.localizedDescription
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            successMessage = nil
            errorMessage = nil
        }
    }

    private func loadServerSettings() async {
        isLoadingServer = true
        errorMessage = nil
        do {
            serverSettings = try await TorrAPI.shared.getSettings()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingServer = false
    }

    private func saveServerSettings() async {
        guard let sets = serverSettings else { return }
        isSavingServer = true
        errorMessage = nil
        do {
            try await TorrAPI.shared.setSettings(sets)
            successMessage = "Saved"
            Task {
                try? await Task.sleep(for: .seconds(2))
                successMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSavingServer = false
    }

    private func resetServerSettings() async {
        errorMessage = nil
        do {
            serverSettings = try await TorrAPI.shared.resetSettings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
