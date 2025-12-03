import Foundation
import UIKit

enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(Int, String?)
    case decodingError(Error)
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .uploadFailed:
            return "Failed to upload file"
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    private var baseURL: String {
        get async {
            await MainActor.run {
                ServerConfigurationManager.shared.currentBaseURL
            }
        }
    }
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Job Operations

    func createJob(
        image: UIImage,
        filename: String,
        formats: [ExportFormat] = [.glb, .usdz],
        wallHeight: Double? = nil,
        scale: Double? = nil
    ) async throws -> JobCreateResponse {
        let base = await baseURL
        guard let url = URL(string: "\(base)\(Constants.API.jobsEndpoint)") else {
            throw APIError.invalidURL
        }

        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw APIError.uploadFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // Add formats
        let formatsString = formats.map { $0.rawValue }.joined(separator: ",")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"formats\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(formatsString)\r\n".data(using: .utf8)!)

        // Add optional parameters
        if let wallHeight = wallHeight {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"wall_height\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(wallHeight)\r\n".data(using: .utf8)!)
        }

        if let scale = scale {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"scale\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(scale)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        return try await performRequest(request)
    }

    func getJob(id: String) async throws -> Job {
        let base = await baseURL
        guard let url = URL(string: "\(base)\(Constants.API.jobsEndpoint)/\(id)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await performRequest(request)
    }

    func getJobProgress(id: String) async throws -> JobProgress {
        let base = await baseURL
        guard let url = URL(string: "\(base)\(Constants.API.jobsEndpoint)/\(id)/progress") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await performRequest(request)
    }

    func deleteJob(id: String) async throws {
        let base = await baseURL
        guard let url = URL(string: "\(base)\(Constants.API.jobsEndpoint)/\(id)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode, nil)
        }
    }

    func downloadFile(jobId: String, filename: String) async throws -> URL {
        let base = await baseURL
        guard let url = URL(string: "\(base)\(Constants.API.jobsEndpoint)/\(jobId)/download/\(filename)") else {
            throw APIError.invalidURL
        }

        let (tempURL, response) = try await session.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode, nil)
        }

        // Move to permanent location
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsPath = documentsPath.appendingPathComponent(Constants.Storage.modelsDirectory)

        try? FileManager.default.createDirectory(at: modelsPath, withIntermediateDirectories: true)

        let destinationURL = modelsPath.appendingPathComponent(filename)

        // Remove existing file if present
        try? FileManager.default.removeItem(at: destinationURL)

        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        return destinationURL
    }

    // MARK: - Input Files

    func listInputFiles() async throws -> InputFilesResponse {
        let base = await baseURL
        guard let url = URL(string: "\(base)/files/input") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await performRequest(request)
    }

    func getInputFileURL(filename: String) async -> URL? {
        let base = await baseURL
        return URL(string: "\(base)/files/input/\(filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename)")
    }

    func deleteInputFile(filename: String) async throws {
        let base = await baseURL
        guard let url = URL(string: "\(base)/files/input/\(filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode, nil)
        }
    }

    func createJobFromFile(
        filename: String,
        formats: [ExportFormat] = [.glb, .usdz],
        wallHeight: Double? = nil,
        numFloors: Int = 1
    ) async throws -> JobCreateResponse {
        let base = await baseURL
        guard var urlComponents = URLComponents(string: "\(base)/jobs/from-file") else {
            throw APIError.invalidURL
        }

        var queryItems = [
            URLQueryItem(name: "filename", value: filename),
            URLQueryItem(name: "export_formats", value: formats.map { $0.rawValue }.joined(separator: ",")),
            URLQueryItem(name: "num_floors", value: String(numFloors))
        ]

        if let wallHeight = wallHeight {
            queryItems.append(URLQueryItem(name: "wall_height", value: String(wallHeight)))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        return try await performRequest(request)
    }

    func listJobs(limit: Int = 50) async throws -> [Job] {
        let base = await baseURL
        guard let url = URL(string: "\(base)/jobs?limit=\(limit)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await performRequest(request)
    }

    // MARK: - File Upload

    func uploadInputFile(image: UIImage, filename: String) async throws -> UploadResponse {
        let base = await baseURL
        guard let url = URL(string: "\(base)/files/input") else {
            throw APIError.invalidURL
        }

        guard let imageData = image.pngData() ?? image.jpegData(compressionQuality: 0.9) else {
            throw APIError.uploadFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        return try await performRequest(request)
    }

    // MARK: - Reconstruction

    func getStrategies() async throws -> StrategiesResponse {
        let base = await baseURL
        guard let url = URL(string: "\(base)/strategies") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await performRequest(request)
    }

    func getPreview(filename: String, wallHeight: Double = 2.8) async throws -> PreviewResponse {
        let base = await baseURL
        guard var urlComponents = URLComponents(string: "\(base)/reconstruct/preview") else {
            throw APIError.invalidURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "filename", value: filename),
            URLQueryItem(name: "wall_height", value: String(wallHeight))
        ]

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        return try await performRequest(request)
    }

    func startReconstruction(
        filename: String,
        strategy: ReconstructionStrategyType = .auto,
        service: String? = nil,
        modelType: String? = nil,
        wallHeight: Double = 2.8,
        exportFormat: ExportFormat = .glb,
        additionalViews: [String]? = nil
    ) async throws -> JobCreateResponse {
        let base = await baseURL
        guard var urlComponents = URLComponents(string: "\(base)/reconstruct") else {
            throw APIError.invalidURL
        }

        var queryItems = [
            URLQueryItem(name: "filename", value: filename),
            URLQueryItem(name: "strategy", value: strategy.rawValue),
            URLQueryItem(name: "wall_height", value: String(wallHeight)),
            URLQueryItem(name: "export_format", value: exportFormat.rawValue)
        ]

        if let service = service {
            queryItems.append(URLQueryItem(name: "service", value: service))
        }

        if let modelType = modelType {
            queryItems.append(URLQueryItem(name: "model_type", value: modelType))
        }

        if let views = additionalViews, !views.isEmpty {
            queryItems.append(URLQueryItem(name: "additional_views", value: views.joined(separator: ",")))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        return try await performRequest(request)
    }

    // MARK: - System

    func checkHealth() async throws -> Bool {
        let base = await baseURL
        guard let url = URL(string: "\(base)/health") else {
            throw APIError.invalidURL
        }

        let (_, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return (200...299).contains(httpResponse.statusCode)
    }

    func getGPUStatus() async throws -> GPUStatus {
        let base = await baseURL
        guard let url = URL(string: "\(base)/system/gpu") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await performRequest(request)
    }

    // MARK: - Output Files

    func listOutputFiles() async throws -> OutputFilesResponse {
        let base = await baseURL
        guard let url = URL(string: "\(base)/files/output") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await performRequest(request)
    }

    func downloadOutputFile(filepath: String) async throws -> URL {
        let base = await baseURL
        let encodedPath = filepath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filepath
        guard let url = URL(string: "\(base)/files/output/\(encodedPath)") else {
            throw APIError.invalidURL
        }

        let (tempURL, response) = try await session.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode, nil)
        }

        // Move to permanent location
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputPath = documentsPath.appendingPathComponent("Output")

        try? FileManager.default.createDirectory(at: outputPath, withIntermediateDirectories: true)

        let filename = URL(fileURLWithPath: filepath).lastPathComponent
        let destinationURL = outputPath.appendingPathComponent(filename)

        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        return destinationURL
    }

    // MARK: - Validation

    func getValidationFormats() async throws -> ValidationFormatsResponse {
        let base = await baseURL
        guard let url = URL(string: "\(base)/validation/formats") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await performRequest(request)
    }

    func runValidation(
        groundTruthFile: String,
        strategy: ReconstructionStrategyType = .auto,
        wallHeight: Double = 2.8,
        floorHeight: Double = 0.0
    ) async throws -> ValidationRunResponse {
        let base = await baseURL
        guard var urlComponents = URLComponents(string: "\(base)/validation/run") else {
            throw APIError.invalidURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "ground_truth_file", value: groundTruthFile),
            URLQueryItem(name: "strategy", value: strategy.rawValue),
            URLQueryItem(name: "wall_height", value: String(wallHeight)),
            URLQueryItem(name: "floor_height", value: String(floorHeight))
        ]

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        return try await performRequest(request)
    }

    func compareMeshes(
        predictedFile: String,
        groundTruthFile: String
    ) async throws -> ValidationCompareResponse {
        let base = await baseURL
        guard var urlComponents = URLComponents(string: "\(base)/validation/compare") else {
            throw APIError.invalidURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "predicted_file", value: predictedFile),
            URLQueryItem(name: "ground_truth_file", value: groundTruthFile)
        ]

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        return try await performRequest(request)
    }

    func projectModel(
        modelFile: String,
        floorHeight: Double = 1.0,
        resolution: Int = 1024
    ) async throws -> ProjectionResponse {
        let base = await baseURL
        guard var urlComponents = URLComponents(string: "\(base)/validation/project") else {
            throw APIError.invalidURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "model_file", value: modelFile),
            URLQueryItem(name: "floor_height", value: String(floorHeight)),
            URLQueryItem(name: "resolution", value: String(resolution))
        ]

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        return try await performRequest(request)
    }

    func generateTrainingPair(
        modelFile: String,
        floorHeight: Double = 1.0
    ) async throws -> TrainingPairResponse {
        let base = await baseURL
        guard var urlComponents = URLComponents(string: "\(base)/validation/training-pair") else {
            throw APIError.invalidURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "model_file", value: modelFile),
            URLQueryItem(name: "floor_height", value: String(floorHeight))
        ]

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        return try await performRequest(request)
    }

    // MARK: - Training Data Generation

    func getTrainingInfo() async throws -> TrainingInfoResponse {
        let base = await baseURL
        guard let url = URL(string: "\(base)/training/info") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await performRequest(request)
    }

    func renderOrthographicViews(
        modelFile: String,
        resolution: Int = 1024,
        views: [String] = ["front", "top", "right"],
        showHiddenLines: Bool = true
    ) async throws -> RenderViewsResponse {
        let base = await baseURL
        guard var urlComponents = URLComponents(string: "\(base)/training/render-views") else {
            throw APIError.invalidURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "model_file", value: modelFile),
            URLQueryItem(name: "resolution", value: String(resolution)),
            URLQueryItem(name: "views", value: views.joined(separator: ",")),
            URLQueryItem(name: "show_hidden_lines", value: String(showHiddenLines))
        ]

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        return try await performRequest(request)
    }

    func generateCAD2ProgramTrainingPair(
        modelFile: String,
        resolution: Int = 1024,
        views: [String] = ["front", "top", "right"]
    ) async throws -> GenerateTrainingPairResponse {
        let base = await baseURL
        guard var urlComponents = URLComponents(string: "\(base)/training/generate-pair") else {
            throw APIError.invalidURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "model_file", value: modelFile),
            URLQueryItem(name: "resolution", value: String(resolution)),
            URLQueryItem(name: "views", value: views.joined(separator: ","))
        ]

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        return try await performRequest(request)
    }

    func batchRenderTrainingData(
        inputFolder: String = "input",
        resolution: Int = 1024
    ) async throws -> BatchRenderResponse {
        let base = await baseURL
        guard var urlComponents = URLComponents(string: "\(base)/training/batch-render") else {
            throw APIError.invalidURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "input_folder", value: inputFolder),
            URLQueryItem(name: "resolution", value: String(resolution))
        ]

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        return try await performRequest(request)
    }

    // MARK: - VLM CAD Strategy

    func getVLMInfo() async throws -> VLMInfoResponse {
        let base = await baseURL
        guard let url = URL(string: "\(base)/vlm-cad/info") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await performRequest(request)
    }

    func downloadVLMModel(modelId: String) async throws -> VLMDownloadResponse {
        let base = await baseURL
        guard var urlComponents = URLComponents(string: "\(base)/vlm-cad/download-model") else {
            throw APIError.invalidURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "model_id", value: modelId)
        ]

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 600 // 10 minutes for model download

        return try await performRequest(request)
    }

    func vlmReconstruct(
        image: UIImage,
        filename: String,
        modelId: String? = nil,
        outputFormat: ExportFormat = .glb
    ) async throws -> URL {
        let base = await baseURL
        guard let url = URL(string: "\(base)/vlm-cad/reconstruct") else {
            throw APIError.invalidURL
        }

        guard let imageData = image.pngData() ?? image.jpegData(compressionQuality: 0.9) else {
            throw APIError.uploadFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300 // 5 minutes for reconstruction

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // Add model_id if provided
        if let modelId = modelId {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"model_id\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(modelId)\r\n".data(using: .utf8)!)
        }

        // Add output format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"output_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(outputFormat.rawValue)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (tempURL, response) = try await session.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode, nil)
        }

        // Move to permanent location
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsPath = documentsPath.appendingPathComponent(Constants.Storage.modelsDirectory)

        try? FileManager.default.createDirectory(at: modelsPath, withIntermediateDirectories: true)

        let outputFilename = filename.replacingOccurrences(of: ".png", with: ".\(outputFormat.rawValue)")
            .replacingOccurrences(of: ".jpg", with: ".\(outputFormat.rawValue)")
            .replacingOccurrences(of: ".jpeg", with: ".\(outputFormat.rawValue)")
        let destinationURL = modelsPath.appendingPathComponent(outputFilename)

        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        return destinationURL
    }

    func vlmGenerateCode(
        image: UIImage,
        filename: String,
        modelId: String? = nil,
        prompt: String? = nil
    ) async throws -> VLMCodeResponse {
        let base = await baseURL
        guard let url = URL(string: "\(base)/vlm-cad/generate-code") else {
            throw APIError.invalidURL
        }

        guard let imageData = image.pngData() ?? image.jpegData(compressionQuality: 0.9) else {
            throw APIError.uploadFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // Add model_id if provided
        if let modelId = modelId {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"model_id\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(modelId)\r\n".data(using: .utf8)!)
        }

        // Add prompt if provided
        if let prompt = prompt {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(prompt)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        return try await performRequest(request)
    }

    // MARK: - Training Management

    func listDatasets() async throws -> DatasetsListResponse {
        let base = await baseURL
        guard let url = URL(string: "\(base)/training/datasets") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await performRequest(request)
    }

    func downloadDataset(datasetId: String, sampleLimit: Int? = nil) async throws -> DatasetDownloadResponse {
        let base = await baseURL
        guard var urlComponents = URLComponents(string: "\(base)/training/datasets/\(datasetId)/download") else {
            throw APIError.invalidURL
        }

        if let limit = sampleLimit {
            urlComponents.queryItems = [
                URLQueryItem(name: "sample_limit", value: String(limit))
            ]
        }

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 3600 // 1 hour for large datasets

        return try await performRequest(request)
    }

    func getDatasetStatus(datasetId: String) async throws -> TrainingDataset {
        let base = await baseURL
        guard let url = URL(string: "\(base)/training/datasets/\(datasetId)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await performRequest(request)
    }

    func startTraining(config: TrainingConfig) async throws -> StartTrainingResponse {
        let base = await baseURL
        guard let url = URL(string: "\(base)/training/start") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(config)

        return try await performRequest(request)
    }

    func listTrainingJobs() async throws -> TrainingJobsResponse {
        let base = await baseURL
        guard let url = URL(string: "\(base)/training/jobs") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await performRequest(request)
    }

    func getTrainingJob(jobId: String) async throws -> TrainingJob {
        let base = await baseURL
        guard let url = URL(string: "\(base)/training/jobs/\(jobId)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await performRequest(request)
    }

    func stopTraining(jobId: String) async throws -> StartTrainingResponse {
        let base = await baseURL
        guard let url = URL(string: "\(base)/training/jobs/\(jobId)/stop") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        return try await performRequest(request)
    }

    func listTrainedModels() async throws -> TrainedModelsResponse {
        let base = await baseURL
        guard let url = URL(string: "\(base)/training/models") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await performRequest(request)
    }

    func deleteTrainedModel(modelId: String) async throws -> StartTrainingResponse {
        let base = await baseURL
        guard let url = URL(string: "\(base)/training/models/\(modelId)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        return try await performRequest(request)
    }

    // MARK: - Private Helpers

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
