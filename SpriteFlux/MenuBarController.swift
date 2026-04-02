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
    private let assetLibrary = AssetLibraryManager.shared
    private let companionManager: CompanionManager
    private let dashboardViewController: DashboardViewController
    private let dashboardWindowController: DashboardWindowController
    private let shortcutSettingsWindowController: ShortcutSettingsWindowController
    private let quickMenu: NSMenu
    private let toggleDashboardMenuItem: NSMenuItem
    private let toggleMoveModeMenuItem: NSMenuItem
    private let toggleClickThroughMenuItem: NSMenuItem

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
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
            title: "Open Asset…",
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
            selector: #selector(companionStateDidChange),
            name: .companionManagerStateDidChange,
            object: companionManager
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
            guard let self, response == .OK, let url = panel.url else {
                return
            }

            guard self.importAndAddCompanion(from: url) else {
                self.showLoadFailedAlert()
                return
            }
        }
    }

    @objc private func toggleMoveMode() {
        companionManager.toggleSelectedMoveMode()
        updateDashboardState()
    }

    @objc private func toggleClickThrough() {
        companionManager.toggleSelectedClickThrough()
        updateDashboardState()
    }

    @objc private func resetPosition() {
        companionManager.resetSelectedPosition()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func companionStateDidChange() {
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
        let selectedCompanion = companionManager.selectedCompanion()
        let selectedController = companionManager.selectedController()
        let selectedEntry = companionManager.selectedAssetEntry()

        let activeCompanions: [DashboardActiveCompanion] = companionManager.allCompanions().compactMap { companion in
            guard let entry = assetLibrary.entry(id: companion.assetEntryID) else {
                return nil
            }

            return DashboardActiveCompanion(
                id: companion.id,
                name: entry.displayName,
                formatLabel: entry.formatLabel,
                thumbnailURL: assetLibrary.thumbnailURL(for: entry),
                isSelected: companion.id == companionManager.selectedCompanionID
            )
        }

        let activeAssetEntryIDs = Set(companionManager.allCompanions().map(\.assetEntryID))
        let libraryAssets = assetLibrary.allEntries().map { entry in
            DashboardLibraryAsset(
                id: entry.id,
                name: entry.displayName,
                formatLabel: entry.formatLabel,
                thumbnailURL: assetLibrary.thumbnailURL(for: entry),
                sourceFileName: entry.originalFileName,
                isFavorite: entry.isFavorite,
                isActive: activeAssetEntryIDs.contains(entry.id)
            )
        }

        let scenePresets = companionManager.allScenePresets().map { preset in
            let companionCount = preset.companions.count
            return DashboardScenePreset(
                id: preset.id,
                name: preset.name,
                detailLabel: companionCount == 1 ? "1 companion" : "\(companionCount) companions"
            )
        }

        let state = DashboardState(
            currentFileName: selectedEntry?.displayName,
            currentFileURL: selectedController?.currentMediaURL,
            activeCompanions: activeCompanions,
            libraryAssets: libraryAssets,
            scenePresets: scenePresets,
            hasSelectedCompanion: selectedCompanion != nil,
            hasActiveCompanions: activeCompanions.isEmpty == false,
            moveModeEnabled: selectedController?.isMoveModeEnabled ?? false,
            clickThroughEnabled: selectedController?.clickThroughEnabled ?? false,
            scale: selectedCompanion?.scale ?? 1.0,
            opacity: selectedCompanion?.opacity ?? 1.0
        )
        dashboardViewController.render(state)
        updateQuickMenuState()
    }

    private func updateQuickMenuState() {
        let hasSelection = companionManager.selectedCompanion() != nil
        toggleDashboardMenuItem.title = dashboardWindowController.isDashboardVisible ? "Hide Dashboard" : "Show Dashboard"
        toggleMoveModeMenuItem.state = companionManager.selectedController()?.isMoveModeEnabled == true ? .on : .off
        toggleClickThroughMenuItem.state = companionManager.selectedController()?.clickThroughEnabled == true ? .on : .off
        toggleMoveModeMenuItem.isEnabled = hasSelection
        toggleClickThroughMenuItem.isEnabled = hasSelection
    }

    private func showLoadFailedAlert() {
        let alert = NSAlert()
        alert.messageText = "Unable to Load File"
        alert.informativeText = "SpriteFlux supports MP4, MOV, GIF, PNG, JPG, JPEG, and WEBP files."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @discardableResult
    private func importAndAddCompanion(from sourceURL: URL) -> Bool {
        do {
            let entry = try assetLibrary.importAsset(from: sourceURL)
            _ = try companionManager.addCompanion(assetEntryID: entry.id)
            updateDashboardState()
            return true
        } catch {
            return false
        }
    }

    // MARK: - DashboardViewControllerDelegate

    func dashboardViewControllerDidRequestOpenAnimation(_ controller: DashboardViewController) {
        openAnimationFile()
    }

    func dashboardViewController(_ controller: DashboardViewController, didRequestImportAsset url: URL) {
        guard importAndAddCompanion(from: url) else {
            showLoadFailedAlert()
            return
        }
    }

    func dashboardViewController(_ controller: DashboardViewController, didRequestAddLibraryAsset id: String) {
        do {
            _ = try companionManager.addCompanion(assetEntryID: id)
            updateDashboardState()
        } catch {
            showLoadFailedAlert()
        }
    }

    func dashboardViewController(_ controller: DashboardViewController, didToggleFavoriteLibraryAsset id: String) {
        do {
            _ = try assetLibrary.toggleFavorite(id: id)
            updateDashboardState()
        } catch {
            NSSound.beep()
        }
    }

    func dashboardViewController(_ controller: DashboardViewController, didRenameLibraryAsset id: String, to newName: String) {
        do {
            _ = try assetLibrary.renameEntry(id: id, displayName: newName)
            updateDashboardState()
        } catch {
            NSSound.beep()
        }
    }

    func dashboardViewController(_ controller: DashboardViewController, didDeleteLibraryAsset id: String) {
        do {
            companionManager.removeCompanions(usingAssetEntryID: id)
            companionManager.removePresetAssetReferences(assetEntryID: id)
            try assetLibrary.removeEntry(id: id)
            updateDashboardState()
        } catch {
            NSSound.beep()
        }
    }

    func dashboardViewController(_ controller: DashboardViewController, didRequestSelectActiveCompanion id: String) {
        companionManager.selectCompanion(id: id)
        updateDashboardState()
    }

    func dashboardViewController(_ controller: DashboardViewController, didRequestRemoveActiveCompanion id: String) {
        companionManager.removeCompanion(id: id)
        updateDashboardState()
    }

    func dashboardViewController(_ controller: DashboardViewController, didRequestSaveScenePreset name: String) {
        do {
            _ = try companionManager.saveScenePreset(named: name)
            updateDashboardState()
        } catch {
            showScenePresetAlert(
                messageText: "Unable to Save Scene",
                informativeText: "Choose a non-empty name and make sure at least one companion is active."
            )
        }
    }

    func dashboardViewController(_ controller: DashboardViewController, didRequestLoadScenePreset id: String) {
        do {
            try companionManager.loadScenePreset(id: id)
            updateDashboardState()
        } catch {
            showScenePresetAlert(
                messageText: "Unable to Load Scene",
                informativeText: "This saved scene no longer contains any available assets."
            )
        }
    }

    func dashboardViewController(_ controller: DashboardViewController, didRequestDeleteScenePreset id: String) {
        do {
            try companionManager.deleteScenePreset(id: id)
            updateDashboardState()
        } catch {
            NSSound.beep()
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
        companionManager.updateSelectedScale(scale)
    }

    func dashboardViewController(_ controller: DashboardViewController, didChangeOpacity opacity: Double) {
        companionManager.updateSelectedOpacity(opacity)
    }

    func dashboardViewControllerDidRequestSettings(_ controller: DashboardViewController) {
        dashboardWindowController.hideDashboard()
        shortcutSettingsWindowController.showShortcutSettings()
        updateQuickMenuState()
    }

    func dashboardViewControllerDidRequestQuit(_ controller: DashboardViewController) {
        quitApp()
    }

    private func showScenePresetAlert(messageText: String, informativeText: String) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
