import Foundation
import SwiftData

@MainActor
public final class StatsService {
    public static let shared = StatsService()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let lastActiveDate = "stats_lastActiveDate"
        static let currentStreak = "stats_currentStreak"
        static let longestStreak = "stats_longestStreak"
        static let totalSessions = "stats_totalSessions"
    }

    private init() {}

    // MARK: - Streak Tracking

    public func recordActivity() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastActive = defaults.object(forKey: Keys.lastActiveDate) as? Date

        if let lastActive = lastActive {
            let lastActiveDay = Calendar.current.startOfDay(for: lastActive)
            let daysDiff = Calendar.current.dateComponents([.day], from: lastActiveDay, to: today).day ?? 0

            if daysDiff == 0 {
                // Same day, no change
                return
            } else if daysDiff == 1 {
                // Consecutive day - increment streak
                let currentStreak = defaults.integer(forKey: Keys.currentStreak) + 1
                defaults.set(currentStreak, forKey: Keys.currentStreak)

                let longestStreak = defaults.integer(forKey: Keys.longestStreak)
                if currentStreak > longestStreak {
                    defaults.set(currentStreak, forKey: Keys.longestStreak)
                }
            } else {
                // Streak broken - reset to 1
                defaults.set(1, forKey: Keys.currentStreak)
            }
        } else {
            // First time - start streak at 1
            defaults.set(1, forKey: Keys.currentStreak)
            defaults.set(1, forKey: Keys.longestStreak)
        }

        defaults.set(today, forKey: Keys.lastActiveDate)
        defaults.set(defaults.integer(forKey: Keys.totalSessions) + 1, forKey: Keys.totalSessions)
    }

    public var currentStreak: Int {
        // Check if streak is still valid (used app yesterday or today)
        guard let lastActive = defaults.object(forKey: Keys.lastActiveDate) as? Date else {
            return 0
        }

        let today = Calendar.current.startOfDay(for: Date())
        let lastActiveDay = Calendar.current.startOfDay(for: lastActive)
        let daysDiff = Calendar.current.dateComponents([.day], from: lastActiveDay, to: today).day ?? 0

        if daysDiff > 1 {
            // Streak is broken
            return 0
        }

        return defaults.integer(forKey: Keys.currentStreak)
    }

    public var longestStreak: Int {
        defaults.integer(forKey: Keys.longestStreak)
    }

    public var totalSessions: Int {
        defaults.integer(forKey: Keys.totalSessions)
    }

    // MARK: - Conversation Stats

    public func calculateStats(from conversations: [Conversation]) -> UsageStats {
        let totalConversations = conversations.count
        let totalMessages = conversations.reduce(0) { $0 + $1.messages.count }
        let userMessages = conversations.reduce(0) { total, conv in
            total + conv.messages.filter { $0.role == .user }.count
        }
        let aiResponses = totalMessages - userMessages

        // Find favorite provider
        var providerCounts: [ProviderType: Int] = [:]
        for conv in conversations {
            providerCounts[conv.providerType, default: 0] += conv.messages.count
        }
        let favoriteProvider = providerCounts.max(by: { $0.value < $1.value })?.key

        // Calculate messages per day (last 7 days)
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentMessages = conversations.flatMap { $0.messages }.filter { $0.timestamp >= sevenDaysAgo }
        let messagesPerDay = Double(recentMessages.count) / 7.0

        // Find most active hour
        var hourCounts: [Int: Int] = [:]
        for conv in conversations {
            for message in conv.messages {
                let hour = Calendar.current.component(.hour, from: message.timestamp)
                hourCounts[hour, default: 0] += 1
            }
        }
        let mostActiveHour = hourCounts.max(by: { $0.value < $1.value })?.key

        // Find most active day of week
        var dayCounts: [Int: Int] = [:]
        for conv in conversations {
            for message in conv.messages {
                let weekday = Calendar.current.component(.weekday, from: message.timestamp)
                dayCounts[weekday, default: 0] += 1
            }
        }
        let mostActiveDay = dayCounts.max(by: { $0.value < $1.value })?.key

        // Get first message date
        let allMessages = conversations.flatMap { $0.messages }
        let firstMessageDate = allMessages.map { $0.timestamp }.min()

        return UsageStats(
            totalConversations: totalConversations,
            totalMessages: totalMessages,
            userMessages: userMessages,
            aiResponses: aiResponses,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            favoriteProvider: favoriteProvider,
            messagesPerDay: messagesPerDay,
            mostActiveHour: mostActiveHour,
            mostActiveDay: mostActiveDay,
            memberSince: firstMessageDate
        )
    }
}

public struct UsageStats {
    public let totalConversations: Int
    public let totalMessages: Int
    public let userMessages: Int
    public let aiResponses: Int
    public let currentStreak: Int
    public let longestStreak: Int
    public let favoriteProvider: ProviderType?
    public let messagesPerDay: Double
    public let mostActiveHour: Int?
    public let mostActiveDay: Int?
    public let memberSince: Date?

    public var mostActiveHourFormatted: String? {
        guard let hour = mostActiveHour else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        var components = DateComponents()
        components.hour = hour
        guard let date = Calendar.current.date(from: components) else { return nil }
        return formatter.string(from: date).lowercased()
    }

    public var mostActiveDayFormatted: String? {
        guard let day = mostActiveDay else { return nil }
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[day - 1]
    }

    public var memberSinceFormatted: String? {
        guard let date = memberSince else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
