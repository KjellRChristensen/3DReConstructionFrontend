import SwiftUI

struct ProgressCard: View {
    let progress: JobProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stage indicator
            HStack(spacing: 8) {
                ForEach(PipelineStage.allCases, id: \.rawValue) { stage in
                    stageIndicator(stage)
                }
            }

            // Current stage info
            VStack(alignment: .leading, spacing: 4) {
                Text(progress.stage.displayName)
                    .font(.headline)

                if let message = progress.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            ProgressView(value: progress.progress) {
                Text("\(Int(progress.progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func stageIndicator(_ stage: PipelineStage) -> some View {
        let isActive = stage.order <= progress.stage.order
        let isCurrent = stage == progress.stage

        Circle()
            .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
            .frame(width: isCurrent ? 12 : 8, height: isCurrent ? 12 : 8)
            .animation(.easeInOut, value: progress.stage)
    }
}

extension PipelineStage: CaseIterable {
    static var allCases: [PipelineStage] {
        [.initializing, .ingestion, .vectorization, .recognition, .reconstruction, .saving_output, .complete]
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressCard(progress: JobProgress(
            stage: .ingestion,
            progress: 0.3,
            message: "Loading PDF document..."
        ))

        ProgressCard(progress: JobProgress(
            stage: .recognition,
            progress: 0.65,
            message: "Detecting walls and openings..."
        ))

        ProgressCard(progress: JobProgress(
            stage: .saving_output,
            progress: 0.9,
            message: "Generating USDZ file..."
        ))
    }
    .padding()
}
