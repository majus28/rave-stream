import Foundation

enum StreamLogger {
    enum Category: String {
        case capture = "📷 CAPTURE"
        case encode  = "🎬 ENCODE"
        case rtmp    = "📡 RTMP"
        case audio   = "🔊 AUDIO"
        case stream  = "🔴 STREAM"
        case perf    = "📊 PERF"
    }

    static func log(_ category: Category, _ message: String) {
        let timestamp = Self.timestamp()
        print("[\(timestamp)] [\(category.rawValue)] \(message)")
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private static func timestamp() -> String {
        formatter.string(from: Date())
    }
}
