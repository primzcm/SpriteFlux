import Cocoa

final class DashboardWindowController: NSWindowController {
    var isDashboardVisible: Bool {
        window?.isVisible ?? false
    }

    init(contentViewController: NSViewController) {
        let initialSize = contentViewController.preferredContentSize == .zero
            ? NSSize(width: 360, height: 320)
            : contentViewController.preferredContentSize

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "SpriteFlux Dashboard"
        window.center()
        window.isReleasedWhenClosed = false
        window.setContentSize(initialSize)
        window.contentViewController = contentViewController

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggleVisibility() {
        if isDashboardVisible {
            hideDashboard()
        } else {
            showDashboard()
        }
    }

    func showDashboard() {
        guard let window else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func hideDashboard() {
        window?.orderOut(nil)
    }
}
