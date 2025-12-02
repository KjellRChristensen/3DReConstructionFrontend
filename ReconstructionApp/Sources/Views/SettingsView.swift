import SwiftUI

struct SettingsView: View {
    @ObservedObject var serverManager = ServerConfigurationManager.shared
    @State private var showingAddServer = false
    @State private var serverHealthStatus: [UUID: Bool] = [:]
    @State private var isCheckingHealth = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Server Selection
                Section {
                    ForEach(serverManager.servers) { server in
                        ServerRow(
                            server: server,
                            isSelected: serverManager.selectedServer?.id == server.id,
                            healthStatus: serverHealthStatus[server.id]
                        ) {
                            serverManager.selectServer(server)
                        }
                    }
                    .onDelete(perform: deleteServers)
                } header: {
                    HStack {
                        Text("Server")
                        Spacer()
                        if isCheckingHealth {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                } footer: {
                    Text("Select the backend server to connect to.")
                }

                // Network Actions
                Section {
                    Button {
                        serverManager.refreshLocalNetworkIP()
                        Task { await checkAllServersHealth() }
                    } label: {
                        Label("Refresh Network", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button {
                        Task { await checkAllServersHealth() }
                    } label: {
                        Label("Check Server Health", systemImage: "heart.text.square")
                    }
                }

                // Add Server
                Section {
                    Button {
                        showingAddServer = true
                    } label: {
                        Label("Add Custom Server", systemImage: "plus.circle")
                    }

                    Button(role: .destructive) {
                        serverManager.resetToDefaults()
                        serverHealthStatus.removeAll()
                    } label: {
                        Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                    }
                }

                // Current Connection Info
                Section("Connection Info") {
                    LabeledContent("Current URL", value: serverManager.currentBaseURL)
                        .font(.caption)

                    if let deviceIP = NetworkUtility.getDeviceIPAddress() {
                        LabeledContent("Device IP", value: deviceIP)
                            .font(.caption)
                    }

                    if let tailscaleIP = NetworkUtility.getTailscaleIP() {
                        LabeledContent("Tailscale IP", value: tailscaleIP)
                            .font(.caption)
                    }
                }

                // App Info
                Section("About") {
                    LabeledContent("App Version", value: Constants.App.version)
                    LabeledContent("App Name", value: Constants.App.name)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddServer) {
                AddServerSheet()
            }
            .task {
                await checkAllServersHealth()
            }
        }
    }

    private func deleteServers(at offsets: IndexSet) {
        for index in offsets {
            let server = serverManager.servers[index]
            if !server.isDefault {
                serverManager.removeServer(server)
            }
        }
    }

    private func checkAllServersHealth() async {
        isCheckingHealth = true
        for server in serverManager.servers {
            let isHealthy = await serverManager.checkServerHealth(server)
            serverHealthStatus[server.id] = isHealthy
        }
        isCheckingHealth = false
    }
}

struct ServerRow: View {
    let server: ServerConfiguration
    let isSelected: Bool
    let healthStatus: Bool?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(server.name)
                            .font(.body)
                            .fontWeight(isSelected ? .semibold : .regular)

                        if server.isDefault {
                            Text("Default")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.2))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }

                    Text(server.displayURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Health indicator
                if let isHealthy = healthStatus {
                    Circle()
                        .fill(isHealthy ? .green : .red)
                        .frame(width: 10, height: 10)
                }

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct AddServerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var serverManager = ServerConfigurationManager.shared

    @State private var name = ""
    @State private var host = ""
    @State private var port = "7001"
    @State private var isSecure = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Details") {
                    TextField("Name", text: $name)
                    TextField("Host (IP or hostname)", text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    Toggle("Use HTTPS", isOn: $isSecure)
                }

                Section {
                    Button("Add Server") {
                        addServer()
                    }
                    .disabled(name.isEmpty || host.isEmpty || port.isEmpty)
                }
            }
            .navigationTitle("Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addServer() {
        guard let portNumber = Int(port) else { return }

        let server = ServerConfiguration(
            name: name,
            host: host,
            port: portNumber,
            isSecure: isSecure
        )

        serverManager.addServer(server)
        dismiss()
    }
}

#Preview {
    SettingsView()
}
