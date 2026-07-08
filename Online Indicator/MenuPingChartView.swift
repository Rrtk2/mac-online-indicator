import AppKit

/// Compact sparkline of ping latency over the last thirty minutes.
final class MenuPingChartView: NSView {

    private var samples: [PingSample] = []

    private let avgLabel = NSTextField(labelWithString: menuNoValue)
    private let maxLabel = NSTextField(labelWithString: menuNoValue)
    private let hoverLabel = NSTextField(labelWithString: "")

    private let statsWidth: CGFloat = 56
    private var trackingArea: NSTrackingArea?
    private var hoveredIndex: Int?

    private struct ChartLayout {
        let chartRect: NSRect
        let plotted: [(sample: PingSample, point: NSPoint)]
    }

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

        hoverLabel.font      = .systemFont(ofSize: 10, weight: .semibold)
        hoverLabel.isHidden  = true
        hoverLabel.isBezeled = false
        hoverLabel.drawsBackground = false
        hoverLabel.isEditable = false
        hoverLabel.isSelectable = false
        addSubview(hoverLabel)

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
        clearHover()
        needsDisplay = true
    }

    func clearHover() {
        hoveredIndex = nil
        hoverLabel.isHidden = true
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

    private func makeLayout() -> ChartLayout? {
        let chartRect = chartRect
        guard chartRect.width > 0, chartRect.height > 0 else { return nil }

        let visible = visibleSamples()
        guard !visible.isEmpty else { return nil }

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

        let plotted = visible.map { sample -> (sample: PingSample, point: NSPoint) in
            let t = sample.date.timeIntervalSince(windowStart) / PingHistory.window
            let x = chartRect.minX + CGFloat(t.clamped(to: 0...1)) * chartRect.width
            let yNorm = (sample.ms - minMs) / range
            let y = chartRect.maxY - CGFloat(yNorm.clamped(to: 0...1)) * chartRect.height
            return (sample, NSPoint(x: x, y: y))
        }

        return ChartLayout(chartRect: chartRect, plotted: plotted)
    }

    private func nearestIndex(to x: CGFloat, in plotted: [(sample: PingSample, point: NSPoint)]) -> Int {
        var bestIndex = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, item) in plotted.enumerated() {
            let distance = abs(item.point.x - x)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }

    private func positionHoverLabel(for item: (sample: PingSample, point: NSPoint), in chartRect: NSRect) {
        hoverLabel.stringValue = String(format: "%.0f ms", item.sample.ms)
        hoverLabel.textColor = color(for: item.sample.ms)
        hoverLabel.sizeToFit()

        var x = item.point.x - hoverLabel.bounds.width / 2
        let maxX = chartRect.maxX - hoverLabel.bounds.width
        x = x.clamped(to: chartRect.minX...maxX)

        var y = item.point.y - hoverLabel.bounds.height - 5
        if y < chartRect.minY {
            y = min(item.point.y + 5, chartRect.maxY - hoverLabel.bounds.height)
        }

        hoverLabel.frame = NSRect(x: x, y: y, width: hoverLabel.bounds.width, height: hoverLabel.bounds.height)
        hoverLabel.isHidden = false
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard let layout = makeLayout(), layout.chartRect.contains(location) else {
            clearHover()
            return
        }

        let index = nearestIndex(to: location.x, in: layout.plotted)
        guard hoveredIndex != index else { return }

        hoveredIndex = index
        positionHoverLabel(for: layout.plotted[index], in: layout.chartRect)
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        clearHover()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let layout = makeLayout() else { return }
        let chartRect = layout.chartRect
        let plotted = layout.plotted

        if plotted.count == 1 {
            let item = plotted[0]
            let segColor = color(for: item.sample.ms)
            let radius: CGFloat = hoveredIndex == 0 ? 3.5 : 2
            let dot = NSBezierPath(ovalIn: NSRect(
                x: item.point.x - radius, y: item.point.y - radius,
                width: radius * 2, height: radius * 2
            ))
            segColor.setFill()
            dot.fill()
            drawHoverGuideIfNeeded(in: chartRect, point: item.point, ms: item.sample.ms, index: 0)
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

        if let hoveredIndex, hoveredIndex < plotted.count {
            let item = plotted[hoveredIndex]
            drawHoverGuideIfNeeded(in: chartRect, point: item.point, ms: item.sample.ms, index: hoveredIndex)
        }
    }

    private func drawHoverGuideIfNeeded(in chartRect: NSRect, point: NSPoint, ms: Double, index: Int) {
        guard hoveredIndex == index else { return }

        NSColor.separatorColor.withAlphaComponent(0.45).setStroke()
        let guide = NSBezierPath()
        guide.move(to: NSPoint(x: point.x, y: chartRect.minY))
        guide.line(to: NSPoint(x: point.x, y: chartRect.maxY))
        guide.lineWidth = 1
        guide.stroke()

        let segColor = color(for: ms)
        let dot = NSBezierPath(ovalIn: NSRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7))
        segColor.setFill()
        dot.fill()
    }

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
