import Foundation

public enum DiagnosticsLevel: String, Codable, CaseIterable, Sendable {
    case info
    case warning
    case error
}

public struct DiagnosticsEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let category: String
    public let level: DiagnosticsLevel
    public let message: String
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: String,
        level: DiagnosticsLevel,
        message: String,
        metadata: [String: String]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.level = level
        self.message = message
        self.metadata = metadata
    }
}

public actor DiagnosticsStore {
    public static let shared = DiagnosticsStore()

    private enum Keys {
        static let diagnosticsEntries = "diagnosticsEntries"
    }

    private let maxEntries = 500
    private let defaults: UserDefaults
    private var entries: [DiagnosticsEntry] = []
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.diagnosticsEntries),
           let decoded = try? decoder.decode([DiagnosticsEntry].self, from: data) {
            entries = decoded
        }
    }

    public func record(
        category: String,
        level: DiagnosticsLevel = .info,
        message: String,
        metadata: [String: String] = [:]
    ) {
        let redactedMessage = Self.redactSecrets(in: message)
        let redactedMetadata = metadata.reduce(into: [String: String]()) { partialResult, item in
            partialResult[item.key] = Self.redactedMetadataValue(forKey: item.key, value: item.value)
        }

        let entry = DiagnosticsEntry(
            category: category,
            level: level,
            message: redactedMessage,
            metadata: redactedMetadata
        )

        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }

        persistEntries()
    }

    public func recentEntries(limit: Int = 200) -> [DiagnosticsEntry] {
        let safeLimit = max(1, limit)
        return Array(entries.suffix(safeLimit))
    }

    public func clear() {
        entries.removeAll()
        defaults.removeObject(forKey: Keys.diagnosticsEntries)
    }

    public func exportText(limit: Int = 300) -> String {
        let safeLimit = max(1, limit)
        let exportEntries = Array(entries.suffix(safeLimit))

        var lines: [String] = []
        lines.append("OllamaRemote Diagnostics Export")
        lines.append("Generated: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("Entries: \(exportEntries.count)")
        lines.append("Secrets: redacted (tokens, API keys, passwords, auth headers)")
        lines.append("")

        for entry in exportEntries {
            let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
            lines.append("[\(timestamp)] [\(entry.level.rawValue.uppercased())] [\(entry.category)] \(entry.message)")

            if !entry.metadata.isEmpty {
                let metadata = entry.metadata
                    .sorted { $0.key < $1.key }
                    .map { "\($0.key)=\($0.value)" }
                    .joined(separator: " ")
                lines.append("  \(metadata)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func persistEntries() {
        guard let data = try? encoder.encode(entries) else {
            return
        }
        defaults.set(data, forKey: Keys.diagnosticsEntries)
    }

    private static func redactedMetadataValue(forKey key: String, value: String) -> String {
        let sensitiveKeyTerms = ["token", "api", "key", "secret", "password", "authorization", "auth"]
        let lowerKey = key.lowercased()
        if sensitiveKeyTerms.contains(where: { lowerKey.contains($0) }) {
            return "[REDACTED]"
        }
        return redactSecrets(in: value)
    }

    private static func redactSecrets(in raw: String) -> String {
        var value = raw

        let bearerPattern = "(?i)(Bearer\\s+)([A-Za-z0-9._\\-]{8,})"
        value = replacingRegexMatches(in: value, pattern: bearerPattern, template: "$1[REDACTED]")

        let keyValuePattern = "(?i)(token|api[_-]?key|password|secret)\\s*[:=]\\s*([A-Za-z0-9._\\-]{8,})"
        value = replacingRegexMatches(in: value, pattern: keyValuePattern, template: "$1=[REDACTED]")

        let longHexPattern = "\\b[a-fA-F0-9]{24,}\\b"
        value = replacingRegexMatches(in: value, pattern: longHexPattern, template: "[REDACTED]")

        return value
    }

    private static func replacingRegexMatches(in value: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, options: [], range: range, withTemplate: template)
    }
}
