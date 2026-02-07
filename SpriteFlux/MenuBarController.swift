import Cocoa
import UniformTypeIdentifiers

final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private weak var overlayWindowController: OverlayWindowController?

    private let toggleMoveModeItem: NSMenuItem
    private let toggleClickThroughItem: NSMenuItem

    init(overlayWindowController: OverlayWindowController) {
        self.overlayWindowController = overlayWindowController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        toggleMoveModeItem = NSMenuItem(
            title: "Toggle Move Mode",
            action: #selector(toggleMoveMode),
            keyEquivalent: "m"
        )

        toggleClickThroughItem = NSMenuItem(
            title: "Toggle Click-through",
            action: #selector(toggleClickThrough),
            keyEquivalent: "c"
        )

        super.init()

        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: "Open Animation File...",
            action: #selector(openAnimationFile),
            keyEquivalent: "o"
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        toggleMoveModeItem.target = self
        menu.addItem(toggleMoveModeItem)

        toggleClickThroughItem.target = self
        menu.addItem(toggleClickThroughItem)

        let resetItem = NSMenuItem(
            title: "Reset Position",
            action: #selector(resetPosition),
            keyEquivalent: "r"
        )
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "SpriteFlux")
            button.image?.isTemplate = true
        }

        updateMenuState()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuState()
    }

    @objc private func openAnimationFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie, .gif]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        panel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else {
                return
            }

            guard let overlay = self.overlayWindowController,
                  overlay.loadMedia(url: url) else {
                self.showLoadFailedAlert()
                return
            }
        }
    }

    @objc private func toggleMoveMode() {
        overlayWindowController?.toggleMoveMode()
        updateMenuState()
    }

    @objc private func toggleClickThrough() {
        overlayWindowController?.toggleClickThrough()
        updateMenuState()
    }

    @objc private func resetPosition() {
        overlayWindowController?.resetPosition()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func updateMenuState() {
        guard let overlay = overlayWindowController else {
            return
        }

        toggleMoveModeItem.state = overlay.isMoveModeEnabled ? .on : .off
        toggleClickThroughItem.state = overlay.clickThroughEnabled ? .on : .off
    }

    private func showLoadFailedAlert() {
        let alert = NSAlert()
        alert.messageText = "Unable to Load File"
        alert.informativeText = "SpriteFlux supports MP4, MOV, and GIF files."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
