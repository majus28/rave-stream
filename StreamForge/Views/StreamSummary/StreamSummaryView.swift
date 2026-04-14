import SwiftUI

struct StreamSummaryView: View {
    @ObservedObject var viewModel: StreamSummaryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Quality score
                    if let summary = viewModel.summary {
                        qualityScoreCard(summary)
                        statsGrid(summary)
                        issuesSection(summary)
                        suggestionsSection(summary)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Stream Summary")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func qualityScoreCard(_ summary: PerformanceSummary) -> some View {
        VStack(spacing: 8) {
            Text("Quality Score")
                .font(.subheadline)
                .foregroundColor(.gray)

            Text("\(summary.qualityScore)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(scoreColor(summary.qualityScore))

            Text(scoreLabel(summary.qualityScore))
                .font(.headline)
                .foregroundColor(scoreColor(summary.qualityScore))

            Text("Duration: \(viewModel.formattedDuration)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(16)
    }

    private func statsGrid(_ summary: PerformanceSummary) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(title: "Avg Bitrate", value: "\(summary.averageBitrate) Kbps", icon: "arrow.up.circle")
            StatCard(title: "Dropped Frames", value: "\(summary.totalDroppedFrames)", icon: "drop.triangle")
            StatCard(title: "Reconnects", value: "\(summary.reconnectCount)", icon: "arrow.clockwise")
            StatCard(title: "Peak Thermal", value: summary.peakThermalState.displayName, icon: summary.peakThermalState.iconName)
        }
    }

    private func issuesSection(_ summary: PerformanceSummary) -> some View {
        Group {
            if !summary.topIssues.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Issues")
                        .font(.headline)
                        .foregroundColor(.white)

                    ForEach(summary.topIssues, id: \.self) { issue in
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(issue)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6).opacity(0.15))
                .cornerRadius(12)
            }
        }
    }

    private func suggestionsSection(_ summary: PerformanceSummary) -> some View {
        Group {
            if !summary.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggestions for Next Time")
                        .font(.headline)
                        .foregroundColor(.white)

                    ForEach(summary.suggestions, id: \.self) { suggestion in
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6).opacity(0.15))
                .cornerRadius(12)
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .red
    }

    private func scoreLabel(_ score: Int) -> String {
        if score >= 90 { return "Excellent" }
        if score >= 80 { return "Great" }
        if score >= 60 { return "Fair" }
        return "Needs Improvement"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)

            Text(value)
                .font(.headline)
                .foregroundColor(.white)

            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(10)
    }
}
