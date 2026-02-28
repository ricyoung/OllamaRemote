import SwiftUI

public struct DiagnosticsView: View {
    @State private var entries: [DiagnosticsEntry] = []
    @State private var exportText: String = ""
    @State private var showExportSheet = false
    @State private var showClearConfirmation = false
    @State private var isRefreshing = false

    public init() {}

    public var body: some View {
        List {
            Section("Privacy") {
                Text("Sensitive values are automatically redacted before display and export (Bearer tokens, API keys, passwords, auth headers).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    Task { await refresh() }
                } label: {
                    HStack {
                        Text("Refresh")
                        Spacer()
                        if isRefreshing {
                            ProgressView()
                        }
                    }
                }
                .disabled(isRefreshing)

                Button("Export Diagnostics") {
                    Task {
                        exportText = await DiagnosticsStore.shared.exportText()
                        showExportSheet = true
                    }
                }

                Button("Clear Diagnostics", role: .destructive) {
                    showClearConfirmation = true
                }
            }

            Section("Recent Events") {
                if entries.isEmpty {
                    Text("No diagnostics captured yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entries.reversed()) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(entry.level.rawValue.uppercased())
                                    .font(.caption2)
                                    .foregroundStyle(levelColor(entry.level))
                            }

                            Text("[\(entry.category)] \(entry.message)")
                                .font(.callout)
                                .textSelection(.enabled)

                            if !entry.metadata.isEmpty {
                                Text(
                                    entry.metadata
                                        .sorted { $0.key < $1.key }
                                        .map { "\($0.key)=\($0.value)" }
                                        .joined(separator: " ")
                                )
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Diagnostics")
        .sheet(isPresented: $showExportSheet) {
            ShareSheet(items: [exportText])
        }
        .confirmationDialog(
            "Clear Diagnostics",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) {
                Task {
                    await DiagnosticsStore.shared.clear()
                    await refresh()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all local diagnostics entries from this device.")
        }
        .task {
            await refresh()
        }
    }

    private func refresh() async {
        isRefreshing = true
        entries = await DiagnosticsStore.shared.recentEntries(limit: 300)
        isRefreshing = false
    }

    private func levelColor(_ level: DiagnosticsLevel) -> Color {
        switch level {
        case .info:
            .blue
        case .warning:
            .orange
        case .error:
            .red
        }
    }
}
