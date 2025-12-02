import SwiftUI

struct ValidationTab: View {
    @StateObject private var viewModel = ValidationViewModel()

    var body: some View {
        NavigationStack {
            List {
                // Supported Formats Section
                Section {
                    if viewModel.isLoadingFormats {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if let formats = viewModel.supportedFormats {
                        ForEach(formats) { format in
                            HStack {
                                Text(format.extension)
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                                    .frame(width: 50, alignment: .leading)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(format.name)
                                        .font(.body)
                                    Text(format.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        Text("Load formats to see supported file types")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Supported Formats")
                }

                // Validation Actions
                Section("Run Validation") {
                    // File selection for ground truth
                    Button {
                        viewModel.showingFilePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.gearshape")
                                .font(.title2)
                                .foregroundStyle(.purple)

                            VStack(alignment: .leading) {
                                Text(viewModel.selectedGroundTruth?.name ?? "Select Ground Truth")
                                    .font(.body)
                                Text("Choose 3D CAD file (IFC, OBJ, GLB)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    // Wall height
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

                    // Floor height
                    HStack {
                        Text("Floor Height")
                        Spacer()
                        TextField("", value: $viewModel.floorHeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("m")
                            .foregroundStyle(.secondary)
                    }

                    // Run validation button
                    Button {
                        Task { await viewModel.runValidation() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isRunningValidation {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Running...")
                            } else {
                                Label("Run Full Validation", systemImage: "play.fill")
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.selectedGroundTruth == nil || viewModel.isRunningValidation)
                }

                // Compare Meshes Section
                Section("Compare Meshes") {
                    Button {
                        viewModel.showingPredictedPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "cube")
                                .foregroundStyle(.blue)
                            Text(viewModel.selectedPredicted?.name ?? "Select Predicted Mesh")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.showingGroundTruthPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "cube.transparent")
                                .foregroundStyle(.green)
                            Text(viewModel.selectedCompareGroundTruth?.name ?? "Select Ground Truth Mesh")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await viewModel.compareMeshes() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isComparing {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Comparing...")
                            } else {
                                Label("Compare", systemImage: "arrow.left.arrow.right")
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.selectedPredicted == nil || viewModel.selectedCompareGroundTruth == nil || viewModel.isComparing)
                }

                // Comparison Results
                if let metrics = viewModel.comparisonMetrics {
                    Section("Comparison Results") {
                        MetricRow(name: "Chamfer Distance", value: String(format: "%.4f", metrics.chamferDistance), isGood: metrics.chamferDistance < 0.1)
                        MetricRow(name: "Hausdorff Distance", value: String(format: "%.4f", metrics.hausdorffDistance), isGood: metrics.hausdorffDistance < 0.2)
                        MetricRow(name: "3D IoU", value: String(format: "%.2f%%", metrics.iou3d * 100), isGood: metrics.iou3d > 0.7)
                        MetricRow(name: "F-Score", value: String(format: "%.2f%%", metrics.fScore * 100), isGood: metrics.fScore > 0.8)
                        MetricRow(name: "Precision", value: String(format: "%.2f%%", metrics.precision * 100), isGood: metrics.precision > 0.8)
                        MetricRow(name: "Recall", value: String(format: "%.2f%%", metrics.recall * 100), isGood: metrics.recall > 0.8)
                    }
                }

                // Utilities Section
                Section("Utilities") {
                    Button {
                        viewModel.showingProjectionFilePicker = true
                    } label: {
                        Label("Generate 2D Projection", systemImage: "square.on.square.dashed")
                    }

                    Button {
                        viewModel.showingTrainingPairFilePicker = true
                    } label: {
                        Label("Generate Training Pair", systemImage: "rectangle.split.2x1")
                    }
                }

                // Error display
                if let error = viewModel.error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Validation")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.loadFormats() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoadingFormats)
                }
            }
            .task {
                await viewModel.loadFormats()
            }
            .sheet(isPresented: $viewModel.showingFilePicker) {
                FileBrowserView(selectedFile: $viewModel.selectedGroundTruth)
            }
            .sheet(isPresented: $viewModel.showingPredictedPicker) {
                OutputFileBrowserView(selectedFile: $viewModel.selectedPredicted)
            }
            .sheet(isPresented: $viewModel.showingGroundTruthPicker) {
                FileBrowserView(selectedFile: $viewModel.selectedCompareGroundTruth)
            }
            .sheet(isPresented: $viewModel.showingProjectionFilePicker) {
                ProjectionSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingTrainingPairFilePicker) {
                TrainingPairSheet(viewModel: viewModel)
            }
        }
    }
}

struct MetricRow: View {
    let name: String
    let value: String
    let isGood: Bool

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(isGood ? .green : .orange)
        }
    }
}

struct OutputFileBrowserView: View {
    @Binding var selectedFile: InputFile?
    @Environment(\.dismiss) private var dismiss
    @State private var files: [OutputFile] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List(files) { file in
                Button {
                    // Convert OutputFile to InputFile for compatibility
                    selectedFile = InputFile(
                        name: file.name,
                        path: file.path,
                        size: file.size,
                        sizeHuman: file.sizeHuman,
                        modified: file.modified,
                        type: file.type,
                        fileExtension: file.fileExtension
                    )
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "cube")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text(file.name)
                            Text(file.sizeHuman)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Select Output File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                do {
                    let response = try await APIClient.shared.listOutputFiles()
                    files = response.files
                } catch {
                    print("Failed to load output files: \(error)")
                }
                isLoading = false
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }
}

struct ProjectionSheet: View {
    @ObservedObject var viewModel: ValidationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFile: InputFile?
    @State private var floorHeight: Double = 1.0
    @State private var resolution: Int = 1024
    @State private var showingFilePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Model File") {
                    Button {
                        showingFilePicker = true
                    } label: {
                        HStack {
                            Text(selectedFile?.name ?? "Select 3D Model")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section("Parameters") {
                    HStack {
                        Text("Floor Height")
                        Spacer()
                        TextField("", value: $floorHeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("m")
                            .foregroundStyle(.secondary)
                    }

                    Picker("Resolution", selection: $resolution) {
                        Text("512").tag(512)
                        Text("1024").tag(1024)
                        Text("2048").tag(2048)
                    }
                }

                Section {
                    Button {
                        Task {
                            guard let file = selectedFile else { return }
                            await viewModel.projectModel(filename: file.name, floorHeight: floorHeight, resolution: resolution)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Generate Projection", systemImage: "square.on.square.dashed")
                            Spacer()
                        }
                    }
                    .disabled(selectedFile == nil)
                }
            }
            .navigationTitle("2D Projection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                FileBrowserView(selectedFile: $selectedFile)
            }
        }
    }
}

struct TrainingPairSheet: View {
    @ObservedObject var viewModel: ValidationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFile: InputFile?
    @State private var floorHeight: Double = 1.0
    @State private var showingFilePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Model File") {
                    Button {
                        showingFilePicker = true
                    } label: {
                        HStack {
                            Text(selectedFile?.name ?? "Select 3D Model")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section("Parameters") {
                    HStack {
                        Text("Floor Height")
                        Spacer()
                        TextField("", value: $floorHeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("m")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        Task {
                            guard let file = selectedFile else { return }
                            await viewModel.generateTrainingPair(filename: file.name, floorHeight: floorHeight)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Generate Training Pair", systemImage: "rectangle.split.2x1")
                            Spacer()
                        }
                    }
                    .disabled(selectedFile == nil)
                }

                Section {
                    Text("Generates paired training data:\n- 2D floor plan image (X)\n- 3D model (Y)\n- Metadata JSON")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Training Pair")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                FileBrowserView(selectedFile: $selectedFile)
            }
        }
    }
}

@MainActor
class ValidationViewModel: ObservableObject {
    @Published var supportedFormats: [SupportedFormat]?
    @Published var metricsInfo: [MetricInfo]?
    @Published var isLoadingFormats = false
    @Published var error: String?

    // Validation run
    @Published var selectedGroundTruth: InputFile?
    @Published var wallHeight: Double = 2.8
    @Published var floorHeight: Double = 0.0
    @Published var isRunningValidation = false
    @Published var showingFilePicker = false

    // Mesh comparison
    @Published var selectedPredicted: InputFile?
    @Published var selectedCompareGroundTruth: InputFile?
    @Published var isComparing = false
    @Published var comparisonMetrics: ValidationMetrics?
    @Published var showingPredictedPicker = false
    @Published var showingGroundTruthPicker = false

    // Utilities
    @Published var showingProjectionFilePicker = false
    @Published var showingTrainingPairFilePicker = false

    private let apiClient = APIClient.shared

    func loadFormats() async {
        isLoadingFormats = true
        error = nil

        do {
            let response = try await apiClient.getValidationFormats()
            supportedFormats = response.supportedFormats
            metricsInfo = response.metricsComputed
        } catch {
            self.error = error.localizedDescription
        }

        isLoadingFormats = false
    }

    func runValidation() async {
        guard let file = selectedGroundTruth else { return }

        isRunningValidation = true
        error = nil

        do {
            let response = try await apiClient.runValidation(
                groundTruthFile: file.name,
                wallHeight: wallHeight,
                floorHeight: floorHeight
            )
            // Job started - you could navigate to job detail or poll for results
            print("Validation job started: \(response.jobId)")
        } catch {
            self.error = error.localizedDescription
        }

        isRunningValidation = false
    }

    func compareMeshes() async {
        guard let predicted = selectedPredicted,
              let groundTruth = selectedCompareGroundTruth else { return }

        isComparing = true
        error = nil
        comparisonMetrics = nil

        do {
            let response = try await apiClient.compareMeshes(
                predictedFile: predicted.name,
                groundTruthFile: groundTruth.name
            )
            comparisonMetrics = response.metrics
        } catch {
            self.error = error.localizedDescription
        }

        isComparing = false
    }

    func projectModel(filename: String, floorHeight: Double, resolution: Int) async {
        error = nil

        do {
            let response = try await apiClient.projectModel(
                modelFile: filename,
                floorHeight: floorHeight,
                resolution: resolution
            )
            print("Projection created: \(response.downloadUrl)")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func generateTrainingPair(filename: String, floorHeight: Double) async {
        error = nil

        do {
            let response = try await apiClient.generateTrainingPair(
                modelFile: filename,
                floorHeight: floorHeight
            )
            print("Training pair created: \(response.files)")
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    ValidationTab()
}
