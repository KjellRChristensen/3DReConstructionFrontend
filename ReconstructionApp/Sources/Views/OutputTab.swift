import SwiftUI
import QuickLook

struct OutputTab: View {
    @StateObject private var viewModel = OutputFilesViewModel()
    @State private var previewURL: URL?
    @State private var selectedFileForViewer: OutputFile?
    @State private var downloadedURLForViewer: URL?
    @State private var showingShareSheet = false
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.files.isEmpty {
                    loadingView
                } else if viewModel.files.isEmpty {
                    emptyView
                } else {
                    outputListView
                }
            }
            .navigationTitle("Output")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task {
                await viewModel.loadFiles()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .quickLookPreview($previewURL)
            .navigationDestination(item: $selectedFileForViewer) { file in
                if let url = downloadedURLForViewer {
                    ModelViewer(url: url)
                } else {
                    ProgressView("Loading...")
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading output files...")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Output Files", systemImage: "square.stack.3d.up")
        } description: {
            Text("Completed reconstruction jobs will appear here.")
        }
    }

    private var outputListView: some View {
        List {
            // Group by file type
            let modelFiles = viewModel.files.filter { isModelFile($0) }
            let imageFiles = viewModel.files.filter { isImageFile($0) }
            let otherFiles = viewModel.files.filter { !isModelFile($0) && !isImageFile($0) }

            if !modelFiles.isEmpty {
                Section("3D Models") {
                    ForEach(modelFiles) { file in
                        OutputFileRow(
                            file: file,
                            isDownloading: viewModel.downloadingFiles.contains(file.path),
                            onView: { await handleView(file) },
                            onAR: { await handleAR(file) },
                            onShare: { await handleShare(file) }
                        )
                    }
                }
            }

            if !imageFiles.isEmpty {
                Section("Images") {
                    ForEach(imageFiles) { file in
                        OutputFileRow(
                            file: file,
                            isDownloading: viewModel.downloadingFiles.contains(file.path),
                            onView: { await handleView(file) },
                            onAR: nil,
                            onShare: { await handleShare(file) }
                        )
                    }
                }
            }

            if !otherFiles.isEmpty {
                Section("Other Files") {
                    ForEach(otherFiles) { file in
                        OutputFileRow(
                            file: file,
                            isDownloading: viewModel.downloadingFiles.contains(file.path),
                            onView: { await handleView(file) },
                            onAR: nil,
                            onShare: { await handleShare(file) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func isModelFile(_ file: OutputFile) -> Bool {
        let modelExtensions = [".obj", ".stl", ".glb", ".gltf", ".usdz", ".usda", ".usd", ".dae", ".ifc"]
        return modelExtensions.contains(file.fileExtension.lowercased())
    }

    private func isImageFile(_ file: OutputFile) -> Bool {
        let imageExtensions = [".png", ".jpg", ".jpeg", ".gif", ".webp", ".tiff"]
        return imageExtensions.contains(file.fileExtension.lowercased())
    }

    private func handleView(_ file: OutputFile) async {
        do {
            let url = try await viewModel.downloadFile(file)

            // Check file type for appropriate viewer
            let ext = file.fileExtension.lowercased()

            switch ext {
            case ".usdz", ".usda", ".usd":
                // QuickLook has native USDZ support with AR
                previewURL = url

            case ".obj", ".dae", ".scn":
                // SceneKit can handle these
                downloadedURLForViewer = url
                selectedFileForViewer = file

            case ".glb", ".gltf":
                // GLB/GLTF - Try QuickLook first, fallback to share
                // Note: iOS 17+ has better GLB support
                if #available(iOS 17.0, *) {
                    previewURL = url
                } else {
                    // Offer to share/open in another app
                    shareURL = url
                    showingShareSheet = true
                }

            case ".png", ".jpg", ".jpeg", ".gif", ".webp", ".tiff":
                // Images - QuickLook
                previewURL = url

            case ".pdf":
                // PDF - QuickLook
                previewURL = url

            default:
                // Try QuickLook for unknown types
                previewURL = url
            }
        } catch {
            viewModel.error = error.localizedDescription
        }
    }

    private func handleAR(_ file: OutputFile) async {
        do {
            let url = try await viewModel.downloadFile(file)
            // AR Quick Look only works with USDZ
            if file.fileExtension.lowercased() == ".usdz" {
                previewURL = url
            } else {
                viewModel.error = "AR preview requires USDZ format. This file is \(file.fileExtension)."
            }
        } catch {
            viewModel.error = error.localizedDescription
        }
    }

    private func handleShare(_ file: OutputFile) async {
        do {
            let url = try await viewModel.downloadFile(file)
            shareURL = url
            showingShareSheet = true
        } catch {
            viewModel.error = error.localizedDescription
        }
    }
}

struct OutputFileRow: View {
    let file: OutputFile
    let isDownloading: Bool
    let onView: () async -> Void
    let onAR: (() async -> Void)?
    let onShare: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // File icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 50, height: 50)

                    if isDownloading {
                        ProgressView()
                    } else {
                        Image(systemName: iconName)
                            .font(.title2)
                            .foregroundStyle(iconColor)
                    }
                }

                // File info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(file.name)
                            .font(.body)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        if file.fileExtension.lowercased() == ".usdz" {
                            Text("AR")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }

                        if file.fileExtension.lowercased() == ".glb" {
                            Text("3D")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.purple.opacity(0.2))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 6) {
                        Text(file.sizeHuman)
                        Text("•")
                        Text(file.fileExtension.uppercased().dropFirst())
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    Task { await onView() }
                } label: {
                    Label("View", systemImage: "eye")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isDownloading)

                if let onAR = onAR, file.fileExtension.lowercased() == ".usdz" {
                    Button {
                        Task { await onAR() }
                    } label: {
                        Label("AR", systemImage: "arkit")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .disabled(isDownloading)
                }

                Button {
                    Task { await onShare() }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isDownloading)
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch file.fileExtension.lowercased() {
        case ".obj", ".stl": return "cube"
        case ".gltf", ".glb": return "cube.transparent"
        case ".usdz", ".usda", ".usd": return "arkit"
        case ".ifc": return "building.2"
        case ".dae": return "cube.transparent"
        case ".png", ".jpg", ".jpeg": return "photo"
        case ".pdf": return "doc.richtext"
        default: return "doc"
        }
    }

    private var iconColor: Color {
        switch file.fileExtension.lowercased() {
        case ".usdz", ".usda", ".usd": return .orange
        case ".glb", ".gltf": return .purple
        case ".obj": return .blue
        case ".ifc": return .green
        case ".dae": return .cyan
        case ".png", ".jpg", ".jpeg": return .pink
        default: return .gray
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Models

struct OutputFile: Identifiable, Codable, Hashable {
    let name: String
    let path: String
    let fullPath: String
    let size: Int
    let sizeHuman: String
    let modified: String
    let type: String
    let fileExtension: String

    var id: String { path }

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case fullPath = "full_path"
        case size
        case sizeHuman = "size_human"
        case modified
        case type
        case fileExtension = "extension"
    }
}

struct OutputFilesResponse: Codable {
    let files: [OutputFile]
    let total: Int
    let directory: String?
}

// MARK: - ViewModel

@MainActor
class OutputFilesViewModel: ObservableObject {
    @Published var files: [OutputFile] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var downloadedURLs: [String: URL] = [:]
    @Published var downloadingFiles: Set<String> = []

    private let apiClient = APIClient.shared

    func loadFiles() async {
        isLoading = true
        error = nil

        do {
            let response = try await apiClient.listOutputFiles()
            files = response.files
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        await loadFiles()
    }

    func downloadFile(_ file: OutputFile) async throws -> URL {
        // Check if already downloaded
        if let url = downloadedURLs[file.path], FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        downloadingFiles.insert(file.path)
        defer { downloadingFiles.remove(file.path) }

        let url = try await apiClient.downloadOutputFile(filepath: file.path)
        downloadedURLs[file.path] = url

        return url
    }
}

#Preview {
    OutputTab()
}
