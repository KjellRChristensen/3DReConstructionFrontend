import Foundation

enum JobStatus: String, Codable {
    case pending
    case processing
    case completed
    case failed

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    var systemImage: String {
        switch self {
        case .pending: return "clock"
        case .processing: return "gearshape.2"
        case .completed: return "checkmark.circle"
        case .failed: return "exclamationmark.triangle"
        }
    }
}

enum PipelineStage: String, Codable {
    case initializing
    case ingestion
    case vectorization
    case recognition
    case reconstruction
    case saving_output
    case complete
    case failed

    var displayName: String {
        switch self {
        case .initializing: return "Initializing"
        case .ingestion: return "Loading Document"
        case .vectorization: return "Vectorizing"
        case .recognition: return "Detecting Elements"
        case .reconstruction: return "Building 3D Model"
        case .saving_output: return "Saving Output"
        case .complete: return "Complete"
        case .failed: return "Failed"
        }
    }

    var order: Int {
        switch self {
        case .initializing: return 0
        case .ingestion: return 1
        case .vectorization: return 2
        case .recognition: return 3
        case .reconstruction: return 4
        case .saving_output: return 5
        case .complete: return 6
        case .failed: return -1
        }
    }
}

struct JobProgress: Codable {
    let stage: PipelineStage
    let progress: Double
    let message: String?
}

struct Job: Identifiable, Codable, Hashable {
    static func == (lhs: Job, rhs: Job) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: String
    let status: JobStatus
    let filename: String
    let createdAt: Date
    let completedAt: Date?
    let progress: JobProgress?
    let currentStage: String?
    let outputFiles: [String]?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case id = "job_id"
        case status
        case filename
        case createdAt = "created_at"
        case completedAt = "completed_at"
        case progress
        case currentStage = "current_stage"
        case outputFiles = "output_files"
        case error
    }
}

struct JobCreateRequest: Encodable {
    let formats: [ExportFormat]
    let wallHeight: Double?
    let scale: Double?

    enum CodingKeys: String, CodingKey {
        case formats
        case wallHeight = "wall_height"
        case scale
    }
}

struct JobCreateResponse: Decodable {
    let jobId: String
    let status: JobStatus
    let strategy: String?
    let message: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case strategy
        case message
    }
}

// MARK: - Reconstruction Strategy

enum ReconstructionStrategyType: String, Codable, CaseIterable, Identifiable {
    case auto
    case external_api
    case basic_extrusion
    case multi_view_dnn

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto (Recommended)"
        case .external_api: return "External AI API"
        case .basic_extrusion: return "Basic Extrusion"
        case .multi_view_dnn: return "Multi-View DNN"
        }
    }

    var systemImage: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .external_api: return "cloud"
        case .basic_extrusion: return "cube"
        case .multi_view_dnn: return "brain"
        }
    }
}

struct ReconstructionStrategy: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let services: [String]
    let requiresApiKey: Bool
    let bestFor: String
    let accuracy: String
    let speed: String
    let available: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, description, services, accuracy, speed, available
        case requiresApiKey = "requires_api_key"
        case bestFor = "best_for"
    }
}

struct StrategiesResponse: Codable {
    let strategies: [ReconstructionStrategy]
    let `default`: String
    let recommended: String
}

// MARK: - Preview Response

struct PreviewResponse: Codable {
    let success: Bool
    let outputFile: String
    let downloadUrl: String
    let format: String
    let strategy: String

    enum CodingKeys: String, CodingKey {
        case success
        case outputFile = "output_file"
        case downloadUrl = "download_url"
        case format
        case strategy
    }
}

// MARK: - GPU Status

struct GPUStatus: Codable {
    let pytorchInstalled: Bool
    let device: String
    let mpsAvailable: Bool
    let mpsBuilt: Bool
    let cudaAvailable: Bool
    let deviceName: String
    let pytorchVersion: String?

    enum CodingKeys: String, CodingKey {
        case pytorchInstalled = "pytorch_installed"
        case device
        case mpsAvailable = "mps_available"
        case mpsBuilt = "mps_built"
        case cudaAvailable = "cuda_available"
        case deviceName = "device_name"
        case pytorchVersion = "pytorch_version"
    }
}

// MARK: - Upload Response

struct UploadResponse: Codable {
    let status: String
    let file: UploadedFileInfo
}

struct UploadedFileInfo: Codable {
    let name: String
    let path: String
    let size: Int
    let sizeHuman: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case name, path, size, type
        case sizeHuman = "size_human"
    }
}

// MARK: - Validation Models

struct SupportedFormat: Codable, Identifiable {
    let `extension`: String
    let name: String
    let description: String

    var id: String { `extension` }
}

struct MetricInfo: Codable, Identifiable {
    let name: String
    let description: String

    var id: String { name }
}

struct ValidationFormatsResponse: Codable {
    let supportedFormats: [SupportedFormat]
    let metricsComputed: [MetricInfo]

    enum CodingKeys: String, CodingKey {
        case supportedFormats = "supported_formats"
        case metricsComputed = "metrics_computed"
    }
}

struct ValidationMetrics: Codable {
    let chamferDistance: Double
    let hausdorffDistance: Double
    let iou3d: Double
    let fScore: Double
    let precision: Double
    let recall: Double

    enum CodingKeys: String, CodingKey {
        case chamferDistance = "chamfer_distance"
        case hausdorffDistance = "hausdorff_distance"
        case iou3d = "iou_3d"
        case fScore = "f_score"
        case precision
        case recall
    }
}

struct ValidationCompareResponse: Codable {
    let success: Bool
    let metrics: ValidationMetrics
    let summary: String
}

struct ValidationRunResponse: Codable {
    let jobId: String
    let status: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case message
    }
}

struct ProjectionInfo: Codable {
    let width: Int
    let height: Int
    let scale: Double
    let floorHeight: Double

    enum CodingKeys: String, CodingKey {
        case width, height, scale
        case floorHeight = "floor_height"
    }
}

struct ProjectionResponse: Codable {
    let success: Bool
    let outputFile: String
    let downloadUrl: String
    let projectionInfo: ProjectionInfo

    enum CodingKeys: String, CodingKey {
        case success
        case outputFile = "output_file"
        case downloadUrl = "download_url"
        case projectionInfo = "projection_info"
    }
}

struct TrainingPairFiles: Codable {
    let x2d: String
    let y3d: String
    let metadata: String

    enum CodingKeys: String, CodingKey {
        case x2d = "x_2d"
        case y3d = "y_3d"
        case metadata
    }
}

struct TrainingPairURLs: Codable {
    let x2d: String
    let y3d: String
    let metadata: String

    enum CodingKeys: String, CodingKey {
        case x2d = "x_2d"
        case y3d = "y_3d"
        case metadata
    }
}

struct TrainingPairResponse: Codable {
    let success: Bool
    let files: TrainingPairFiles
    let downloadUrls: TrainingPairURLs

    enum CodingKeys: String, CodingKey {
        case success
        case files
        case downloadUrls = "download_urls"
    }
}

// MARK: - Training Data Generation Models

struct TrainingFeatures: Codable {
    let hiddenLines: String
    let batchProcessing: String
    let metadata: String

    enum CodingKeys: String, CodingKey {
        case hiddenLines = "hidden_lines"
        case batchProcessing = "batch_processing"
        case metadata
    }
}

struct TrainingInfoResponse: Codable {
    let description: String
    let supportedInputFormats: [String]
    let outputViews: [String]
    let defaultViews: [String]
    let features: TrainingFeatures

    enum CodingKeys: String, CodingKey {
        case description
        case supportedInputFormats = "supported_input_formats"
        case outputViews = "output_views"
        case defaultViews = "default_views"
        case features
    }
}

struct RenderedViewInfo: Codable {
    let file: String
    let downloadUrl: String
    let scale: Double?
    let visibleEdges: Int?
    let hiddenEdges: Int?

    enum CodingKeys: String, CodingKey {
        case file
        case downloadUrl = "download_url"
        case scale
        case visibleEdges = "visible_edges"
        case hiddenEdges = "hidden_edges"
    }
}

struct RenderConfig: Codable {
    let resolution: Int
    let showHiddenLines: Bool

    enum CodingKeys: String, CodingKey {
        case resolution
        case showHiddenLines = "show_hidden_lines"
    }
}

struct RenderViewsResponse: Codable {
    let success: Bool
    let model: String
    let views: [String: RenderedViewInfo]
    let config: RenderConfig
}

struct TrainingPairViewInfo: Codable {
    let file: String
    let downloadUrl: String

    enum CodingKeys: String, CodingKey {
        case file
        case downloadUrl = "download_url"
    }
}

struct TrainingPairData: Codable {
    let views: [String: TrainingPairViewInfo]
    let groundTruth: TrainingPairViewInfo
    let metadata: TrainingPairViewInfo

    enum CodingKeys: String, CodingKey {
        case views
        case groundTruth = "ground_truth"
        case metadata
    }
}

struct ModelInfo: Codable {
    let boundsMin: [Double]
    let boundsMax: [Double]
    let extents: [Double]
    let numVertices: Int
    let numFaces: Int

    enum CodingKeys: String, CodingKey {
        case boundsMin = "bounds_min"
        case boundsMax = "bounds_max"
        case extents
        case numVertices = "num_vertices"
        case numFaces = "num_faces"
    }
}

struct GenerateTrainingPairResponse: Codable {
    let success: Bool
    let trainingPair: TrainingPairData
    let modelInfo: ModelInfo

    enum CodingKeys: String, CodingKey {
        case success
        case trainingPair = "training_pair"
        case modelInfo = "model_info"
    }
}

struct BatchRenderResponse: Codable {
    let jobId: String
    let status: String
    let modelCount: Int
    let message: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case modelCount = "model_count"
        case message
    }
}

// MARK: - VLM CAD Models

struct VLMDeviceInfo: Codable {
    let device: String
    let hasTorch: Bool
    let hasTransformers: Bool
    let cudaAvailable: Bool
    let mpsAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case device
        case hasTorch = "has_torch"
        case hasTransformers = "has_transformers"
        case cudaAvailable = "cuda_available"
        case mpsAvailable = "mps_available"
    }
}

struct VLMModel: Codable, Identifiable {
    let id: String
    let name: String
    let size: String
    let type: String
    let requiresGpu: Bool
    let minVramGb: Double
    let downloaded: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, size, type
        case requiresGpu = "requires_gpu"
        case minVramGb = "min_vram_gb"
        case downloaded
    }
}

struct VLMInfoResponse: Codable {
    let available: Bool
    let deviceInfo: VLMDeviceInfo
    let models: [VLMModel]

    enum CodingKeys: String, CodingKey {
        case available
        case deviceInfo = "device_info"
        case models
    }
}

struct VLMDownloadResponse: Codable {
    let success: Bool
    let modelId: String
    let path: String

    enum CodingKeys: String, CodingKey {
        case success
        case modelId = "model_id"
        case path
    }
}

struct VLMCodeResponse: Codable {
    let success: Bool
    let code: String
    let modelId: String
    let modelName: String

    enum CodingKeys: String, CodingKey {
        case success, code
        case modelId = "model_id"
        case modelName = "model_name"
    }
}

// MARK: - Training Management Models

struct TrainingDataset: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let source: String
    let size: String
    let sampleCount: Int
    let format: String
    let license: String
    let recommended: Bool
    let downloaded: Bool
    let downloadProgress: Double?
    let localPath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, source, size, format, license, recommended, downloaded
        case sampleCount = "sample_count"
        case downloadProgress = "download_progress"
        case localPath = "local_path"
    }
}

struct DatasetsListResponse: Codable {
    let datasets: [TrainingDataset]
    let downloadedCount: Int
    let totalSize: String

    enum CodingKeys: String, CodingKey {
        case datasets
        case downloadedCount = "downloaded_count"
        case totalSize = "total_size"
    }
}

struct DatasetDownloadResponse: Codable {
    let success: Bool
    let datasetId: String
    let jobId: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case success
        case datasetId = "dataset_id"
        case jobId = "job_id"
        case message
    }
}

struct TrainingConfig: Codable {
    var datasetId: String
    var baseModel: String
    var epochs: Int
    var batchSize: Int
    var learningRate: Double
    var loraEnabled: Bool
    var loraRank: Int
    var validationSplit: Double
    var sampleLimit: Int?

    enum CodingKeys: String, CodingKey {
        case datasetId = "dataset_id"
        case baseModel = "base_model"
        case epochs
        case batchSize = "batch_size"
        case learningRate = "learning_rate"
        case loraEnabled = "lora_enabled"
        case loraRank = "lora_rank"
        case validationSplit = "validation_split"
        case sampleLimit = "sample_limit"
    }

    static var `default`: TrainingConfig {
        TrainingConfig(
            datasetId: "openecad",
            baseModel: "openecad-0.89b",
            epochs: 3,
            batchSize: 4,
            learningRate: 2e-5,
            loraEnabled: true,
            loraRank: 16,
            validationSplit: 0.1,
            sampleLimit: nil
        )
    }
}

struct TrainingMetrics: Codable {
    let epoch: Int
    let step: Int
    let totalSteps: Int
    let loss: Double
    let learningRate: Double
    let validationLoss: Double?
    let accuracy: Double?
    let elapsedTime: Double
    let estimatedRemaining: Double?

    enum CodingKeys: String, CodingKey {
        case epoch, step, loss, accuracy
        case totalSteps = "total_steps"
        case learningRate = "learning_rate"
        case validationLoss = "validation_loss"
        case elapsedTime = "elapsed_time"
        case estimatedRemaining = "estimated_remaining"
    }
}

struct TrainingJob: Codable, Identifiable {
    let id: String
    let datasetId: String
    let baseModel: String
    let status: String
    let progress: Double
    let currentEpoch: Int
    let totalEpochs: Int
    let metrics: TrainingMetrics?
    let createdAt: String
    let startedAt: String?
    let completedAt: String?
    let error: String?
    let outputModelPath: String?

    enum CodingKeys: String, CodingKey {
        case id, status, progress, metrics, error
        case datasetId = "dataset_id"
        case baseModel = "base_model"
        case currentEpoch = "current_epoch"
        case totalEpochs = "total_epochs"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case outputModelPath = "output_model_path"
    }
}

struct StartTrainingResponse: Codable {
    let success: Bool
    let jobId: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case success
        case jobId = "job_id"
        case message
    }
}

struct TrainingJobsResponse: Codable {
    let jobs: [TrainingJob]
    let activeCount: Int
    let completedCount: Int

    enum CodingKeys: String, CodingKey {
        case jobs
        case activeCount = "active_count"
        case completedCount = "completed_count"
    }
}

struct TrainedModel: Codable, Identifiable {
    let id: String
    let name: String
    let baseModel: String
    let datasetId: String
    let createdAt: String
    let size: String
    let metrics: TrainingMetrics?
    let path: String

    enum CodingKeys: String, CodingKey {
        case id, name, size, metrics, path
        case baseModel = "base_model"
        case datasetId = "dataset_id"
        case createdAt = "created_at"
    }
}

struct TrainedModelsResponse: Codable {
    let models: [TrainedModel]
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case models
        case totalCount = "total_count"
    }
}
