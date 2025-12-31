import Foundation

@Observable
@MainActor
public final class LocalModelManager {
    public static let shared = LocalModelManager()

    public private(set) var downloadProgress: [String: Double] = [:]
    public private(set) var downloadingModels: Set<String> = []
    public private(set) var downloadedModels: Set<String> = []

    private var downloadTasks: [String: URLSessionDownloadTask] = [:]

    private var modelsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsPath = documentsPath.appendingPathComponent("Models", isDirectory: true)

        if !FileManager.default.fileExists(atPath: modelsPath.path) {
            try? FileManager.default.createDirectory(at: modelsPath, withIntermediateDirectories: true)
        }

        return modelsPath
    }

    private init() {
        loadDownloadedModels()
    }

    public func isModelDownloaded(_ model: LocalModel) -> Bool {
        downloadedModels.contains(model.id)
    }

    public func localPath(for model: LocalModel) -> URL? {
        let path = modelsDirectory.appendingPathComponent(model.filename)
        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }

    public func downloadModel(_ model: LocalModel) async throws {
        guard !downloadingModels.contains(model.id) else { return }

        downloadingModels.insert(model.id)
        downloadProgress[model.id] = 0

        let destinationURL = modelsDirectory.appendingPathComponent(model.filename)

        // Remove existing file if any
        try? FileManager.default.removeItem(at: destinationURL)

        let (tempURL, _) = try await downloadWithProgress(from: model.downloadURL, modelId: model.id)

        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        downloadedModels.insert(model.id)
        downloadingModels.remove(model.id)
        downloadProgress.removeValue(forKey: model.id)

        saveDownloadedModels()
    }

    private func downloadWithProgress(from url: URL, modelId: String) async throws -> (URL, URLResponse) {
        let request = URLRequest(url: url)

        return try await withCheckedThrowingContinuation { continuation in
            let session = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)

            let task = session.downloadTask(with: request) { [weak self] tempURL, response, error in
                Task { @MainActor in
                    self?.downloadTasks.removeValue(forKey: modelId)
                }

                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let tempURL = tempURL, let response = response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }

                // Move to a temp location we control
                let newTempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                do {
                    try FileManager.default.moveItem(at: tempURL, to: newTempURL)
                    continuation.resume(returning: (newTempURL, response))
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            // Observe progress
            let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                Task { @MainActor in
                    self?.downloadProgress[modelId] = progress.fractionCompleted
                }
            }

            // Store reference to prevent deallocation
            objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN)

            downloadTasks[modelId] = task
            task.resume()
        }
    }

    public func cancelDownload(for model: LocalModel) {
        downloadTasks[model.id]?.cancel()
        downloadTasks.removeValue(forKey: model.id)
        downloadingModels.remove(model.id)
        downloadProgress.removeValue(forKey: model.id)
    }

    public func deleteModel(_ model: LocalModel) throws {
        let path = modelsDirectory.appendingPathComponent(model.filename)
        try FileManager.default.removeItem(at: path)
        downloadedModels.remove(model.id)
        saveDownloadedModels()
    }

    public func modelSize(_ model: LocalModel) -> String? {
        guard let path = localPath(for: model) else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: path.path)
        guard let size = attributes?[.size] as? Int64 else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func loadDownloadedModels() {
        let models = LocalModel.availableModels
        for model in models {
            let path = modelsDirectory.appendingPathComponent(model.filename)
            if FileManager.default.fileExists(atPath: path.path) {
                downloadedModels.insert(model.id)
            }
        }
    }

    private func saveDownloadedModels() {
        // Models are tracked by file existence, no separate persistence needed
    }
}
