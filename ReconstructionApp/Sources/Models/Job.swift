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

// MARK: - Training Pipeline Models

/// Dataset available on the server (already prepared/extracted)
struct ServerDataset: Codable, Identifiable {
    let id: Int
    let name: String
    let path: String
    let description: String?
    let models: Int           // Number of CAD models
    let trainSamples: Int
    let valSamples: Int
    let images: Int
    let conversations: Int
    let sizeBytes: Int?
    let size: String?
    let status: String        // "ready", "processing", etc.
    let created: String?
    let updated: String?

    // Computed properties for UI
    var totalSamples: Int { trainSamples + valSamples }
    var isReady: Bool { status == "ready" }

    enum CodingKeys: String, CodingKey {
        case id, name, path, description, models, images, conversations, size, status, created, updated
        case trainSamples = "train_samples"
        case valSamples = "val_samples"
        case sizeBytes = "size_bytes"
    }
}


struct ServerDatasetsResponse: Codable {
    let datasets: [ServerDataset]
    let total: Int
}

// Remove old DatasetStatus enum - now using String status

/// Request to extract a subset from a source dataset
struct DatasetExtractRequest: Codable {
    var sourceName: String
    var trainSize: Int
    var valSize: Int?
    var outputName: String?

    enum CodingKeys: String, CodingKey {
        case sourceName = "source_name"
        case trainSize = "train_size"
        case valSize = "val_size"
        case outputName = "output_name"
    }
}

struct DatasetExtractResponse: Codable {
    let jobId: String
    let datasetName: String
    let status: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case datasetName = "dataset_name"
        case status, message
    }
}

/// Request to render views for a dataset
struct DatasetRenderRequest: Codable {
    var resolution: Int
    var views: [String]

    init(resolution: Int = 512, views: [String] = ["front", "top", "right"]) {
        self.resolution = resolution
        self.views = views
    }
}

struct DatasetRenderResponse: Codable {
    let jobId: String
    let status: String
    let totalModels: Int
    let message: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case totalModels = "total_models"
        case message
    }
}

/// Request to convert dataset to training format
struct DatasetConvertRequest: Codable {
    var format: String

    init(format: String = "tinyllava") {
        self.format = format
    }
}

struct DatasetConvertResponse: Codable {
    let jobId: String
    let status: String
    let outputFormat: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case outputFormat = "output_format"
        case message
    }
}

/// Dataset validation response
struct DatasetValidationResponse: Codable {
    let valid: Bool
    let samples: Int
    let issues: [String]?
    let warnings: [String]?
}

/// Available model for training
struct TrainingModel: Codable, Identifiable {
    let id: Int
    let name: String
    let displayName: String
    let description: String
    let architecture: String
    let baseModel: String
    let visionModel: String?
    let parameters: String
    let supportsLora: Bool
    let supportsFullFinetune: Bool
    let recommendedForCad: Bool
    let minVramGb: Int
    let minRamGb: Int
    let available: Bool
    let verified: Bool
    let huggingfaceId: String?
    let created: String?
    let updated: String?

    // Computed for UI
    var vramDisplay: String { "\(minVramGb)GB" }
    var isRecommended: Bool { recommendedForCad }

    enum CodingKeys: String, CodingKey {
        case id, name, description, architecture, parameters, available, verified, created, updated
        case displayName = "display_name"
        case baseModel = "base_model"
        case visionModel = "vision_model"
        case supportsLora = "supports_lora"
        case supportsFullFinetune = "supports_full_finetune"
        case recommendedForCad = "recommended_for_cad"
        case minVramGb = "min_vram_gb"
        case minRamGb = "min_ram_gb"
        case huggingfaceId = "huggingface_id"
    }
}

struct TrainingModelsResponse: Codable {
    let models: [TrainingModel]
    let total: Int
}

/// Test run request for quick convergence check
struct TestRunRequest: Codable {
    var datasetId: Int
    var modelId: Int
    var epochs: Int
    var batchSize: Int
    var device: String

    enum CodingKeys: String, CodingKey {
        case datasetId = "dataset_id"
        case modelId = "model_id"
        case epochs
        case batchSize = "batch_size"
        case device
    }
}

struct TestRunResponse: Codable {
    let jobId: String
    let status: String
    let estimatedTime: String?
    let message: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case estimatedTime = "estimated_time"
        case message
    }
}

/// Test run results
struct TestRunResults: Codable {
    let success: Bool
    let initialLoss: Double
    let finalLoss: Double
    let lossReduction: Double
    let convergenceRate: Double?
    let recommendation: String?

    enum CodingKeys: String, CodingKey {
        case success
        case initialLoss = "initial_loss"
        case finalLoss = "final_loss"
        case lossReduction = "loss_reduction"
        case convergenceRate = "convergence_rate"
        case recommendation
    }
}

/// Full training request
struct TrainingStartRequest: Codable {
    var datasetId: Int
    var modelId: Int
    var epochs: Int
    var batchSize: Int
    var learningRate: Double
    var useLora: Bool
    var device: String

    enum CodingKeys: String, CodingKey {
        case datasetId = "dataset_id"
        case modelId = "model_id"
        case epochs
        case batchSize = "batch_size"
        case learningRate = "learning_rate"
        case useLora = "use_lora"
        case device
    }
}

struct TrainingStartResponse: Codable {
    let jobId: String
    let status: String
    let runName: String?
    let dataset: String?
    let model: String?
    let estimatedTime: String?
    let message: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case runName = "run_name"
        case dataset
        case model
        case estimatedTime = "estimated_time"
        case message
    }
}

/// Download progress for model downloads
struct DownloadProgress: Codable {
    let jobId: String
    let isDownloading: Bool
    let message: String?
    let modelId: String?
    let totalSizeBytes: Int64?
    let totalSizeGb: Double?
    let downloadedBytes: Int64?
    let downloadedGb: Double?
    let progressPercentage: Double?
    let downloadSpeedMbps: Double?
    let etaSeconds: Int?
    let etaHuman: String?
    let filesTotal: Int?
    let filesComplete: Int?
    let startedAt: String?

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case isDownloading = "is_downloading"
        case message
        case modelId = "model_id"
        case totalSizeBytes = "total_size_bytes"
        case totalSizeGb = "total_size_gb"
        case downloadedBytes = "downloaded_bytes"
        case downloadedGb = "downloaded_gb"
        case progressPercentage = "progress_percentage"
        case downloadSpeedMbps = "download_speed_mbps"
        case etaSeconds = "eta_seconds"
        case etaHuman = "eta_human"
        case filesTotal = "files_total"
        case filesComplete = "files_complete"
        case startedAt = "started_at"
    }
}

/// Training job metrics (nested in response)
struct TrainingJobMetrics: Codable {
    let epoch: Int?
    let step: Int?
    let loss: Double?
    let accuracy: Double?
    let etaSeconds: Double?
    let totalSteps: Int?
    let learningRate: Double?
    let validationLoss: Double?

    enum CodingKeys: String, CodingKey {
        case epoch, step, loss, accuracy
        case etaSeconds = "eta_seconds"
        case totalSteps = "total_steps"
        case learningRate = "learning_rate"
        case validationLoss = "validation_loss"
    }
}

/// Training status/progress from /jobs/{job_id}
struct TrainingProgress: Codable {
    let jobId: String
    let status: String
    let progress: Double?
    let currentStage: String?
    let metrics: TrainingJobMetrics?
    let error: String?
    let topLevelLoss: Double?  // Top-level loss from API
    let isLoadingModel: Bool?  // True when model is being loaded/downloaded

    // Computed properties for UI compatibility
    var progressValue: Double { progress ?? 0 }
    var currentEpoch: Int { metrics?.epoch ?? 0 }
    var totalEpochs: Int { 0 }  // Not provided by backend - parse from currentStage if needed
    var currentStep: Int { metrics?.step ?? 0 }
    var totalSteps: Int { metrics?.totalSteps ?? 0 }
    var loss: Double { topLevelLoss ?? metrics?.loss ?? 0 }
    var accuracy: Double? { metrics?.accuracy }
    var validationLoss: Double? { metrics?.validationLoss }
    var learningRate: Double { metrics?.learningRate ?? 0 }
    var etaSeconds: Double? { metrics?.etaSeconds }
    var isLoading: Bool { isLoadingModel ?? false }

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status, progress, metrics, error
        case currentStage = "current_stage"
        case topLevelLoss = "loss"
        case isLoadingModel = "is_loading_model"
    }
}

// MARK: - Training Management Models (Legacy)

// Remote datasets available for download (HuggingFace, etc.)
struct RemoteDataset: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let downloadUrl: String
    let size: String
    let samples: Int
    let status: String  // "available", "downloading", "downloaded"
    let format: String?
    let license: String?
    let recommended: Bool?
    let downloadProgress: Double?

    var sampleCount: Int { samples }
    var source: String { downloadUrl }
    var downloaded: Bool { status == "downloaded" }
    var localPath: String? { nil }

    enum CodingKeys: String, CodingKey {
        case id, name, description, size, samples, status, format, license, recommended
        case downloadUrl = "download_url"
        case downloadProgress = "download_progress"
    }

    init(id: String, name: String, description: String, downloadUrl: String = "", size: String, samples: Int, status: String = "available", format: String? = nil, license: String? = nil, recommended: Bool? = nil, downloadProgress: Double? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.downloadUrl = downloadUrl
        self.size = size
        self.samples = samples
        self.status = status
        self.format = format
        self.license = license
        self.recommended = recommended
        self.downloadProgress = downloadProgress
    }

    // Legacy initializer for backwards compatibility with mock data
    init(id: String, name: String, description: String, source: String, size: String, sampleCount: Int, format: String, license: String, recommended: Bool, downloaded: Bool, downloadProgress: Double?, localPath: String?) {
        self.id = id
        self.name = name
        self.description = description
        self.downloadUrl = source
        self.size = size
        self.samples = sampleCount
        self.status = downloaded ? "downloaded" : "available"
        self.format = format
        self.license = license
        self.recommended = recommended
        self.downloadProgress = downloadProgress
    }
}

struct RemoteDatasetsResponse: Codable {
    let datasets: [RemoteDataset]
}

// Local datasets created/downloaded on the server
struct LocalDataset: Codable, Identifiable {
    let name: String
    let path: String
    let created: String
    let stats: DatasetStats?

    var id: String { name }
}

struct DatasetStats: Codable {
    let totalModels: Int
    let successful: Int
    let errors: Int
    let trainSamples: Int
    let valSamples: Int

    enum CodingKeys: String, CodingKey {
        case totalModels = "total_models"
        case successful, errors
        case trainSamples = "train_samples"
        case valSamples = "val_samples"
    }
}

struct LocalDatasetsResponse: Codable {
    let datasets: [LocalDataset]
    let total: Int
}

struct DatasetDownloadResponse: Codable {
    let jobId: String
    let status: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status, message
    }
}

struct DatasetCreateRequest: Codable {
    var name: String
    var sourceFolder: String
    var annotationsFile: String?
    var resolution: Int
    var views: String
    var trainSplit: Double

    enum CodingKeys: String, CodingKey {
        case name
        case sourceFolder = "source_folder"
        case annotationsFile = "annotations_file"
        case resolution, views
        case trainSplit = "train_split"
    }
}

struct DatasetCreateResponse: Codable {
    let jobId: String
    let status: String
    let datasetName: String
    let modelCount: Int
    let message: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case datasetName = "dataset_name"
        case modelCount = "model_count"
        case message
    }
}

struct FinetuneConfig: Codable {
    var datasetName: String
    var baseModel: String
    var epochs: Int
    var batchSize: Int
    var learningRate: Double
    var loraRank: Int
    var runName: String?

    enum CodingKeys: String, CodingKey {
        case datasetName = "dataset_name"
        case baseModel = "base_model"
        case epochs
        case batchSize = "batch_size"
        case learningRate = "learning_rate"
        case loraRank = "lora_rank"
        case runName = "run_name"
    }

    static var `default`: FinetuneConfig {
        FinetuneConfig(
            datasetName: "",
            baseModel: "Yuan-Che/OpenECADv2-SigLIP-0.89B",
            epochs: 3,
            batchSize: 2,
            learningRate: 0.0001,
            loraRank: 128,
            runName: nil
        )
    }
}

/// UI model for configuring training runs (wraps FinetuneConfig for the UI)
struct TrainingConfig {
    var datasetId: String = ""
    var baseModel: String = "openecad-0.89b"
    var epochs: Int = 3
    var batchSize: Int = 2
    var learningRate: Double = 0.0001
    var loraEnabled: Bool = true
    var loraRank: Int = 64
    var validationSplit: Double = 0.1
    var sampleLimit: Int?

    static var `default`: TrainingConfig {
        TrainingConfig()
    }

    /// Convert UI model to API model
    func toFinetuneConfig() -> FinetuneConfig {
        // Map UI model IDs to full HuggingFace repo paths
        let modelMap: [String: String] = [
            "openecad-0.55b": "Yuan-Che/OpenECADv2-CLIP-0.55B",
            "openecad-0.89b": "Yuan-Che/OpenECADv2-SigLIP-0.89B",
            "openecad-2.4b": "Yuan-Che/OpenECADv2-SigLIP-2.4B",
            "openecad-3.1b": "Yuan-Che/OpenECAD-SigLIP-3.1B",
            "internvl2-2b": "OpenGVLab/InternVL2-2B",
            "internvl2-8b": "OpenGVLab/InternVL2-8B"
        ]

        return FinetuneConfig(
            datasetName: datasetId,
            baseModel: modelMap[baseModel] ?? baseModel,
            epochs: epochs,
            batchSize: batchSize,
            learningRate: learningRate,
            loraRank: loraEnabled ? loraRank : 0,
            runName: nil
        )
    }
}

struct FinetuneStartResponse: Codable {
    let jobId: String
    let status: String
    let runName: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case runName = "run_name"
        case message
    }
}

struct TrainingMetrics: Codable {
    let epoch: Int
    let step: Int
    let loss: Double
    let accuracy: Double?
    let etaSeconds: Double?
    let totalSteps: Int?
    let learningRate: Double?
    let validationLoss: Double?

    // Computed properties for UI backward compatibility
    var estimatedRemaining: Double? { etaSeconds }

    enum CodingKeys: String, CodingKey {
        case epoch, step, loss, accuracy
        case etaSeconds = "eta_seconds"
        case totalSteps = "total_steps"
        case learningRate = "learning_rate"
        case validationLoss = "validation_loss"
    }
}

struct TrainingJobStatus: Codable, Identifiable {
    let jobId: String
    let status: String
    let progress: Double
    let currentStage: String?
    let jobType: String?
    let runName: String?
    let datasetName: String?
    let metrics: TrainingMetrics?
    let config: TrainingJobConfig?
    let startedAt: String?
    let completedAt: String?
    let error: String?
    let loss: Double?  // Top-level loss from API (latest training loss)

    var id: String { jobId }

    // Backward compatibility computed properties for UI
    var datasetId: String { datasetName ?? config?.datasetId ?? "Unknown" }
    var baseModel: String { config?.modelId ?? "Unknown" }
    var currentEpoch: Int { metrics?.epoch ?? 0 }
    var totalEpochs: Int { config?.epochs ?? 1 }

    /// Get the current loss value - prefers top-level loss, falls back to metrics
    var currentLoss: Double? { loss ?? metrics?.loss }

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status, progress, metrics, config, error, loss
        case currentStage = "current_stage"
        case jobType = "job_type"
        case runName = "run_name"
        case datasetName = "dataset_name"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

struct TrainingJobConfig: Codable {
    let modelId: String?
    let datasetId: String?
    let epochs: Int?

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case datasetId = "dataset_id"
        case epochs
    }
}

struct TrainingJobsListResponse: Codable {
    let jobs: [TrainingJobStatus]
}

struct CheckpointInfo: Codable, Identifiable {
    let name: String
    let path: String
    let created: String
    let hasLoraAdapter: Bool
    let config: CheckpointConfig?
    let size: String?
    let metrics: CheckpointMetrics?

    var id: String { name }

    // Backward compatibility computed properties for UI
    var baseModel: String { config?.baseModel ?? "Unknown" }
    var datasetId: String { "local" }
    var createdAt: String { created }

    enum CodingKeys: String, CodingKey {
        case name, path, created, config, size, metrics
        case hasLoraAdapter = "has_lora_adapter"
    }
}

struct CheckpointConfig: Codable {
    let baseModel: String
    let loraRank: Int?
    let epochs: Int?

    enum CodingKeys: String, CodingKey {
        case baseModel = "base_model"
        case loraRank = "lora_rank"
        case epochs
    }
}

struct CheckpointMetrics: Codable {
    let loss: Double?
    let accuracy: Double?
    let epochs: Int?
}

struct CheckpointsResponse: Codable {
    let checkpoints: [CheckpointInfo]
    let total: Int
}

struct FinetuneStatusResponse: Codable {
    let ready: Bool
    let dependencies: [String: Bool]
    let device: String
    let recommendedSetup: [String: String]?

    enum CodingKeys: String, CodingKey {
        case ready, dependencies, device
        case recommendedSetup = "recommended_setup"
    }
}

struct GenericResponse: Codable {
    let success: Bool
    let message: String?
}

// Keep legacy types for backwards compatibility
typealias TrainingDataset = RemoteDataset
typealias TrainingJob = TrainingJobStatus
typealias TrainedModel = CheckpointInfo
