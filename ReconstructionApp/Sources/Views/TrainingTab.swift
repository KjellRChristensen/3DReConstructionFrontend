import SwiftUI

// MARK: - Debug Logging with Colors

private enum LogColor: String {
    case reset = "\u{001B}[0m"
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case magenta = "\u{001B}[35m"
    case cyan = "\u{001B}[36m"
    case white = "\u{001B}[37m"
    case boldRed = "\u{001B}[1;31m"
    case boldGreen = "\u{001B}[1;32m"
    case boldYellow = "\u{001B}[1;33m"
    case boldBlue = "\u{001B}[1;34m"
    case boldCyan = "\u{001B}[1;36m"
}

private func logTraining(_ message: String, color: LogColor = .cyan) {
    print("\(color.rawValue)[Training]\(LogColor.reset.rawValue) \(message)")
}

private func logSuccess(_ message: String) {
    print("\(LogColor.boldGreen.rawValue)[Training] ✓\(LogColor.reset.rawValue) \(LogColor.green.rawValue)\(message)\(LogColor.reset.rawValue)")
}

private func logError(_ message: String) {
    print("\(LogColor.boldRed.rawValue)[Training] ✗\(LogColor.reset.rawValue) \(LogColor.red.rawValue)\(message)\(LogColor.reset.rawValue)")
}

private func logWarning(_ message: String) {
    print("\(LogColor.boldYellow.rawValue)[Training] ⚠\(LogColor.reset.rawValue) \(LogColor.yellow.rawValue)\(message)\(LogColor.reset.rawValue)")
}

private func logInfo(_ message: String) {
    print("\(LogColor.blue.rawValue)[Training]\(LogColor.reset.rawValue) \(message)")
}

private func logData(_ label: String, _ value: String) {
    print("\(LogColor.magenta.rawValue)[Training]\(LogColor.reset.rawValue)   \(label): \(LogColor.white.rawValue)\(value)\(LogColor.reset.rawValue)")
}

private func logHeader(_ message: String) {
    print("\(LogColor.boldCyan.rawValue)[Training] ========== \(message) ==========\(LogColor.reset.rawValue)")
}

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
            let readyDatasets = viewModel.serverDatasets.filter { $0.isReady }
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
            let processingDatasets = viewModel.serverDatasets.filter { $0.status == "processing" }
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
            let otherDatasets = viewModel.serverDatasets.filter { !$0.isReady && $0.status != "processing" }
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

                    HStack {
                        Text("Batch Size")
                        Spacer()
                        Text("\(viewModel.trainingConfig.batchSize)")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: Binding(
                        get: { Double(viewModel.trainingConfig.batchSize) },
                        set: { viewModel.trainingConfig.batchSize = Int($0) }
                    ), in: 1...64, step: 1)

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

                    Toggle("Use MPS (Metal)", isOn: $viewModel.trainingConfig.useMps)
                } header: {
                    Text("Training Parameters")
                } footer: {
                    Text(viewModel.trainingConfig.useMps ? "Device: mps" : "Device: cpu (for debugging)")
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
                            if viewModel.isTraining && !(viewModel.activeTrainingJob?.isLoading ?? false) {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Label("Start Training", systemImage: "play.circle.fill")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.isRunningTest || viewModel.isTraining)

                    // Loading Model indicator (shown when model is loading)
                    if let activeJob = viewModel.activeTrainingJob, activeJob.isLoading {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Label("Loading Model", systemImage: "cpu")
                                .foregroundStyle(.orange)
                            Spacer()
                            Text(activeJob.currentStage ?? "Please wait...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Run a quick test first to verify convergence before starting full training.")
                }
            }

            // Active Training Job
            if let activeJob = viewModel.activeTrainingJob {
                Section {
                    ActiveTrainingJobView(
                        progress: activeJob,
                        downloadProgress: viewModel.downloadProgress,
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

                        Text("\(dataset.trainSamples.formatted()) train / \(dataset.valSamples.formatted()) val")
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

                // Info row
                HStack(spacing: 12) {
                    Label("\(dataset.models.formatted()) models", systemImage: "cube.box")
                    Label("\(dataset.images.formatted()) images", systemImage: "photo")
                    if let size = dataset.size {
                        Label(size, systemImage: "externaldrive")
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
    let status: String

    var body: some View {
        Text(displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }

    private var displayName: String {
        switch status {
        case "ready": return "Ready"
        case "processing": return "Processing..."
        case "error": return "Error"
        default: return status.capitalized
        }
    }

    private var backgroundColor: Color {
        switch status {
        case "ready": return .green
        case "processing": return .blue
        case "error": return .red
        default: return .orange
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
                    Text("\(dataset.trainSamples.formatted()) train / \(dataset.valSamples.formatted()) val samples")
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

            HStack(spacing: 12) {
                Label("\(dataset.models.formatted()) models", systemImage: "cube.box")
                Label("\(dataset.images.formatted()) images", systemImage: "photo")
                if let size = dataset.size {
                    Label(size, systemImage: "externaldrive")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
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
                        Text(model.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if model.recommendedForCad {
                            Text("Recommended")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.2))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }

                        if model.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.blue)
                                .font(.caption)
                        }
                    }

                    Text(model.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        Label(model.parameters, systemImage: "slider.horizontal.3")
                        Label("\(model.minVramGb)GB VRAM", systemImage: "memorychip")
                        if model.supportsLora {
                            Label("LoRA", systemImage: "sparkles")
                        }
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

// MARK: - Download Progress View

struct DownloadProgressView: View {
    let download: DownloadProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
                Text("Downloading Model")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.1f%%", download.progressPercentage ?? 0))
                    .font(.headline)
                    .foregroundStyle(.blue)
            }

            ProgressView(value: (download.progressPercentage ?? 0) / 100)
                .tint(.blue)

            HStack {
                if let downloadedGb = download.downloadedGb, let totalGb = download.totalSizeGb {
                    Label(String(format: "%.1f / %.1f GB", downloadedGb, totalGb), systemImage: "internaldrive")
                }
                Spacer()
                if let speed = download.downloadSpeedMbps {
                    Label(String(format: "%.1f MB/s", speed), systemImage: "speedometer")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                if let filesComplete = download.filesComplete, let filesTotal = download.filesTotal {
                    Label("\(filesComplete)/\(filesTotal) files", systemImage: "doc.on.doc")
                }
                Spacer()
                if let eta = download.etaHuman {
                    Label("ETA: \(eta)", systemImage: "clock")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Model Loading View

struct ModelLoadingView: View {
    let stage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Loading Model")
                        .font(.headline)

                    Text(stage ?? "Initializing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text("This may take a few minutes for large models. The model weights are being loaded into memory.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Active Training Job View

struct ActiveTrainingJobView: View {
    let progress: TrainingProgress
    let downloadProgress: DownloadProgress?
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show download progress if downloading
            if let download = downloadProgress, download.isDownloading {
                DownloadProgressView(download: download)
            }

            // Show model loading state
            if progress.isLoading {
                ModelLoadingView(stage: progress.currentStage)
            } else {
                // Progress bar (only when actually training)
                VStack(spacing: 4) {
                    ProgressView(value: progress.progressValue)

                    HStack {
                        if let stage = progress.currentStage {
                            Text(stage)
                        } else {
                            Text("Epoch \(progress.currentEpoch)")
                        }
                        Spacer()
                        Text("\(Int(progress.progressValue * 100))%")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                // Metrics grid (only show when training, not loading)
                if downloadProgress == nil || downloadProgress?.isDownloading == false {
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
                }
            }

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
    var batchSize: Int = 32
    var learningRate: Double = 0.0001
    var useLoRA: Bool = true
    var loraRank: Int = 64
    var useMps: Bool = true

    /// Returns the device string for the API ("mps" or "cpu")
    var device: String {
        useMps ? "mps" : "cpu"
    }
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
    @Published var downloadProgress: DownloadProgress?

    private let apiClient = APIClient.shared
    private var pollingTask: Task<Void, Never>?
    private var downloadPollingTask: Task<Void, Never>?
    private var activeJobId: String?

    // Computed - all models are compatible with TinyLLaVA format datasets
    var compatibleModels: [TrainingModel] {
        guard selectedDataset != nil else { return [] }
        // All available models support our dataset format (TinyLLaVA JSON)
        return availableModels.filter { $0.available }
    }

    func loadAll() async {
        logInfo("loadAll() - Starting data load...")
        isLoading = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadServerDatasets() }
            group.addTask { await self.loadModels() }
            group.addTask { await self.loadCheckpoints() }
        }
        isLoading = false
        logSuccess("loadAll() - Completed. Datasets: \(serverDatasets.count), Models: \(availableModels.count), Checkpoints: \(checkpoints.count)")
    }

    func refresh() async {
        logInfo("refresh() - Refreshing all data...")
        await loadAll()
    }

    func selectDataset(_ dataset: ServerDataset) {
        logTraining("selectDataset() - Selected dataset: id=\(dataset.id), name=\(dataset.name)")
        selectedDataset = dataset
        selectedModel = nil
        testRunResults = nil

        // Auto-select recommended model if available
        if let recommended = compatibleModels.first(where: { $0.recommendedForCad }) {
            selectedModel = recommended
            logSuccess("Auto-selected recommended model: id=\(recommended.id), name=\(recommended.name)")
        } else if let first = compatibleModels.first {
            selectedModel = first
            logInfo("Auto-selected first model: id=\(first.id), name=\(first.name)")
        } else {
            logWarning("No compatible models available")
        }
    }

    private func loadServerDatasets() async {
        logInfo("GET /training/datasets")
        do {
            let response = try await withTimeout(seconds: 3) {
                try await self.apiClient.listServerDatasets()
            }
            serverDatasets = response.datasets
            logSuccess("Loaded \(response.datasets.count) datasets")
            for ds in response.datasets {
                logData("Dataset", "id=\(ds.id), name=\(ds.name), status=\(ds.status), samples=\(ds.totalSamples)")
            }
        } catch {
            logError("loadServerDatasets() failed: \(error.localizedDescription)")
            serverDatasets = []
        }
    }

    private func loadModels() async {
        logInfo("GET /training/models/available")
        do {
            let response = try await withTimeout(seconds: 3) {
                try await self.apiClient.listTrainingModels()
            }
            availableModels = response.models
            logSuccess("Loaded \(response.models.count) models")
            for model in response.models {
                logData("Model", "id=\(model.id), name=\(model.name), available=\(model.available), recommended=\(model.recommendedForCad)")
            }
        } catch {
            logError("loadModels() failed: \(error.localizedDescription)")
            availableModels = []
        }
    }

    private func loadCheckpoints() async {
        logInfo("GET /training/finetune/checkpoints")
        do {
            let response = try await withTimeout(seconds: 3) {
                try await self.apiClient.listCheckpoints()
            }
            checkpoints = response.checkpoints
            logSuccess("Loaded \(response.checkpoints.count) checkpoints")
        } catch {
            logError("loadCheckpoints() failed: \(error.localizedDescription)")
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
        guard let dataset = selectedDataset, let model = selectedModel else {
            logWarning("startTestRun() - Aborted: No dataset or model selected")
            return
        }

        logHeader("TEST RUN")
        logData("Dataset", "id=\(dataset.id), name=\(dataset.name)")
        logData("Model", "id=\(model.id), name=\(model.name)")

        isRunningTest = true
        testRunResults = nil

        do {
            let request = TestRunRequest(
                datasetId: dataset.id,
                modelId: model.id,
                epochs: 5,
                batchSize: trainingConfig.batchSize,
                device: trainingConfig.device
            )
            logInfo("POST /training/test-run")
            logData("Payload", "{dataset_id: \(request.datasetId), model_id: \(request.modelId), epochs: \(request.epochs), batch_size: \(request.batchSize), device: \(request.device)}")

            let response = try await withTimeout(seconds: 10) {
                try await self.apiClient.startTestRun(request: request)
            }
            activeJobId = response.jobId
            logSuccess("Test run started: job_id=\(response.jobId)")

            // Poll for results
            await pollForTestResults(jobId: response.jobId)
        } catch {
            logError("startTestRun() failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
            isRunningTest = false
        }
    }

    private func pollForTestResults(jobId: String) async {
        logInfo("Polling for test results: job_id=\(jobId)")
        var pollCount = 0
        let maxPolls = 100 // Max 5 minutes (100 * 3 seconds)

        while isRunningTest && pollCount < maxPolls {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            pollCount += 1

            do {
                let results = try await withTimeout(seconds: 5) {
                    try await self.apiClient.getTestRunResults(jobId: jobId)
                }
                logSuccess("Test results received after \(pollCount) polls")
                logData("Results", "success=\(results.success), initialLoss=\(results.initialLoss), finalLoss=\(results.finalLoss)")
                testRunResults = results
                isRunningTest = false
                return
            } catch {
                if pollCount % 5 == 0 {
                    logWarning("Poll #\(pollCount): Still waiting...")
                }
            }
        }

        // Timeout after max polls
        if isRunningTest {
            logError("Test run polling timed out after \(pollCount) polls")
            isRunningTest = false
            self.error = "Test run polling timed out"
        }
    }

    func startTraining() async {
        guard let dataset = selectedDataset, let model = selectedModel else {
            logWarning("startTraining() - Aborted: No dataset or model selected")
            return
        }

        logHeader("STARTING TRAINING")
        logData("Dataset", "id=\(dataset.id), name=\(dataset.name)")
        logData("Model", "id=\(model.id), name=\(model.name)")
        logData("Config", "epochs=\(trainingConfig.epochs), batchSize=\(trainingConfig.batchSize), useLora=\(trainingConfig.useLoRA), device=\(trainingConfig.device)")

        isTraining = true

        do {
            let request = TrainingStartRequest(
                datasetId: dataset.id,
                modelId: model.id,
                epochs: trainingConfig.epochs,
                batchSize: trainingConfig.batchSize,
                learningRate: trainingConfig.learningRate,
                useLora: trainingConfig.useLoRA,
                device: trainingConfig.device
            )

            logInfo("POST /training/start")
            logData("Payload", "{\"dataset_id\": \(request.datasetId), \"model_id\": \(request.modelId), \"epochs\": \(request.epochs), \"batch_size\": \(request.batchSize), \"learning_rate\": \(request.learningRate), \"use_lora\": \(request.useLora), \"device\": \"\(request.device)\"}")

            let response = try await withTimeout(seconds: 10) {
                try await self.apiClient.startTrainingPipeline(request: request)
            }
            activeJobId = response.jobId

            logSuccess("Training job created!")
            logData("job_id", response.jobId)
            logData("status", response.status)
            logData("dataset", response.dataset ?? "n/a")
            logData("model", response.model ?? "n/a")
            logData("message", response.message)

            // Start polling for progress
            startProgressPolling(jobId: response.jobId)
        } catch {
            logError("startTraining() FAILED!")
            logError("Error: \(error.localizedDescription)")
            if let apiError = error as? APIError {
                logError("APIError details: \(apiError)")
            }
            self.error = error.localizedDescription
            isTraining = false
        }
    }

    func stopTraining() async {
        guard let jobId = activeJobId else {
            logWarning("stopTraining() - No active job to stop")
            return
        }

        logWarning("Stopping training job: \(jobId)")

        do {
            _ = try await withTimeout(seconds: 5) {
                try await self.apiClient.stopTraining(jobId: jobId)
            }
            logSuccess("Training stopped successfully")
            pollingTask?.cancel()
            pollingTask = nil
            isTraining = false
            activeTrainingJob = nil
            activeJobId = nil
        } catch {
            logError("stopTraining() failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    private func startProgressPolling(jobId: String) {
        logInfo("Starting progress polling for job: \(jobId)")
        logInfo("GET /jobs/\(jobId)")
        pollingTask?.cancel()
        downloadPollingTask?.cancel()

        // Start download progress polling
        startDownloadPolling(jobId: jobId)

        pollingTask = Task {
            var consecutiveFailures = 0
            let maxConsecutiveFailures = 10 // Stop after 10 consecutive failures
            var pollCount = 0

            while !Task.isCancelled && isTraining {
                pollCount += 1
                do {
                    let progress = try await withTimeout(seconds: 5) {
                        try await self.apiClient.getTrainingProgress(jobId: jobId)
                    }
                    activeTrainingJob = progress
                    consecutiveFailures = 0 // Reset on success

                    let progressPct = String(format: "%.1f%%", (progress.progress ?? 0) * 100)
                    let lossStr = String(format: "%.4f", progress.loss)
                    let stage = progress.currentStage ?? "unknown"
                    let loadingStr = progress.isLoading ? " [LOADING MODEL]" : ""
                    logTraining("Poll #\(pollCount): status=\(progress.status), progress=\(progressPct), stage=\(stage), loss=\(lossStr)\(loadingStr)", color: progress.isLoading ? .yellow : .white)

                    if progress.status == "completed" {
                        logSuccess("Training completed!")
                        isTraining = false
                        downloadPollingTask?.cancel()
                        downloadProgress = nil
                        logInfo("Loading updated checkpoints...")
                        await loadCheckpoints()
                        break
                    } else if progress.status == "failed" {
                        logError("Training failed!")
                        if let errorMsg = progress.error {
                            logError("Error: \(errorMsg)")
                            self.error = errorMsg
                        }
                        isTraining = false
                        downloadPollingTask?.cancel()
                        downloadProgress = nil
                        break
                    }
                } catch {
                    consecutiveFailures += 1
                    logError("Poll #\(pollCount): Failed (\(consecutiveFailures)/\(maxConsecutiveFailures)) - \(error.localizedDescription)")
                    if consecutiveFailures >= maxConsecutiveFailures {
                        logError("Too many failures - stopping polling")
                        self.error = "Lost connection to training server"
                        isTraining = false
                        downloadPollingTask?.cancel()
                        break
                    }
                    // Continue polling on transient errors
                }

                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
            logInfo("Progress polling ended")
            pollingTask = nil
        }
    }

    private func startDownloadPolling(jobId: String) {
        logInfo("Starting download polling for job: \(jobId)")
        logInfo("GET /training/jobs/\(jobId)/download")
        downloadPollingTask = Task {
            var downloadPollCount = 0
            while !Task.isCancelled && isTraining {
                downloadPollCount += 1
                do {
                    let download = try await withTimeout(seconds: 3) {
                        try await self.apiClient.getDownloadProgress(jobId: jobId)
                    }

                    if download.isDownloading {
                        downloadProgress = download
                        let pctStr = download.progressPercentage.map { String(format: "%.1f%%", $0) } ?? "..."
                        let speedStr = download.downloadSpeedMbps.map { String(format: "%.1f MB/s", $0) } ?? "..."
                        let etaStr = download.etaHuman ?? "..."
                        let filesStr = "\(download.filesComplete ?? 0)/\(download.filesTotal ?? 0)"
                        logTraining("Download #\(downloadPollCount): \(pctStr) | \(speedStr) | ETA: \(etaStr) | Files: \(filesStr)", color: .yellow)
                    } else {
                        // Download complete or not started
                        if downloadProgress != nil {
                            logSuccess("Model download complete!")
                            downloadProgress = nil
                        } else if let msg = download.message {
                            logInfo("Download #\(downloadPollCount): \(msg)")
                        }
                    }
                } catch {
                    logWarning("Download #\(downloadPollCount): \(error.localizedDescription)")
                }

                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            }
            logInfo("Download polling ended")
            downloadPollingTask = nil
        }
    }

    func deleteCheckpoint(_ name: String) async {
        logWarning("Deleting checkpoint: \(name)")
        do {
            _ = try await withTimeout(seconds: 5) {
                try await self.apiClient.deleteCheckpoint(name: name)
            }
            logSuccess("Checkpoint deleted: \(name)")
            await loadCheckpoints()
        } catch {
            logError("deleteCheckpoint() failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    TrainingTab()
}
