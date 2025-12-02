import SwiftUI

struct InputTab: View {
    @StateObject private var viewModel = InputFilesViewModel()
    @State private var selectedFile: InputFile?
    @State private var showingFileDetail = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.files.isEmpty {
                    loadingView
                } else if viewModel.files.isEmpty {
                    emptyView
                } else {
                    fileListView
                }
            }
            .navigationTitle("Input Files")
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
            .sheet(item: $selectedFile) { file in
                FileDetailSheet(file: file, onDelete: {
                    Task {
                        await viewModel.deleteFile(file)
                        selectedFile = nil
                    }
                })
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading files...")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Input Files", systemImage: "folder")
        } description: {
            Text("Add floor plans to the server's data/input folder to see them here.")
        } actions: {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }

    private var fileListView: some View {
        List {
            Section {
                ForEach(viewModel.files) { file in
                    InputFileRow(file: file)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFile = file
                        }
                }
            } header: {
                HStack {
                    Text("\(viewModel.files.count) files")
                    Spacer()
                    if let dir = viewModel.directory {
                        Text(dir)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct InputFileRow: View {
    let file: InputFile

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail/Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: file.iconName)
                    .font(.title2)
                    .foregroundStyle(iconColor)
            }

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(file.sizeHuman)
                    Text("•")
                    Text(file.type.capitalized)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        switch file.type {
        case "image": return .blue
        case "document": return .red
        case "cad": return .purple
        default: return .gray
        }
    }
}

struct FileDetailSheet: View {
    let file: InputFile
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // File icon
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 100, height: 100)

                            Image(systemName: file.iconName)
                                .font(.system(size: 44))
                                .foregroundStyle(.blue)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("File Information") {
                    LabeledContent("Name", value: file.name)
                    LabeledContent("Size", value: file.sizeHuman)
                    LabeledContent("Type", value: file.type.capitalized)
                    LabeledContent("Extension", value: file.fileExtension)
                    if let date = file.modifiedDate {
                        LabeledContent("Modified", value: date.formatted())
                    }
                }

                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Delete File", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("File Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

@MainActor
class InputFilesViewModel: ObservableObject {
    @Published var files: [InputFile] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var directory: String?

    private let apiClient = APIClient.shared

    func loadFiles() async {
        isLoading = true
        error = nil

        do {
            let response = try await apiClient.listInputFiles()
            files = response.files
            directory = response.directory
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        await loadFiles()
    }

    func deleteFile(_ file: InputFile) async {
        do {
            try await apiClient.deleteInputFile(filename: file.name)
            files.removeAll { $0.id == file.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    InputTab()
}
