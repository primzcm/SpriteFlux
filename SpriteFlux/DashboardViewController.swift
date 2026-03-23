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
    private let moveModeSwitch = NSSwitch()
    private let clickThroughSwitch = NSSwitch()

    override func loadView() {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        self.view = visualEffectView

        preferredContentSize = NSSize(width: 360, height: 480)

        let titleLabel = NSTextField(labelWithString: "SpriteFlux")
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)

        let subtitleLabel = NSTextField(labelWithString: "Overlay Dashboard")
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .medium)

        let headerStack = NSStackView(views: [titleLabel, subtitleLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .centerX
        headerStack.spacing = 2

        let statusIcon = DashboardViewController.makeIcon(symbolName: "info.circle.fill", tint: .controlAccentColor)
        let statusHeader = DashboardViewController.makeSectionHeader(title: "Status", icon: statusIcon)
        let statusStack = DashboardViewController.makeInfoStack(title: "Current State", valueLabel: statusValueLabel)

        let fileIcon = DashboardViewController.makeIcon(symbolName: "film.fill", tint: .controlAccentColor)
        let fileHeader = DashboardViewController.makeSectionHeader(title: "Animation", icon: fileIcon)
        let fileStack = DashboardViewController.makeInfoStack(title: "Loaded File", valueLabel: fileValueLabel)

        let hotkeyIcon = DashboardViewController.makeIcon(symbolName: "keyboard", tint: .secondaryLabelColor)
        let hotkeyHeader = DashboardViewController.makeSectionHeader(title: "Shortcuts", icon: hotkeyIcon)
        let hotkeyLabel = NSTextField(labelWithString: "Global Toggle: Cmd + Shift + M")
        hotkeyLabel.textColor = .secondaryLabelColor
        hotkeyLabel.font = .systemFont(ofSize: 12, weight: .regular)

        let infoSection = DashboardViewController.makeSection(
            arrangedSubviews: [
                statusHeader,
                statusStack,
                DashboardViewController.makeSeparator(),
                fileHeader,
                fileStack,
                DashboardViewController.makeSeparator(),
                hotkeyHeader,
                hotkeyLabel
            ]
        )

        moveModeSwitch.target = self
        moveModeSwitch.action = #selector(toggleMoveMode)
        let moveModeRow = DashboardViewController.makeSwitchRow(title: "Move Mode", icon: "arrow.up.and.down.and.arrow.left.and.right", toggle: moveModeSwitch)

        clickThroughSwitch.target = self
        clickThroughSwitch.action = #selector(toggleClickThrough)
        let clickThroughRow = DashboardViewController.makeSwitchRow(title: "Click-through", icon: "cursorarrow.click", toggle: clickThroughSwitch)

        let openButtonRow = NSButton(title: " Open Animation...", target: self, action: #selector(openAnimationFile))
        openButtonRow.bezelStyle = .rounded
        openButtonRow.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        
        let resetButton = NSButton(title: " Reset Position", target: self, action: #selector(resetPosition))
        resetButton.bezelStyle = .rounded
        resetButton.image = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: nil)

        let buttonRow = NSStackView(views: [openButtonRow, resetButton])
        buttonRow.orientation = .horizontal
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 10

        let controlsSection = DashboardViewController.makeSection(
            arrangedSubviews: [moveModeRow, clickThroughRow, DashboardViewController.makeSeparator(), buttonRow]
        )

        let hideButton = NSButton(title: " Hide", target: self, action: #selector(hideDashboard))
        hideButton.bezelStyle = .rounded
        hideButton.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: nil)

        let quitButton = NSButton(title: " Quit App", target: self, action: #selector(quitApp))
        quitButton.bezelStyle = .rounded
        quitButton.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)

        let footerStack = NSStackView(views: [hideButton, quitButton])
        footerStack.orientation = .horizontal
        footerStack.distribution = .fillEqually
        footerStack.spacing = 10

        let contentStack = NSStackView(views: [headerStack, infoSection, controlsSection, footerStack])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        headerStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        infoSection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        controlsSection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        footerStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        visualEffectView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 40),
            contentStack.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -20)
        ])
    }

    func render(_ state: DashboardState) {
        moveModeSwitch.state = state.moveModeEnabled ? .on : .off
        clickThroughSwitch.state = state.clickThroughEnabled ? .on : .off

        if state.moveModeEnabled {
            statusValueLabel.stringValue = "Move mode active"
            statusValueLabel.textColor = .systemBlue
        } else if state.clickThroughEnabled {
            statusValueLabel.stringValue = "Click-through active"
            statusValueLabel.textColor = .systemGreen
        } else {
            statusValueLabel.stringValue = "Interactive overlay"
            statusValueLabel.textColor = .labelColor
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

    private static func makeSectionHeader(title: String, icon: NSImageView) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title.uppercased())
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.font = .systemFont(ofSize: 11, weight: .bold)

        let stack = NSStackView(views: [icon, titleLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        return stack
    }

    private static func makeInfoStack(title: String, valueLabel: NSTextField) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)

        let stack = NSStackView(views: [titleLabel, valueLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        return stack
    }

    private static func makeSwitchRow(title: String, icon: String, toggle: NSSwitch) -> NSStackView {
        let iconView = makeIcon(symbolName: icon, tint: .labelColor)
        
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .medium)

        let leftStack = NSStackView(views: [iconView, label])
        leftStack.orientation = .horizontal
        leftStack.alignment = .centerY
        leftStack.spacing = 8

        let rowStack = NSStackView(views: [])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.addView(leftStack, in: .leading)
        rowStack.addView(toggle, in: .trailing)
        
        return rowStack
    }

    private static func makeIcon(symbolName: String, tint: NSColor) -> NSImageView {
        let config = NSImage.SymbolConfiguration(textStyle: .body, scale: .medium)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        let imageView = NSImageView(image: image ?? NSImage())
        imageView.contentTintColor = tint
        return imageView
    }

    private static func makeSection(arrangedSubviews: [NSView]) -> NSBox {
        let stack = NSStackView(views: arrangedSubviews)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        for view in arrangedSubviews {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 14
        box.borderWidth = 1
        box.borderColor = NSColor.separatorColor.withAlphaComponent(0.2)
        box.fillColor = NSColor.windowBackgroundColor.withAlphaComponent(0.6)
        box.contentViewMargins = .zero
        box.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: box.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -16)
        ])

        return box
    }

    private static func makeValueLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.lineBreakMode = .byTruncatingMiddle
        label.maximumNumberOfLines = 1
        return label
    }

    private static func makeSeparator() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        separator.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return separator
    }
}
