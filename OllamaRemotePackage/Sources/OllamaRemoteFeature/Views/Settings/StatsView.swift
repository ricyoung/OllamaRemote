import SwiftUI
import SwiftData

public struct StatsView: View {
    @Query private var conversations: [Conversation]
    @State private var stats: UsageStats?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Streak Card
                streakCard

                // Quick Stats Grid
                quickStatsGrid

                // Activity Insights
                activityInsights

                // Provider Breakdown
                providerBreakdown
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Your Stats")
        .onAppear {
            stats = StatsService.shared.calculateStats(from: conversations)
        }
    }

    @ViewBuilder
    private var streakCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange.gradient)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(stats?.currentStreak ?? 0)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))

                    Text("Day Streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(stats?.longestStreak ?? 0)")
                        .font(.title2.bold())
                        .foregroundStyle(.orange)
                    Text("Best")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Streak visualization
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { day in
                    Circle()
                        .fill(day < (stats?.currentStreak ?? 0) ? Color.orange : Color(.systemGray4))
                        .frame(width: 12, height: 12)
                }
                Spacer()
                Text("Keep it going!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var quickStatsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                icon: "bubble.left.and.bubble.right.fill",
                iconColor: .blue,
                value: "\(stats?.totalConversations ?? 0)",
                label: "Conversations"
            )

            StatCard(
                icon: "text.bubble.fill",
                iconColor: .green,
                value: "\(stats?.totalMessages ?? 0)",
                label: "Total Messages"
            )

            StatCard(
                icon: "person.fill",
                iconColor: .purple,
                value: "\(stats?.userMessages ?? 0)",
                label: "You Sent"
            )

            StatCard(
                icon: "cpu.fill",
                iconColor: .cyan,
                value: "\(stats?.aiResponses ?? 0)",
                label: "AI Responses"
            )
        }
    }

    @ViewBuilder
    private var activityInsights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Insights")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                if let avg = stats?.messagesPerDay {
                    InsightRow(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: .green,
                        title: "Daily Average",
                        value: String(format: "%.1f messages", avg)
                    )
                    Divider().padding(.leading, 44)
                }

                if let hour = stats?.mostActiveHourFormatted {
                    InsightRow(
                        icon: "clock.fill",
                        iconColor: .orange,
                        title: "Most Active Time",
                        value: hour
                    )
                    Divider().padding(.leading, 44)
                }

                if let day = stats?.mostActiveDayFormatted {
                    InsightRow(
                        icon: "calendar",
                        iconColor: .blue,
                        title: "Most Active Day",
                        value: day
                    )
                    Divider().padding(.leading, 44)
                }

                if let since = stats?.memberSinceFormatted {
                    InsightRow(
                        icon: "star.fill",
                        iconColor: .yellow,
                        title: "Member Since",
                        value: since
                    )
                }
            }
            .padding(.vertical, 4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var providerBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Provider Usage")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(providerStats, id: \.type) { stat in
                    HStack {
                        Image(systemName: stat.type.iconName)
                            .font(.title3)
                            .foregroundStyle(providerColor(stat.type))
                            .frame(width: 32)

                        Text(stat.type.displayName)
                            .font(.subheadline)

                        Spacer()

                        Text("\(stat.count) msgs")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // Progress bar
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(providerColor(stat.type).opacity(0.3))
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(providerColor(stat.type))
                                        .frame(width: geo.size.width * stat.percentage)
                                }
                        }
                        .frame(width: 60, height: 8)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    if stat.type != providerStats.last?.type {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var providerStats: [ProviderStat] {
        var counts: [ProviderType: Int] = [:]
        for conv in conversations {
            counts[conv.providerType, default: 0] += conv.messages.count
        }

        let total = max(counts.values.reduce(0, +), 1)

        return counts.map { type, count in
            ProviderStat(type: type, count: count, percentage: Double(count) / Double(total))
        }.sorted { $0.count > $1.count }
    }

    private func providerColor(_ type: ProviderType) -> Color {
        switch type {
        case .appleIntelligence: return .indigo
        case .onDevice: return .purple
        case .localOllama: return .blue
        case .ollamaCloud: return .cyan
        case .openRouter: return .orange
        }
    }
}

private struct ProviderStat {
    let type: ProviderType
    let count: Int
    let percentage: Double
}

private struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor.gradient)

            Text(value)
                .font(.title.bold())

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct InsightRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            Text(title)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
