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
}

extension LocalModel {
    // MLX models from mlx-community (optimized for Apple Silicon)
    public static let mlxModels: [LocalModel] = [
        LocalModel(
            id: "smollm-135m-mlx",
            name: "SmolLM-135M-Instruct-4bit",
            displayName: "SmolLM 135M (Fastest)",
            size: "~79 MB",
            parameters: "135M",
            format: .mlx,
            downloadURL: URL(string: "https://huggingface.co/mlx-community/SmolLM-135M-Instruct-4bit")!,
            filename: "SmolLM-135M-Instruct-4bit",
            huggingFaceId: "mlx-community/SmolLM-135M-Instruct-4bit"
        ),
        LocalModel(
            id: "smollm-360m-mlx",
            name: "SmolLM-360M-Instruct-4bit",
            displayName: "SmolLM 360M",
            size: "~195 MB",
            parameters: "360M",
            format: .mlx,
            downloadURL: URL(string: "https://huggingface.co/mlx-community/SmolLM-360M-Instruct-4bit")!,
            filename: "SmolLM-360M-Instruct-4bit",
            huggingFaceId: "mlx-community/SmolLM-360M-Instruct-4bit"
        ),
        LocalModel(
            id: "smollm-1.7b-mlx",
            name: "SmolLM-1.7B-Instruct-4bit",
            displayName: "SmolLM 1.7B",
            size: "~920 MB",
            parameters: "1.7B",
            format: .mlx,
            downloadURL: URL(string: "https://huggingface.co/mlx-community/SmolLM-1.7B-Instruct-4bit")!,
            filename: "SmolLM-1.7B-Instruct-4bit",
            huggingFaceId: "mlx-community/SmolLM-1.7B-Instruct-4bit"
        ),
        LocalModel(
            id: "qwen2.5-0.5b-mlx",
            name: "Qwen2.5-0.5B-Instruct-4bit",
            displayName: "Qwen2.5 0.5B",
            size: "~350 MB",
            parameters: "0.5B",
            format: .mlx,
            downloadURL: URL(string: "https://huggingface.co/mlx-community/Qwen2.5-0.5B-Instruct-4bit")!,
            filename: "Qwen2.5-0.5B-Instruct-4bit",
            huggingFaceId: "mlx-community/Qwen2.5-0.5B-Instruct-4bit"
        ),
        LocalModel(
            id: "qwen2.5-1.5b-mlx",
            name: "Qwen2.5-1.5B-Instruct-4bit",
            displayName: "Qwen2.5 1.5B",
            size: "~950 MB",
            parameters: "1.5B",
            format: .mlx,
            downloadURL: URL(string: "https://huggingface.co/mlx-community/Qwen2.5-1.5B-Instruct-4bit")!,
            filename: "Qwen2.5-1.5B-Instruct-4bit",
            huggingFaceId: "mlx-community/Qwen2.5-1.5B-Instruct-4bit"
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
