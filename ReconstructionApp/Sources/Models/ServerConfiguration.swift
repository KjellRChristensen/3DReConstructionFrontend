import Foundation

// MARK: - Network Utility

struct NetworkUtility {

    /// Resolve a .local hostname (mDNS/Bonjour) to an IPv4 address
    static func getMacServerIP(hostname: String = "macbook-pro-max.local") -> String? {
        // Ensure .local suffix
        let fullHostname = hostname.hasSuffix(".local") ? hostname : "\(hostname).local"

        // Try to resolve the hostname to an IPv4 address
        if let resolved = resolveHostname(fullHostname) {
            print("✅ [NetworkUtility] Resolved: \(fullHostname) → \(resolved)")
            return resolved
        }

        print("❌ [NetworkUtility] Failed to resolve: \(fullHostname)")
        return nil
    }

    /// Get the device's own IP address on the local network
    static func getDeviceIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family

                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)

                    // Check for network interfaces
                    // en0 = WiFi, en1 = Ethernet, bridge100 = simulator bridge
                    if name == "en0" || name == "en1" || name == "bridge100" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

                        if getnameinfo(
                            interface.ifa_addr,
                            socklen_t(interface.ifa_addr.pointee.sa_len),
                            &hostname,
                            socklen_t(hostname.count),
                            nil,
                            0,
                            NI_NUMERICHOST
                        ) == 0 {
                            let addressString = String(cString: hostname)

                            // Get valid IPv4 address (not loopback or link-local)
                            if !addressString.hasPrefix("169.254.") &&
                               !addressString.hasPrefix("127.") &&
                               addressString.contains(".") {
                                // Prefer en0/en1 over bridge100
                                if name == "en0" || name == "en1" {
                                    return addressString
                                } else if address == nil {
                                    address = addressString
                                }
                            }
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        return address
    }

    /// Get Tailscale VPN IP address if available
    static func getTailscaleIP() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family

                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)

                    // Check for Tailscale interfaces (utun)
                    if name.hasPrefix("utun") {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

                        if getnameinfo(
                            interface.ifa_addr,
                            socklen_t(interface.ifa_addr.pointee.sa_len),
                            &hostname,
                            socklen_t(hostname.count),
                            nil,
                            0,
                            NI_NUMERICHOST
                        ) == 0 {
                            let addressString = String(cString: hostname)

                            // Tailscale uses 100.64.0.0/10 range
                            if addressString.hasPrefix("100.") {
                                address = addressString
                                break
                            }
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        return address
    }

    /// Resolve hostname using DNS/mDNS
    static func resolveHostname(_ hostname: String) -> String? {
        var hints = addrinfo()
        hints.ai_family = AF_INET // Force IPv4 only
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP

        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(hostname, nil, &hints, &result)

        guard status == 0, let addrInfo = result else {
            return nil
        }

        defer { freeaddrinfo(result) }

        var ipAddress = [CChar](repeating: 0, count: Int(NI_MAXHOST))

        if getnameinfo(
            addrInfo.pointee.ai_addr,
            addrInfo.pointee.ai_addrlen,
            &ipAddress,
            socklen_t(ipAddress.count),
            nil,
            0,
            NI_NUMERICHOST
        ) == 0 {
            return String(cString: ipAddress)
        }

        return nil
    }
}

// MARK: - Server Configuration

struct ServerConfiguration: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var isSecure: Bool
    var isDefault: Bool

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int,
        isSecure: Bool = false,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.isSecure = isSecure
        self.isDefault = isDefault
    }

    var baseURL: String {
        let scheme = isSecure ? "https" : "http"
        return "\(scheme)://\(host):\(port)"
    }

    var healthURL: String {
        "\(baseURL)/health"
    }

    var displayURL: String {
        baseURL
    }

    // Predefined server configurations
    static var defaultServers: [ServerConfiguration] {
        [
            ServerConfiguration(
                name: "Local Network",
                host: NetworkUtility.getMacServerIP() ?? NetworkUtility.getDeviceIPAddress() ?? "macbook-pro-max.local",
                port: 7001,
                isSecure: false,
                isDefault: true
            ),
            ServerConfiguration(
                name: "Localhost (Simulator)",
                host: "localhost",
                port: 7001,
                isSecure: false
            ),
            ServerConfiguration(
                name: "Tailscale",
                host: NetworkUtility.getTailscaleIP() ?? "100.100.100.100",
                port: 7001,
                isSecure: false
            )
        ]
    }
}

// MARK: - Server Configuration Manager

@MainActor
class ServerConfigurationManager: ObservableObject {
    static let shared = ServerConfigurationManager()

    @Published var servers: [ServerConfiguration] = []
    @Published var selectedServer: ServerConfiguration?
    @Published var isRefreshing = false

    private let userDefaultsKey = "serverConfigurations"
    private let selectedServerKey = "selectedServerId"

    init() {
        loadConfigurations()
    }

    var currentBaseURL: String {
        selectedServer?.baseURL ?? ServerConfiguration.defaultServers.first?.baseURL ?? "http://localhost:7001"
    }

    func loadConfigurations() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([ServerConfiguration].self, from: data) {
            servers = decoded
        } else {
            servers = ServerConfiguration.defaultServers
            saveConfigurations()
        }

        // Load selected server
        if let selectedId = UserDefaults.standard.string(forKey: selectedServerKey),
           let uuid = UUID(uuidString: selectedId),
           let server = servers.first(where: { $0.id == uuid }) {
            selectedServer = server
        } else {
            selectedServer = servers.first(where: { $0.isDefault }) ?? servers.first
        }
    }

    func saveConfigurations() {
        if let encoded = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    func selectServer(_ server: ServerConfiguration) {
        selectedServer = server
        UserDefaults.standard.set(server.id.uuidString, forKey: selectedServerKey)
    }

    func refreshLocalNetworkIP() {
        isRefreshing = true

        // Try to resolve the Mac's IP
        if let resolvedIP = NetworkUtility.getMacServerIP() {
            updateLocalNetworkServer(host: resolvedIP)
        } else if let deviceIP = NetworkUtility.getDeviceIPAddress() {
            updateLocalNetworkServer(host: deviceIP)
        }

        // Update Tailscale if available
        if let tailscaleIP = NetworkUtility.getTailscaleIP() {
            if let index = servers.firstIndex(where: { $0.name == "Tailscale" }) {
                servers[index].host = tailscaleIP
            }
        }

        saveConfigurations()
        isRefreshing = false
    }

    func updateLocalNetworkServer(host: String) {
        if let index = servers.firstIndex(where: { $0.name == "Local Network" }) {
            servers[index].host = host
            if selectedServer?.name == "Local Network" {
                selectedServer = servers[index]
            }
        }
        saveConfigurations()
    }

    func addServer(_ server: ServerConfiguration) {
        servers.append(server)
        saveConfigurations()
    }

    func removeServer(_ server: ServerConfiguration) {
        servers.removeAll { $0.id == server.id }
        if selectedServer?.id == server.id {
            selectedServer = servers.first
        }
        saveConfigurations()
    }

    func resetToDefaults() {
        servers = ServerConfiguration.defaultServers
        selectedServer = servers.first(where: { $0.isDefault }) ?? servers.first
        saveConfigurations()
        if let selected = selectedServer {
            UserDefaults.standard.set(selected.id.uuidString, forKey: selectedServerKey)
        }
    }

    func checkServerHealth(_ server: ServerConfiguration) async -> Bool {
        guard let url = URL(string: server.healthURL) else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return (200...299).contains(httpResponse.statusCode)
            }
        } catch {
            print("Health check failed for \(server.name): \(error.localizedDescription)")
        }

        return false
    }
}
