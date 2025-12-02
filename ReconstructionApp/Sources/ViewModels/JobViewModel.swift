import Foundation
import UIKit
import Combine

@MainActor
class JobViewModel: ObservableObject {
    @Published var job: Job?
    @Published var progress: JobProgress?
    @Published var isLoading = false
    @Published var error: String?
    @Published var downloadedFiles: [URL] = []

    private var pollingTask: Task<Void, Never>?
    private let apiClient = APIClient.shared

    let jobId: String

    init(jobId: String) {
        self.jobId = jobId
    }

    deinit {
        pollingTask?.cancel()
    }

    func loadJob() async {
        isLoading = true
        error = nil

        do {
            job = try await apiClient.getJob(id: jobId)

            if job?.status == .processing {
                startPolling()
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func startPolling() {
        pollingTask?.cancel()

        pollingTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                    let updatedJob = try await apiClient.getJob(id: jobId)
                    self.job = updatedJob

                    if updatedJob.status == .processing {
                        let progressUpdate = try await apiClient.getJobProgress(id: jobId)
                        self.progress = progressUpdate
                    } else {
                        // Job finished - stop polling
                        break
                    }
                } catch {
                    if !Task.isCancelled {
                        self.error = error.localizedDescription
                    }
                    break
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func downloadFile(filename: String) async {
        do {
            let url = try await apiClient.downloadFile(jobId: jobId, filename: filename)
            downloadedFiles.append(url)
        } catch {
            self.error = "Download failed: \(error.localizedDescription)"
        }
    }

    func downloadAllFiles() async {
        guard let outputFiles = job?.outputFiles else { return }

        for filename in outputFiles {
            await downloadFile(filename: filename)
        }
    }
}

@MainActor
class UploadViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var selectedFormats: Set<ExportFormat> = [.glb, .usdz]
    @Published var wallHeight: Double = 2.7
    @Published var scale: Double = 1.0
    @Published var isUploading = false
    @Published var uploadError: String?
    @Published var createdJobId: String?

    private let apiClient = APIClient.shared

    var canUpload: Bool {
        selectedImage != nil && !selectedFormats.isEmpty
    }

    func upload() async {
        guard let image = selectedImage else { return }

        isUploading = true
        uploadError = nil

        // Resize image if too large to reduce memory
        let maxDimension: CGFloat = 2048
        let resizedImage = resizeImageIfNeeded(image, maxDimension: maxDimension)

        do {
            let filename = "floorplan_\(Date().timeIntervalSince1970).jpg"
            let response = try await apiClient.createJob(
                image: resizedImage,
                filename: filename,
                formats: Array(selectedFormats),
                wallHeight: wallHeight,
                scale: scale
            )

            createdJobId = response.jobId
            // Clear image after successful upload to free memory
            selectedImage = nil
        } catch {
            uploadError = error.localizedDescription
        }

        isUploading = false
    }

    func reset() {
        selectedImage = nil
        createdJobId = nil
        uploadError = nil
    }

    private func resizeImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
