import SwiftUI
import QuickLook

struct JobDetailView: View {
    @StateObject private var viewModel: JobViewModel
    @State private var previewURL: URL?

    init(jobId: String) {
        _viewModel = StateObject(wrappedValue: JobViewModel(jobId: jobId))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status card
                statusCard

                // Progress section (if processing)
                if viewModel.job?.status == .processing {
                    progressSection
                }

                // Error section (if failed)
                if let error = viewModel.job?.error {
                    errorSection(error)
                }

                // Results section (if completed)
                if viewModel.job?.status == .completed {
                    resultsSection
                }

                // Downloaded files section
                if !viewModel.downloadedFiles.isEmpty {
                    downloadedFilesSection
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.job?.filename ?? "Job Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadJob()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .quickLookPreview($previewURL)
    }

    private var statusCard: some View {
        VStack(spacing: 16) {
            if let job = viewModel.job {
                Image(systemName: job.status.systemImage)
                    .font(.system(size: 48))
                    .foregroundStyle(statusColor(for: job.status))

                Text(job.status.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(spacing: 4) {
                    Text("Created: \(job.createdAt.formatted())")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let completedAt = job.completedAt {
                        Text("Completed: \(completedAt.formatted())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if viewModel.isLoading {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.headline)

            if let progress = viewModel.progress {
                ProgressCard(progress: progress)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorSection(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Error", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(.red)

            Text(error)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.headline)

            if let outputFiles = viewModel.job?.outputFiles, !outputFiles.isEmpty {
                ForEach(outputFiles, id: \.self) { filename in
                    fileRow(filename: filename)
                }

                Button {
                    Task {
                        await viewModel.downloadAllFiles()
                    }
                } label: {
                    Label("Download All", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            } else {
                Text("No output files available")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fileRow(filename: String) -> some View {
        HStack {
            Image(systemName: fileIcon(for: filename))
                .foregroundStyle(.blue)

            Text(filename)
                .lineLimit(1)

            Spacer()

            Button {
                Task {
                    await viewModel.downloadFile(filename: filename)
                }
            } label: {
                Image(systemName: "arrow.down.circle")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var downloadedFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Downloaded Files")
                .font(.headline)

            ForEach(viewModel.downloadedFiles, id: \.absoluteString) { url in
                downloadedFileRow(url: url)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func downloadedFileRow(url: URL) -> some View {
        Button {
            previewURL = url
        } label: {
            HStack {
                Image(systemName: fileIcon(for: url.lastPathComponent))
                    .foregroundStyle(.green)

                Text(url.lastPathComponent)
                    .lineLimit(1)

                Spacer()

                if url.pathExtension == "usdz" {
                    Label("AR", systemImage: "arkit")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Image(systemName: "eye")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statusColor(for status: JobStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }

    private func fileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "obj", "stl": return "cube"
        case "gltf", "glb": return "cube.transparent"
        case "usdz": return "arkit"
        case "ifc": return "building.2"
        case "step": return "gearshape"
        default: return "doc"
        }
    }
}

#Preview {
    NavigationStack {
        JobDetailView(jobId: "test-123")
    }
}
