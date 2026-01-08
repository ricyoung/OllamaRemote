import SwiftUI

public struct LocalModelsView: View {
    @State private var modelManager = LocalModelManager.shared
    @State private var showDeleteConfirmation = false
    @State private var modelToDelete: LocalModel?
    @State private var downloadError: String?

    public init() {}

    public var body: some View {
        List {
            Section {
                ForEach(LocalModel.mlxModels) { model in
                    ModelRowView(
                        model: model,
                        modelManager: modelManager,
                        onDownload: { await downloadModel(model) },
                        onDelete: { confirmDelete(model) }
                    )
                }
            } header: {
                Label("MLX Models (Apple Silicon)", systemImage: "bolt.fill")
            } footer: {
                Text("Optimized for Apple Silicon. Models are downloaded from Hugging Face and run locally using MLX.")
            }

            if !modelManager.downloadedModels.isEmpty {
                Section("Storage") {
                    HStack {
                        Text("Downloaded Models")
                        Spacer()
                        Text("\(modelManager.downloadedModels.count)")
                            .foregroundStyle(.secondary)
                    }

                    let totalSize = calculateTotalSize()
                    HStack {
                        Text("Total Size")
                        Spacer()
                        Text(totalSize)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("MLX Powered", systemImage: "bolt.fill")
                        .font(.headline)
                        .foregroundStyle(.tint)

                    Text("MLX models run efficiently on Apple Silicon. All processing happens locally on your device with no data sent externally.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Local Models")
        .alert("Delete Model", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    deleteModel(model)
                }
            }
        } message: {
            if let model = modelToDelete {
                Text("Delete \(model.displayName)? This will free up storage space.")
            }
        }
        .alert("Download Error", isPresented: .constant(downloadError != nil)) {
            Button("OK") {
                downloadError = nil
            }
        } message: {
            if let error = downloadError {
                Text(error)
            }
        }
    }

    private func downloadModel(_ model: LocalModel) async {
        do {
            try await modelManager.downloadModel(model)
        } catch {
            downloadError = error.localizedDescription
        }
    }

    private func confirmDelete(_ model: LocalModel) {
        modelToDelete = model
        showDeleteConfirmation = true
    }

    private func deleteModel(_ model: LocalModel) {
        try? modelManager.deleteModel(model)
        modelToDelete = nil
    }

    private func calculateTotalSize() -> String {
        var totalBytes: Int64 = 0
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsPath = documentsPath.appendingPathComponent("Models", isDirectory: true)

        for model in LocalModel.availableModels where modelManager.downloadedModels.contains(model.id) {
            let path = modelsPath.appendingPathComponent(model.filename)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
               let size = attrs[.size] as? Int64 {
                totalBytes += size
            }
        }

        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
}

struct ModelRowView: View {
    let model: LocalModel
    let modelManager: LocalModelManager
    let onDownload: () async -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.headline)

                    HStack(spacing: 8) {
                        Text(model.parameters)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.1), in: Capsule())

                        Text(model.size)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                actionButton
            }

            if modelManager.downloadingModels.contains(model.id) {
                ProgressView(value: modelManager.downloadProgress[model.id] ?? 0) {
                    Text("\(Int((modelManager.downloadProgress[model.id] ?? 0) * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionButton: some View {
        if modelManager.downloadingModels.contains(model.id) {
            Button {
                modelManager.cancelDownload(for: model)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        } else if modelManager.downloadedModels.contains(model.id) {
            Menu {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Downloaded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Button {
                Task {
                    await onDownload()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                    Text("Download")
                        .font(.caption)
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
    }
}
