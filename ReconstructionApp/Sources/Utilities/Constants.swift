import Foundation

enum Constants {
    enum API {
        @MainActor
        static var baseURL: String {
            ServerConfigurationManager.shared.currentBaseURL
        }
        static let jobsEndpoint = "/jobs"
        static let defaultPort = 7001
    }

    enum App {
        static let name = "3D Reconstruction"
        static let version = "1.0.0"
    }

    enum Storage {
        static let modelsDirectory = "Models"
        static let imagesDirectory = "Images"
    }

    enum Network {
        static let defaultHostname = "macbook-pro-max.local"
    }
}
