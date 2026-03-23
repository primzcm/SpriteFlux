import AVFoundation
import Cocoa

struct AssetLibraryEntry: Codable {
    let id: String
    let assetFileName: String
    let originalFileName: String
    var displayName: String
    var formatLabel: String
    let importedAt: Date
    var lastUsedAt: Date
    var isFavorite: Bool
}

final class AssetLibraryManager {
    static let shared = AssetLibraryManager()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var entries: [AssetLibraryEntry] = []

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        loadEntries()
    }

    func allEntries() -> [AssetLibraryEntry] {
        entries.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite {
                return lhs.isFavorite && !rhs.isFavorite
            }
            if lhs.lastUsedAt != rhs.lastUsedAt {
                return lhs.lastUsedAt > rhs.lastUsedAt
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func entry(id: String) -> AssetLibraryEntry? {
        entries.first { $0.id == id }
    }

    func entry(forAssetURL url: URL) -> AssetLibraryEntry? {
        entries.first { assetURL(for: $0).path == url.path }
    }

    func importAsset(from sourceURL: URL) throws -> AssetLibraryEntry {
        try ensureDirectories()

        let id = UUID().uuidString
        let ext = sourceURL.pathExtension
        let assetFileName = ext.isEmpty ? id : "\(id).\(ext)"
        let destinationURL = assetsDirectoryURL.appendingPathComponent(assetFileName)
        try copyItem(at: sourceURL, to: destinationURL)

        let now = Date()
        let entry = AssetLibraryEntry(
            id: id,
            assetFileName: assetFileName,
            originalFileName: sourceURL.lastPathComponent,
            displayName: sourceURL.deletingPathExtension().lastPathComponent,
            formatLabel: ext.isEmpty ? "FILE" : ext.uppercased(),
            importedAt: now,
            lastUsedAt: now,
            isFavorite: false
        )

        try generateThumbnail(for: entry)
        entries.append(entry)
        try persistEntries()
        return entry
    }

    @discardableResult
    func markUsed(id: String) throws -> AssetLibraryEntry {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            throw AssetLibraryError.entryNotFound
        }

        entries[index].lastUsedAt = Date()
        try persistEntries()
        return entries[index]
    }

    @discardableResult
    func renameEntry(id: String, displayName: String) throws -> AssetLibraryEntry {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            throw AssetLibraryError.entryNotFound
        }

        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw AssetLibraryError.invalidName
        }

        entries[index].displayName = trimmed
        try persistEntries()
        return entries[index]
    }

    @discardableResult
    func toggleFavorite(id: String) throws -> AssetLibraryEntry {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            throw AssetLibraryError.entryNotFound
        }

        entries[index].isFavorite.toggle()
        try persistEntries()
        return entries[index]
    }

    func removeEntry(id: String) throws {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            throw AssetLibraryError.entryNotFound
        }

        let entry = entries.remove(at: index)
        let assetURL = assetURL(for: entry)
        let thumbURL = thumbnailURL(for: entry)

        if fileManager.fileExists(atPath: assetURL.path) {
            try fileManager.removeItem(at: assetURL)
        }

        if fileManager.fileExists(atPath: thumbURL.path) {
            try fileManager.removeItem(at: thumbURL)
        }

        try persistEntries()
    }

    func assetURL(for entry: AssetLibraryEntry) -> URL {
        assetsDirectoryURL.appendingPathComponent(entry.assetFileName)
    }

    func thumbnailURL(for entry: AssetLibraryEntry) -> URL {
        thumbnailsDirectoryURL.appendingPathComponent("\(entry.id).png")
    }

    private var appSupportDirectoryURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("SpriteFlux", isDirectory: true)
    }

    private var libraryDirectoryURL: URL {
        appSupportDirectoryURL.appendingPathComponent("Library", isDirectory: true)
    }

    private var assetsDirectoryURL: URL {
        libraryDirectoryURL.appendingPathComponent("Assets", isDirectory: true)
    }

    private var thumbnailsDirectoryURL: URL {
        libraryDirectoryURL.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    private var metadataURL: URL {
        libraryDirectoryURL.appendingPathComponent("library.json")
    }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: assetsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: thumbnailsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }

    private func loadEntries() {
        do {
            try ensureDirectories()

            guard fileManager.fileExists(atPath: metadataURL.path) else {
                entries = []
                return
            }

            let data = try Data(contentsOf: metadataURL)
            let decodedEntries = try decoder.decode([AssetLibraryEntry].self, from: data)
            entries = decodedEntries.filter { fileManager.fileExists(atPath: assetURL(for: $0).path) }

            if entries.count != decodedEntries.count {
                try persistEntries()
            }
        } catch {
            entries = []
        }
    }

    private func persistEntries() throws {
        try ensureDirectories()
        let data = try encoder.encode(entries)
        try data.write(to: metadataURL, options: .atomic)
    }

    private func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            let data = try Data(contentsOf: sourceURL)
            try data.write(to: destinationURL, options: .atomic)
        }
    }

    private func generateThumbnail(for entry: AssetLibraryEntry) throws {
        let sourceURL = assetURL(for: entry)
        let targetURL = thumbnailURL(for: entry)
        guard let image = thumbnailImage(for: sourceURL),
              let pngData = image.pngData else {
            return
        }

        try pngData.write(to: targetURL, options: .atomic)
    }

    private func thumbnailImage(for sourceURL: URL) -> NSImage? {
        let ext = sourceURL.pathExtension.lowercased()

        if ["mp4", "mov"].contains(ext) {
            return videoThumbnail(for: sourceURL)
        }

        guard let image = NSImage(contentsOf: sourceURL) else {
            return nil
        }

        return image.sf_resizedThumbnail
    }

    private func videoThumbnail(for url: URL) -> NSImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        guard let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) else {
            return nil
        }

        let image = NSImage(cgImage: cgImage, size: .zero)
        return image.sf_resizedThumbnail
    }
}

enum AssetLibraryError: Error {
    case entryNotFound
    case invalidName
}

private extension NSImage {
    var sf_resizedThumbnail: NSImage? {
        let targetSize = NSSize(width: 52, height: 52)
        let image = NSImage(size: targetSize)

        image.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: targetSize)).fill()

        let sourceSize = size == .zero ? targetSize : size
        let ratio = min(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height)
        let scaledSize = NSSize(width: sourceSize.width * ratio, height: sourceSize.height * ratio)
        let origin = NSPoint(
            x: (targetSize.width - scaledSize.width) / 2,
            y: (targetSize.height - scaledSize.height) / 2
        )

        draw(
            in: NSRect(origin: origin, size: scaledSize),
            from: NSRect(origin: .zero, size: sourceSize),
            operation: .sourceOver,
            fraction: 1.0
        )

        image.unlockFocus()
        return image
    }

    var pngData: Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }
}
