import Foundation

struct PingSample: Equatable {
    let date: Date
    let ms: Double
}

/// Rolling window of ping samples for sparkline display.
final class PingHistory {

    static let window: TimeInterval = 30 * 60

    private var samples: [PingSample] = []

    var currentSamples: [PingSample] {
        prune()
        return samples
    }

    func record(_ ms: Double, at date: Date = Date()) {
        prune(before: date)
        samples.append(PingSample(date: date, ms: ms))
    }

    func reset() {
        samples.removeAll()
    }

    @discardableResult
    private func prune(before now: Date = Date()) -> [PingSample] {
        let cutoff = now.addingTimeInterval(-Self.window)
        samples.removeAll { $0.date < cutoff }
        return samples
    }
}
