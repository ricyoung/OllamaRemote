import Foundation

public enum ModelFormat: String, Codable, Sendable {
    case gguf       // For llama.cpp (Metal GPU)
    case coreML     // For Neural Engine + GPU
    case mlx        // For MLX Swift (Apple Silicon)
}

public struct LocalModel: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let displayName: String
    public let size: String
    public let parameters: String
    public let format: ModelFormat
    public let downloadURL: URL
    public let filename: String
    public let tokenizerURL: URL?
    public let huggingFaceId: String? // For MLX models

    public init(
        id: String,
        name: String,
        displayName: String,
        size: String,
        parameters: String,
        format: ModelFormat = .coreML,
        downloadURL: URL,
        filename: String,
        tokenizerURL: URL? = nil,
        huggingFaceId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.size = size
        self.parameters = parameters
        self.format = format
        self.downloadURL = downloadURL
        self.filename = filename
        self.tokenizerURL = tokenizerURL
        self.huggingFaceId = huggingFaceId
    }

    /// URL to the model's HuggingFace page
    public var huggingFaceURL: URL? {
        guard let huggingFaceId else { return nil }
        return URL(string: "https://huggingface.co/\(huggingFaceId)")
    }
}

extension LocalModel {
    // MLX models from mlx-community (optimized for Apple Silicon)
    // Ranked by quality and popularity - no Llama models per user preference
    public static let mlxModels: [LocalModel] = [
        // === Tier 1: Ultra Light (<500MB) - Fast responses ===
        LocalModel(
            id: "qwen3-0.6b-mlx",
            name: "Qwen3-0.6B-4bit",
            displayName: "Qwen3 0.6B (Fastest)",
            size: "~400 MB",
            parameters: "0.6B",
            format: .mlx,
            downloadURL: URL(string: "https://huggingface.co/mlx-community/Qwen3-0.6B-4bit")!,
            filename: "Qwen3-0.6B-4bit",
            huggingFaceId: "mlx-community/Qwen3-0.6B-4bit"
        ),
        LocalModel(
            id: "smollm2-360m-mlx",
            name: "SmolLM2-360M-Instruct-4bit",
            displayName: "SmolLM2 360M",
            size: "~200 MB",
            parameters: "360M",
            format: .mlx,
            downloadURL: URL(string: "https://huggingface.co/mlx-community/SmolLM2-360M-Instruct-4bit")!,
            filename: "SmolLM2-360M-Instruct-4bit",
            huggingFaceId: "mlx-community/SmolLM2-360M-Instruct-4bit"
        ),

        // === Tier 2: Balanced (~1GB) - Best quality/size ratio ===
        LocalModel(
            id: "qwen3-1.7b-mlx",
            name: "Qwen3-1.7B-4bit",
            displayName: "Qwen3 1.7B",
            size: "~1.0 GB",
            parameters: "1.7B",
            format: .mlx,
            downloadURL: URL(string: "https://huggingface.co/mlx-community/Qwen3-1.7B-4bit")!,
            filename: "Qwen3-1.7B-4bit",
            huggingFaceId: "mlx-community/Qwen3-1.7B-4bit"
        ),
        LocalModel(
            id: "gemma3-1b-mlx",
            name: "gemma-3-1b-it-qat-4bit",
            displayName: "Gemma 3 1B",
            size: "~600 MB",
            parameters: "1B",
            format: .mlx,
            downloadURL: URL(string: "https://huggingface.co/mlx-community/gemma-3-1b-it-qat-4bit")!,
            filename: "gemma-3-1b-it-qat-4bit",
            huggingFaceId: "mlx-community/gemma-3-1b-it-qat-4bit"
        ),

        // === Tier 3: High Quality (~2-3GB) - Best responses ===
        LocalModel(
            id: "qwen3-4b-mlx",
            name: "Qwen3-4B-4bit",
            displayName: "Qwen3 4B",
            size: "~2.5 GB",
            parameters: "4B",
            format: .mlx,
            downloadURL: URL(string: "https://huggingface.co/mlx-community/Qwen3-4B-4bit")!,
            filename: "Qwen3-4B-4bit",
            huggingFaceId: "mlx-community/Qwen3-4B-4bit"
        ),
        LocalModel(
            id: "gemma3-4b-mlx",
            name: "gemma-3-4b-it-qat-4bit",
            displayName: "Gemma 3 4B",
            size: "~2.5 GB",
            parameters: "4B",
            format: .mlx,
            downloadURL: URL(string: "https://huggingface.co/mlx-community/gemma-3-4b-it-qat-4bit")!,
            filename: "gemma-3-4b-it-qat-4bit",
            huggingFaceId: "mlx-community/gemma-3-4b-it-qat-4bit"
        ),
        LocalModel(
            id: "ministral-3b-mlx",
            name: "Ministral-3-3B-Instruct-2512-4bit",
            displayName: "Ministral 3B",
            size: "~1.8 GB",
            parameters: "3B",
            format: .mlx,
            downloadURL: URL(string: "https://huggingface.co/mlx-community/Ministral-3-3B-Instruct-2512-4bit")!,
            filename: "Ministral-3-3B-Instruct-2512-4bit",
            huggingFaceId: "mlx-community/Ministral-3-3B-Instruct-2512-4bit"
        ),

        // === Tier 4: Premium (~4GB+) - Maximum quality ===
        LocalModel(
            id: "gemma3-12b-mlx",
            name: "gemma-3-12b-it-qat-4bit",
            displayName: "Gemma 3 12B (Best)",
            size: "~7.0 GB",
            parameters: "12B",
            format: .mlx,
            downloadURL: URL(string: "https://huggingface.co/mlx-community/gemma-3-12b-it-qat-4bit")!,
            filename: "gemma-3-12b-it-qat-4bit",
            huggingFaceId: "mlx-community/gemma-3-12b-it-qat-4bit"
        )
    ]

    // Legacy Core ML models (deprecated in favor of MLX)
    public static let coreMLModels: [LocalModel] = []

    // Legacy GGUF models (requires llama.cpp integration)
    public static let ggufModels: [LocalModel] = []

    public static var availableModels: [LocalModel] {
        // MLX models are the primary on-device option
        mlxModels
    }
}
