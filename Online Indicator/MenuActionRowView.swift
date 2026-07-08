import AppKit

/// A clickable menu row with a left label and optional right detail text.
final class MenuActionRowView: MenuHoverView {

    var onAction: (() -> Void)?

    private let labelField = NSTextField(labelWithString: "")
    private let detailField = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        autoresizingMask = .width

        addSubview(highlightView)
        NSLayoutConstraint.activate([
            highlightView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            highlightView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            highlightView.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            highlightView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
        ])

        labelField.font      = .systemFont(ofSize: 13, weight: .regular)
        labelField.textColor = .labelColor
        labelField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labelField)

        detailField.font      = .monospacedSystemFont(ofSize: 12, weight: .regular)
        detailField.textColor = .secondaryLabelColor
        detailField.alignment = .right
        detailField.lineBreakMode = .byTruncatingMiddle
        detailField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(detailField)

        NSLayoutConstraint.activate([
            labelField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: MenuLayout.heroLeadingPadding),
            labelField.centerYAnchor.constraint(equalTo: centerYAnchor),
            labelField.trailingAnchor.constraint(lessThanOrEqualTo: detailField.leadingAnchor, constant: -8),

            detailField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -MenuLayout.heroLeadingPadding),
            detailField.centerYAnchor.constraint(equalTo: centerYAnchor),
            detailField.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.55),
        ])
    }

    func configure(label: String, detail: String) {
        labelField.stringValue  = label
        detailField.stringValue = detail
        setAccessibilityLabel("\(label), \(detail)")
    }

    override func mouseDown(with event: NSEvent) { onAction?() }

    // MARK: - Accessibility

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityHelp() -> String? { "Click to run \(labelField.stringValue)" }
}
