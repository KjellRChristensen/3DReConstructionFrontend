import Foundation
import Combine

@MainActor
class JobListViewModel: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var isLoading = false
    @Published var error: String?

    private let apiClient = APIClient.shared

    func loadJobs() async {
        isLoading = true
        error = nil

        do {
            jobs = try await apiClient.listJobs()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func addJob(_ job: Job) {
        if !jobs.contains(where: { $0.id == job.id }) {
            jobs.insert(job, at: 0)
        }
    }

    func updateJob(_ job: Job) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = job
        }
    }

    func removeJob(id: String) {
        jobs.removeAll { $0.id == id }
    }

    func deleteJob(id: String) async {
        do {
            try await apiClient.deleteJob(id: id)
            removeJob(id: id)
        } catch {
            self.error = "Failed to delete job: \(error.localizedDescription)"
        }
    }
}
