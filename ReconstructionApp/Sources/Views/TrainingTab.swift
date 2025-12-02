import SwiftUI

struct TrainingTab: View {
    @StateObject private var viewModel = TrainingViewModel()
    @State private var showingRenderSheet = false
    @State private var showingBatchSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingInfo {
                    loadingView
                } else if let info = viewModel.trainingInfo {
                    trainingContentView(info: info)
                } else {
                    errorView
                }
            }
            .navigationTitle("Training Data")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.loadTrainingInfo() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoadingInfo)
                }
            }
            .task {
                await viewModel.loadTrainingInfo()
                await viewModel.loadInputFiles()
            }
            .sheet(isPresented: $showingRenderSheet) {
                RenderViewsSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingBatchSheet) {
                BatchRenderSheet(viewModel: viewModel)
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
            Text("Loading training info...")
                .foregroundStyle(.secondary)
        }
    }

    private var errorView: some View {
        ContentUnavailableView {
            Label("Training Unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Could not load training information from the server.")
        } actions: {
            Button("Retry") {
                Task { await viewModel.loadTrainingInfo() }
            }
            .buttonStyle(.bordered)
        }
    }

    private func trainingContentView(info: TrainingInfoResponse) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(info.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("About")
            }

            Section {
                LabeledContent("Input Formats") {
                    Text(info.supportedInputFormats.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Output Views") {
                    Text(info.outputViews.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Default Views") {
                    Text(info.defaultViews.joined(separator: ", "))
                        .font(.caption)
                }
            } header: {
                Text("Configuration")
            }

            Section {
                FeatureRow(
                    icon: "eye.slash",
                    title: "Hidden Lines",
                    description: info.features.hiddenLines
                )

                FeatureRow(
                    icon: "square.stack.3d.up",
                    title: "Batch Processing",
                    description: info.features.batchProcessing
                )

                FeatureRow(
                    icon: "doc.text",
                    title: "Metadata",
                    description: info.features.metadata
                )
            } header: {
                Text("Features")
            }

            Section {
                Button {
                    showingRenderSheet = true
                } label: {
                    Label("Render Orthographic Views", systemImage: "camera.viewfinder")
                }
                .disabled(viewModel.inputFiles.isEmpty)

                Button {
                    showingBatchSheet = true
                } label: {
                    Label("Batch Render Training Data", systemImage: "square.stack.3d.down.right")
                }
            } header: {
                Text("Actions")
            }

            if !viewModel.recentResults.isEmpty {
                Section {
                    ForEach(viewModel.recentResults, id: \.model) { result in
                        RenderResultRow(result: result)
                    }
                } header: {
                    Text("Recent Results")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RenderResultRow: View {
    let result: RenderViewsResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cube")
                    .foregroundStyle(.purple)
                Text(result.model)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            HStack(spacing: 16) {
                ForEach(Array(result.views.keys.sorted()), id: \.self) { viewName in
                    VStack(spacing: 4) {
                        Image(systemName: viewIconName(viewName))
                            .font(.caption)
                        Text(viewName)
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("\(result.config.resolution)px")
                if result.config.showHiddenLines {
                    Text("Hidden lines")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func viewIconName(_ view: String) -> String {
        switch view {
        case "front": return "square"
        case "top": return "square.tophalf.filled"
        case "right": return "square.righthalf.filled"
        case "left": return "square.lefthalf.filled"
        case "back": return "square.dashed"
        case "bottom": return "square.bottomhalf.filled"
        case "isometric": return "cube"
        default: return "square"
        }
    }
}

// MARK: - Render Views Sheet

struct RenderViewsSheet: View {
    @ObservedObject var viewModel: TrainingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFile: InputFile?
    @State private var resolution: Double = 1024
    @State private var showHiddenLines = true
    @State private var selectedViews: Set<String> = ["front", "top", "right"]

    private let availableViews = ["front", "top", "right", "left", "back", "bottom", "isometric"]
    private let resolutions = [512.0, 1024.0, 2048.0, 4096.0]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("3D Model", selection: $selectedFile) {
                        Text("Select a model").tag(nil as InputFile?)
                        ForEach(viewModel.inputFiles.filter { isModelFile($0) }) { file in
                            Text(file.name).tag(file as InputFile?)
                        }
                    }
                } header: {
                    Text("Model")
                }

                Section {
                    Picker("Resolution", selection: $resolution) {
                        ForEach(resolutions, id: \.self) { res in
                            Text("\(Int(res))px").tag(res)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Show Hidden Lines", isOn: $showHiddenLines)
                } header: {
                    Text("Options")
                }

                Section {
                    ForEach(availableViews, id: \.self) { view in
                        Toggle(view.capitalized, isOn: Binding(
                            get: { selectedViews.contains(view) },
                            set: { isSelected in
                                if isSelected {
                                    selectedViews.insert(view)
                                } else {
                                    selectedViews.remove(view)
                                }
                            }
                        ))
                    }
                } header: {
                    Text("Views")
                }

                if viewModel.isRendering {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Rendering views...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Render Views")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Render") {
                        Task {
                            if let file = selectedFile {
                                await viewModel.renderViews(
                                    modelFile: file.name,
                                    resolution: Int(resolution),
                                    views: Array(selectedViews),
                                    showHiddenLines: showHiddenLines
                                )
                                if viewModel.error == nil {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .disabled(selectedFile == nil || selectedViews.isEmpty || viewModel.isRendering)
                }
            }
        }
    }

    private func isModelFile(_ file: InputFile) -> Bool {
        let modelExtensions = [".obj", ".glb", ".gltf", ".stl", ".ply", ".ifc"]
        return modelExtensions.contains(file.fileExtension.lowercased())
    }
}

// MARK: - Batch Render Sheet

struct BatchRenderSheet: View {
    @ObservedObject var viewModel: TrainingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var inputFolder = "input"
    @State private var resolution: Double = 1024

    private let resolutions = [512.0, 1024.0, 2048.0]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Folder", text: $inputFolder)
                } header: {
                    Text("Input Folder")
                } footer: {
                    Text("Folder containing 3D models to process")
                }

                Section {
                    Picker("Resolution", selection: $resolution) {
                        ForEach(resolutions, id: \.self) { res in
                            Text("\(Int(res))px").tag(res)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Options")
                }

                if viewModel.isRendering {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Starting batch job...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let batchResult = viewModel.batchResult {
                    Section {
                        LabeledContent("Job ID", value: batchResult.jobId)
                        LabeledContent("Status", value: batchResult.status)
                        LabeledContent("Models", value: "\(batchResult.modelCount)")
                        Text(batchResult.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Batch Job Started")
                    }
                }
            }
            .navigationTitle("Batch Render")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        Task {
                            await viewModel.batchRender(
                                inputFolder: inputFolder,
                                resolution: Int(resolution)
                            )
                        }
                    }
                    .disabled(inputFolder.isEmpty || viewModel.isRendering)
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class TrainingViewModel: ObservableObject {
    @Published var trainingInfo: TrainingInfoResponse?
    @Published var inputFiles: [InputFile] = []
    @Published var recentResults: [RenderViewsResponse] = []
    @Published var batchResult: BatchRenderResponse?
    @Published var isLoadingInfo = false
    @Published var isRendering = false
    @Published var error: String?

    private let apiClient = APIClient.shared

    func loadTrainingInfo() async {
        isLoadingInfo = true
        error = nil

        do {
            trainingInfo = try await apiClient.getTrainingInfo()
        } catch {
            self.error = error.localizedDescription
        }

        isLoadingInfo = false
    }

    func loadInputFiles() async {
        do {
            let response = try await apiClient.listInputFiles()
            inputFiles = response.files
        } catch {
            // Silent fail for input files
        }
    }

    func renderViews(
        modelFile: String,
        resolution: Int,
        views: [String],
        showHiddenLines: Bool
    ) async {
        isRendering = true
        error = nil

        do {
            let result = try await apiClient.renderOrthographicViews(
                modelFile: modelFile,
                resolution: resolution,
                views: views,
                showHiddenLines: showHiddenLines
            )
            recentResults.insert(result, at: 0)
            if recentResults.count > 5 {
                recentResults.removeLast()
            }
        } catch {
            self.error = error.localizedDescription
        }

        isRendering = false
    }

    func generateTrainingPair(
        modelFile: String,
        resolution: Int,
        views: [String]
    ) async {
        isRendering = true
        error = nil

        do {
            _ = try await apiClient.generateCAD2ProgramTrainingPair(
                modelFile: modelFile,
                resolution: resolution,
                views: views
            )
        } catch {
            self.error = error.localizedDescription
        }

        isRendering = false
    }

    func batchRender(inputFolder: String, resolution: Int) async {
        isRendering = true
        error = nil

        do {
            batchResult = try await apiClient.batchRenderTrainingData(
                inputFolder: inputFolder,
                resolution: resolution
            )
        } catch {
            self.error = error.localizedDescription
        }

        isRendering = false
    }
}

#Preview {
    TrainingTab()
}
