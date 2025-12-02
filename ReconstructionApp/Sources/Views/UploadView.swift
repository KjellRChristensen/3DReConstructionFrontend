import SwiftUI

struct UploadView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var jobListViewModel: JobListViewModel
    @StateObject private var viewModel = ProcessViewModel()

    @State private var showingFileBrowser = false

    var body: some View {
        NavigationStack {
            Form {
                // File selection section
                Section {
                    if let file = viewModel.selectedFile {
                        selectedFileView(file)
                    } else {
                        fileSelectionButton
                    }
                } header: {
                    Text("Floor Plan")
                } footer: {
                    Text("Select a file from the server's input folder")
                }

                // Export formats section
                Section("Export Formats") {
                    ForEach(ExportFormat.allCases) { format in
                        Toggle(isOn: Binding(
                            get: { viewModel.selectedFormats.contains(format) },
                            set: { isSelected in
                                if isSelected {
                                    viewModel.selectedFormats.insert(format)
                                } else {
                                    viewModel.selectedFormats.remove(format)
                                }
                            }
                        )) {
                            VStack(alignment: .leading) {
                                Text(format.displayName)
                                if format.supportsARQuickLook {
                                    Text("Supports AR Quick Look")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // Parameters section
                Section("Parameters") {
                    HStack {
                        Text("Wall Height")
                        Spacer()
                        TextField("Height", value: $viewModel.wallHeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("m")
                            .foregroundStyle(.secondary)
                    }

                    Stepper("Floors: \(viewModel.numFloors)", value: $viewModel.numFloors, in: 1...10)
                }

                // Process button
                Section {
                    Button {
                        Task {
                            await viewModel.startProcessing()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isProcessing {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Starting...")
                            } else {
                                Label("Start Reconstruction", systemImage: "cube.transparent")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!viewModel.canProcess || viewModel.isProcessing)
                }

                // Error display
                if let error = viewModel.error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Reconstruction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingFileBrowser) {
                FileBrowserView(selectedFile: $viewModel.selectedFile)
            }
            .onChange(of: viewModel.createdJobId) { _, jobId in
                if jobId != nil {
                    dismiss()
                }
            }
        }
    }

    private func selectedFileView(_ file: InputFile) -> some View {
        HStack(spacing: 12) {
            Image(systemName: file.iconName)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(file.sizeHuman)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Change") {
                showingFileBrowser = true
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private var fileSelectionButton: some View {
        Button {
            showingFileBrowser = true
        } label: {
            HStack {
                Image(systemName: "folder")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading) {
                    Text("Browse Files")
                        .font(.body)
                    Text("Select from server input folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
    }
}

@MainActor
class ProcessViewModel: ObservableObject {
    @Published var selectedFile: InputFile?
    @Published var selectedFormats: Set<ExportFormat> = [.glb, .usdz]
    @Published var wallHeight: Double = 2.7
    @Published var numFloors: Int = 1
    @Published var isProcessing = false
    @Published var error: String?
    @Published var createdJobId: String?

    private let apiClient = APIClient.shared

    var canProcess: Bool {
        selectedFile != nil && !selectedFormats.isEmpty
    }

    func startProcessing() async {
        guard let file = selectedFile else { return }

        isProcessing = true
        error = nil

        do {
            let response = try await apiClient.createJobFromFile(
                filename: file.name,
                formats: Array(selectedFormats),
                wallHeight: wallHeight,
                numFloors: numFloors
            )

            createdJobId = response.jobId
        } catch {
            self.error = error.localizedDescription
        }

        isProcessing = false
    }

    func reset() {
        selectedFile = nil
        createdJobId = nil
        error = nil
    }
}

#Preview {
    UploadView()
        .environmentObject(JobListViewModel())
}
