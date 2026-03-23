import Cocoa
import UniformTypeIdentifiers

final class MenuBarController: NSObject, DashboardViewControllerDelegate {
    private static let supportedContentTypes: [UTType] = {
        var types: [UTType] = [.mpeg4Movie, .quickTimeMovie, .gif, .png, .jpeg]

        if let jpg = UTType(filenameExtension: "jpg") {
            types.append(jpg)
        }

        if let webp = UTType(filenameExtension: "webp") {
            types.append(webp)
        }

        return types
    }()

    private let statusItem: NSStatusItem
    private weak var overlayWindowController: OverlayWindowController?
    private let dashboardViewController: DashboardViewController
    private let dashboardWindowController: DashboardWindowController
    private let shortcutSettingsWindowController: ShortcutSettingsWindowController
    private let quickMenu: NSMenu
    private let toggleDashboardMenuItem: NSMenuItem
    private let toggleMoveModeMenuItem: NSMenuItem
    private let toggleClickThroughMenuItem: NSMenuItem

    init(overlayWindowController: OverlayWindowController) {
        self.overlayWindowController = overlayWindowController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        dashboardViewController = DashboardViewController()
        dashboardWindowController = DashboardWindowController(contentViewController: dashboardViewController)
        shortcutSettingsWindowController = ShortcutSettingsWindowController()
        quickMenu = NSMenu()
        toggleDashboardMenuItem = NSMenuItem(
            title: "Show Dashboard",
            action: #selector(toggleDashboardFromMenu),
            keyEquivalent: ""
        )
        toggleMoveModeMenuItem = NSMenuItem(
            title: "Move Mode",
            action: #selector(toggleMoveMode),
            keyEquivalent: "m"
        )
        toggleClickThroughMenuItem = NSMenuItem(
            title: "Click-through",
            action: #selector(toggleClickThrough),
            keyEquivalent: "c"
        )

        super.init()

        dashboardViewController.delegate = self
        shortcutSettingsWindowController.onBack = { [weak self] in
            self?.showDashboardWindow()
        }

        toggleDashboardMenuItem.target = self
        quickMenu.addItem(toggleDashboardMenuItem)

        let openItem = NSMenuItem(
            title: "Open Animation File...",
            action: #selector(openAnimationFile),
            keyEquivalent: "o"
        )
        openItem.target = self
        quickMenu.addItem(openItem)

        quickMenu.addItem(.separator())

        toggleMoveModeMenuItem.target = self
        quickMenu.addItem(toggleMoveModeMenuItem)

        toggleClickThroughMenuItem.target = self
        quickMenu.addItem(toggleClickThroughMenuItem)

        let resetItem = NSMenuItem(
            title: "Reset Position",
            action: #selector(resetPosition),
            keyEquivalent: "r"
        )
        resetItem.target = self
        quickMenu.addItem(resetItem)

        quickMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quickMenu.addItem(quitItem)

        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "SpriteFlux") {
                button.image = image
                button.image?.isTemplate = true
                button.title = ""
            } else {
                button.image = nil
                button.title = "SF"
            }
            button.toolTip = "SpriteFlux"
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(overlayStateDidChange),
            name: .overlayWindowControllerStateDidChange,
            object: overlayWindowController
        )

        updateDashboardState()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let button = statusItem.button,
              let event = NSApp.currentEvent else {
            return
        }

        if event.type == .rightMouseUp {
            updateQuickMenuState()
            NSMenu.popUpContextMenu(quickMenu, with: event, for: button)
            return
        }

        toggleDashboardWindow()
    }

    @objc private func toggleDashboardFromMenu() {
        toggleDashboardWindow()
    }

    @objc private func openAnimationFile() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.allowedContentTypes = Self.supportedContentTypes
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        panel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else {
                return
            }

            guard self.loadAsset(url: url) else {
                self.showLoadFailedAlert()
                return
            }
        }
    }

    @objc private func toggleMoveMode() {
        overlayWindowController?.toggleMoveMode()
        updateDashboardState()
    }

    @objc private func toggleClickThrough() {
        overlayWindowController?.toggleClickThrough()
        updateDashboardState()
    }

    @objc private func resetPosition() {
        overlayWindowController?.resetPosition()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func overlayStateDidChange() {
        updateDashboardState()
    }

    func showDashboardWindow() {
        updateDashboardState()
        dashboardWindowController.showDashboard()
        updateQuickMenuState()
    }

    private func toggleDashboardWindow() {
        updateDashboardState()
        dashboardWindowController.toggleVisibility()
        updateQuickMenuState()
    }

    private func updateDashboardState() {
        guard let overlay = overlayWindowController else {
            return
        }

        let recentAssets = SettingsManager.shared.recentFileURLs.map { url in
            DashboardRecentAsset(
                name: url.deletingPathExtension().lastPathComponent,
                url: url,
                formatLabel: url.pathExtension.uppercased(),
                isCurrent: url == overlay.currentMediaURL
            )
        }

        let state = DashboardState(
            currentFileName: overlay.currentMediaURL?.lastPathComponent,
            currentFileURL: overlay.currentMediaURL,
            recentAssets: recentAssets,
            moveModeEnabled: overlay.isMoveModeEnabled,
            clickThroughEnabled: overlay.clickThroughEnabled,
            scale: SettingsManager.shared.scale,
            opacity: SettingsManager.shared.opacity
        )
        dashboardViewController.render(state)
        updateQuickMenuState()
    }

    private func updateQuickMenuState() {
        toggleDashboardMenuItem.title = dashboardWindowController.isDashboardVisible ? "Hide Dashboard" : "Show Dashboard"
        toggleMoveModeMenuItem.state = overlayWindowController?.isMoveModeEnabled == true ? .on : .off
        toggleClickThroughMenuItem.state = overlayWindowController?.clickThroughEnabled == true ? .on : .off
    }

    private func showLoadFailedAlert() {
        let alert = NSAlert()
        alert.messageText = "Unable to Load File"
        alert.informativeText = "SpriteFlux supports MP4, MOV, GIF, PNG, JPG, JPEG, and WEBP files."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @discardableResult
    private func loadAsset(url: URL) -> Bool {
        guard let overlay = overlayWindowController,
              overlay.loadMedia(url: url) else {
            return false
        }

        updateDashboardState()
        return true
    }

    // MARK: - DashboardViewControllerDelegate

    func dashboardViewControllerDidRequestOpenAnimation(_ controller: DashboardViewController) {
        openAnimationFile()
    }

    func dashboardViewController(_ controller: DashboardViewController, didRequestLoadAsset url: URL) {
        guard loadAsset(url: url) else {
            showLoadFailedAlert()
            return
        }
    }

    func dashboardViewControllerDidToggleMoveMode(_ controller: DashboardViewController) {
        toggleMoveMode()
    }

    func dashboardViewControllerDidToggleClickThrough(_ controller: DashboardViewController) {
        toggleClickThrough()
    }

    func dashboardViewControllerDidRequestResetPosition(_ controller: DashboardViewController) {
        resetPosition()
    }

    func dashboardViewControllerDidRequestHide(_ controller: DashboardViewController) {
        dashboardWindowController.hideDashboard()
        updateQuickMenuState()
    }

    func dashboardViewController(_ controller: DashboardViewController, didChangeScale scale: Double) {
        SettingsManager.shared.scale = scale
        overlayWindowController?.updateScale()
    }

    func dashboardViewController(_ controller: DashboardViewController, didChangeOpacity opacity: Double) {
        SettingsManager.shared.opacity = opacity
        overlayWindowController?.updateOpacity()
    }

    func dashboardViewControllerDidRequestSettings(_ controller: DashboardViewController) {
        dashboardWindowController.hideDashboard()
        shortcutSettingsWindowController.showShortcutSettings()
        updateQuickMenuState()
    }

    func dashboardViewControllerDidRequestQuit(_ controller: DashboardViewController) {
        quitApp()
    }
}
