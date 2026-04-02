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

struct ScenePreset: Codable, Equatable {
    let id: String
    let createdAt: Date
    var name: String
    var updatedAt: Date
    var companions: [CompanionState]
    var selectedCompanionID: String?
}

final class CompanionManager {
    static let shared = CompanionManager()

    private enum Keys {
        static let activeCompanions = "activeCompanions"
        static let selectedCompanionID = "selectedCompanionID"
        static let scenePresets = "scenePresets"
    }

    private let defaults = UserDefaults.standard
    private let assetLibrary = AssetLibraryManager.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var companions: [CompanionState] = []
    private var scenePresets: [ScenePreset] = []
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
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
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

    func allScenePresets() -> [ScenePreset] {
        scenePresets.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
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

    @discardableResult
    func saveScenePreset(named name: String) throws -> ScenePreset {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            throw CompanionManagerError.invalidPresetName
        }
        guard companions.isEmpty == false else {
            throw CompanionManagerError.emptyScene
        }

        let now = Date()
        let presetCompanions = companions
        let normalizedSelectedID = normalizedSelectedCompanionID(selectedCompanionID, in: presetCompanions)
        let preset: ScenePreset

        if let index = scenePresets.firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }) {
            scenePresets[index].name = trimmedName
            scenePresets[index].updatedAt = now
            scenePresets[index].companions = presetCompanions
            scenePresets[index].selectedCompanionID = normalizedSelectedID
            preset = scenePresets[index]
        } else {
            preset = ScenePreset(
                id: UUID().uuidString,
                createdAt: now,
                name: trimmedName,
                updatedAt: now,
                companions: presetCompanions,
                selectedCompanionID: normalizedSelectedID
            )
            scenePresets.append(preset)
        }

        try persistState()
        postStateDidChange()
        return preset
    }

    func loadScenePreset(id: String) throws {
        guard let preset = scenePresets.first(where: { $0.id == id }) else {
            throw CompanionManagerError.presetNotFound
        }

        let validCompanions = sanitize(companions: preset.companions)
        guard validCompanions.isEmpty == false else {
            throw CompanionManagerError.emptyScene
        }

        replaceScene(with: validCompanions, selectedCompanionID: normalizedSelectedCompanionID(preset.selectedCompanionID, in: validCompanions))
    }

    func deleteScenePreset(id: String) throws {
        guard let index = scenePresets.firstIndex(where: { $0.id == id }) else {
            throw CompanionManagerError.presetNotFound
        }

        scenePresets.remove(at: index)
        try persistState()
        postStateDidChange()
    }

    func removePresetAssetReferences(assetEntryID: String) {
        let updatedPresets = scenePresets.compactMap { preset -> ScenePreset? in
            let remainingCompanions = preset.companions.filter { $0.assetEntryID != assetEntryID }
            guard remainingCompanions.isEmpty == false else {
                return nil
            }

            var updatedPreset = preset
            updatedPreset.companions = remainingCompanions
            updatedPreset.selectedCompanionID = normalizedSelectedCompanionID(preset.selectedCompanionID, in: remainingCompanions)
            return updatedPreset
        }

        guard updatedPresets != scenePresets else {
            return
        }

        scenePresets = updatedPresets
        persistIgnoringErrors()
        postStateDidChange()
    }

    private func loadPersistedState() {
        if let data = defaults.data(forKey: Keys.activeCompanions),
           let decoded = try? decoder.decode([CompanionState].self, from: data) {
            companions = decoded
        }

        if let data = defaults.data(forKey: Keys.scenePresets),
           let decoded = try? decoder.decode([ScenePreset].self, from: data) {
            scenePresets = decoded
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
        sanitizeScenePresets()
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

    private func replaceScene(with companions: [CompanionState], selectedCompanionID: String?) {
        controllers.values.forEach { $0.close() }
        controllers.removeAll()
        self.companions = companions

        for (index, companion) in companions.enumerated() {
            guard let entry = assetLibrary.entry(id: companion.assetEntryID) else {
                continue
            }

            let controller = makeController(for: companion, assetEntry: entry, index: index)
            controllers[companion.id] = controller
            controller.showWindow(nil)
        }

        self.selectedCompanionID = normalizedSelectedCompanionID(selectedCompanionID, in: companions)
        persistIgnoringErrors()
        postStateDidChange()
    }

    private func sanitizeScenePresets() {
        scenePresets = scenePresets.compactMap { preset in
            let validCompanions = sanitize(companions: preset.companions)
            guard validCompanions.isEmpty == false else {
                return nil
            }

            var sanitizedPreset = preset
            sanitizedPreset.companions = validCompanions
            sanitizedPreset.selectedCompanionID = normalizedSelectedCompanionID(preset.selectedCompanionID, in: validCompanions)
            return sanitizedPreset
        }
    }

    private func sanitize(companions: [CompanionState]) -> [CompanionState] {
        companions.filter { assetLibrary.entry(id: $0.assetEntryID) != nil }
    }

    private func normalizedSelectedCompanionID(_ selectedCompanionID: String?, in companions: [CompanionState]) -> String? {
        if let selectedCompanionID,
           companions.contains(where: { $0.id == selectedCompanionID }) {
            return selectedCompanionID
        }

        return companions.first?.id
    }

    private func persistState() throws {
        let companionsData = try encoder.encode(companions)
        let presetsData = try encoder.encode(scenePresets)
        defaults.set(companionsData, forKey: Keys.activeCompanions)
        defaults.set(presetsData, forKey: Keys.scenePresets)
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
    case presetNotFound
    case invalidPresetName
    case emptyScene
}
