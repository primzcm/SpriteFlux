import Cocoa

struct DashboardState {
    let currentFileName: String?
    let currentFileURL: URL?
    let moveModeEnabled: Bool
    let clickThroughEnabled: Bool
    let scale: Double
    let opacity: Double
}

protocol DashboardViewControllerDelegate: AnyObject {
    func dashboardViewControllerDidRequestOpenAnimation(_ controller: DashboardViewController)
    func dashboardViewControllerDidToggleMoveMode(_ controller: DashboardViewController)
    func dashboardViewControllerDidToggleClickThrough(_ controller: DashboardViewController)
    func dashboardViewControllerDidRequestResetPosition(_ controller: DashboardViewController)
    func dashboardViewControllerDidRequestHide(_ controller: DashboardViewController)
    func dashboardViewControllerDidRequestQuit(_ controller: DashboardViewController)
    func dashboardViewController(_ controller: DashboardViewController, didChangeScale scale: Double)
    func dashboardViewController(_ controller: DashboardViewController, didChangeOpacity opacity: Double)
    func dashboardViewControllerDidRequestSettings(_ controller: DashboardViewController)
}

final class DashboardViewController: NSViewController {
    weak var delegate: DashboardViewControllerDelegate?

    private let moveModeSwitch = NSSwitch()
    private let clickThroughSwitch = NSSwitch()
    private let scaleSlider = NSSlider(value: 1.0, minValue: 0.5, maxValue: 2.0, target: nil, action: nil)
    private let opacitySlider = NSSlider(value: 1.0, minValue: 0.1, maxValue: 1.0, target: nil, action: nil)
    
    private let thumbnailView = OverlayView()
    private var loadedFileURL: URL?

    override func loadView() {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        self.view = visualEffectView

        preferredContentSize = NSSize(width: 330, height: 490)

        // 1. Header & Preview
        let titleLabel = NSTextField(labelWithString: "SpriteFlux")
        titleLabel.font = .systemFont(ofSize: 26, weight: .heavy)
        titleLabel.textColor = .labelColor

        let thumbnailContainer = NSBox()
        thumbnailContainer.boxType = .custom
        thumbnailContainer.cornerRadius = 45
        thumbnailContainer.borderWidth = 0
        thumbnailContainer.fillColor = NSColor.windowBackgroundColor.withAlphaComponent(0.2)
        thumbnailContainer.contentViewMargins = .zero
        thumbnailContainer.translatesAutoresizingMaskIntoConstraints = false
        thumbnailContainer.widthAnchor.constraint(equalToConstant: 90).isActive = true
        thumbnailContainer.heightAnchor.constraint(equalToConstant: 90).isActive = true

        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailContainer.addSubview(thumbnailView)
        NSLayoutConstraint.activate([
            thumbnailView.centerXAnchor.constraint(equalTo: thumbnailContainer.centerXAnchor),
            thumbnailView.centerYAnchor.constraint(equalTo: thumbnailContainer.centerYAnchor),
            thumbnailView.widthAnchor.constraint(equalTo: thumbnailContainer.widthAnchor),
            thumbnailView.heightAnchor.constraint(equalTo: thumbnailContainer.heightAnchor)
        ])

        let headerStack = NSStackView(views: [titleLabel, thumbnailContainer])
        headerStack.orientation = .vertical
        headerStack.alignment = .centerX
        headerStack.spacing = 16

        // 2. Toggles Section
        moveModeSwitch.target = self
        moveModeSwitch.action = #selector(toggleMoveMode)
        let moveModeRow = DashboardViewController.makeSwitchRow(title: "Move Mode", icon: "arrow.up.and.down.and.arrow.left.and.right", toggle: moveModeSwitch)

        clickThroughSwitch.target = self
        clickThroughSwitch.action = #selector(toggleClickThrough)
        let clickThroughRow = DashboardViewController.makeSwitchRow(title: "Click-through", icon: "cursorarrow.click", toggle: clickThroughSwitch)

        let togglesSection = DashboardViewController.makeSection(arrangedSubviews: [moveModeRow, clickThroughRow])

        // 3. Sliders Section
        scaleSlider.target = self
        scaleSlider.action = #selector(scaleChanged)
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)

        scaleSlider.isContinuous = true
        opacitySlider.isContinuous = true

        let scaleStack = DashboardViewController.makeSliderRow(title: "Scale", icon: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", slider: scaleSlider)
        let opacityStack = DashboardViewController.makeSliderRow(title: "Opacity", icon: "circle.lefthalf.filled", slider: opacitySlider)
        
        let slidersSection = DashboardViewController.makeSection(arrangedSubviews: [scaleStack, opacityStack])

        // 4. Actions
        let openButton = NSButton(title: " Open File", target: self, action: #selector(openAnimationFile))
        openButton.bezelStyle = .rounded
        openButton.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        
        let resetButton = NSButton(title: " Reset Position", target: self, action: #selector(resetPosition))
        resetButton.bezelStyle = .rounded
        resetButton.image = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: nil)

        let buttonRow = NSStackView(views: [openButton, resetButton])
        buttonRow.orientation = .horizontal
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 10

        let actionsSection = DashboardViewController.makeSection(arrangedSubviews: [buttonRow])

        // 5. Footer
        let hideButton = NSButton(image: NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Hide Dashboard")!, target: self, action: #selector(hideDashboard))
        hideButton.isBordered = false
        hideButton.contentTintColor = .secondaryLabelColor

        let quitButton = NSButton(image: NSImage(systemSymbolName: "power", accessibilityDescription: "Quit Application")!, target: self, action: #selector(quitApp))
        quitButton.isBordered = false
        quitButton.contentTintColor = .secondaryLabelColor

        let footerStack = NSStackView(views: [hideButton, quitButton])
        footerStack.orientation = .horizontal
        footerStack.distribution = .gravityAreas
        footerStack.addView(hideButton, in: .leading)
        footerStack.addView(quitButton, in: .trailing)

        // Assembly
        let contentStack = NSStackView(views: [headerStack, togglesSection, slidersSection, actionsSection, footerStack])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        headerStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        togglesSection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        slidersSection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        actionsSection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        footerStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        visualEffectView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -24),
            contentStack.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 36),
            contentStack.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -20)
        ])
    }

    func render(_ state: DashboardState) {
        moveModeSwitch.state = state.moveModeEnabled ? .on : .off
        clickThroughSwitch.state = state.clickThroughEnabled ? .on : .off
        
        if scaleSlider.doubleValue != state.scale {
            scaleSlider.doubleValue = state.scale
        }
        if opacitySlider.doubleValue != state.opacity {
            opacitySlider.doubleValue = state.opacity
        }

        if let url = state.currentFileURL, url != loadedFileURL {
             loadedFileURL = url
             _ = thumbnailView.loadMedia(url: url)
        }
    }

    @objc private func scaleChanged() {
        delegate?.dashboardViewController(self, didChangeScale: scaleSlider.doubleValue)
    }

    @objc private func opacityChanged() {
        delegate?.dashboardViewController(self, didChangeOpacity: opacitySlider.doubleValue)
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

    private static func makeSliderRow(title: String, icon: String, slider: NSSlider) -> NSStackView {
        let iconView = makeIcon(symbolName: icon, tint: .labelColor)
        
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.widthAnchor.constraint(equalToConstant: 60).isActive = true

        let leftStack = NSStackView(views: [iconView, label])
        leftStack.orientation = .horizontal
        leftStack.alignment = .centerY
        leftStack.spacing = 8

        let rowStack = NSStackView(views: [leftStack, slider])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 10
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)

        return rowStack
    }

    private static func makeIcon(symbolName: String, tint: NSColor) -> NSImageView {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        let imageView = NSImageView(image: image ?? NSImage())
        imageView.contentTintColor = tint
        imageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        return imageView
    }

    private static func makeSection(arrangedSubviews: [NSView]) -> NSBox {
        let stack = NSStackView(views: arrangedSubviews)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        for view in arrangedSubviews {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 14
        box.borderWidth = 1
        box.borderColor = NSColor.separatorColor.withAlphaComponent(0.2)
        box.fillColor = NSColor.windowBackgroundColor.withAlphaComponent(0.4)
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
}
