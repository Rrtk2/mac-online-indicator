import AppKit

/// Compact sparkline of ping latency over the last thirty minutes.
final class MenuPingChartView: NSView {

    private var samples: [PingSample] = []

    private let avgLabel = NSTextField(labelWithString: menuNoValue)
    private let maxLabel = NSTextField(labelWithString: menuNoValue)

    private let statsWidth: CGFloat = 56

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer       = true
        autoresizingMask = .width

        for label in [avgLabel, maxLabel] {
            label.font      = .systemFont(ofSize: 9, weight: .medium)
            label.textColor = .tertiaryLabelColor
            label.alignment = .right
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }

        NSLayoutConstraint.activate([
            avgLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -MenuLayout.heroLeadingPadding),
            avgLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            maxLabel.trailingAnchor.constraint(equalTo: avgLabel.trailingAnchor),
            maxLabel.topAnchor.constraint(equalTo: avgLabel.bottomAnchor, constant: 2),
        ])
    }

    func update(samples: [PingSample]) {
        self.samples = samples
        updateStats()
        needsDisplay = true
    }

    func reset() {
        samples = []
        avgLabel.stringValue = menuNoValue
        maxLabel.stringValue = menuNoValue
        needsDisplay = true
    }

    private func visibleSamples() -> [PingSample] {
        let windowStart = Date().addingTimeInterval(-PingHistory.window)
        return samples.filter { $0.date >= windowStart }
    }

    private func updateStats() {
        let visible = visibleSamples()
        guard !visible.isEmpty else {
            avgLabel.stringValue = menuNoValue
            maxLabel.stringValue = menuNoValue
            return
        }
        let msValues = visible.map(\.ms)
        let avg = msValues.reduce(0, +) / Double(msValues.count)
        let max = msValues.max() ?? 0
        avgLabel.stringValue = String(format: "avg %.0f", avg)
        maxLabel.stringValue = String(format: "max %.0f", max)
    }

    private var chartRect: NSRect {
        NSRect(
            x: MenuLayout.heroLeadingPadding,
            y: 8,
            width: bounds.width - MenuLayout.heroLeadingPadding - statsWidth - 8,
            height: bounds.height - 16
        )
    }

    private enum PingThreshold {
        static let good: Double = 50
        static let fair: Double = 100
    }

    private func color(for ms: Double) -> NSColor {
        switch ms {
        case ..<PingThreshold.good: return .systemGreen
        case ..<PingThreshold.fair: return .systemOrange
        default:                    return .systemRed
        }
    }

    private func segmentColor(ms1: Double, ms2: Double) -> NSColor {
        color(for: max(ms1, ms2))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let chartRect = chartRect
        guard chartRect.width > 0, chartRect.height > 0 else { return }

        let visible = visibleSamples()
        guard !visible.isEmpty else { return }

        let now = Date()
        let windowStart = now.addingTimeInterval(-PingHistory.window)

        let msValues = visible.map(\.ms)
        var minMs = msValues.min() ?? 0
        var maxMs = msValues.max() ?? 0
        if minMs == maxMs {
            minMs = max(0, minMs - 10)
            maxMs += 10
        } else {
            let pad = max(2, (maxMs - minMs) * 0.12)
            minMs = max(0, minMs - pad)
            maxMs += pad
        }
        let range = maxMs - minMs

        func point(for sample: PingSample) -> NSPoint {
            let t = sample.date.timeIntervalSince(windowStart) / PingHistory.window
            let x = chartRect.minX + CGFloat(t.clamped(to: 0...1)) * chartRect.width
            let yNorm = (sample.ms - minMs) / range
            let y = chartRect.maxY - CGFloat(yNorm.clamped(to: 0...1)) * chartRect.height
            return NSPoint(x: x, y: y)
        }

        let plotted = visible.map { (sample: $0, point: point(for: $0)) }

        if plotted.count == 1 {
            let sample = plotted[0]
            let segColor = color(for: sample.sample.ms)
            let dot = NSBezierPath(ovalIn: NSRect(x: sample.point.x - 2, y: sample.point.y - 2, width: 4, height: 4))
            segColor.setFill()
            dot.fill()
            return
        }

        for index in 0..<(plotted.count - 1) {
            let start = plotted[index]
            let end = plotted[index + 1]
            let segColor = segmentColor(ms1: start.sample.ms, ms2: end.sample.ms)

            let fillPath = NSBezierPath()
            fillPath.move(to: NSPoint(x: start.point.x, y: chartRect.maxY))
            fillPath.line(to: start.point)
            fillPath.line(to: end.point)
            fillPath.line(to: NSPoint(x: end.point.x, y: chartRect.maxY))
            fillPath.close()
            segColor.withAlphaComponent(0.12).setFill()
            fillPath.fill()

            let linePath = NSBezierPath()
            linePath.lineWidth = 1.5
            linePath.lineCapStyle = .round
            linePath.move(to: start.point)
            linePath.line(to: end.point)
            segColor.setStroke()
            linePath.stroke()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? {
        guard !samples.isEmpty else { return "Ping history, no data yet" }
        let visible = visibleSamples()
        guard !visible.isEmpty else { return "Ping history, no data yet" }
        let msValues = visible.map(\.ms)
        let avg = msValues.reduce(0, +) / Double(msValues.count)
        let max = msValues.max() ?? 0
        return String(format: "Ping history over the last thirty minutes, average %.0f milliseconds, max %.0f milliseconds", avg, max)
    }
}
