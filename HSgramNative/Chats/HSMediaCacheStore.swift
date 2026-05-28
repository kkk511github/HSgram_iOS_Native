import Foundation
import Network
import UIKit
import UniformTypeIdentifiers

struct HSMediaCacheStatistics: Equatable {
    let fileCount: Int
    let totalBytes: Int64
}

enum HSMediaCacheKeepDuration: String, CaseIterable, Identifiable {
    case days3
    case days7
    case month
    case forever

    var id: String { rawValue }

    var title: String {
        switch self {
        case .days3:
            return "3 天"
        case .days7:
            return "7 天"
        case .month:
            return "1 个月"
        case .forever:
            return "永久"
        }
    }

    var retentionInterval: TimeInterval? {
        switch self {
        case .days3:
            return 3 * 24 * 60 * 60
        case .days7:
            return 7 * 24 * 60 * 60
        case .month:
            return 31 * 24 * 60 * 60
        case .forever:
            return nil
        }
    }
}

struct HSMediaCacheSizeLimitOption: Identifiable, Hashable {
    let gigabytes: Int?

    var id: String {
        gigabytes.map(String.init) ?? "unlimited"
    }

    var title: String {
        guard let gigabytes else {
            return "不限制"
        }
        return "\(gigabytes) GB"
    }

    var byteLimit: Int64? {
        gigabytes.map { Int64($0) * 1024 * 1024 * 1024 }
    }
}

struct HSMediaCachePolicy: Equatable {
    var keepDuration: HSMediaCacheKeepDuration
    var sizeLimitGigabytes: Int?

    private enum Key {
        static let keepDuration = "HSMediaCacheKeepDuration"
        static let sizeLimitGigabytes = "HSMediaCacheSizeLimitGigabytes"
    }

    static let `default` = HSMediaCachePolicy(keepDuration: .forever, sizeLimitGigabytes: nil)

    static func load(defaults: UserDefaults = .standard) -> HSMediaCachePolicy {
        let keepDuration = defaults.string(forKey: Key.keepDuration)
            .flatMap(HSMediaCacheKeepDuration.init(rawValue:)) ?? Self.default.keepDuration
        let sizeLimit: Int?
        if defaults.object(forKey: Key.sizeLimitGigabytes) == nil {
            sizeLimit = Self.default.sizeLimitGigabytes
        } else {
            let value = defaults.integer(forKey: Key.sizeLimitGigabytes)
            sizeLimit = value > 0 ? value : nil
        }
        return HSMediaCachePolicy(keepDuration: keepDuration, sizeLimitGigabytes: sizeLimit)
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(keepDuration.rawValue, forKey: Key.keepDuration)
        if let sizeLimitGigabytes {
            defaults.set(sizeLimitGigabytes, forKey: Key.sizeLimitGigabytes)
        } else {
            defaults.set(0, forKey: Key.sizeLimitGigabytes)
        }
    }

    static func sizeLimitOptions(fileManager: FileManager = .default) -> [HSMediaCacheSizeLimitOption] {
        let diskSpace = totalDiskSpace(fileManager: fileManager)
        let values: [Int]
        if diskSpace > 100 * 1024 * 1024 * 1024 {
            values = [5, 20, 50]
        } else if diskSpace > 50 * 1024 * 1024 * 1024 {
            values = [5, 16, 32]
        } else if diskSpace > 24 * 1024 * 1024 * 1024 {
            values = [2, 8, 16]
        } else {
            values = [1, 4, 8]
        }
        return values.map { HSMediaCacheSizeLimitOption(gigabytes: $0) } + [HSMediaCacheSizeLimitOption(gigabytes: nil)]
    }

    private static func totalDiskSpace(fileManager: FileManager) -> Int64 {
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            return (attributes[.systemSize] as? NSNumber)?.int64Value ?? 0
        } catch {
            return 0
        }
    }
}

enum HSMediaAutoDownloadNetwork: String, CaseIterable, Codable, Identifiable {
    case wifi
    case cellular

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "蜂窝网络"
        }
    }
}

enum HSMediaAutoDownloadPreset: String, CaseIterable, Codable, Identifiable {
    case low
    case medium
    case high
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low:
            return "低"
        case .medium:
            return "中"
        case .high:
            return "高"
        case .custom:
            return "自定义"
        }
    }

    var categories: HSMediaAutoDownloadCategories {
        switch self {
        case .low:
            return .low
        case .medium:
            return .medium
        case .high:
            return .high
        case .custom:
            return .medium
        }
    }
}

enum HSMediaAutoDownloadPeerType: String, CaseIterable, Codable, Identifiable {
    case contact
    case otherPrivate
    case group
    case channel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .contact:
            return "联系人"
        case .otherPrivate:
            return "私聊"
        case .group:
            return "群聊"
        case .channel:
            return "频道"
        }
    }
}

enum HSMediaAutoDownloadMediaCategory: String, CaseIterable, Codable, Identifiable {
    case photo
    case video
    case file
    case story

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photo:
            return "照片"
        case .video:
            return "视频"
        case .file:
            return "文件"
        case .story:
            return "Stories"
        }
    }
}

struct HSMediaAutoDownloadCategory: Codable, Equatable {
    var contacts: Bool
    var otherPrivate: Bool
    var groups: Bool
    var channels: Bool
    var sizeLimit: Int64
    var predownload: Bool

    func allows(peerType: HSMediaAutoDownloadPeerType) -> Bool {
        switch peerType {
        case .contact:
            return contacts
        case .otherPrivate:
            return otherPrivate
        case .group:
            return groups
        case .channel:
            return channels
        }
    }

    mutating func setAllows(_ enabled: Bool, peerType: HSMediaAutoDownloadPeerType) {
        switch peerType {
        case .contact:
            contacts = enabled
        case .otherPrivate:
            otherPrivate = enabled
        case .group:
            groups = enabled
        case .channel:
            channels = enabled
        }
    }

    var hasAnyPeer: Bool {
        contacts || otherPrivate || groups || channels
    }

    var enabledPeerTitles: [String] {
        HSMediaAutoDownloadPeerType.allCases.compactMap { peerType in
            allows(peerType: peerType) ? peerType.title : nil
        }
    }
}

struct HSMediaAutoDownloadCategories: Codable, Equatable {
    var photo: HSMediaAutoDownloadCategory
    var video: HSMediaAutoDownloadCategory
    var file: HSMediaAutoDownloadCategory
    var stories: HSMediaAutoDownloadCategory

    private enum CodingKeys: String, CodingKey {
        case photo
        case video
        case file
        case stories
    }

    private static let mb: Int64 = 1024 * 1024

    init(
        photo: HSMediaAutoDownloadCategory,
        video: HSMediaAutoDownloadCategory,
        file: HSMediaAutoDownloadCategory,
        stories: HSMediaAutoDownloadCategory
    ) {
        self.photo = photo
        self.video = video
        self.file = file
        self.stories = stories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        photo = try container.decode(HSMediaAutoDownloadCategory.self, forKey: .photo)
        video = try container.decode(HSMediaAutoDownloadCategory.self, forKey: .video)
        file = try container.decode(HSMediaAutoDownloadCategory.self, forKey: .file)
        stories = try container.decodeIfPresent(HSMediaAutoDownloadCategory.self, forKey: .stories) ?? Self.defaultStoriesCategory
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(photo, forKey: .photo)
        try container.encode(video, forKey: .video)
        try container.encode(file, forKey: .file)
        try container.encode(stories, forKey: .stories)
    }

    static let low = HSMediaAutoDownloadCategories(
        photo: HSMediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false),
        video: HSMediaAutoDownloadCategory(contacts: false, otherPrivate: false, groups: false, channels: false, sizeLimit: 1 * mb, predownload: false),
        file: HSMediaAutoDownloadCategory(contacts: false, otherPrivate: false, groups: false, channels: false, sizeLimit: 1 * mb, predownload: false),
        stories: HSMediaAutoDownloadCategory(contacts: false, otherPrivate: false, groups: false, channels: false, sizeLimit: 20 * mb, predownload: false)
    )

    static let medium = HSMediaAutoDownloadCategories(
        photo: HSMediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false),
        video: HSMediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: Int64(2.5 * Double(mb)), predownload: false),
        file: HSMediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false),
        stories: HSMediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 20 * mb, predownload: false)
    )

    static let high = HSMediaAutoDownloadCategories(
        photo: HSMediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 1 * mb, predownload: false),
        video: HSMediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 10 * mb, predownload: true),
        file: HSMediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 3 * mb, predownload: false),
        stories: HSMediaAutoDownloadCategory(contacts: true, otherPrivate: true, groups: true, channels: true, sizeLimit: 20 * mb, predownload: false)
    )

    func category(for mediaCategory: HSMediaAutoDownloadMediaCategory) -> HSMediaAutoDownloadCategory {
        switch mediaCategory {
        case .photo:
            return photo
        case .video:
            return video
        case .file:
            return file
        case .story:
            return stories
        }
    }

    mutating func setCategory(_ category: HSMediaAutoDownloadCategory, for mediaCategory: HSMediaAutoDownloadMediaCategory) {
        switch mediaCategory {
        case .photo:
            photo = category
        case .video:
            video = category
        case .file:
            file = category
        case .story:
            stories = category
        }
    }

    private static let defaultStoriesCategory = HSMediaAutoDownloadCategory(
        contacts: true,
        otherPrivate: true,
        groups: true,
        channels: true,
        sizeLimit: 20 * mb,
        predownload: false
    )
}

struct HSMediaAutoDownloadConnection: Codable, Equatable {
    var enabled: Bool
    var preset: HSMediaAutoDownloadPreset
    var custom: HSMediaAutoDownloadCategories?

    var categories: HSMediaAutoDownloadCategories {
        switch preset {
        case .custom:
            return custom ?? HSMediaAutoDownloadPreset.medium.categories
        case .low, .medium, .high:
            return preset.categories
        }
    }

    mutating func setPreset(_ preset: HSMediaAutoDownloadPreset) {
        if preset == .custom, custom == nil {
            custom = categories
        }
        self.preset = preset
    }

    mutating func setPeerEnabled(
        _ enabled: Bool,
        peerType: HSMediaAutoDownloadPeerType,
        mediaCategory: HSMediaAutoDownloadMediaCategory
    ) {
        updateCategory(for: mediaCategory) { category in
            category.setAllows(enabled, peerType: peerType)
        }
    }

    mutating func updateCategory(
        for mediaCategory: HSMediaAutoDownloadMediaCategory,
        _ update: (inout HSMediaAutoDownloadCategory) -> Void
    ) {
        var updatedCategories = categories
        var category = updatedCategories.category(for: mediaCategory)
        update(&category)
        updatedCategories.setCategory(category, for: mediaCategory)
        preset = .custom
        custom = updatedCategories
    }
}

struct HSEnergyUsageSettings: Codable, Equatable {
    var activationThreshold: Int32
    var autoplayVideo: Bool
    var autoplayGif: Bool
    var loopStickers: Bool
    var loopEmoji: Bool
    var fullTranslucency: Bool
    var extendBackgroundWork: Bool
    var autodownloadInBackground: Bool

    static let `default` = HSEnergyUsageSettings(
        activationThreshold: 15,
        autoplayVideo: true,
        autoplayGif: true,
        loopStickers: true,
        loopEmoji: true,
        fullTranslucency: true,
        extendBackgroundWork: true,
        autodownloadInBackground: true
    )

    static let powerSavingDefault = HSEnergyUsageSettings(
        activationThreshold: 15,
        autoplayVideo: false,
        autoplayGif: false,
        loopStickers: false,
        loopEmoji: false,
        fullTranslucency: false,
        extendBackgroundWork: false,
        autodownloadInBackground: false
    )

    var clampedActivationThreshold: Int32 {
        max(4, min(96, activationThreshold))
    }

    func isPowerSavingActive() -> Bool {
        let threshold = clampedActivationThreshold
        if threshold <= 4 {
            return false
        }
        if threshold >= 96 {
            return true
        }
        let device = UIDevice.current
        let wasMonitoring = device.isBatteryMonitoringEnabled
        device.isBatteryMonitoringEnabled = true
        defer {
            device.isBatteryMonitoringEnabled = wasMonitoring
        }
        let batteryLevel = device.batteryLevel
        guard batteryLevel >= 0 else {
            return ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        return batteryLevel <= Float(threshold) / 100.0 || ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}

struct HSMediaAutoDownloadSettings: Codable, Equatable {
    var wifi: HSMediaAutoDownloadConnection
    var cellular: HSMediaAutoDownloadConnection
    var downloadInBackground: Bool
    var energyUsageSettings: HSEnergyUsageSettings
    var highQualityStories: Bool

    private enum CodingKeys: String, CodingKey {
        case wifi
        case cellular
        case downloadInBackground
        case energyUsageSettings
        case highQualityStories
    }

    private enum Key {
        static let settings = "HSMediaAutoDownloadSettings"
    }

    static let `default` = HSMediaAutoDownloadSettings(
        wifi: HSMediaAutoDownloadConnection(enabled: true, preset: .high, custom: nil),
        cellular: HSMediaAutoDownloadConnection(enabled: true, preset: .medium, custom: nil),
        downloadInBackground: true,
        energyUsageSettings: .default,
        highQualityStories: false
    )

    init(
        wifi: HSMediaAutoDownloadConnection,
        cellular: HSMediaAutoDownloadConnection,
        downloadInBackground: Bool,
        energyUsageSettings: HSEnergyUsageSettings,
        highQualityStories: Bool
    ) {
        self.wifi = wifi
        self.cellular = cellular
        self.downloadInBackground = downloadInBackground
        self.energyUsageSettings = energyUsageSettings
        self.highQualityStories = highQualityStories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = HSMediaAutoDownloadSettings.default
        wifi = try container.decodeIfPresent(HSMediaAutoDownloadConnection.self, forKey: .wifi) ?? defaults.wifi
        cellular = try container.decodeIfPresent(HSMediaAutoDownloadConnection.self, forKey: .cellular) ?? defaults.cellular
        downloadInBackground = try container.decodeIfPresent(Bool.self, forKey: .downloadInBackground) ?? defaults.downloadInBackground
        energyUsageSettings = try container.decodeIfPresent(HSEnergyUsageSettings.self, forKey: .energyUsageSettings) ?? defaults.energyUsageSettings
        highQualityStories = try container.decodeIfPresent(Bool.self, forKey: .highQualityStories) ?? defaults.highQualityStories
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(wifi, forKey: .wifi)
        try container.encode(cellular, forKey: .cellular)
        try container.encode(downloadInBackground, forKey: .downloadInBackground)
        try container.encode(energyUsageSettings, forKey: .energyUsageSettings)
        try container.encode(highQualityStories, forKey: .highQualityStories)
    }

    static func load(defaults: UserDefaults = .standard) -> HSMediaAutoDownloadSettings {
        guard let data = defaults.data(forKey: Key.settings),
              let settings = try? JSONDecoder().decode(HSMediaAutoDownloadSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else {
            return
        }
        defaults.set(data, forKey: Key.settings)
    }

    static func reset(defaults: UserDefaults = .standard) -> HSMediaAutoDownloadSettings {
        defaults.removeObject(forKey: Key.settings)
        return .default
    }

    func connection(for network: HSMediaAutoDownloadNetwork) -> HSMediaAutoDownloadConnection {
        switch network {
        case .wifi:
            return wifi
        case .cellular:
            return cellular
        }
    }

    func summary(for network: HSMediaAutoDownloadNetwork) -> String {
        let connection = connection(for: network)
        guard connection.enabled else {
            return "全部关闭"
        }
        let categories = connection.categories
        var parts: [String] = []
        if categories.photo.hasAnyPeer {
            parts.append("照片\(Self.peerSummary(categories.photo))")
        }
        if categories.video.hasAnyPeer {
            parts.append("视频最高 \(Self.byteText(categories.video.sizeLimit))\(Self.peerSummary(categories.video))")
        }
        if categories.file.hasAnyPeer {
            parts.append("文件最高 \(Self.byteText(categories.file.sizeLimit))\(Self.peerSummary(categories.file))")
        }
        if categories.stories.hasAnyPeer {
            parts.append("Stories\(Self.peerSummary(categories.stories))")
        }
        return parts.isEmpty ? "全部关闭" : parts.joined(separator: "、")
    }

    func allowsAutomaticDownload(
        media: HSMessageMedia,
        network: HSMediaAutoDownloadNetwork,
        peerType: HSMediaAutoDownloadPeerType
    ) -> Bool {
        let connection = connection(for: network)
        guard connection.enabled else {
            return false
        }
        let categories = connection.categories
        switch media.kind {
        case .sticker:
            return true
        case .webpage:
            return false
        case .photo:
            let category = categories.photo
            guard category.allows(peerType: peerType) else {
                return false
            }
            return media.size ?? 0 <= category.sizeLimit
        case .gif, .video:
            let category = categories.video
            guard category.sizeLimit > 0, category.allows(peerType: peerType), let size = media.size else {
                return false
            }
            return size <= category.sizeLimit
        case .voice:
            return media.size ?? Int64.max <= max(2 * 1024 * 1024, categories.file.sizeLimit)
        case .audio, .file:
            let category = categories.file
            guard category.sizeLimit > 0, category.allows(peerType: peerType), let size = media.size else {
                return false
            }
            return size <= category.sizeLimit
        case .unknown:
            return false
        }
    }

    func allowsBackgroundAutomaticDownloads() -> Bool {
        downloadInBackground &&
            energyUsageSettings.autodownloadInBackground &&
            !energyUsageSettings.isPowerSavingActive()
    }

    private static func peerSummary(_ category: HSMediaAutoDownloadCategory) -> String {
        if category.contacts && category.otherPrivate && category.groups && category.channels {
            return ""
        }
        let titles = category.enabledPeerTitles
        guard !titles.isEmpty else {
            return "关闭"
        }
        return "（\(titles.joined(separator: "、"))）"
    }

    private static func byteText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

final class HSMediaNetworkPathMonitor {
    static let shared = HSMediaNetworkPathMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "cloud.hsgram.native.media-network-path")
    private let lock = NSLock()
    private var networkType: HSMediaAutoDownloadNetwork?

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let nextType: HSMediaAutoDownloadNetwork?
            if path.status != .satisfied {
                nextType = nil
            } else if path.usesInterfaceType(.cellular) {
                nextType = .cellular
            } else {
                nextType = .wifi
            }
            self?.lock.lock()
            self?.networkType = nextType
            self?.lock.unlock()
        }
        monitor.start(queue: queue)
    }

    var currentNetworkType: HSMediaAutoDownloadNetwork? {
        lock.lock()
        defer { lock.unlock() }
        return networkType
    }
}

final class HSMediaCacheStore {
    static let shared = HSMediaCacheStore()

    private struct CachedFile {
        let url: URL
        let size: Int64
        let lastAccessDate: Date
    }

    private let fileManager: FileManager
    private let directoryName = "HSgramMedia"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func cachedURL(for media: HSMessageMedia, messageID: Int64) throws -> URL? {
        let url = try cacheURL(for: media, messageID: messageID, createDirectory: false)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return nil
        }
        touch(url)
        return url
    }

    func store(data: Data, media: HSMessageMedia, messageID: Int64) throws -> URL {
        let url = try cacheURL(for: media, messageID: messageID, createDirectory: true)
        try data.write(to: url, options: .atomic)
        touch(url)
        _ = try applyAutomaticEviction(preserving: url)
        return url
    }

    func statistics() throws -> HSMediaCacheStatistics {
        let cachedFiles = try files()
        return HSMediaCacheStatistics(
            fileCount: cachedFiles.count,
            totalBytes: cachedFiles.reduce(Int64(0)) { $0 + $1.size }
        )
    }

    @discardableResult
    func applyAutomaticEviction(
        policy: HSMediaCachePolicy = .load(),
        preserving preservedURL: URL? = nil
    ) throws -> HSMediaCacheStatistics {
        let preservedPath = preservedURL?.standardizedFileURL.path
        var cachedFiles = try files()
        var removedPaths = Set<String>()

        if let retentionInterval = policy.keepDuration.retentionInterval {
            let cutoffDate = Date().addingTimeInterval(-retentionInterval)
            for file in cachedFiles where file.lastAccessDate < cutoffDate && file.url.standardizedFileURL.path != preservedPath {
                try fileManager.removeItem(at: file.url)
                removedPaths.insert(file.url.standardizedFileURL.path)
            }
            if !removedPaths.isEmpty {
                cachedFiles.removeAll { removedPaths.contains($0.url.standardizedFileURL.path) }
            }
        }

        if let sizeLimit = HSMediaCacheSizeLimitOption(gigabytes: policy.sizeLimitGigabytes).byteLimit {
            var totalBytes = cachedFiles.reduce(Int64(0)) { $0 + $1.size }
            let candidates = cachedFiles
                .filter { $0.url.standardizedFileURL.path != preservedPath }
                .sorted { lhs, rhs in
                    if lhs.lastAccessDate == rhs.lastAccessDate {
                        return lhs.url.lastPathComponent < rhs.url.lastPathComponent
                    }
                    return lhs.lastAccessDate < rhs.lastAccessDate
                }
            for file in candidates where totalBytes > sizeLimit {
                try fileManager.removeItem(at: file.url)
                totalBytes -= file.size
                removedPaths.insert(file.url.standardizedFileURL.path)
            }
        }

        if removedPaths.isEmpty {
            return HSMediaCacheStatistics(
                fileCount: cachedFiles.count,
                totalBytes: cachedFiles.reduce(Int64(0)) { $0 + $1.size }
            )
        }
        let remainingFiles = try files()
        return HSMediaCacheStatistics(
            fileCount: remainingFiles.count,
            totalBytes: remainingFiles.reduce(Int64(0)) { $0 + $1.size }
        )
    }

    func clear() throws {
        let directory = try mediaDirectoryURL(create: false)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }

    private func files() throws -> [CachedFile] {
        let directory = try mediaDirectoryURL(create: false)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
            .contentAccessDateKey,
            .contentModificationDateKey
        ]
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: Array(keys)) else {
            return []
        }

        var result: [CachedFile] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: keys)
            guard values.isRegularFile == true else {
                continue
            }
            result.append(CachedFile(
                url: url,
                size: Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0),
                lastAccessDate: values.contentAccessDate ?? values.contentModificationDate ?? .distantPast
            ))
        }
        return result
    }

    private func touch(_ url: URL) {
        var values = URLResourceValues()
        values.contentAccessDate = Date()
        var mutableURL = url
        try? mutableURL.setResourceValues(values)
    }

    private func cacheURL(for media: HSMessageMedia, messageID: Int64, createDirectory: Bool) throws -> URL {
        try mediaDirectoryURL(create: createDirectory)
            .appendingPathComponent(fileName(for: media, messageID: messageID), isDirectory: false)
    }

    private func mediaDirectoryURL(create: Bool) throws -> URL {
        let cacheRoot = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = cacheRoot.appendingPathComponent(directoryName, isDirectory: true)
        if create {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func fileName(for media: HSMessageMedia, messageID: Int64) -> String {
        let rawName = media.fileName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = rawName?.isEmpty == false ? rawName! : "message-\(messageID).\(fallbackFileExtension(for: media))"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let sanitized = String(baseName.unicodeScalars.map { allowed.contains($0) ? Character($0) : Character("-") })
        return sanitized.isEmpty ? "message-\(messageID).dat" : "\(messageID)-\(sanitized)"
    }

    private func fallbackFileExtension(for media: HSMessageMedia) -> String {
        if let mimeType = media.mimeType,
           let type = UTType(mimeType: mimeType),
           let fileExtension = type.preferredFilenameExtension {
            return fileExtension
        }
        switch media.kind {
        case .photo:
            return "jpg"
        case .video:
            return "mp4"
        case .gif:
            return "gif"
        case .audio, .voice:
            return "m4a"
        case .sticker:
            return "webp"
        case .webpage:
            return "html"
        case .file, .unknown:
            return "dat"
        }
    }
}
