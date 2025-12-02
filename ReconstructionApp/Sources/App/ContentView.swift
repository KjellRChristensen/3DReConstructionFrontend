import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1
    @State private var showingSettings = false

    var body: some View {
        TabView(selection: $selectedTab) {
            InputTab()
                .tabItem {
                    Label("Input", systemImage: "folder")
                }
                .tag(0)

            ReconstructTab()
                .tabItem {
                    Label("Reconstruct", systemImage: "cube.transparent")
                }
                .tag(1)

            OutputTab()
                .tabItem {
                    Label("Output", systemImage: "square.stack.3d.up")
                }
                .tag(2)

            ValidationTab()
                .tabItem {
                    Label("Validate", systemImage: "checkmark.seal")
                }
                .tag(3)

            TrainingTab()
                .tabItem {
                    Label("Training", systemImage: "brain")
                }
                .tag(4)

            VLMTab()
                .tabItem {
                    Label("VLM", systemImage: "eye.circle")
                }
                .tag(5)

            SettingsTab(showingSettings: $showingSettings)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(6)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

struct SettingsTab: View {
    @Binding var showingSettings: Bool
    @ObservedObject var serverManager = ServerConfigurationManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Current Server") {
                    if let server = serverManager.selectedServer {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(server.name)
                                .font(.headline)
                            Text(server.displayURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Server Settings", systemImage: "server.rack")
                    }

                    Button {
                        serverManager.refreshLocalNetworkIP()
                    } label: {
                        Label("Refresh Network", systemImage: "arrow.triangle.2.circlepath")
                    }
                }

                Section("Connection Info") {
                    if let deviceIP = NetworkUtility.getDeviceIPAddress() {
                        LabeledContent("Device IP", value: deviceIP)
                    }

                    if let tailscaleIP = NetworkUtility.getTailscaleIP() {
                        LabeledContent("Tailscale IP", value: tailscaleIP)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Constants.App.version)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(JobListViewModel())
}
