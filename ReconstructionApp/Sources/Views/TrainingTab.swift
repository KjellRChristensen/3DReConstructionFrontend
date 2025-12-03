import SwiftUI

struct TrainingTab: View {
    @StateObject private var viewModel = TrainingPipelineViewModel()
    @State private var selectedSection: TrainingSection = .datasets

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
                        trainingView
                    case .results:
                        resultsView
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
            if viewModel.isLoading && viewModel.serverDatasets.isEmpty {
                loadingView("Loading datasets...")
            } else if viewModel.serverDatasets.isEmpty {
                emptyDatasetView
            } else {
                datasetsList
            }
        }
    }

    private var emptyDatasetView: some View {
        ContentUnavailableView {
            Label("No Datasets Available", systemImage: "externaldrive.badge.xmark")
        } description: {
            Text("Could not load datasets from the server.\nCheck that the backend is running and try again.")
        } actions: {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var datasetsList: some View {
        List {
            // Ready for Training
            let readyDatasets = viewModel.serverDatasets.filter { $0.status.isReady }
            if !readyDatasets.isEmpty {
                Section {
                    ForEach(readyDatasets) { dataset in
                        ServerDatasetRow(
                            dataset: dataset,
                            isSelected: viewModel.selectedDataset?.id == dataset.id,
                            onSelect: {
                                viewModel.selectDataset(dataset)
                            }
                        )
                    }
                } header: {
                    Label("Ready for Training", systemImage: "checkmark.circle.fill")
                }
            }

            // Processing
            let processingDatasets = viewModel.serverDatasets.filter { $0.status.isProcessing }
            if !processingDatasets.isEmpty {
                Section {
                    ForEach(processingDatasets) { dataset in
                        ServerDatasetRow(
                            dataset: dataset,
                            isSelected: false,
                            onSelect: nil
                        )
                    }
                } header: {
                    Label("Processing", systemImage: "gearshape.2")
                }
            }

            // Other statuses
            let otherDatasets = viewModel.serverDatasets.filter { !$0.status.isReady && !$0.status.isProcessing }
            if !otherDatasets.isEmpty {
                Section {
                    ForEach(otherDatasets) { dataset in
                        ServerDatasetRow(
                            dataset: dataset,
                            isSelected: false,
                            onSelect: nil
                        )
                    }
                } header: {
                    Text("Other")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Training View

    private var trainingView: some View {
        Group {
            if viewModel.selectedDataset == nil {
                noDatasetSelectedView
            } else {
                trainingConfigView
            }
        }
    }

    private var noDatasetSelectedView: some View {
        ContentUnavailableView {
            Label("Select a Dataset", systemImage: "doc.badge.plus")
        } description: {
            Text("Go to the Datasets tab and select a dataset that is ready for training.")
        } actions: {
            Button("Go to Datasets") {
                selectedSection = .datasets
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var trainingConfigView: some View {
        List {
            // Selected Dataset
            if let dataset = viewModel.selectedDataset {
                Section {
                    SelectedDatasetCard(dataset: dataset) {
                        viewModel.selectedDataset = nil
                    }
                } header: {
                    Text("Selected Dataset")
                }
            }

            // Model Selection
            Section {
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Loading models...")
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.availableModels.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("No models available", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Could not load models from the server.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            Task { await viewModel.loadAll() }
                        } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                        .font(.caption)
                    }
                } else if viewModel.compatibleModels.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("No compatible models", systemImage: "cpu.fill")
                            .foregroundStyle(.secondary)
                        Text("No models support this dataset's format.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(viewModel.compatibleModels) { model in
                        ModelSelectionRow(
                            model: model,
                            isSelected: viewModel.selectedModel?.id == model.id,
                            onSelect: {
                                viewModel.selectedModel = model
                            }
                        )
                    }
                }
            } header: {
                Text("Select Model")
            } footer: {
                if !viewModel.compatibleModels.isEmpty {
                    Text("Models compatible with the selected dataset's format.")
                }
            }

            // Training Parameters
            if viewModel.selectedModel != nil {
                Section {
                    Stepper("Epochs: \(viewModel.trainingConfig.epochs)", value: $viewModel.trainingConfig.epochs, in: 1...100)

                    Picker("Batch Size", selection: $viewModel.trainingConfig.batchSize) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("4").tag(4)
                        Text("8").tag(8)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Learning Rate")
                        Spacer()
                        Text(String(format: "%.0e", viewModel.trainingConfig.learningRate))
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: Binding(
                        get: { log10(viewModel.trainingConfig.learningRate) },
                        set: { viewModel.trainingConfig.learningRate = pow(10, $0) }
                    ), in: -6...(-3), step: 0.5)

                    Toggle("Use LoRA", isOn: $viewModel.trainingConfig.useLoRA)

                    if viewModel.trainingConfig.useLoRA {
                        Picker("LoRA Rank", selection: $viewModel.trainingConfig.loraRank) {
                            Text("8").tag(8)
                            Text("16").tag(16)
                            Text("32").tag(32)
                            Text("64").tag(64)
                            Text("128").tag(128)
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Text("Training Parameters")
                }

                // Actions
                Section {
                    // Test Run Button
                    Button {
                        Task { await viewModel.startTestRun() }
                    } label: {
                        HStack {
                            if viewModel.isRunningTest {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Label("Run Convergence Test", systemImage: "waveform.path.ecg")
                            Spacer()
                            Text("~5 min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(viewModel.isRunningTest || viewModel.isTraining)

                    // Start Training Button
                    Button {
                        Task { await viewModel.startTraining() }
                    } label: {
                        HStack {
                            if viewModel.isTraining {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Label("Start Training", systemImage: "play.circle.fill")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.isRunningTest || viewModel.isTraining)
                } footer: {
                    Text("Run a quick test first to verify convergence before starting full training.")
                }
            }

            // Active Training Job
            if let activeJob = viewModel.activeTrainingJob {
                Section {
                    ActiveTrainingJobView(
                        progress: activeJob,
                        onStop: {
                            Task { await viewModel.stopTraining() }
                        }
                    )
                } header: {
                    Label("Training in Progress", systemImage: "bolt.fill")
                }
            }

            // Test Results
            if let testResults = viewModel.testRunResults {
                Section {
                    TestResultsView(results: testResults)
                } header: {
                    Text("Test Results")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Results View

    private var resultsView: some View {
        Group {
            if viewModel.isLoading && viewModel.checkpoints.isEmpty {
                loadingView("Loading results...")
            } else if viewModel.checkpoints.isEmpty {
                emptyResultsView
            } else {
                resultsList
            }
        }
    }

    private var emptyResultsView: some View {
        ContentUnavailableView {
            Label("No Trained Models", systemImage: "cube.box")
        } description: {
            Text("No checkpoints available.\nCompleted training runs will appear here.")
        } actions: {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private var resultsList: some View {
        List {
            ForEach(viewModel.checkpoints) { checkpoint in
                CheckpointRow(
                    checkpoint: checkpoint,
                    onDelete: {
                        Task { await viewModel.deleteCheckpoint(checkpoint.name) }
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
}

// MARK: - Section Enum

enum TrainingSection: String, CaseIterable {
    case datasets
    case training
    case results

    var title: String {
        switch self {
        case .datasets: return "Datasets"
        case .training: return "Training"
        case .results: return "Results"
        }
    }
}

// MARK: - Server Dataset Row

struct ServerDatasetRow: View {
    let dataset: ServerDataset
    let isSelected: Bool
    let onSelect: (() -> Void)?

    var body: some View {
        Button {
            onSelect?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dataset.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("\(dataset.samples.formatted()) samples")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.title2)
                    } else {
                        StatusBadge(status: dataset.status)
                    }
                }

                // Progress bars for processing states
                if dataset.status.isProcessing {
                    if let progress = dataset.renderProgress, dataset.status == .rendering {
                        ProgressView(value: progress)
                        Text("Rendering: \(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let progress = dataset.conversionProgress, dataset.status == .converting {
                        ProgressView(value: progress)
                        Text("Converting: \(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Info row
                HStack(spacing: 12) {
                    Label(dataset.format, systemImage: "doc.text")
                    if let size = dataset.size {
                        Label(size, systemImage: "externaldrive")
                    }
                    if !dataset.compatibleModels.isEmpty {
                        Label("\(dataset.compatibleModels.count) models", systemImage: "cpu")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(onSelect == nil)
    }
}

struct StatusBadge: View {
    let status: DatasetStatus

    var body: some View {
        Text(status.displayName)
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
        case .ready: return .green
        case .extracting, .rendering, .converting, .validating: return .blue
        case .extracted, .rendered, .converted: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Selected Dataset Card

struct SelectedDatasetCard: View {
    let dataset: ServerDataset
    let onDeselect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dataset.name)
                        .font(.headline)
                    Text("\(dataset.samples.formatted()) samples | \(dataset.format)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    onDeselect()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if !dataset.compatibleModels.isEmpty {
                Text("Compatible with: \(dataset.compatibleModels.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Model Selection Row

struct ModelSelectionRow: View {
    let model: TrainingModel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if model.recommended == true {
                            Text("Recommended")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.2))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }

                    Text(model.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        Label(model.parameters, systemImage: "slider.horizontal.3")
                        Label(model.vram, systemImage: "memorychip")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title2)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Active Training Job View

struct ActiveTrainingJobView: View {
    let progress: TrainingProgress
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Progress bar
            VStack(spacing: 4) {
                ProgressView(value: progress.progress)

                HStack {
                    Text("Epoch \(progress.currentEpoch)/\(progress.totalEpochs)")
                    Spacer()
                    Text("\(Int(progress.progress * 100))%")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Metrics grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                MetricCell(label: "Loss", value: String(format: "%.4f", progress.loss))
                if let valLoss = progress.validationLoss {
                    MetricCell(label: "Val Loss", value: String(format: "%.4f", valLoss))
                }
                if let accuracy = progress.accuracy {
                    MetricCell(label: "Accuracy", value: String(format: "%.1f%%", accuracy * 100))
                }
                MetricCell(label: "Step", value: "\(progress.currentStep)/\(progress.totalSteps)")
                MetricCell(label: "LR", value: String(format: "%.2e", progress.learningRate))
                if let eta = progress.etaSeconds {
                    MetricCell(label: "ETA", value: formatTime(Double(eta)))
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // GPU info
            HStack {
                if let gpu = progress.gpuMemory {
                    Label(gpu, systemImage: "memorychip")
                }
                if let throughput = progress.throughput {
                    Label(throughput, systemImage: "speedometer")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Stop button
            Button(role: .destructive) {
                onStop()
            } label: {
                Label("Stop Training", systemImage: "stop.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
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

// MARK: - Test Results View

struct TestResultsView: View {
    let results: TestRunResults

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: results.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(results.success ? .green : .red)
                    .font(.title2)

                Text(results.success ? "Convergence Test Passed" : "Test Failed")
                    .font(.headline)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                MetricCell(label: "Initial Loss", value: String(format: "%.4f", results.initialLoss))
                MetricCell(label: "Final Loss", value: String(format: "%.4f", results.finalLoss))
                MetricCell(label: "Reduction", value: String(format: "%.1f%%", results.lossReduction * 100))
                if let rate = results.convergenceRate {
                    MetricCell(label: "Conv. Rate", value: String(format: "%.2f", rate))
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if let recommendation = results.recommendation {
                Text(recommendation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Checkpoint Row

struct CheckpointRow: View {
    let checkpoint: CheckpointInfo
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(checkpoint.name)
                        .font(.headline)
                    Text(checkpoint.baseModel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let size = checkpoint.size {
                    Text(size)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }

                if checkpoint.hasLoraAdapter {
                    Text("LoRA")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.2))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }

            HStack {
                Label(checkpoint.created, systemImage: "calendar")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let metrics = checkpoint.metrics {
                HStack(spacing: 16) {
                    if let loss = metrics.loss {
                        Label(String(format: "Loss: %.4f", loss), systemImage: "chart.line.downtrend.xyaxis")
                    }
                    if let accuracy = metrics.accuracy {
                        Label(String(format: "Acc: %.1f%%", accuracy * 100), systemImage: "checkmark.circle")
                    }
                }
                .font(.caption)
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Metric Cell

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

// MARK: - Training Config

struct TrainingUIConfig {
    var epochs: Int = 3
    var batchSize: Int = 2
    var learningRate: Double = 0.0001
    var useLoRA: Bool = true
    var loraRank: Int = 64
}

// MARK: - Timeout Error

struct TimeoutError: Error {
    var localizedDescription: String { "Request timed out" }
}

// MARK: - ViewModel

@MainActor
class TrainingPipelineViewModel: ObservableObject {
    // Data
    @Published var serverDatasets: [ServerDataset] = []
    @Published var availableModels: [TrainingModel] = []
    @Published var checkpoints: [CheckpointInfo] = []

    // Selection
    @Published var selectedDataset: ServerDataset?
    @Published var selectedModel: TrainingModel?

    // Configuration
    @Published var trainingConfig = TrainingUIConfig()

    // State
    @Published var isLoading = false
    @Published var isRunningTest = false
    @Published var isTraining = false
    @Published var error: String?

    // Progress
    @Published var activeTrainingJob: TrainingProgress?
    @Published var testRunResults: TestRunResults?

    private let apiClient = APIClient.shared
    private var pollingTask: Task<Void, Never>?
    private var activeJobId: String?

    // Computed
    var compatibleModels: [TrainingModel] {
        guard let dataset = selectedDataset else { return [] }
        return availableModels.filter { model in
            dataset.compatibleModels.contains(model.id) ||
            dataset.compatibleModels.contains(model.inputFormat)
        }
    }

    func loadAll() async {
        isLoading = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadServerDatasets() }
            group.addTask { await self.loadModels() }
            group.addTask { await self.loadCheckpoints() }
        }
        isLoading = false
    }

    func refresh() async {
        await loadAll()
    }

    func selectDataset(_ dataset: ServerDataset) {
        selectedDataset = dataset
        selectedModel = nil
        testRunResults = nil

        // Auto-select recommended model if available
        if let recommended = compatibleModels.first(where: { $0.recommended == true }) {
            selectedModel = recommended
        } else if let first = compatibleModels.first {
            selectedModel = first
        }
    }

    private func loadServerDatasets() async {
        do {
            let response = try await withTimeout(seconds: 3) {
                try await self.apiClient.listServerDatasets()
            }
            serverDatasets = response.datasets
        } catch {
            // No data available - keep empty
            serverDatasets = []
        }
    }

    private func loadModels() async {
        do {
            let response = try await withTimeout(seconds: 3) {
                try await self.apiClient.listTrainingModels()
            }
            availableModels = response.models
        } catch {
            // No data available - keep empty
            availableModels = []
        }
    }

    private func loadCheckpoints() async {
        do {
            let response = try await withTimeout(seconds: 3) {
                try await self.apiClient.listCheckpoints()
            }
            checkpoints = response.checkpoints
        } catch {
            // No data available - keep empty
            checkpoints = []
        }
    }

    /// Execute an async operation with a timeout
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    func startTestRun() async {
        guard let dataset = selectedDataset, let model = selectedModel else { return }

        isRunningTest = true
        testRunResults = nil

        do {
            let request = TestRunRequest(
                datasetName: dataset.name,
                modelId: model.id,
                epochs: 5,
                batchSize: trainingConfig.batchSize
            )
            let response = try await withTimeout(seconds: 10) {
                try await self.apiClient.startTestRun(request: request)
            }
            activeJobId = response.jobId

            // Poll for results
            await pollForTestResults(jobId: response.jobId)
        } catch {
            self.error = error.localizedDescription
            isRunningTest = false
        }
    }

    private func pollForTestResults(jobId: String) async {
        var pollCount = 0
        let maxPolls = 100 // Max 5 minutes (100 * 3 seconds)

        while isRunningTest && pollCount < maxPolls {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            pollCount += 1

            do {
                let results = try await withTimeout(seconds: 5) {
                    try await self.apiClient.getTestRunResults(jobId: jobId)
                }
                testRunResults = results
                isRunningTest = false
                return
            } catch {
                // Still running or timeout, continue polling
            }
        }

        // Timeout after max polls
        if isRunningTest {
            isRunningTest = false
            self.error = "Test run polling timed out"
        }
    }

    func startTraining() async {
        guard let dataset = selectedDataset, let model = selectedModel else { return }

        isTraining = true

        do {
            let request = TrainingStartRequest(
                datasetName: dataset.name,
                modelId: model.id,
                epochs: trainingConfig.epochs,
                batchSize: trainingConfig.batchSize,
                learningRate: trainingConfig.learningRate,
                loraRank: trainingConfig.useLoRA ? trainingConfig.loraRank : nil,
                runName: nil
            )
            let response = try await withTimeout(seconds: 10) {
                try await self.apiClient.startTrainingPipeline(request: request)
            }
            activeJobId = response.jobId

            // Start polling for progress
            startProgressPolling(jobId: response.jobId)
        } catch {
            self.error = error.localizedDescription
            isTraining = false
        }
    }

    func stopTraining() async {
        guard let jobId = activeJobId else { return }

        do {
            _ = try await withTimeout(seconds: 5) {
                try await self.apiClient.stopTraining(jobId: jobId)
            }
            pollingTask?.cancel()
            pollingTask = nil
            isTraining = false
            activeTrainingJob = nil
            activeJobId = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func startProgressPolling(jobId: String) {
        pollingTask?.cancel()
        pollingTask = Task {
            var consecutiveFailures = 0
            let maxConsecutiveFailures = 10 // Stop after 10 consecutive failures

            while !Task.isCancelled && isTraining {
                do {
                    let progress = try await withTimeout(seconds: 5) {
                        try await self.apiClient.getTrainingProgress(jobId: jobId)
                    }
                    activeTrainingJob = progress
                    consecutiveFailures = 0 // Reset on success

                    if progress.status == "completed" || progress.status == "failed" {
                        isTraining = false
                        if progress.status == "completed" {
                            await loadCheckpoints()
                        }
                        break
                    }
                } catch {
                    consecutiveFailures += 1
                    if consecutiveFailures >= maxConsecutiveFailures {
                        self.error = "Lost connection to training server"
                        isTraining = false
                        break
                    }
                    // Continue polling on transient errors
                }

                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
            pollingTask = nil
        }
    }

    func deleteCheckpoint(_ name: String) async {
        do {
            _ = try await withTimeout(seconds: 5) {
                try await self.apiClient.deleteCheckpoint(name: name)
            }
            await loadCheckpoints()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    TrainingTab()
}
