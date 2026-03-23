import Cocoa

struct DashboardRecentAsset {
    let name: String
    let url: URL
    let formatLabel: String
    let isCurrent: Bool
}

struct DashboardState {
    let currentFileName: String?
    let currentFileURL: URL?
    let recentAssets: [DashboardRecentAsset]
    let moveModeEnabled: Bool
    let clickThroughEnabled: Bool
    let scale: Double
    let opacity: Double
}

protocol DashboardViewControllerDelegate: AnyObject {
    func dashboardViewControllerDidRequestOpenAnimation(_ controller: DashboardViewController)
    func dashboardViewController(_ controller: DashboardViewController, didRequestLoadAsset url: URL)
    func dashboardViewControllerDidToggleMoveMode(_ controller: DashboardViewController)
    func dashboardViewControllerDidToggleClickThrough(_ controller: DashboardViewController)
    func dashboardViewControllerDidRequestResetPosition(_ controller: DashboardViewController)
    func dashboardViewControllerDidRequestHide(_ controller: DashboardViewController)
    func dashboardViewControllerDidRequestQuit(_ controller: DashboardViewController)
    func dashboardViewController(_ controller: DashboardViewController, didChangeScale scale: Double)
    func dashboardViewController(_ controller: DashboardViewController, didChangeOpacity opacity: Double)
    func dashboardViewControllerDidRequestSettings(_ controller: DashboardViewController)
}

private final class DashboardDropView: NSVisualEffectView {
    var onFileDrop: ((URL) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard firstDroppedFile(from: sender) != nil else {
            return []
        }

        layer?.borderWidth = 2
        layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.65).cgColor
        layer?.cornerRadius = 20
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        clearDropHighlight()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { clearDropHighlight() }

        guard let url = firstDroppedFile(from: sender) else {
            return false
        }

        onFileDrop?(url)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        clearDropHighlight()
    }

    private func firstDroppedFile(from draggingInfo: NSDraggingInfo) -> URL? {
        let classes: [AnyClass] = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return draggingInfo.draggingPasteboard.readObjects(forClasses: classes, options: options)?.first as? URL
    }

    private func clearDropHighlight() {
        layer?.borderWidth = 0
        layer?.borderColor = nil
    }
}

final class DashboardViewController: NSViewController {
    weak var delegate: DashboardViewControllerDelegate?

    private let moveModeSwitch = NSSwitch()
    private let clickThroughSwitch = NSSwitch()
    private let scaleSlider = NSSlider(value: 1.0, minValue: 0.5, maxValue: 2.0, target: nil, action: nil)
    private let opacitySlider = NSSlider(value: 1.0, minValue: 0.1, maxValue: 1.0, target: nil, action: nil)

    private let thumbnailView = OverlayView()
    private var loadedFileURL: URL?
    private let fileNameLabel = NSTextField(labelWithString: "")
    private let scaleValueLabel = NSTextField(labelWithString: "")
    private let opacityValueLabel = NSTextField(labelWithString: "")
    private let recentAssetsStack = NSStackView()
    private let recentAssetsEmptyLabel = NSTextField(labelWithString: "No recent assets yet")

    override func loadView() {
        let visualEffectView = DashboardDropView()
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.onFileDrop = { [weak self] url in
            guard let self = self else {
                return
            }
            self.delegate?.dashboardViewController(self, didRequestLoadAsset: url)
        }
        self.view = visualEffectView

        preferredContentSize = NSSize(width: 330, height: 660)

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

        fileNameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        fileNameLabel.textColor = .tertiaryLabelColor
        fileNameLabel.alignment = .center
        fileNameLabel.lineBreakMode = .byTruncatingMiddle
        fileNameLabel.maximumNumberOfLines = 1
        fileNameLabel.stringValue = "No animation loaded"

        let headerStack = NSStackView(views: [titleLabel, thumbnailContainer, fileNameLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .centerX
        headerStack.spacing = 12

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

        scaleValueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        scaleValueLabel.textColor = .secondaryLabelColor
        scaleValueLabel.alignment = .right
        scaleValueLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true
        updateScaleValueLabel(with: scaleSlider.doubleValue)

        opacityValueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        opacityValueLabel.textColor = .secondaryLabelColor
        opacityValueLabel.alignment = .right
        opacityValueLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true
        updateOpacityValueLabel(with: opacitySlider.doubleValue)

        let scaleStack = DashboardViewController.makeSliderRow(
            title: "Scale",
            icon: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left",
            slider: scaleSlider,
            valueLabel: scaleValueLabel
        )
        let opacityStack = DashboardViewController.makeSliderRow(
            title: "Opacity",
            icon: "circle.lefthalf.filled",
            slider: opacitySlider,
            valueLabel: opacityValueLabel
        )

        let slidersSection = DashboardViewController.makeSection(arrangedSubviews: [scaleStack, opacityStack])

        // 4. Library
        let libraryTitleLabel = NSTextField(labelWithString: "Library")
        libraryTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let libraryHintLabel = NSTextField(labelWithString: "Drop MP4, MOV, GIF, PNG, JPG, or WEBP here, or reopen a recent asset.")
        libraryHintLabel.font = .systemFont(ofSize: 11, weight: .medium)
        libraryHintLabel.textColor = .secondaryLabelColor
        libraryHintLabel.lineBreakMode = .byWordWrapping
        libraryHintLabel.maximumNumberOfLines = 2

        recentAssetsStack.orientation = .vertical
        recentAssetsStack.alignment = .leading
        recentAssetsStack.spacing = 8

        recentAssetsEmptyLabel.font = .systemFont(ofSize: 12, weight: .medium)
        recentAssetsEmptyLabel.textColor = .tertiaryLabelColor

        let librarySection = DashboardViewController.makeSection(
            arrangedSubviews: [libraryTitleLabel, libraryHintLabel, recentAssetsStack]
        )

        // 5. Actions
        let openButton = NSButton(title: "Open…", target: self, action: #selector(openAnimationFile))
        openButton.bezelStyle = .rounded
        openButton.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        openButton.imagePosition = .imageLeading
        openButton.toolTip = "Open an asset from disk"
        
        let resetButton = NSButton(title: "Reset Position", target: self, action: #selector(resetPosition))
        resetButton.bezelStyle = .rounded
        resetButton.image = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: nil)
        resetButton.imagePosition = .imageLeading
        resetButton.toolTip = "Reset overlay position"

        let buttonRow = NSStackView(views: [openButton, resetButton])
        buttonRow.orientation = .horizontal
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 10

        let optionsButton = NSButton(title: "Shortcuts…", target: self, action: #selector(openOptions))
        optionsButton.bezelStyle = .rounded
        optionsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        optionsButton.imagePosition = .imageLeading
        optionsButton.toolTip = "Edit keyboard shortcuts"

        let actionsSection = DashboardViewController.makeSection(arrangedSubviews: [buttonRow, optionsButton])

        // 6. Footer
        let hideButton = NSButton(image: NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Hide Dashboard")!, target: self, action: #selector(hideDashboard))
        hideButton.isBordered = false
        hideButton.contentTintColor = .secondaryLabelColor
        hideButton.toolTip = "Hide Dashboard"

        let quitButton = NSButton(image: NSImage(systemSymbolName: "power", accessibilityDescription: "Quit Application")!, target: self, action: #selector(quitApp))
        quitButton.isBordered = false
        quitButton.contentTintColor = .secondaryLabelColor
        quitButton.toolTip = "Quit SpriteFlux"

        let footerStack = NSStackView(views: [hideButton, quitButton])
        footerStack.orientation = .horizontal
        footerStack.distribution = .gravityAreas
        footerStack.addView(hideButton, in: .leading)
        footerStack.addView(quitButton, in: .trailing)

        // Assembly
        let contentStack = NSStackView(views: [headerStack, togglesSection, slidersSection, librarySection, actionsSection, footerStack])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        headerStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        togglesSection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        slidersSection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        librarySection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
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
            updateScaleValueLabel(with: state.scale)
        }
        if opacitySlider.doubleValue != state.opacity {
            opacitySlider.doubleValue = state.opacity
            updateOpacityValueLabel(with: state.opacity)
        }

        if let url = state.currentFileURL, url != loadedFileURL {
             loadedFileURL = url
             _ = thumbnailView.loadMedia(url: url)
        }

        if let name = state.currentFileName, !name.isEmpty {
            fileNameLabel.stringValue = name
            fileNameLabel.textColor = .secondaryLabelColor
        } else {
            fileNameLabel.stringValue = "No animation loaded"
            fileNameLabel.textColor = .tertiaryLabelColor
        }

        reloadRecentAssets(state.recentAssets)
    }

    @objc private func scaleChanged() {
        updateScaleValueLabel(with: scaleSlider.doubleValue)
        delegate?.dashboardViewController(self, didChangeScale: scaleSlider.doubleValue)
    }

    @objc private func opacityChanged() {
        updateOpacityValueLabel(with: opacitySlider.doubleValue)
        delegate?.dashboardViewController(self, didChangeOpacity: opacitySlider.doubleValue)
    }

    @objc private func openAnimationFile() {
        delegate?.dashboardViewControllerDidRequestOpenAnimation(self)
    }

    @objc private func openRecentAsset(_ sender: NSButton) {
        guard let path = sender.identifier?.rawValue else {
            return
        }

        let url = URL(fileURLWithPath: path)
        delegate?.dashboardViewController(self, didRequestLoadAsset: url)
    }

    @objc private func openOptions() {
        delegate?.dashboardViewControllerDidRequestSettings(self)
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

    private static func makeSliderRow(title: String, icon: String, slider: NSSlider, valueLabel: NSTextField) -> NSStackView {
        let iconView = makeIcon(symbolName: icon, tint: .labelColor)
        
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.widthAnchor.constraint(equalToConstant: 60).isActive = true

        let leftStack = NSStackView(views: [iconView, label])
        leftStack.orientation = .horizontal
        leftStack.alignment = .centerY
        leftStack.spacing = 8

        let rowStack = NSStackView(views: [leftStack, slider, valueLabel])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 10
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

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

    private func reloadRecentAssets(_ assets: [DashboardRecentAsset]) {
        recentAssetsStack.arrangedSubviews.forEach { view in
            recentAssetsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard assets.isEmpty == false else {
            recentAssetsStack.addArrangedSubview(recentAssetsEmptyLabel)
            return
        }

        for asset in assets {
            recentAssetsStack.addArrangedSubview(makeRecentAssetButton(for: asset))
        }
    }

    private func makeRecentAssetButton(for asset: DashboardRecentAsset) -> NSButton {
        let button = NSButton(title: "\(asset.name)  \(asset.formatLabel)", target: self, action: #selector(openRecentAsset(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(asset.url.path)
        button.bezelStyle = .rounded
        button.image = NSImage(systemSymbolName: asset.isCurrent ? "checkmark.circle.fill" : "clock.arrow.circlepath", accessibilityDescription: nil)
        button.imagePosition = .imageLeading
        button.contentTintColor = asset.isCurrent ? .controlAccentColor : .secondaryLabelColor
        button.cell?.lineBreakMode = .byTruncatingMiddle
        button.toolTip = asset.url.path
        return button
    }

    private func updateScaleValueLabel(with scale: Double) {
        let percentValue = Int((scale * 100.0).rounded())
        scaleValueLabel.stringValue = "\(percentValue)%"
    }

    private func updateOpacityValueLabel(with opacity: Double) {
        let percentValue = Int((opacity * 100.0).rounded())
        opacityValueLabel.stringValue = "\(percentValue)%"
    }
}
