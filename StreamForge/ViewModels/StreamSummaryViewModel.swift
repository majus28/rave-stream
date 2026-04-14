import Foundation

final class StreamSummaryViewModel: ObservableObject {
    @Published var summary: PerformanceSummary?

    let session: StreamSession
    let performanceMonitor: PerformanceMonitor

    init(session: StreamSession, performanceMonitor: PerformanceMonitor) {
        self.session = session
        self.performanceMonitor = performanceMonitor
        self.summary = performanceMonitor.generateSummary()
    }

    var formattedDuration: String {
        guard let duration = session.duration else { return "N/A" }
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    var qualityScoreColor: String {
        guard let score = summary?.qualityScore else { return "gray" }
        if score >= 80 { return "green" }
        if score >= 60 { return "yellow" }
        return "red"
    }
}
