import SwiftUI

struct ReconstructTab: View {
    @EnvironmentObject var jobListViewModel: JobListViewModel
    @State private var showingNewJob = false

    var body: some View {
        NavigationStack {
            Group {
                if jobListViewModel.isLoading && jobListViewModel.jobs.isEmpty {
                    loadingView
                } else if jobListViewModel.jobs.isEmpty {
                    emptyView
                } else {
                    jobListView
                }
            }
            .navigationTitle("Reconstruct")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewJob = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await jobListViewModel.loadJobs() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(jobListViewModel.isLoading)
                }
            }
            .sheet(isPresented: $showingNewJob) {
                NewJobSheet()
            }
            .task {
                await jobListViewModel.loadJobs()
            }
            .refreshable {
                await jobListViewModel.loadJobs()
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading jobs...")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Jobs", systemImage: "cube.transparent")
        } description: {
            Text("Start a new reconstruction job to convert floor plans into 3D models.")
        } actions: {
            Button {
                showingNewJob = true
            } label: {
                Label("New Job", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var jobListView: some View {
        List {
            // Active jobs section
            let activeJobs = jobListViewModel.jobs.filter { $0.status == .processing || $0.status == .pending }
            if !activeJobs.isEmpty {
                Section("Active") {
                    ForEach(activeJobs) { job in
                        NavigationLink(value: job) {
                            JobRow(job: job)
                        }
                    }
                }
            }

            // Completed jobs section
            let completedJobs = jobListViewModel.jobs.filter { $0.status == .completed }
            if !completedJobs.isEmpty {
                Section("Completed") {
                    ForEach(completedJobs) { job in
                        NavigationLink(value: job) {
                            JobRow(job: job)
                        }
                    }
                    .onDelete { indexSet in
                        deleteJobs(at: indexSet, from: completedJobs)
                    }
                }
            }

            // Failed jobs section
            let failedJobs = jobListViewModel.jobs.filter { $0.status == .failed }
            if !failedJobs.isEmpty {
                Section("Failed") {
                    ForEach(failedJobs) { job in
                        NavigationLink(value: job) {
                            JobRow(job: job)
                        }
                    }
                    .onDelete { indexSet in
                        deleteJobs(at: indexSet, from: failedJobs)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: Job.self) { job in
            JobDetailView(jobId: job.id)
        }
    }

    private func deleteJobs(at offsets: IndexSet, from jobs: [Job]) {
        for index in offsets {
            let job = jobs[index]
            Task {
                await jobListViewModel.deleteJob(id: job.id)
            }
        }
    }
}

struct JobRow: View {
    let job: Job

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                if job.status == .processing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: job.status.systemImage)
                        .font(.title3)
                        .foregroundStyle(statusColor)
                }
            }

            // Job info
            VStack(alignment: .leading, spacing: 4) {
                Text(job.filename)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(job.status.displayName)
                        .foregroundStyle(statusColor)

                    if let progress = job.progress, job.status == .processing {
                        Text("•")
                        Text("\(Int(progress.progress * 100))%")
                    }

                    Text("•")
                    Text(job.createdAt, style: .relative)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch job.status {
        case .pending: return .orange
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

struct NewJobSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = NewJobViewModel()

    var body: some View {
        NavigationStack {
            Form {
                // File selection
                Section {
                    if let file = viewModel.selectedFile {
                        selectedFileRow(file)
                    } else {
                        Button {
                            viewModel.showingFilePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "folder")
                                    .font(.title2)
                                    .foregroundStyle(.blue)

                                VStack(alignment: .leading) {
                                    Text("Select File")
                                        .font(.body)
                                    Text("Choose from input folder")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Floor Plan")
                }

                // Strategy selection
                Section {
                    ForEach(ReconstructionStrategyType.allCases) { strategy in
                        Button {
                            viewModel.selectedStrategy = strategy
                        } label: {
                            HStack {
                                Image(systemName: strategy.systemImage)
                                    .font(.title3)
                                    .foregroundStyle(strategy == viewModel.selectedStrategy ? .blue : .secondary)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(strategy.displayName)
                                        .font(.body)
                                        .foregroundStyle(.primary)

                                    Text(strategyDescription(for: strategy))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if strategy == viewModel.selectedStrategy {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Strategy")
                } footer: {
                    Text("Auto will select the best available strategy based on your input.")
                }

                // Export format (single selection for new API)
                Section("Export Format") {
                    Picker("Format", selection: $viewModel.selectedFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            HStack {
                                Text(format.displayName)
                                if format.supportsARQuickLook {
                                    Text("AR")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.orange.opacity(0.2))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }
                            }
                            .tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Parameters
                Section("Parameters") {
                    HStack {
                        Text("Wall Height")
                        Spacer()
                        TextField("", value: $viewModel.wallHeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("m")
                            .foregroundStyle(.secondary)
                    }
                }

                // Quick Preview button
                if viewModel.selectedFile != nil {
                    Section {
                        Button {
                            Task { await viewModel.getPreview() }
                        } label: {
                            HStack {
                                Spacer()
                                if viewModel.isLoadingPreview {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                    Text("Generating Preview...")
                                } else {
                                    Label("Quick Preview", systemImage: "eye")
                                }
                                Spacer()
                            }
                        }
                        .disabled(viewModel.isProcessing || viewModel.isLoadingPreview)
                    } footer: {
                        Text("Generate a fast preview using basic extrusion.")
                    }
                }

                // Start button
                Section {
                    Button {
                        Task { await viewModel.startJob() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isProcessing {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Starting...")
                            } else {
                                Label("Start Reconstruction", systemImage: "play.fill")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!viewModel.canStart || viewModel.isProcessing)
                }

                // Error
                if let error = viewModel.error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                // Preview result
                if let previewURL = viewModel.previewDownloadURL {
                    Section("Preview Result") {
                        Text("Preview generated: \(previewURL)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $viewModel.showingFilePicker) {
                FileBrowserView(selectedFile: $viewModel.selectedFile)
            }
            .onChange(of: viewModel.jobCreated) { _, created in
                if created { dismiss() }
            }
        }
    }

    private func selectedFileRow(_ file: InputFile) -> some View {
        HStack(spacing: 12) {
            Image(systemName: file.iconName)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(1)
                Text(file.sizeHuman)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Change") {
                viewModel.showingFilePicker = true
            }
            .font(.subheadline)
        }
    }

    private func strategyDescription(for strategy: ReconstructionStrategyType) -> String {
        switch strategy {
        case .auto:
            return "Automatically select the best strategy"
        case .external_api:
            return "High-quality using cloud AI (requires API key)"
        case .basic_extrusion:
            return "Fast, simple wall extrusion"
        case .multi_view_dnn:
            return "Deep learning reconstruction"
        }
    }
}

@MainActor
class NewJobViewModel: ObservableObject {
    @Published var selectedFile: InputFile?
    @Published var selectedStrategy: ReconstructionStrategyType = .auto
    @Published var selectedFormat: ExportFormat = .glb
    @Published var wallHeight: Double = 2.8
    @Published var isProcessing = false
    @Published var isLoadingPreview = false
    @Published var error: String?
    @Published var showingFilePicker = false
    @Published var jobCreated = false
    @Published var previewDownloadURL: String?

    private let apiClient = APIClient.shared

    var canStart: Bool {
        selectedFile != nil
    }

    func startJob() async {
        guard let file = selectedFile else { return }

        isProcessing = true
        error = nil

        do {
            _ = try await apiClient.startReconstruction(
                filename: file.name,
                strategy: selectedStrategy,
                wallHeight: wallHeight,
                exportFormat: selectedFormat
            )
            jobCreated = true
        } catch {
            self.error = error.localizedDescription
        }

        isProcessing = false
    }

    func getPreview() async {
        guard let file = selectedFile else { return }

        isLoadingPreview = true
        error = nil
        previewDownloadURL = nil

        do {
            let preview = try await apiClient.getPreview(
                filename: file.name,
                wallHeight: wallHeight
            )
            previewDownloadURL = preview.downloadUrl
        } catch {
            self.error = error.localizedDescription
        }

        isLoadingPreview = false
    }
}

#Preview {
    ReconstructTab()
        .environmentObject(JobListViewModel())
}
