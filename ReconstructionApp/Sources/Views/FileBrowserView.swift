import SwiftUI

struct FileBrowserView: View {
    @StateObject private var viewModel = FileBrowserViewModel()
    @Binding var selectedFile: InputFile?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.files.isEmpty {
                    loadingView
                } else if viewModel.files.isEmpty {
                    emptyView
                } else {
                    fileList
                }
            }
            .navigationTitle("Select File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

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
            Text("Loading files...")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Files", systemImage: "folder")
        } description: {
            Text("No floor plans found in the input folder.\nAdd files to the backend's data/input directory.")
        }
    }

    private var fileList: some View {
        List {
            Section {
                ForEach(viewModel.files) { file in
                    FileRowView(file: file, isSelected: selectedFile?.id == file.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFile = file
                            dismiss()
                        }
                }
            } header: {
                Text("\(viewModel.files.count) files")
            } footer: {
                if let dir = viewModel.directory {
                    Text("Source: \(dir)")
                        .font(.caption2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.refresh()
        }
    }
}

struct FileRowView: View {
    let file: InputFile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // File type icon
            Image(systemName: file.iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(file.sizeHuman)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let date = file.modifiedDate {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
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

@MainActor
class FileBrowserViewModel: ObservableObject {
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
}

#Preview {
    FileBrowserView(selectedFile: .constant(nil))
}
