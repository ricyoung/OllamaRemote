import Foundation

public enum ModelFormat: String, Codable, Sendable {
    case gguf       // For llama.cpp (Metal GPU)
    case coreML     // For Neural Engine + GPU
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

    public init(
        id: String,
        name: String,
        displayName: String,
        size: String,
        parameters: String,
        format: ModelFormat = .coreML,
        downloadURL: URL,
        filename: String,
        tokenizerURL: URL? = nil
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
    }
}

extension LocalModel {
    // Core ML models optimized for Neural Engine
    public static let coreMLModels: [LocalModel] = [
        LocalModel(
            id: "openelm-270m-coreml",
            name: "OpenELM-270M-Instruct",
            displayName: "Apple OpenELM 270M",
            size: "270 MB",
            parameters: "270M",
            format: .coreML,
            downloadURL: URL(string: "https://huggingface.co/apple/OpenELM-270M-Instruct/resolve/main/coreml/OpenELM-270M-Instruct.mlpackage.zip")!,
            filename: "OpenELM-270M-Instruct.mlpackage",
            tokenizerURL: URL(string: "https://huggingface.co/apple/OpenELM-270M-Instruct/resolve/main/tokenizer.json")
        ),
        LocalModel(
            id: "openelm-450m-coreml",
            name: "OpenELM-450M-Instruct",
            displayName: "Apple OpenELM 450M",
            size: "450 MB",
            parameters: "450M",
            format: .coreML,
            downloadURL: URL(string: "https://huggingface.co/apple/OpenELM-450M-Instruct/resolve/main/coreml/OpenELM-450M-Instruct.mlpackage.zip")!,
            filename: "OpenELM-450M-Instruct.mlpackage",
            tokenizerURL: URL(string: "https://huggingface.co/apple/OpenELM-450M-Instruct/resolve/main/tokenizer.json")
        ),
        LocalModel(
            id: "openelm-1b-coreml",
            name: "OpenELM-1_1B-Instruct",
            displayName: "Apple OpenELM 1.1B",
            size: "1.1 GB",
            parameters: "1.1B",
            format: .coreML,
            downloadURL: URL(string: "https://huggingface.co/apple/OpenELM-1_1B-Instruct/resolve/main/coreml/OpenELM-1_1B-Instruct.mlpackage.zip")!,
            filename: "OpenELM-1_1B-Instruct.mlpackage",
            tokenizerURL: URL(string: "https://huggingface.co/apple/OpenELM-1_1B-Instruct/resolve/main/tokenizer.json")
        ),
        LocalModel(
            id: "smollm-135m-coreml",
            name: "SmolLM-135M-Instruct",
            displayName: "SmolLM 135M (Fastest)",
            size: "135 MB",
            parameters: "135M",
            format: .coreML,
            downloadURL: URL(string: "https://huggingface.co/HuggingFaceTB/SmolLM-135M-Instruct/resolve/main/coreml/SmolLM-135M-Instruct.mlpackage.zip")!,
            filename: "SmolLM-135M-Instruct.mlpackage",
            tokenizerURL: URL(string: "https://huggingface.co/HuggingFaceTB/SmolLM-135M-Instruct/resolve/main/tokenizer.json")
        )
    ]

    // GGUF models for llama.cpp (Metal GPU fallback)
    public static let ggufModels: [LocalModel] = [
        LocalModel(
            id: "qwen2-0.5b-gguf",
            name: "Qwen2-0.5B-Instruct",
            displayName: "Qwen2 0.5B (GGUF)",
            size: "395 MB",
            parameters: "0.5B",
            format: .gguf,
            downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen2-0.5B-Instruct-GGUF/resolve/main/qwen2-0_5b-instruct-q4_k_m.gguf")!,
            filename: "qwen2-0_5b-instruct-q4_k_m.gguf"
        ),
        LocalModel(
            id: "tinyllama-1.1b-gguf",
            name: "TinyLlama-1.1B-Chat",
            displayName: "TinyLlama 1.1B (GGUF)",
            size: "637 MB",
            parameters: "1.1B",
            format: .gguf,
            downloadURL: URL(string: "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf")!,
            filename: "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
        )
    ]

    public static var availableModels: [LocalModel] {
        // Only Core ML models are currently supported
        // GGUF models require llama.cpp integration (coming in future update)
        coreMLModels
    }
}
