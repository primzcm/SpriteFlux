import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let companionManager = CompanionManager.shared
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        companionManager.bootstrapLegacyCompanionIfNeeded(from: SettingsManager.shared.lastFileURL)
        menuBarController = MenuBarController(companionManager: companionManager)

        HotkeyManager.shared.onHotkey = { [weak companionManager] in
            companionManager?.toggleSelectedMoveMode()
        }
        HotkeyManager.shared.register()

        menuBarController?.showDashboardWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
    }
}
