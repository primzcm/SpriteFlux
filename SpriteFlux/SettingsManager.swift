import Cocoa

final class SettingsManager {
    static let shared = SettingsManager()

    private enum Keys {
        static let lastFilePath = "lastFilePath"
        static let recentFilePaths = "recentFilePaths"
        static let lastWindowOriginX = "lastWindowOriginX"
        static let lastWindowOriginY = "lastWindowOriginY"
        static let clickThroughEnabled = "clickThroughEnabled"
        static let isMoveMode = "isMoveMode"
        static let scale = "scale"
        static let opacity = "opacity"
        static let moveModeHotkeyKeyCode = "moveModeHotkeyKeyCode"
        static let moveModeHotkeyModifiers = "moveModeHotkeyModifiers"
    }

    private let defaults = UserDefaults.standard
    private let maxRecentFiles = 6

    var lastFileURL: URL? {
        get {
            guard let path = defaults.string(forKey: Keys.lastFilePath) else {
                return nil
            }
            return URL(fileURLWithPath: path)
        }
        set {
            if let url = newValue {
                defaults.set(url.path, forKey: Keys.lastFilePath)
            } else {
                defaults.removeObject(forKey: Keys.lastFilePath)
            }
        }
    }

    var recentFileURLs: [URL] {
        let storedPaths = defaults.stringArray(forKey: Keys.recentFilePaths) ?? []
        let uniquePaths = Array(NSOrderedSet(array: storedPaths)) as? [String] ?? []
        let existingPaths = uniquePaths.filter { FileManager.default.fileExists(atPath: $0) }

        if existingPaths != storedPaths {
            defaults.set(existingPaths, forKey: Keys.recentFilePaths)
        }

        return existingPaths.map(URL.init(fileURLWithPath:))
    }

    var lastWindowOrigin: NSPoint? {
        get {
            guard defaults.object(forKey: Keys.lastWindowOriginX) != nil,
                  defaults.object(forKey: Keys.lastWindowOriginY) != nil else {
                return nil
            }
            let x = defaults.double(forKey: Keys.lastWindowOriginX)
            let y = defaults.double(forKey: Keys.lastWindowOriginY)
            return NSPoint(x: x, y: y)
        }
        set {
            if let point = newValue {
                defaults.set(point.x, forKey: Keys.lastWindowOriginX)
                defaults.set(point.y, forKey: Keys.lastWindowOriginY)
            } else {
                defaults.removeObject(forKey: Keys.lastWindowOriginX)
                defaults.removeObject(forKey: Keys.lastWindowOriginY)
            }
        }
    }

    var clickThroughEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.clickThroughEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.clickThroughEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.clickThroughEnabled)
        }
    }

    var isMoveMode: Bool {
        get {
            if defaults.object(forKey: Keys.isMoveMode) == nil {
                return false
            }
            return defaults.bool(forKey: Keys.isMoveMode)
        }
        set {
            defaults.set(newValue, forKey: Keys.isMoveMode)
        }
    }

    var scale: Double {
        get {
            if defaults.object(forKey: Keys.scale) == nil {
                return 1.0
            }
            return defaults.double(forKey: Keys.scale)
        }
        set {
            defaults.set(newValue, forKey: Keys.scale)
        }
    }

    var opacity: Double {
        get {
            if defaults.object(forKey: Keys.opacity) == nil {
                return 1.0
            }
            return defaults.double(forKey: Keys.opacity)
        }
        set {
            defaults.set(newValue, forKey: Keys.opacity)
        }
    }

    var moveModeShortcut: KeyboardShortcut {
        get {
            let defaultShortcut = KeyboardShortcut.moveModeDefault
            let keyCode = defaults.object(forKey: Keys.moveModeHotkeyKeyCode) == nil
                ? defaultShortcut.keyCode
                : UInt32(defaults.integer(forKey: Keys.moveModeHotkeyKeyCode))
            let modifiers = defaults.object(forKey: Keys.moveModeHotkeyModifiers) == nil
                ? defaultShortcut.modifiers
                : UInt32(defaults.integer(forKey: Keys.moveModeHotkeyModifiers))

            return KeyboardShortcut(keyCode: keyCode, modifiers: modifiers)
        }
        set {
            defaults.set(Int(newValue.keyCode), forKey: Keys.moveModeHotkeyKeyCode)
            defaults.set(Int(newValue.modifiers), forKey: Keys.moveModeHotkeyModifiers)
        }
    }

    func registerRecentFile(_ url: URL) {
        var paths = recentFileURLs.map(\.path)
        paths.removeAll { $0 == url.path }
        paths.insert(url.path, at: 0)

        if paths.count > maxRecentFiles {
            paths = Array(paths.prefix(maxRecentFiles))
        }

        defaults.set(paths, forKey: Keys.recentFilePaths)
    }
}
