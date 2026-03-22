import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindowController: OverlayWindowController?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let overlay = OverlayWindowController()
        overlay.showWindow(nil)
        overlayWindowController = overlay
        menuBarController = MenuBarController(overlayWindowController: overlay)

        HotkeyManager.shared.onHotkey = { [weak overlay] in
            overlay?.toggleMoveMode()
        }
        HotkeyManager.shared.register()

        if let url = SettingsManager.shared.lastFileURL {
            overlay.loadMedia(url: url)
        }

        menuBarController?.showDashboardWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
    }
}
