import Cocoa

struct DashboardActiveCompanion {
    let id: String
    let name: String
    let formatLabel: String
    let thumbnailURL: URL?
    let isSelected: Bool
}

struct DashboardLibraryAsset {
    let id: String
    let name: String
    let formatLabel: String
    let thumbnailURL: URL?
    let sourceFileName: String
    let isFavorite: Bool
    let isActive: Bool
}

struct DashboardState {
    let currentFileName: String?
    let currentFileURL: URL?
    let activeCompanions: [DashboardActiveCompanion]
    let libraryAssets: [DashboardLibraryAsset]
    let hasSelectedCompanion: Bool
    let moveModeEnabled: Bool
    let clickThroughEnabled: Bool
    let scale: Double
    let opacity: Double
}

protocol DashboardViewControllerDelegate: AnyObject {
    func dashboardViewControllerDidRequestOpenAnimation(_ controller: DashboardViewController)
    func dashboardViewController(_ controller: DashboardViewController, didRequestImportAsset url: URL)
    func dashboardViewController(_ controller: DashboardViewController, didRequestAddLibraryAsset id: String)
    func dashboardViewController(_ controller: DashboardViewController, didToggleFavoriteLibraryAsset id: String)
    func dashboardViewController(_ controller: DashboardViewController, didRenameLibraryAsset id: String, to newName: String)
    func dashboardViewController(_ controller: DashboardViewController, didDeleteLibraryAsset id: String)
    func dashboardViewController(_ controller: DashboardViewController, didRequestSelectActiveCompanion id: String)
    func dashboardViewController(_ controller: DashboardViewController, didRequestRemoveActiveCompanion id: String)
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
    private let activeCompanionsStack = NSStackView()
    private let activeCompanionsEmptyLabel = NSTextField(labelWithString: "No active companions")
    private let activeCompanionsScrollView = NSScrollView()
    private let recentAssetsStack = NSStackView()
    private let recentAssetsEmptyLabel = NSTextField(labelWithString: "No recent assets yet")
    private let libraryScrollView = NSScrollView()
    private let resetPositionButton = NSButton()

    override func loadView() {
        let visualEffectView = DashboardDropView()
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.onFileDrop = { [weak self] url in
            guard let self = self else {
                return
            }
            self.delegate?.dashboardViewController(self, didRequestImportAsset: url)
        }
        self.view = visualEffectView

        preferredContentSize = NSSize(width: 330, height: 600)

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

        // 2. Active Companions
        let activeTitleLabel = NSTextField(labelWithString: "Active")
        activeTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let activeHintLabel = NSTextField(labelWithString: "Select the companion you want to edit or remove.")
        activeHintLabel.font = .systemFont(ofSize: 11, weight: .medium)
        activeHintLabel.textColor = .secondaryLabelColor

        activeCompanionsStack.orientation = .vertical
        activeCompanionsStack.alignment = .leading
        activeCompanionsStack.spacing = 8
        activeCompanionsStack.translatesAutoresizingMaskIntoConstraints = false

        activeCompanionsEmptyLabel.font = .systemFont(ofSize: 12, weight: .medium)
        activeCompanionsEmptyLabel.textColor = .tertiaryLabelColor

        let activeDocumentView = NSView()
        activeDocumentView.translatesAutoresizingMaskIntoConstraints = false
        activeDocumentView.addSubview(activeCompanionsStack)

        NSLayoutConstraint.activate([
            activeCompanionsStack.leadingAnchor.constraint(equalTo: activeDocumentView.leadingAnchor),
            activeCompanionsStack.trailingAnchor.constraint(equalTo: activeDocumentView.trailingAnchor),
            activeCompanionsStack.topAnchor.constraint(equalTo: activeDocumentView.topAnchor),
            activeCompanionsStack.bottomAnchor.constraint(equalTo: activeDocumentView.bottomAnchor),
            activeCompanionsStack.widthAnchor.constraint(equalTo: activeDocumentView.widthAnchor)
        ])

        activeCompanionsScrollView.translatesAutoresizingMaskIntoConstraints = false
        activeCompanionsScrollView.drawsBackground = false
        activeCompanionsScrollView.hasVerticalScroller = true
        activeCompanionsScrollView.hasHorizontalScroller = false
        activeCompanionsScrollView.autohidesScrollers = true
        activeCompanionsScrollView.borderType = .noBorder
        activeCompanionsScrollView.documentView = activeDocumentView
        activeCompanionsScrollView.heightAnchor.constraint(equalToConstant: 96).isActive = true

        let activeSection = DashboardViewController.makeSection(
            arrangedSubviews: [activeTitleLabel, activeHintLabel, activeCompanionsScrollView]
        )

        // 3. Toggles Section
        moveModeSwitch.target = self
        moveModeSwitch.action = #selector(toggleMoveMode)
        let moveModeRow = DashboardViewController.makeSwitchRow(title: "Move Mode", icon: "arrow.up.and.down.and.arrow.left.and.right", toggle: moveModeSwitch)

        clickThroughSwitch.target = self
        clickThroughSwitch.action = #selector(toggleClickThrough)
        let clickThroughRow = DashboardViewController.makeSwitchRow(title: "Click-through", icon: "cursorarrow.click", toggle: clickThroughSwitch)

        let togglesSection = DashboardViewController.makeSection(arrangedSubviews: [moveModeRow, clickThroughRow])

        // 4. Sliders Section
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

        // 5. Library
        let libraryTitleLabel = NSTextField(labelWithString: "Library")
        libraryTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let libraryHintLabel = NSTextField(labelWithString: "Drop a supported file here or load, favorite, rename, and delete saved assets.")
        libraryHintLabel.font = .systemFont(ofSize: 11, weight: .medium)
        libraryHintLabel.textColor = .secondaryLabelColor
        libraryHintLabel.lineBreakMode = .byWordWrapping
        libraryHintLabel.maximumNumberOfLines = 2

        recentAssetsStack.orientation = .vertical
        recentAssetsStack.alignment = .leading
        recentAssetsStack.spacing = 8
        recentAssetsStack.translatesAutoresizingMaskIntoConstraints = false

        recentAssetsEmptyLabel.font = .systemFont(ofSize: 12, weight: .medium)
        recentAssetsEmptyLabel.textColor = .tertiaryLabelColor
        recentAssetsEmptyLabel.stringValue = "No saved assets yet"

        let libraryDocumentView = NSView()
        libraryDocumentView.translatesAutoresizingMaskIntoConstraints = false
        libraryDocumentView.addSubview(recentAssetsStack)

        NSLayoutConstraint.activate([
            recentAssetsStack.leadingAnchor.constraint(equalTo: libraryDocumentView.leadingAnchor),
            recentAssetsStack.trailingAnchor.constraint(equalTo: libraryDocumentView.trailingAnchor),
            recentAssetsStack.topAnchor.constraint(equalTo: libraryDocumentView.topAnchor),
            recentAssetsStack.bottomAnchor.constraint(equalTo: libraryDocumentView.bottomAnchor),
            recentAssetsStack.widthAnchor.constraint(equalTo: libraryDocumentView.widthAnchor)
        ])

        libraryScrollView.translatesAutoresizingMaskIntoConstraints = false
        libraryScrollView.drawsBackground = false
        libraryScrollView.hasVerticalScroller = true
        libraryScrollView.hasHorizontalScroller = false
        libraryScrollView.autohidesScrollers = true
        libraryScrollView.borderType = .noBorder
        libraryScrollView.documentView = libraryDocumentView
        libraryScrollView.contentView.postsBoundsChangedNotifications = true
        libraryScrollView.heightAnchor.constraint(equalToConstant: 180).isActive = true

        let librarySection = DashboardViewController.makeSection(
            arrangedSubviews: [libraryTitleLabel, libraryHintLabel, libraryScrollView]
        )

        // 6. Actions
        let openButton = NSButton(title: "Open…", target: self, action: #selector(openAnimationFile))
        openButton.bezelStyle = .rounded
        openButton.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        openButton.imagePosition = .imageLeading
        openButton.toolTip = "Open an asset from disk"
        
        resetPositionButton.title = "Reset Position"
        resetPositionButton.target = self
        resetPositionButton.action = #selector(resetPosition)
        resetPositionButton.bezelStyle = .rounded
        resetPositionButton.image = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: nil)
        resetPositionButton.imagePosition = .imageLeading
        resetPositionButton.toolTip = "Reset overlay position"

        let buttonRow = NSStackView(views: [openButton, resetPositionButton])
        buttonRow.orientation = .horizontal
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 10

        let optionsButton = NSButton(title: "Shortcuts…", target: self, action: #selector(openOptions))
        optionsButton.bezelStyle = .rounded
        optionsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        optionsButton.imagePosition = .imageLeading
        optionsButton.toolTip = "Edit keyboard shortcuts"

        let actionsSection = DashboardViewController.makeSection(arrangedSubviews: [buttonRow, optionsButton])

        // 7. Footer
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
        let contentStack = NSStackView(views: [headerStack, activeSection, togglesSection, slidersSection, librarySection, actionsSection, footerStack])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        headerStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        activeSection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        togglesSection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        slidersSection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        librarySection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        actionsSection.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        footerStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        let contentDocumentView = NSView()
        contentDocumentView.translatesAutoresizingMaskIntoConstraints = false
        contentDocumentView.addSubview(contentStack)

        let dashboardScrollView = NSScrollView()
        dashboardScrollView.translatesAutoresizingMaskIntoConstraints = false
        dashboardScrollView.drawsBackground = false
        dashboardScrollView.hasVerticalScroller = true
        dashboardScrollView.hasHorizontalScroller = false
        dashboardScrollView.autohidesScrollers = true
        dashboardScrollView.borderType = .noBorder
        dashboardScrollView.documentView = contentDocumentView

        visualEffectView.addSubview(dashboardScrollView)

        NSLayoutConstraint.activate([
            dashboardScrollView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            dashboardScrollView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            dashboardScrollView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            dashboardScrollView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),

            contentDocumentView.leadingAnchor.constraint(equalTo: dashboardScrollView.contentView.leadingAnchor),
            contentDocumentView.trailingAnchor.constraint(equalTo: dashboardScrollView.contentView.trailingAnchor),
            contentDocumentView.topAnchor.constraint(equalTo: dashboardScrollView.contentView.topAnchor),
            contentDocumentView.bottomAnchor.constraint(equalTo: dashboardScrollView.contentView.bottomAnchor),
            contentDocumentView.widthAnchor.constraint(equalTo: dashboardScrollView.contentView.widthAnchor),

            contentStack.leadingAnchor.constraint(equalTo: contentDocumentView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: contentDocumentView.trailingAnchor, constant: -24),
            contentStack.topAnchor.constraint(equalTo: contentDocumentView.topAnchor, constant: 24),
            contentStack.bottomAnchor.constraint(equalTo: contentDocumentView.bottomAnchor, constant: -16)
        ])
    }

    func render(_ state: DashboardState) {
        reloadActiveCompanions(state.activeCompanions)
        setSelectionControlsEnabled(state.hasSelectedCompanion)
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
        } else if state.currentFileURL == nil {
            loadedFileURL = nil
            thumbnailView.clearContent()
        }

        if let name = state.currentFileName, !name.isEmpty {
            fileNameLabel.stringValue = name
            fileNameLabel.textColor = .secondaryLabelColor
        } else {
            fileNameLabel.stringValue = "No companion selected"
            fileNameLabel.textColor = .tertiaryLabelColor
        }

        reloadLibraryAssets(state.libraryAssets)
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

    @objc private func addLibraryAsset(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else {
            return
        }

        delegate?.dashboardViewController(self, didRequestAddLibraryAsset: id)
    }

    @objc private func toggleFavoriteLibraryAsset(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else {
            return
        }

        delegate?.dashboardViewController(self, didToggleFavoriteLibraryAsset: id)
    }

    @objc private func renameLibraryAsset(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Rename Asset"
        alert.informativeText = "Choose a display name for this asset."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.stringValue = currentLibraryAssetName(for: id)
        alert.accessoryView = textField

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        delegate?.dashboardViewController(self, didRenameLibraryAsset: id, to: textField.stringValue)
    }

    @objc private func deleteLibraryAsset(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Delete Asset?"
        alert.informativeText = "This removes the saved asset and its thumbnail from SpriteFlux."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        delegate?.dashboardViewController(self, didDeleteLibraryAsset: id)
    }

    @objc private func selectActiveCompanion(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else {
            return
        }

        delegate?.dashboardViewController(self, didRequestSelectActiveCompanion: id)
    }

    @objc private func removeActiveCompanion(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else {
            return
        }

        delegate?.dashboardViewController(self, didRequestRemoveActiveCompanion: id)
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

    private func reloadActiveCompanions(_ companions: [DashboardActiveCompanion]) {
        activeCompanionsStack.arrangedSubviews.forEach { view in
            activeCompanionsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard companions.isEmpty == false else {
            activeCompanionsStack.addArrangedSubview(activeCompanionsEmptyLabel)
            return
        }

        for companion in companions {
            activeCompanionsStack.addArrangedSubview(makeActiveCompanionRow(for: companion))
        }
    }

    private func reloadLibraryAssets(_ assets: [DashboardLibraryAsset]) {
        recentAssetsStack.arrangedSubviews.forEach { view in
            recentAssetsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard assets.isEmpty == false else {
            recentAssetsStack.addArrangedSubview(recentAssetsEmptyLabel)
            return
        }

        for asset in assets {
            recentAssetsStack.addArrangedSubview(makeLibraryAssetRow(for: asset))
        }
    }

    private func makeLibraryAssetRow(for asset: DashboardLibraryAsset) -> NSView {
        let thumbnailImageView = NSImageView()
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.imageScaling = .scaleAxesIndependently
        thumbnailImageView.wantsLayer = true
        thumbnailImageView.layer?.cornerRadius = 8
        thumbnailImageView.layer?.masksToBounds = true
        thumbnailImageView.widthAnchor.constraint(equalToConstant: 44).isActive = true
        thumbnailImageView.heightAnchor.constraint(equalToConstant: 44).isActive = true
        thumbnailImageView.image = asset.thumbnailURL.flatMap(NSImage.init(contentsOf:)) ?? NSImage(systemSymbolName: "photo", accessibilityDescription: nil)

        let nameLabel = NSTextField(labelWithString: asset.name)
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1

        let detailLabel = NSTextField(labelWithString: "\(asset.formatLabel)  •  \(asset.sourceFileName)")
        detailLabel.font = .systemFont(ofSize: 11, weight: .medium)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingMiddle
        detailLabel.maximumNumberOfLines = 1

        let labelsStack = NSStackView(views: [nameLabel, detailLabel])
        labelsStack.orientation = .vertical
        labelsStack.alignment = .leading
        labelsStack.spacing = 3

        let addButton = makeLibraryActionButton(
            symbolName: asset.isActive ? "plus.circle.fill" : "plus.circle",
            toolTip: "Add companion",
            id: asset.id,
            action: #selector(addLibraryAsset(_:))
        )
        addButton.contentTintColor = asset.isActive ? .controlAccentColor : .secondaryLabelColor

        let favoriteButton = makeLibraryActionButton(
            symbolName: asset.isFavorite ? "star.fill" : "star",
            toolTip: asset.isFavorite ? "Remove favorite" : "Favorite asset",
            id: asset.id,
            action: #selector(toggleFavoriteLibraryAsset(_:))
        )
        favoriteButton.contentTintColor = asset.isFavorite ? .systemYellow : .secondaryLabelColor

        let renameButton = makeLibraryActionButton(
            symbolName: "pencil",
            toolTip: "Rename asset",
            id: asset.id,
            action: #selector(renameLibraryAsset(_:))
        )

        let deleteButton = makeLibraryActionButton(
            symbolName: "trash",
            toolTip: "Delete asset",
            id: asset.id,
            action: #selector(deleteLibraryAsset(_:))
        )

        let controlsStack = NSStackView(views: [addButton, favoriteButton, renameButton, deleteButton])
        controlsStack.orientation = .horizontal
        controlsStack.alignment = .centerY
        controlsStack.spacing = 4

        let row = NSStackView(views: [thumbnailImageView, labelsStack, controlsStack])
        row.identifier = NSUserInterfaceItemIdentifier(asset.id)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        labelsStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        controlsStack.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }

    private func makeActiveCompanionRow(for companion: DashboardActiveCompanion) -> NSView {
        let thumbnailImageView = NSImageView()
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.imageScaling = .scaleAxesIndependently
        thumbnailImageView.wantsLayer = true
        thumbnailImageView.layer?.cornerRadius = 8
        thumbnailImageView.layer?.masksToBounds = true
        thumbnailImageView.widthAnchor.constraint(equalToConstant: 34).isActive = true
        thumbnailImageView.heightAnchor.constraint(equalToConstant: 34).isActive = true
        thumbnailImageView.image = companion.thumbnailURL.flatMap(NSImage.init(contentsOf:)) ?? NSImage(systemSymbolName: "photo", accessibilityDescription: nil)

        let nameLabel = NSTextField(labelWithString: companion.name)
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1

        let detailLabel = NSTextField(labelWithString: companion.formatLabel)
        detailLabel.font = .systemFont(ofSize: 10, weight: .medium)
        detailLabel.textColor = .secondaryLabelColor

        let labelsStack = NSStackView(views: [nameLabel, detailLabel])
        labelsStack.orientation = .vertical
        labelsStack.alignment = .leading
        labelsStack.spacing = 2

        let selectButton = makeLibraryActionButton(
            symbolName: companion.isSelected ? "checkmark.circle.fill" : "circle",
            toolTip: companion.isSelected ? "Selected companion" : "Select companion",
            id: companion.id,
            action: #selector(selectActiveCompanion(_:))
        )
        selectButton.contentTintColor = companion.isSelected ? .controlAccentColor : .secondaryLabelColor

        let removeButton = makeLibraryActionButton(
            symbolName: "xmark.circle",
            toolTip: "Remove companion",
            id: companion.id,
            action: #selector(removeActiveCompanion(_:))
        )

        let controlsStack = NSStackView(views: [selectButton, removeButton])
        controlsStack.orientation = .horizontal
        controlsStack.alignment = .centerY
        controlsStack.spacing = 4

        let row = NSStackView(views: [thumbnailImageView, labelsStack, controlsStack])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        labelsStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        controlsStack.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }

    private func makeLibraryActionButton(symbolName: String, toolTip: String, id: String, action: Selector) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) ?? NSImage(), target: self, action: action)
        button.identifier = NSUserInterfaceItemIdentifier(id)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = toolTip
        return button
    }

    private func currentLibraryAssetName(for id: String) -> String {
        guard let row = recentAssetsStack.arrangedSubviews.first(where: { $0.identifier?.rawValue == id }) as? NSStackView,
              row.arrangedSubviews.count > 1,
              let labelsStack = row.arrangedSubviews[1] as? NSStackView,
              let nameLabel = labelsStack.arrangedSubviews.first as? NSTextField else {
            return ""
        }

        return nameLabel.stringValue
    }

    private func setSelectionControlsEnabled(_ enabled: Bool) {
        moveModeSwitch.isEnabled = enabled
        clickThroughSwitch.isEnabled = enabled
        scaleSlider.isEnabled = enabled
        opacitySlider.isEnabled = enabled
        resetPositionButton.isEnabled = enabled
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
