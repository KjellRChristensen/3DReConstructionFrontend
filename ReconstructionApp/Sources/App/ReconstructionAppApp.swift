import SwiftUI

@main
struct ReconstructionAppApp: App {
    @StateObject private var jobListViewModel = JobListViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(jobListViewModel)
        }
    }
}
