import SwiftUI

struct TrainingTab: View {
    @StateObject private var viewModel = TrainingManagementViewModel()
    @State private var selectedSection: TrainingSection = .datasets
    @State private var showingTrainingConfig = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section Picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(TrainingSection.allCases, id: \.self) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                Group {
                    switch selectedSection {
                    case .datasets:
                        datasetsView
                    case .training:
                        trainingJobsView
                    case .models:
                        trainedModelsView
                    }
                }
            }
            .navigationTitle("Training")
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
                await viewModel.loadAll()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showingTrainingConfig) {
                TrainingConfigSheet(viewModel: viewModel)
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    // MARK: - Datasets View

    private var datasetsView: some View {
        Group {
            if viewModel.isLoading && viewModel.datasets.isEmpty {
                loadingView("Loading datasets...")
            } else if viewModel.datasets.isEmpty {
                emptyView("No Datasets", "Available training datasets will appear here.")
            } else {
                datasetsList
            }
        }
    }

    private var datasetsList: some View {
        List {
            // Recommended Section
            let recommended = viewModel.datasets.filter { $0.recommended }
            if !recommended.isEmpty {
                Section {
                    ForEach(recommended) { dataset in
                        DatasetRow(
                            dataset: dataset,
                            isDownloading: viewModel.downloadingDatasets.contains(dataset.id),
                            onDownload: { limit in
                                Task { await viewModel.downloadDataset(dataset.id, sampleLimit: limit) }
                            }
                        )
                    }
                } header: {
                    Label("Recommended", systemImage: "star.fill")
                }
            }

            // Other Datasets
            let others = viewModel.datasets.filter { !$0.recommended }
            if !others.isEmpty {
                Section {
                    ForEach(others) { dataset in
                        DatasetRow(
                            dataset: dataset,
                            isDownloading: viewModel.downloadingDatasets.contains(dataset.id),
                            onDownload: { limit in
                                Task { await viewModel.downloadDataset(dataset.id, sampleLimit: limit) }
                            }
                        )
                    }
                } header: {
                    Text("Alternative Datasets")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Training Jobs View

    private var trainingJobsView: some View {
        Group {
            if viewModel.isLoading && viewModel.trainingJobs.isEmpty {
                loadingView("Loading training jobs...")
            } else {
                trainingJobsList
            }
        }
    }

    private var trainingJobsList: some View {
        List {
            // Start Training Button
            Section {
                Button {
                    showingTrainingConfig = true
                } label: {
                    Label("Start New Training", systemImage: "play.circle.fill")
                        .font(.headline)
                }
                .disabled(viewModel.datasets.filter { $0.downloaded }.isEmpty)
            }

            // Active Jobs
            let activeJobs = viewModel.trainingJobs.filter { $0.status == "running" || $0.status == "pending" }
            if !activeJobs.isEmpty {
                Section {
                    ForEach(activeJobs) { job in
                        TrainingJobRow(
                            job: job,
                            onStop: {
                                Task { await viewModel.stopTraining(job.id) }
                            }
                        )
                    }
                } header: {
                    Label("Active", systemImage: "bolt.fill")
                }
            }

            // Completed Jobs
            let completedJobs = viewModel.trainingJobs.filter { $0.status == "completed" }
            if !completedJobs.isEmpty {
                Section {
                    ForEach(completedJobs) { job in
                        TrainingJobRow(job: job, onStop: nil)
                    }
                } header: {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                }
            }

            // Failed Jobs
            let failedJobs = viewModel.trainingJobs.filter { $0.status == "failed" }
            if !failedJobs.isEmpty {
                Section {
                    ForEach(failedJobs) { job in
                        TrainingJobRow(job: job, onStop: nil)
                    }
                } header: {
                    Label("Failed", systemImage: "xmark.circle.fill")
                }
            }

            if viewModel.trainingJobs.isEmpty {
                Section {
                    Text("No training jobs yet. Start a new training to see progress here.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Trained Models View

    private var trainedModelsView: some View {
        Group {
            if viewModel.isLoading && viewModel.trainedModels.isEmpty {
                loadingView("Loading models...")
            } else if viewModel.trainedModels.isEmpty {
                emptyView("No Trained Models", "Completed training jobs will produce models here.")
            } else {
                trainedModelsList
            }
        }
    }

    private var trainedModelsList: some View {
        List {
            ForEach(viewModel.trainedModels) { model in
                TrainedModelRow(
                    model: model,
                    onDelete: {
                        Task { await viewModel.deleteModel(model.id) }
                    }
                )
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Helper Views

    private func loadingView(_ message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyView(_ title: String, _ description: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: "tray")
        } description: {
            Text(description)
        }
    }
}

// MARK: - Section Enum

enum TrainingSection: String, CaseIterable {
    case datasets
    case training
    case models

    var title: String {
        switch self {
        case .datasets: return "Datasets"
        case .training: return "Training"
        case .models: return "Models"
        }
    }
}

// MARK: - Dataset Row

struct DatasetRow: View {
    let dataset: TrainingDataset
    let isDownloading: Bool
    let onDownload: (Int?) -> Void

    @State private var showingDownloadOptions = false
    @State private var sampleLimit: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(dataset.name)
                            .font(.headline)

                        if dataset.recommended {
                            Text("Recommended")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.2))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }

                    Text(dataset.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if dataset.downloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                } else if isDownloading {
                    ProgressView()
                }
            }

            // Info Grid
            HStack(spacing: 16) {
                InfoBadge(icon: "doc.fill", text: "\(dataset.sampleCount.formatted()) samples")
                InfoBadge(icon: "externaldrive", text: dataset.size)
                InfoBadge(icon: "doc.text", text: dataset.format)
            }

            // Source
            if let url = URL(string: dataset.source) {
                Link(destination: url) {
                    Label(url.host ?? "Source", systemImage: "link")
                        .font(.caption)
                }
            }

            // Download Actions
            if !dataset.downloaded && !isDownloading {
                Divider()

                VStack(spacing: 8) {
                    Button {
                        onDownload(nil)
                    } label: {
                        Label("Download Full Dataset", systemImage: "arrow.down.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showingDownloadOptions = true
                    } label: {
                        Label("Download Subset...", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Download Progress
            if isDownloading, let progress = dataset.downloadProgress {
                VStack(spacing: 4) {
                    ProgressView(value: progress)
                    Text("\(Int(progress * 100))% downloaded")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .alert("Download Subset", isPresented: $showingDownloadOptions) {
            TextField("Sample limit (e.g., 10000)", text: $sampleLimit)
                .keyboardType(.numberPad)
            Button("Download") {
                if let limit = Int(sampleLimit), limit > 0 {
                    onDownload(limit)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter the number of samples to download for quick testing.")
        }
    }
}

struct InfoBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Training Job Row

struct TrainingJobRow: View {
    let job: TrainingJob
    let onStop: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Training on \(job.datasetId)")
                        .font(.headline)
                    Text("Base: \(job.baseModel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusBadge(status: job.status)
            }

            // Progress
            if job.status == "running" {
                VStack(spacing: 4) {
                    ProgressView(value: job.progress)

                    HStack {
                        Text("Epoch \(job.currentEpoch)/\(job.totalEpochs)")
                        Spacer()
                        Text("\(Int(job.progress * 100))%")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            // Metrics
            if let metrics = job.metrics {
                MetricsGrid(metrics: metrics)
            }

            // Error
            if let error = job.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Actions
            if job.status == "running", let onStop = onStop {
                Button(role: .destructive) {
                    onStop()
                } label: {
                    Label("Stop Training", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 8)
    }
}

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case "running": return .blue
        case "pending": return .orange
        case "completed": return .green
        case "failed": return .red
        default: return .gray
        }
    }
}

struct MetricsGrid: View {
    let metrics: TrainingMetrics

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            MetricCell(label: "Loss", value: String(format: "%.4f", metrics.loss))
            if let valLoss = metrics.validationLoss {
                MetricCell(label: "Val Loss", value: String(format: "%.4f", valLoss))
            }
            if let accuracy = metrics.accuracy {
                MetricCell(label: "Accuracy", value: String(format: "%.1f%%", accuracy * 100))
            }
            MetricCell(label: "Step", value: "\(metrics.step)/\(metrics.totalSteps)")
            MetricCell(label: "LR", value: String(format: "%.2e", metrics.learningRate))
            if let remaining = metrics.estimatedRemaining {
                MetricCell(label: "ETA", value: formatTime(remaining))
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatTime(_ seconds: Double) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            return String(format: "%.1fh", seconds / 3600)
        }
    }
}

struct MetricCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Trained Model Row

struct TrainedModelRow: View {
    let model: TrainedModel
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.headline)
                    Text("Based on \(model.baseModel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(model.size)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }

            HStack {
                Label(model.datasetId, systemImage: "doc.fill")
                Spacer()
                Text(model.createdAt)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let metrics = model.metrics {
                HStack(spacing: 16) {
                    Label(String(format: "Loss: %.4f", metrics.loss), systemImage: "chart.line.downtrend.xyaxis")
                    if let accuracy = metrics.accuracy {
                        Label(String(format: "Acc: %.1f%%", accuracy * 100), systemImage: "checkmark.circle")
                    }
                }
                .font(.caption)
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Model", systemImage: "trash")
            }
            .font(.caption)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Training Config Sheet

struct TrainingConfigSheet: View {
    @ObservedObject var viewModel: TrainingManagementViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var config = TrainingConfig.default
    @State private var useSampleLimit = false
    @State private var sampleLimitText = "10000"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Dataset", selection: $config.datasetId) {
                        ForEach(viewModel.datasets.filter { $0.downloaded }) { dataset in
                            Text(dataset.name).tag(dataset.id)
                        }
                    }

                    Picker("Base Model", selection: $config.baseModel) {
                        Text("OpenECAD 0.89B").tag("openecad-0.89b")
                        Text("InternVL2 2B").tag("internvl2-2b")
                    }
                } header: {
                    Text("Model & Data")
                }

                Section {
                    Stepper("Epochs: \(config.epochs)", value: $config.epochs, in: 1...20)

                    Picker("Batch Size", selection: $config.batchSize) {
                        Text("2").tag(2)
                        Text("4").tag(4)
                        Text("8").tag(8)
                        Text("16").tag(16)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Learning Rate")
                        Spacer()
                        Text(String(format: "%.0e", config.learningRate))
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: Binding(
                        get: { log10(config.learningRate) },
                        set: { config.learningRate = pow(10, $0) }
                    ), in: -6...(-3), step: 0.5)
                } header: {
                    Text("Training Parameters")
                }

                Section {
                    Toggle("Use LoRA", isOn: $config.loraEnabled)

                    if config.loraEnabled {
                        Picker("LoRA Rank", selection: $config.loraRank) {
                            Text("8").tag(8)
                            Text("16").tag(16)
                            Text("32").tag(32)
                            Text("64").tag(64)
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Text("Fine-tuning Method")
                } footer: {
                    Text("LoRA uses less memory and trains faster while maintaining quality.")
                }

                Section {
                    Toggle("Limit Samples", isOn: $useSampleLimit)

                    if useSampleLimit {
                        TextField("Sample Limit", text: $sampleLimitText)
                            .keyboardType(.numberPad)
                    }

                    HStack {
                        Text("Validation Split")
                        Spacer()
                        Text("\(Int(config.validationSplit * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $config.validationSplit, in: 0.05...0.3, step: 0.05)
                } header: {
                    Text("Data Options")
                }

                Section {
                    Button {
                        Task {
                            if useSampleLimit, let limit = Int(sampleLimitText) {
                                config.sampleLimit = limit
                            }
                            await viewModel.startTraining(config)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isStartingTraining {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text("Start Training")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isStartingTraining)
                }
            }
            .navigationTitle("Training Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class TrainingManagementViewModel: ObservableObject {
    @Published var datasets: [TrainingDataset] = []
    @Published var trainingJobs: [TrainingJob] = []
    @Published var trainedModels: [TrainedModel] = []

    @Published var isLoading = false
    @Published var isStartingTraining = false
    @Published var downloadingDatasets: Set<String> = []
    @Published var error: String?

    private let apiClient = APIClient.shared
    private var pollingTask: Task<Void, Never>?

    func loadAll() async {
        isLoading = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadDatasets() }
            group.addTask { await self.loadTrainingJobs() }
            group.addTask { await self.loadTrainedModels() }
        }
        isLoading = false

        // Start polling for active jobs
        startPollingIfNeeded()
    }

    func refresh() async {
        await loadAll()
    }

    private func loadDatasets() async {
        do {
            let response = try await apiClient.listDatasets()
            datasets = response.datasets
        } catch {
            // Use mock data if API not available
            datasets = Self.mockDatasets
        }
    }

    private func loadTrainingJobs() async {
        do {
            let response = try await apiClient.listTrainingJobs()
            trainingJobs = response.jobs
        } catch {
            // Silently fail
        }
    }

    private func loadTrainedModels() async {
        do {
            let response = try await apiClient.listTrainedModels()
            trainedModels = response.models
        } catch {
            // Silently fail
        }
    }

    func downloadDataset(_ datasetId: String, sampleLimit: Int? = nil) async {
        downloadingDatasets.insert(datasetId)

        do {
            _ = try await apiClient.downloadDataset(datasetId: datasetId, sampleLimit: sampleLimit)
            await loadDatasets()
        } catch {
            self.error = error.localizedDescription
        }

        downloadingDatasets.remove(datasetId)
    }

    func startTraining(_ config: TrainingConfig) async {
        isStartingTraining = true

        do {
            _ = try await apiClient.startTraining(config: config)
            await loadTrainingJobs()
            startPollingIfNeeded()
        } catch {
            self.error = error.localizedDescription
        }

        isStartingTraining = false
    }

    func stopTraining(_ jobId: String) async {
        do {
            _ = try await apiClient.stopTraining(jobId: jobId)
            await loadTrainingJobs()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteModel(_ modelId: String) async {
        do {
            _ = try await apiClient.deleteTrainedModel(modelId: modelId)
            await loadTrainedModels()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func startPollingIfNeeded() {
        let hasActiveJobs = trainingJobs.contains { $0.status == "running" || $0.status == "pending" }

        if hasActiveJobs && pollingTask == nil {
            pollingTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    await loadTrainingJobs()

                    let stillActive = trainingJobs.contains { $0.status == "running" || $0.status == "pending" }
                    if !stillActive {
                        break
                    }
                }
                pollingTask = nil
            }
        }
    }

    // MARK: - Mock Data

    static let mockDatasets: [TrainingDataset] = [
        TrainingDataset(
            id: "openecad",
            name: "OpenECAD Dataset",
            description: "918,719 image-code pairs in TinyLLaVA conversation format. Ready for direct training.",
            source: "https://huggingface.co/datasets/Yuan-Che/OpenECAD-Dataset",
            size: "1.73 GB",
            sampleCount: 918719,
            format: "Parquet",
            license: "MIT",
            recommended: true,
            downloaded: false,
            downloadProgress: nil,
            localPath: nil
        ),
        TrainingDataset(
            id: "deepcad",
            name: "DeepCAD",
            description: "178,238 CAD models with JSON construction sequences from Onshape.",
            source: "https://github.com/ChrisWu1997/DeepCAD",
            size: "2.1 GB",
            sampleCount: 178238,
            format: "JSON",
            license: "MIT",
            recommended: false,
            downloaded: false,
            downloadProgress: nil,
            localPath: nil
        ),
        TrainingDataset(
            id: "text2cad",
            name: "Text2CAD",
            description: "Multi-level text-to-CAD with 4 difficulty levels from Abstract to Expert.",
            source: "https://huggingface.co/datasets/SadilKhan/Text2CAD",
            size: "1.3 GB",
            sampleCount: 180000,
            format: "CSV/JSON",
            license: "CC BY-NC-SA 4.0",
            recommended: false,
            downloaded: false,
            downloadProgress: nil,
            localPath: nil
        ),
        TrainingDataset(
            id: "fusion360",
            name: "Fusion 360 Gallery",
            description: "8,625 real-world human-designed sequences from Autodesk.",
            source: "https://github.com/AutodeskAILab/Fusion360GalleryDataset",
            size: "2.0 GB",
            sampleCount: 8625,
            format: "JSON + STEP",
            license: "Apache 2.0",
            recommended: false,
            downloaded: false,
            downloadProgress: nil,
            localPath: nil
        )
    ]
}

#Preview {
    TrainingTab()
}
