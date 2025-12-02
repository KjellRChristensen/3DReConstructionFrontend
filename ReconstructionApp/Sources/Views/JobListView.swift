import SwiftUI

struct JobListView: View {
    @EnvironmentObject var jobListViewModel: JobListViewModel

    var body: some View {
        List {
            ForEach(jobListViewModel.jobs) { job in
                NavigationLink(value: job) {
                    JobRowView(job: job)
                }
            }
            .onDelete(perform: deleteJobs)
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: Job.self) { job in
            JobDetailView(jobId: job.id)
        }
        .refreshable {
            await jobListViewModel.loadJobs()
        }
    }

    private func deleteJobs(at offsets: IndexSet) {
        for index in offsets {
            let job = jobListViewModel.jobs[index]
            Task {
                await jobListViewModel.deleteJob(id: job.id)
            }
        }
    }
}

struct JobRowView: View {
    let job: Job

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: job.status.systemImage)
                .font(.title2)
                .foregroundStyle(statusColor)
                .frame(width: 44, height: 44)
                .background(statusColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(job.filename)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Text(job.status.displayName)
                        .font(.caption)
                        .foregroundStyle(statusColor)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(job.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if job.status == .processing {
                ProgressView()
            } else if job.status == .completed {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch job.status {
        case .pending: return .orange
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

#Preview {
    NavigationStack {
        JobListView()
    }
    .environmentObject(JobListViewModel())
}
