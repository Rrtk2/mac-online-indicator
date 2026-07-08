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

        let linePath = NSBezierPath()
        linePath.lineWidth = 1.5
        linePath.lineCapStyle = .round
        linePath.lineJoinStyle = .round

        let fillPath = NSBezierPath()
        let first = point(for: visible[0])
        linePath.move(to: first)
        fillPath.move(to: NSPoint(x: first.x, y: chartRect.maxY))
        fillPath.line(to: first)

        for sample in visible.dropFirst() {
            let p = point(for: sample)
            linePath.line(to: p)
            fillPath.line(to: p)
        }

        let last = point(for: visible[visible.count - 1])
        fillPath.line(to: NSPoint(x: last.x, y: chartRect.maxY))
        fillPath.close()

        NSColor.systemGreen.withAlphaComponent(0.12).setFill()
        fillPath.fill()

        NSColor.systemGreen.setStroke()
        linePath.stroke()
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
