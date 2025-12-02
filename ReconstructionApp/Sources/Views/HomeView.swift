import SwiftUI

struct HomeView: View {
    @EnvironmentObject var jobListViewModel: JobListViewModel
    @State private var showingUpload = false

    var body: some View {
        NavigationStack {
            Group {
                if jobListViewModel.isLoading && jobListViewModel.jobs.isEmpty {
                    loadingView
                } else if jobListViewModel.jobs.isEmpty {
                    emptyStateView
                } else {
                    JobListView()
                }
            }
            .navigationTitle("3D Reconstruction")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingUpload = true
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
            .sheet(isPresented: $showingUpload) {
                UploadView()
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

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Reconstructions", systemImage: "cube.transparent")
        } description: {
            Text("Start by selecting a floor plan from the server to reconstruct into a 3D model.")
        } actions: {
            Button {
                showingUpload = true
            } label: {
                Label("New Reconstruction", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(JobListViewModel())
}
