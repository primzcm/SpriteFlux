import Cocoa
import Carbon

final class ShortcutSettingsWindowController: NSWindowController, NSWindowDelegate {
    private let shortcutSettingsViewController: ShortcutSettingsViewController
    var onBack: (() -> Void)?

    init() {
        shortcutSettingsViewController = ShortcutSettingsViewController()
        let initialSize = shortcutSettingsViewController.preferredContentSize == .zero
            ? NSSize(width: 480, height: 260)
            : shortcutSettingsViewController.preferredContentSize

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Shortcuts"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.center()
        window.isReleasedWhenClosed = false
        window.setContentSize(initialSize)
        window.contentViewController = shortcutSettingsViewController

        super.init(window: window)
        self.window?.delegate = self

        shortcutSettingsViewController.onBack = { [weak self] in
            self?.handleBack()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showShortcutSettings() {
        guard let window else {
            return
        }

        shortcutSettingsViewController.prepareForDisplay()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        shortcutSettingsViewController.cancelShortcutCapture()
    }

    private func handleBack() {
        shortcutSettingsViewController.cancelShortcutCapture()
        window?.orderOut(nil)
        onBack?()
    }
}

final class ShortcutSettingsViewController: NSViewController {
    var onBack: (() -> Void)?

    private let statusLabel = NSTextField(labelWithString: "")
    private let recorderButton = NSButton(title: "", target: nil, action: nil)
    private let recorderTextLabel = NSTextField(labelWithString: "")
    private let recorderIconView = NSImageView()
    private var keyMonitor: Any?
    private var isCapturingShortcut = false

    override func loadView() {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        view = visualEffectView

        preferredContentSize = NSSize(width: 480, height: 260)

        let backButton = NSButton(title: " Back", target: self, action: #selector(goBack))
        backButton.bezelStyle = .rounded
        backButton.image = NSImage(systemSymbolName: "arrow.left", accessibilityDescription: nil)

        let titleLabel = NSTextField(labelWithString: "Shortcuts")
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)

        let subtitleLabel = NSTextField(labelWithString: "Edit your keyboard shortcut.")
        subtitleLabel.textColor = .secondaryLabelColor

        let headerTextStack = NSStackView(views: [titleLabel, subtitleLabel])
        headerTextStack.orientation = .vertical
        headerTextStack.alignment = .centerX
        headerTextStack.spacing = 4
        headerTextStack.translatesAutoresizingMaskIntoConstraints = false

        let headerRow = NSView()
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        backButton.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addSubview(backButton)
        headerRow.addSubview(headerTextStack)

        let shortcutTitleLabel = NSTextField(labelWithString: "Toggle Move Mode")
        shortcutTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        let shortcutDescriptionLabel = NSTextField(labelWithString: "Global shortcut")
        shortcutDescriptionLabel.textColor = .secondaryLabelColor

        let shortcutInfoStack = NSStackView(views: [shortcutTitleLabel, shortcutDescriptionLabel])
        shortcutInfoStack.orientation = .vertical
        shortcutInfoStack.alignment = .leading
        shortcutInfoStack.spacing = 4

        recorderButton.target = self
        recorderButton.action = #selector(toggleShortcutCapture)
        recorderButton.isBordered = false
        recorderButton.wantsLayer = true
        recorderButton.layer?.cornerRadius = 14
        recorderButton.layer?.borderWidth = 1
        recorderButton.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.4).cgColor
        recorderButton.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.35).cgColor
        recorderButton.setContentHuggingPriority(.required, for: .horizontal)
        recorderButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 190).isActive = true
        recorderButton.heightAnchor.constraint(equalToConstant: 34).isActive = true

        recorderIconView.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        recorderIconView.contentTintColor = .labelColor
        recorderIconView.translatesAutoresizingMaskIntoConstraints = false

        recorderTextLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        recorderTextLabel.textColor = .labelColor
        recorderTextLabel.lineBreakMode = .byTruncatingTail
        recorderTextLabel.translatesAutoresizingMaskIntoConstraints = false

        recorderButton.addSubview(recorderIconView)
        recorderButton.addSubview(recorderTextLabel)

        NSLayoutConstraint.activate([
            recorderIconView.leadingAnchor.constraint(equalTo: recorderButton.leadingAnchor, constant: 12),
            recorderIconView.centerYAnchor.constraint(equalTo: recorderButton.centerYAnchor),
            recorderIconView.widthAnchor.constraint(equalToConstant: 18),
            recorderIconView.heightAnchor.constraint(equalToConstant: 18),
            recorderTextLabel.leadingAnchor.constraint(equalTo: recorderIconView.trailingAnchor, constant: 10),
            recorderTextLabel.trailingAnchor.constraint(equalTo: recorderButton.trailingAnchor, constant: -12),
            recorderTextLabel.centerYAnchor.constraint(equalTo: recorderButton.centerYAnchor)
        ])

        let resetButton = NSButton(
            image: NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: "Restore Default")!,
            target: self,
            action: #selector(restoreDefaultShortcut)
        )
        resetButton.isBordered = false
        resetButton.contentTintColor = .secondaryLabelColor
        resetButton.toolTip = "Restore Default"

        let actionRow = NSStackView(views: [recorderButton, resetButton])
        actionRow.orientation = .horizontal
        actionRow.alignment = .centerY
        actionRow.spacing = 10
        actionRow.setContentHuggingPriority(.required, for: .horizontal)

        let spacerView = NSView()
        spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let shortcutRow = NSStackView(views: [shortcutInfoStack, spacerView, actionRow])
        shortcutRow.orientation = .horizontal
        shortcutRow.alignment = .centerY
        shortcutRow.distribution = .fill
        shortcutRow.spacing = 16

        let shortcutCard = NSBox()
        shortcutCard.boxType = .custom
        shortcutCard.cornerRadius = 18
        shortcutCard.borderWidth = 0
        shortcutCard.fillColor = NSColor.windowBackgroundColor.withAlphaComponent(0.22)
        shortcutCard.contentViewMargins = NSSize(width: 18, height: 18)
        shortcutCard.translatesAutoresizingMaskIntoConstraints = false
        shortcutCard.contentView = NSView()

        guard let cardContentView = shortcutCard.contentView else {
            fatalError("Shortcut card content view unavailable")
        }

        shortcutRow.translatesAutoresizingMaskIntoConstraints = false
        cardContentView.addSubview(shortcutRow)

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 1

        let contentStack = NSStackView(views: [headerRow, shortcutCard, statusLabel])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 18
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        visualEffectView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -24),
            contentStack.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 24),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: visualEffectView.bottomAnchor, constant: -24),
            headerRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            headerRow.heightAnchor.constraint(equalToConstant: 70),
            backButton.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            headerTextStack.centerXAnchor.constraint(equalTo: headerRow.centerXAnchor),
            headerTextStack.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            shortcutCard.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            shortcutRow.leadingAnchor.constraint(equalTo: cardContentView.leadingAnchor),
            shortcutRow.trailingAnchor.constraint(equalTo: cardContentView.trailingAnchor),
            shortcutRow.topAnchor.constraint(equalTo: cardContentView.topAnchor),
            shortcutRow.bottomAnchor.constraint(equalTo: cardContentView.bottomAnchor)
        ])

        refreshShortcutValue()
        updateStatus(message: "Click the shortcut to record.")
    }

    deinit {
        stopShortcutCapture()
    }

    func prepareForDisplay() {
        refreshShortcutValue()
        stopShortcutCapture()
        updateStatus(message: "Click the shortcut to record.")
    }

    func cancelShortcutCapture() {
        guard isCapturingShortcut else {
            return
        }

        stopShortcutCapture()
        updateStatus(message: "Canceled.")
    }

    @objc private func toggleShortcutCapture() {
        if isCapturingShortcut {
            cancelShortcutCapture()
            return
        }

        isCapturingShortcut = true
        recorderTextLabel.stringValue = "Recording..."
        recorderTextLabel.textColor = .systemBlue
        recorderIconView.contentTintColor = .systemBlue
        recorderButton.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.5).cgColor
        recorderButton.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        updateStatus(message: "Press keys now. Esc cancels.")

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleShortcutEvent(event)
            return nil
        }
    }

    @objc private func restoreDefaultShortcut() {
        let shortcut = KeyboardShortcut.moveModeDefault
        SettingsManager.shared.moveModeShortcut = shortcut
        HotkeyManager.shared.register(shortcut: shortcut)
        refreshShortcutValue()
        stopShortcutCapture()
        updateStatus(message: "Default restored.")
    }

    @objc private func goBack() {
        onBack?()
    }

    private func handleShortcutEvent(_ event: NSEvent) {
        let keyCode = UInt32(event.keyCode)

        if keyCode == UInt32(kVK_Escape) {
            stopShortcutCapture()
            updateStatus(message: "Canceled.")
            return
        }

        if KeyboardShortcutFormatter.isModifierOnlyKeyCode(keyCode) {
            NSSound.beep()
            updateStatus(message: "Add a modifier and key.")
            return
        }

        let relevantFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let modifiers = KeyboardShortcutFormatter.carbonModifiers(from: relevantFlags)
        if modifiers == 0 {
            NSSound.beep()
            updateStatus(message: "Use Command, Option, Control, or Shift.")
            return
        }

        let shortcut = KeyboardShortcut(keyCode: keyCode, modifiers: modifiers)
        SettingsManager.shared.moveModeShortcut = shortcut
        HotkeyManager.shared.register(shortcut: shortcut)
        refreshShortcutValue()
        stopShortcutCapture()
        updateStatus(message: "Shortcut saved.")
    }

    private func refreshShortcutValue() {
        recorderTextLabel.stringValue = KeyboardShortcutFormatter.symbolicString(for: SettingsManager.shared.moveModeShortcut)
        recorderTextLabel.textColor = .labelColor
        recorderIconView.contentTintColor = .labelColor
        recorderButton.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.4).cgColor
        recorderButton.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.35).cgColor
    }

    private func stopShortcutCapture() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }

        isCapturingShortcut = false
        refreshShortcutValue()
    }

    private func updateStatus(message: String) {
        statusLabel.stringValue = message
    }
}
