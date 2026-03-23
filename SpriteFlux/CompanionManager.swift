import Cocoa

extension Notification.Name {
    static let companionManagerStateDidChange = Notification.Name("CompanionManagerStateDidChange")
}

struct CompanionState: Codable, Equatable {
    let id: String
    let assetEntryID: String
    var originX: Double?
    var originY: Double?
    var scale: Double
    var opacity: Double
    var moveModeEnabled: Bool
    var clickThroughEnabled: Bool
}

final class CompanionManager {
    static let shared = CompanionManager()

    private enum Keys {
        static let activeCompanions = "activeCompanions"
        static let selectedCompanionID = "selectedCompanionID"
    }

    private let defaults = UserDefaults.standard
    private let assetLibrary = AssetLibraryManager.shared
    private var companions: [CompanionState] = []
    private var controllers: [String: OverlayWindowController] = [:]

    var selectedCompanionID: String? {
        didSet {
            if oldValue != selectedCompanionID {
                defaults.set(selectedCompanionID, forKey: Keys.selectedCompanionID)
                postStateDidChange()
            }
        }
    }

    private init() {
        loadPersistedState()
        rebuildControllers()
        normalizeSelection()
    }

    func allCompanions() -> [CompanionState] {
        companions
    }

    func selectedCompanion() -> CompanionState? {
        guard let id = selectedCompanionID else {
            return nil
        }
        return companions.first { $0.id == id }
    }

    func selectedController() -> OverlayWindowController? {
        guard let id = selectedCompanionID else {
            return nil
        }
        return controllers[id]
    }

    func selectedAssetEntry() -> AssetLibraryEntry? {
        guard let companion = selectedCompanion() else {
            return nil
        }
        return assetLibrary.entry(id: companion.assetEntryID)
    }

    func bootstrapLegacyCompanionIfNeeded(from legacyURL: URL?) {
        guard companions.isEmpty, let legacyURL, FileManager.default.fileExists(atPath: legacyURL.path) else {
            return
        }

        let entry: AssetLibraryEntry?
        if let existing = assetLibrary.entry(forAssetURL: legacyURL) {
            entry = existing
        } else {
            entry = try? assetLibrary.importAsset(from: legacyURL)
        }

        guard let entry else {
            return
        }

        _ = try? addCompanion(assetEntryID: entry.id)
    }

    @discardableResult
    func addCompanion(assetEntryID: String) throws -> CompanionState {
        guard let entry = assetLibrary.entry(id: assetEntryID) else {
            throw CompanionManagerError.assetNotFound
        }

        let companion = CompanionState(
            id: UUID().uuidString,
            assetEntryID: assetEntryID,
            originX: nil,
            originY: nil,
            scale: 1.0,
            opacity: 1.0,
            moveModeEnabled: false,
            clickThroughEnabled: true
        )

        companions.append(companion)
        let controller = makeController(for: companion, assetEntry: entry, index: companions.count - 1)
        controllers[companion.id] = controller
        controller.showWindow(nil)
        selectedCompanionID = companion.id
        try persistState()
        postStateDidChange()
        return companion
    }

    func removeCompanion(id: String) {
        guard let index = companions.firstIndex(where: { $0.id == id }) else {
            return
        }

        companions.remove(at: index)
        controllers[id]?.close()
        controllers.removeValue(forKey: id)

        if selectedCompanionID == id {
            selectedCompanionID = companions.first?.id
        }

        persistIgnoringErrors()
        postStateDidChange()
    }

    func removeCompanions(usingAssetEntryID assetEntryID: String) {
        let ids = companions
            .filter { $0.assetEntryID == assetEntryID }
            .map(\.id)

        ids.forEach(removeCompanion(id:))
    }

    func selectCompanion(id: String) {
        guard companions.contains(where: { $0.id == id }) else {
            return
        }

        selectedCompanionID = id
        postStateDidChange()
    }

    func toggleSelectedMoveMode() {
        selectedController()?.toggleMoveMode()
    }

    func toggleSelectedClickThrough() {
        selectedController()?.toggleClickThrough()
    }

    func resetSelectedPosition() {
        selectedController()?.resetPosition()
    }

    func updateSelectedScale(_ scale: Double) {
        selectedController()?.setScale(scale)
    }

    func updateSelectedOpacity(_ opacity: Double) {
        selectedController()?.setOpacity(opacity)
    }

    private func loadPersistedState() {
        if let data = defaults.data(forKey: Keys.activeCompanions),
           let decoded = try? JSONDecoder().decode([CompanionState].self, from: data) {
            companions = decoded
        }

        selectedCompanionID = defaults.string(forKey: Keys.selectedCompanionID)
    }

    private func rebuildControllers() {
        var validCompanions: [CompanionState] = []

        for (index, companion) in companions.enumerated() {
            guard let entry = assetLibrary.entry(id: companion.assetEntryID) else {
                continue
            }

            let controller = makeController(for: companion, assetEntry: entry, index: index)
            controllers[companion.id] = controller
            controller.showWindow(nil)
            validCompanions.append(companion)
        }

        companions = validCompanions
        persistIgnoringErrors()
    }

    private func normalizeSelection() {
        if let selectedCompanionID,
           companions.contains(where: { $0.id == selectedCompanionID }) {
            return
        }

        selectedCompanionID = companions.first?.id
    }

    private func makeController(for companion: CompanionState, assetEntry: AssetLibraryEntry, index: Int) -> OverlayWindowController {
        let origin: NSPoint?
        if let x = companion.originX, let y = companion.originY {
            origin = NSPoint(x: x, y: y)
        } else {
            origin = nil
        }

        let controller = OverlayWindowController(
            companionID: companion.id,
            initialMediaURL: assetLibrary.assetURL(for: assetEntry),
            initialScale: companion.scale,
            initialOpacity: companion.opacity,
            clickThroughEnabled: companion.clickThroughEnabled,
            moveModeEnabled: companion.moveModeEnabled,
            initialOrigin: origin,
            defaultOriginOffsetIndex: index
        )

        controller.onStateChange = { [weak self] snapshot in
            self?.applySnapshot(snapshot)
        }

        return controller
    }

    private func applySnapshot(_ snapshot: OverlayWindowController.StateSnapshot) {
        guard let index = companions.firstIndex(where: { $0.id == snapshot.id }) else {
            return
        }

        companions[index].originX = snapshot.origin.x
        companions[index].originY = snapshot.origin.y
        companions[index].scale = snapshot.scale
        companions[index].opacity = snapshot.opacity
        companions[index].moveModeEnabled = snapshot.moveModeEnabled
        companions[index].clickThroughEnabled = snapshot.clickThroughEnabled
        persistIgnoringErrors()
        postStateDidChange()
    }

    private func persistState() throws {
        let data = try JSONEncoder().encode(companions)
        defaults.set(data, forKey: Keys.activeCompanions)
        defaults.set(selectedCompanionID, forKey: Keys.selectedCompanionID)
    }

    private func persistIgnoringErrors() {
        try? persistState()
    }

    private func postStateDidChange() {
        NotificationCenter.default.post(name: .companionManagerStateDidChange, object: self)
    }
}

enum CompanionManagerError: Error {
    case assetNotFound
}
