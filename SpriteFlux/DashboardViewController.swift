import Cocoa

struct DashboardState {
    let currentFileName: String?
    let moveModeEnabled: Bool
    let clickThroughEnabled: Bool
}

protocol DashboardViewControllerDelegate: AnyObject {
    func dashboardViewControllerDidRequestOpenAnimation(_ controller: DashboardViewController)
    func dashboardViewControllerDidToggleMoveMode(_ controller: DashboardViewController)
    func dashboardViewControllerDidToggleClickThrough(_ controller: DashboardViewController)
    func dashboardViewControllerDidRequestResetPosition(_ controller: DashboardViewController)
    func dashboardViewControllerDidRequestHide(_ controller: DashboardViewController)
    func dashboardViewControllerDidRequestQuit(_ controller: DashboardViewController)
}

final class DashboardViewController: NSViewController {
    weak var delegate: DashboardViewControllerDelegate?

    private let statusValueLabel = DashboardViewController.makeValueLabel()
    private let fileValueLabel = DashboardViewController.makeValueLabel()
    private let moveModeButton = NSButton(checkboxWithTitle: "Move Mode", target: nil, action: nil)
    private let clickThroughButton = NSButton(checkboxWithTitle: "Click-through", target: nil, action: nil)

    override func loadView() {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        self.view = visualEffectView

        preferredContentSize = NSSize(width: 320, height: 280)

        let titleLabel = NSTextField(labelWithString: "SpriteFlux")
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        let subtitleLabel = NSTextField(labelWithString: "Overlay dashboard")
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)

        let headerStack = NSStackView(views: [titleLabel, subtitleLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 2

        let statusStack = DashboardViewController.makeInfoStack(title: "Status", valueLabel: statusValueLabel)
        let fileStack = DashboardViewController.makeInfoStack(title: "Animation", valueLabel: fileValueLabel)
        let hotkeyLabel = NSTextField(labelWithString: "Hotkey: Cmd + Shift + M")
        hotkeyLabel.textColor = .secondaryLabelColor
        hotkeyLabel.font = .systemFont(ofSize: 12, weight: .regular)

        let summarySection = DashboardViewController.makeSection(
            arrangedSubviews: [
                statusStack,
                DashboardViewController.makeSeparator(),
                fileStack,
                DashboardViewController.makeSeparator(),
                hotkeyLabel
            ]
        )

        let openButton = NSButton(title: "Open Animation File...", target: self, action: #selector(openAnimationFile))
        openButton.bezelStyle = .rounded

        moveModeButton.target = self
        moveModeButton.action = #selector(toggleMoveMode)

        clickThroughButton.target = self
        clickThroughButton.action = #selector(toggleClickThrough)

        let resetButton = NSButton(title: "Reset Position", target: self, action: #selector(resetPosition))
        resetButton.bezelStyle = .rounded

        let controlsSection = DashboardViewController.makeSection(
            arrangedSubviews: [openButton, moveModeButton, clickThroughButton, resetButton]
        )

        let hideButton = NSButton(title: "Hide Dashboard", target: self, action: #selector(hideDashboard))
        hideButton.bezelStyle = .rounded

        let quitButton = NSButton(title: "Quit", target: self, action: #selector(quitApp))
        quitButton.bezelStyle = .rounded

        let footerStack = NSStackView(views: [hideButton, quitButton])
        footerStack.orientation = NSUserInterfaceLayoutOrientation.horizontal
        footerStack.alignment = .centerY
        footerStack.distribution = .fillEqually
        footerStack.spacing = 10

        let contentStack = NSStackView(views: [headerStack, summarySection, controlsSection, footerStack])
        contentStack.orientation = NSUserInterfaceLayoutOrientation.vertical
        contentStack.alignment = NSLayoutConstraint.Attribute.leading
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        visualEffectView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -16),
            contentStack.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -16)
        ])
    }

    func render(_ state: DashboardState) {
        moveModeButton.state = state.moveModeEnabled ? .on : .off
        clickThroughButton.state = state.clickThroughEnabled ? .on : .off

        if state.moveModeEnabled {
            statusValueLabel.stringValue = "Move mode enabled"
        } else if state.clickThroughEnabled {
            statusValueLabel.stringValue = "Click-through enabled"
        } else {
            statusValueLabel.stringValue = "Overlay interactive"
        }

        fileValueLabel.stringValue = state.currentFileName ?? "No animation selected"
    }

    @objc private func openAnimationFile() {
        delegate?.dashboardViewControllerDidRequestOpenAnimation(self)
    }

    @objc private func toggleMoveMode() {
        delegate?.dashboardViewControllerDidToggleMoveMode(self)
    }

    @objc private func toggleClickThrough() {
        delegate?.dashboardViewControllerDidToggleClickThrough(self)
    }

    @objc private func resetPosition() {
        delegate?.dashboardViewControllerDidRequestResetPosition(self)
    }

    @objc private func hideDashboard() {
        delegate?.dashboardViewControllerDidRequestHide(self)
    }

    @objc private func quitApp() {
        delegate?.dashboardViewControllerDidRequestQuit(self)
    }

    private static func makeInfoStack(title: String, valueLabel: NSTextField) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title.uppercased())
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)

        let stack = NSStackView(views: [titleLabel, valueLabel])
        stack.orientation = NSUserInterfaceLayoutOrientation.vertical
        stack.alignment = NSLayoutConstraint.Attribute.leading
        stack.spacing = 4
        return stack
    }

    private static func makeSection(arrangedSubviews: [NSView]) -> NSBox {
        let stack = NSStackView(views: arrangedSubviews)
        stack.orientation = NSUserInterfaceLayoutOrientation.vertical
        stack.alignment = NSLayoutConstraint.Attribute.leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 12
        box.borderWidth = 0
        box.fillColor = NSColor.windowBackgroundColor.withAlphaComponent(0.55)
        box.contentViewMargins = NSSize(width: 0, height: 0)
        box.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -12)
        ])

        return box
    }

    private static func makeValueLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.lineBreakMode = .byTruncatingMiddle
        label.maximumNumberOfLines = 1
        return label
    }

    private static func makeSeparator() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }
}
