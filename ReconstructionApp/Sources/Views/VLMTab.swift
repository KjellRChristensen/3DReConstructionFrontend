import SwiftUI
import PhotosUI
import QuickLook

struct VLMTab: View {
    @StateObject private var viewModel = VLMViewModel()
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var previewURL: URL?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingInfo {
                    loadingView
                } else if let info = viewModel.vlmInfo {
                    vlmContentView(info: info)
                } else {
                    errorView
                }
            }
            .navigationTitle("VLM CAD")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.loadVLMInfo() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoadingInfo)
                }
            }
            .task {
                await viewModel.loadVLMInfo()
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $viewModel.selectedImage, isPresented: $showingImagePicker, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(image: $viewModel.selectedImage, isPresented: $showingCamera, sourceType: .camera)
            }
            .quickLookPreview($previewURL)
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
            Text("Loading VLM info...")
                .foregroundStyle(.secondary)
        }
    }

    private var errorView: some View {
        ContentUnavailableView {
            Label("VLM CAD Unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Could not load VLM CAD information from the server.")
        } actions: {
            Button("Retry") {
                Task { await viewModel.loadVLMInfo() }
            }
            .buttonStyle(.bordered)
        }
    }

    private func vlmContentView(info: VLMInfoResponse) -> some View {
        List {
            // Status Section
            Section {
                HStack {
                    Image(systemName: info.available ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(info.available ? .green : .red)
                    Text(info.available ? "VLM CAD Available" : "VLM CAD Unavailable")
                        .fontWeight(.medium)
                }

                LabeledContent("Device") {
                    Text(info.deviceInfo.device.uppercased())
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(Capsule())
                }

                if info.deviceInfo.mpsAvailable {
                    Label("Apple Silicon GPU (MPS)", systemImage: "cpu")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Status")
            }

            // Models Section
            Section {
                ForEach(info.models) { model in
                    VLMModelRow(
                        model: model,
                        isDownloading: viewModel.downloadingModel == model.id,
                        onDownload: {
                            Task { await viewModel.downloadModel(modelId: model.id) }
                        }
                    )
                }
            } header: {
                Text("Available Models")
            } footer: {
                Text("Models are downloaded from Hugging Face. Ensure you have sufficient storage.")
            }

            // Image Selection Section
            Section {
                if let image = viewModel.selectedImage {
                    VStack(spacing: 12) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button(role: .destructive) {
                            viewModel.selectedImage = nil
                        } label: {
                            Label("Remove Image", systemImage: "trash")
                        }
                    }
                } else {
                    HStack(spacing: 16) {
                        Button {
                            showingImagePicker = true
                        } label: {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                        }

                        Button {
                            showingCamera = true
                        } label: {
                            Label("Camera", systemImage: "camera")
                        }
                    }
                }
            } header: {
                Text("CAD Drawing")
            } footer: {
                Text("Select a 2D CAD drawing image to convert to 3D")
            }

            // Model Selection
            if viewModel.selectedImage != nil {
                Section {
                    Picker("Model", selection: $viewModel.selectedModelId) {
                        Text("Auto").tag(nil as String?)
                        ForEach(info.models.filter { $0.downloaded }) { model in
                            Text(model.name).tag(model.id as String?)
                        }
                    }

                    Picker("Output Format", selection: $viewModel.outputFormat) {
                        Text("GLB").tag(ExportFormat.glb)
                        Text("OBJ").tag(ExportFormat.obj)
                        Text("STL").tag(ExportFormat.stl)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Options")
                }
            }

            // Reconstruction Button
            if viewModel.selectedImage != nil {
                Section {
                    Button {
                        Task { await viewModel.reconstruct() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isProcessing {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Processing...")
                            } else {
                                Image(systemName: "cube.transparent")
                                Text("Generate 3D Model")
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(viewModel.isProcessing || !hasDownloadedModel(info))

                    Button {
                        Task { await viewModel.generateCode() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isGeneratingCode {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Generating...")
                            } else {
                                Image(systemName: "doc.text")
                                Text("Generate CAD Code Only")
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(viewModel.isGeneratingCode || !hasDownloadedModel(info))
                }

                if !hasDownloadedModel(info) {
                    Section {
                        Label("Download a model first to use VLM reconstruction", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            // Result Section
            if let resultURL = viewModel.resultURL {
                Section {
                    Button {
                        previewURL = resultURL
                    } label: {
                        Label("View 3D Model", systemImage: "arkit")
                    }

                    ShareLink(item: resultURL) {
                        Label("Share Model", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Result")
                }
            }

            // Generated Code Section
            if let code = viewModel.generatedCode {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(code)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                    }
                    .frame(maxHeight: 200)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        UIPasteboard.general.string = code
                    } label: {
                        Label("Copy Code", systemImage: "doc.on.doc")
                    }
                } header: {
                    Text("Generated CAD Code")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func hasDownloadedModel(_ info: VLMInfoResponse) -> Bool {
        info.models.contains { $0.downloaded }
    }
}

struct VLMModelRow: View {
    let model: VLMModel
    let isDownloading: Bool
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack(spacing: 8) {
                        Text(model.size)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())

                        Text("\(String(format: "%.0f", model.minVramGb))GB VRAM")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if model.requiresGpu {
                            Image(systemName: "cpu")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Spacer()

                if model.downloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if isDownloading {
                    ProgressView()
                } else {
                    Button {
                        onDownload()
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.title2)
                    }
                }
            }

            Text(model.type)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ViewModel

@MainActor
class VLMViewModel: ObservableObject {
    @Published var vlmInfo: VLMInfoResponse?
    @Published var selectedImage: UIImage?
    @Published var selectedModelId: String?
    @Published var outputFormat: ExportFormat = .glb
    @Published var resultURL: URL?
    @Published var generatedCode: String?

    @Published var isLoadingInfo = false
    @Published var isProcessing = false
    @Published var isGeneratingCode = false
    @Published var downloadingModel: String?
    @Published var error: String?

    private let apiClient = APIClient.shared

    func loadVLMInfo() async {
        isLoadingInfo = true
        error = nil

        do {
            vlmInfo = try await apiClient.getVLMInfo()
        } catch {
            self.error = error.localizedDescription
        }

        isLoadingInfo = false
    }

    func downloadModel(modelId: String) async {
        downloadingModel = modelId
        error = nil

        do {
            _ = try await apiClient.downloadVLMModel(modelId: modelId)
            // Refresh info to update downloaded status
            await loadVLMInfo()
        } catch {
            self.error = error.localizedDescription
        }

        downloadingModel = nil
    }

    func reconstruct() async {
        guard let image = selectedImage else { return }

        isProcessing = true
        error = nil
        resultURL = nil

        do {
            let filename = "cad_drawing_\(Date().timeIntervalSince1970).png"
            let url = try await apiClient.vlmReconstruct(
                image: image,
                filename: filename,
                modelId: selectedModelId,
                outputFormat: outputFormat
            )
            resultURL = url
        } catch {
            self.error = error.localizedDescription
        }

        isProcessing = false
    }

    func generateCode() async {
        guard let image = selectedImage else { return }

        isGeneratingCode = true
        error = nil
        generatedCode = nil

        do {
            let filename = "cad_drawing_\(Date().timeIntervalSince1970).png"
            let response = try await apiClient.vlmGenerateCode(
                image: image,
                filename: filename,
                modelId: selectedModelId
            )
            generatedCode = response.code
        } catch {
            self.error = error.localizedDescription
        }

        isGeneratingCode = false
    }
}

#Preview {
    VLMTab()
}
