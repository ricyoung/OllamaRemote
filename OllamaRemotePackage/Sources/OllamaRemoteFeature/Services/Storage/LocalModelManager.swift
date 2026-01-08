import Foundation
import MLXLMCommon

@Observable
@MainActor
public final class LocalModelManager {
    public static let shared = LocalModelManager()

    public private(set) var downloadProgress: [String: Double] = [:]
    public private(set) var downloadingModels: Set<String> = []
    public private(set) var downloadedModels: Set<String> = []

    private let downloadedModelsKey = "downloadedMLXModels"

    private init() {
        loadDownloadedModels()
    }

    public func isModelDownloaded(_ model: LocalModel) -> Bool {
        downloadedModels.contains(model.id)
    }

    /// Download an MLX model from HuggingFace
    public func downloadModel(_ model: LocalModel) async throws {
        guard model.format == .mlx else {
            throw LocalModelError.unsupportedFormat("Only MLX format models can be downloaded")
        }

        guard let huggingFaceId = model.huggingFaceId else {
            throw LocalModelError.missingHuggingFaceId
        }

        guard !downloadingModels.contains(model.id) else { return }

        downloadingModels.insert(model.id)
        downloadProgress[model.id] = 0

        do {
            // Use MLX's built-in model loading which handles HuggingFace downloads
            // This downloads and caches the model
            _ = try await loadModelContainer(id: huggingFaceId) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.downloadProgress[model.id] = progress.fractionCompleted
                }
            }

            // Mark as downloaded
            downloadedModels.insert(model.id)
            saveDownloadedModels()

        } catch {
            downloadingModels.remove(model.id)
            downloadProgress.removeValue(forKey: model.id)
            throw error
        }

        downloadingModels.remove(model.id)
        downloadProgress.removeValue(forKey: model.id)
    }

    public func cancelDownload(for model: LocalModel) {
        // MLX doesn't support download cancellation directly
        // Just update the UI state
        downloadingModels.remove(model.id)
        downloadProgress.removeValue(forKey: model.id)
    }

    public func deleteModel(_ model: LocalModel) throws {
        // For MLX models, we need to clear the cache
        // The MLX library caches models in its own directory
        // For now, just mark as not downloaded - user can clear app cache if needed
        downloadedModels.remove(model.id)
        saveDownloadedModels()

        // Try to find and delete the cached model directory
        if let huggingFaceId = model.huggingFaceId {
            tryDeleteMLXCache(for: huggingFaceId)
        }
    }

    private func tryDeleteMLXCache(for huggingFaceId: String) {
        // MLX caches models in Library/Caches/huggingface/hub/
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let hubDir = cacheDir.appendingPathComponent("huggingface/hub")

        // The model ID is converted to a directory format (e.g., mlx-community/SmolLM becomes models--mlx-community--SmolLM)
        let sanitizedId = huggingFaceId.replacingOccurrences(of: "/", with: "--")
        let modelDir = hubDir.appendingPathComponent("models--\(sanitizedId)")

        try? FileManager.default.removeItem(at: modelDir)
    }

    public func modelSize(_ model: LocalModel) -> String? {
        // Return the estimated size from the model definition
        return model.size
    }

    private func loadDownloadedModels() {
        if let savedModels = UserDefaults.standard.stringArray(forKey: downloadedModelsKey) {
            downloadedModels = Set(savedModels)
        }
    }

    private func saveDownloadedModels() {
        UserDefaults.standard.set(Array(downloadedModels), forKey: downloadedModelsKey)
    }
}

public enum LocalModelError: LocalizedError {
    case unsupportedFormat(String)
    case missingHuggingFaceId
    case downloadFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let reason):
            return "Unsupported format: \(reason)"
        case .missingHuggingFaceId:
            return "Model is missing HuggingFace ID"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        }
    }
}
