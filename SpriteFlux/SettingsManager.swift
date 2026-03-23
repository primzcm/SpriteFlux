import Cocoa

final class SettingsManager {
    static let shared = SettingsManager()

    private enum Keys {
        static let lastFilePath = "lastFilePath"
        static let lastWindowOriginX = "lastWindowOriginX"
        static let lastWindowOriginY = "lastWindowOriginY"
        static let clickThroughEnabled = "clickThroughEnabled"
        static let isMoveMode = "isMoveMode"
        static let scale = "scale"
        static let opacity = "opacity"
    }

    private let defaults = UserDefaults.standard

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
}
