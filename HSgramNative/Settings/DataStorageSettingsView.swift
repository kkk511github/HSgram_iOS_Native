import SwiftUI

struct DataStorageSettingsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var settings: HSStorageSettings?
    @State private var localCacheStats = HSMediaCacheStatistics(fileCount: 0, totalBytes: 0)
    @State private var cachePolicy = HSMediaCachePolicy.load()
    @State private var autoDownloadSettings = HSMediaAutoDownloadSettings.load()
    @State private var errorMessage: String?
    @State private var isClearingCache = false
    @State private var isConfirmingCacheClear = false
    @State private var isApplyingCachePolicy = false

    var body: some View {
        List {
            if let errorMessage {
                HSErrorBanner(message: errorMessage)
            }

            if let settings {
                Section("用量") {
                    LabeledContent("媒体", value: byteText(settings.mediaBytes))
                    LabeledContent("文档", value: byteText(settings.documentBytes))
                    LabeledContent("缓存", value: byteText(settings.cacheBytes))
                    LabeledContent("其他", value: byteText(settings.otherBytes))
                }

                Section("资源") {
                    LabeledContent("已安装贴纸", value: "\(settings.installedStickerSets)")
                    LabeledContent("精选贴纸", value: "\(settings.featuredStickerSets)")
                    LabeledContent("表情回应", value: "\(settings.availableReactions)")
                }

                automaticDownloadSection
                energySavingSection
            } else if errorMessage == nil {
                ProgressView()
            }

            Section {
                LabeledContent("已缓存文件", value: "\(localCacheStats.fileCount)")
                LabeledContent("占用空间", value: byteText(localCacheStats.totalBytes))
                Picker("保留媒体", selection: Binding(
                    get: { cachePolicy.keepDuration },
                    set: { updateKeepDuration($0) }
                )) {
                    ForEach(HSMediaCacheKeepDuration.allCases) { duration in
                        Text(duration.title).tag(duration)
                    }
                }
                Picker("最大缓存", selection: Binding<Int?>(
                    get: { cachePolicy.sizeLimitGigabytes },
                    set: { updateSizeLimit($0) }
                )) {
                    ForEach(cacheSizeLimitOptions) { option in
                        Text(option.title).tag(option.gigabytes as Int?)
                    }
                }
                if isApplyingCachePolicy {
                    Label("正在按当前策略清理", systemImage: "hourglass")
                        .foregroundStyle(HSTheme.secondaryText)
                }

                Button(role: .destructive) {
                    isConfirmingCacheClear = true
                } label: {
                    HStack {
                        if isClearingCache {
                            ProgressView()
                        } else {
                            Image(systemName: "trash")
                        }
                        Text("清理媒体缓存")
                    }
                }
                .disabled(localCacheStats.fileCount == 0 || isClearingCache)
            } header: {
                Text("本地媒体缓存")
            } footer: {
                Text("保留媒体和最大缓存沿用旧 iOS 的本机缓存策略，只清理本机已下载的图片、视频和文件缓存，不会删除服务端消息或影响 Android/PC。")
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle("数据与存储")
        .confirmationDialog(
            "清理本地媒体缓存？",
            isPresented: $isConfirmingCacheClear,
            titleVisibility: .visible
        ) {
            Button("清理 \(byteText(localCacheStats.totalBytes))", role: .destructive) {
                Task {
                    await clearLocalMediaCache()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("已下载媒体会从本机缓存移除，再次打开时会按现有服务端协议重新下载。")
        }
        .task {
            await refresh()
        }
        .refreshable {
            await refresh()
        }
    }

    private var automaticDownloadSection: some View {
        Section {
            automaticDownloadNetworkControls(.wifi)
            automaticDownloadNetworkControls(.cellular)

            Button {
                autoDownloadSettings = HSMediaAutoDownloadSettings.reset()
            } label: {
                Label("重置自动下载设置", systemImage: "arrow.counterclockwise")
            }
            .disabled(autoDownloadSettings == .default)
        } header: {
            Text("自动下载")
        } footer: {
            Text("设置仅保存在本机，按旧 iOS 的蜂窝/Wi-Fi、低/中/高/自定义、联系人/私聊/群聊/频道来源控制媒体自动缓存。Stories 目前仅保留旧 iOS 自动下载偏好，服务端故事消息尚未迁移。")
        }
    }

    private var energySavingSection: some View {
        Section {
            LabeledContent("当前状态", value: autoDownloadSettings.energyUsageSettings.isPowerSavingActive() ? "省电中" : "正常")
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("省电模式")
                    Spacer()
                    Text(energySavingThresholdText)
                        .foregroundStyle(HSTheme.secondaryText)
                }
                Slider(value: Binding(
                    get: { Double(autoDownloadSettings.energyUsageSettings.clampedActivationThreshold) },
                    set: { updateEnergyActivationThreshold(Int32($0.rounded())) }
                ), in: 4...96, step: 1)
            }
            ForEach(HSEnergySavingItem.allCases) { item in
                Toggle(isOn: Binding(
                    get: { energySavingToggleValue(item) },
                    set: { updateEnergyUsage(item, enabled: $0) }
                )) {
                    Label(item.title, systemImage: item.iconName)
                }
                .disabled(!energySavingOptionsEnabled)
            }
        } header: {
            Text("省电模式")
        } footer: {
            Text("沿用旧 iOS 的省电阈值和选项。达到阈值时会暂停后台自动下载、自动播放和额外后台工作；当前 Native 已将后台自动下载约束接入聊天媒体预缓存。")
        }
    }

    @ViewBuilder
    private func automaticDownloadNetworkControls(_ network: HSMediaAutoDownloadNetwork) -> some View {
        Toggle(isOn: Binding(
            get: { autoDownloadSettings.connection(for: network).enabled },
            set: { updateAutomaticDownload(network: network, enabled: $0) }
        )) {
            Label(network.title, systemImage: automaticDownloadNetworkIcon(network))
        }
        if autoDownloadSettings.connection(for: network).enabled {
            Picker("\(network.title) 用量", selection: Binding(
                get: { autoDownloadSettings.connection(for: network).preset },
                set: { updateAutomaticDownload(network: network, preset: $0) }
            )) {
                ForEach(HSMediaAutoDownloadPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            LabeledContent("\(network.title) 内容", value: autoDownloadSettings.summary(for: network))

            ForEach(HSMediaAutoDownloadMediaCategory.allCases) { mediaCategory in
                let category = automaticDownloadCategory(network: network, mediaCategory: mediaCategory)
                DisclosureGroup {
                    ForEach(automaticDownloadPeerTypes(for: mediaCategory, category: category)) { peerType in
                        Toggle(isOn: Binding(
                            get: {
                                automaticDownloadCategory(network: network, mediaCategory: mediaCategory)
                                    .allows(peerType: peerType)
                            },
                            set: {
                                updateAutomaticDownload(
                                    network: network,
                                    mediaCategory: mediaCategory,
                                    peerType: peerType,
                                    enabled: $0
                                )
                            }
                        )) {
                            Text(automaticDownloadPeerTitle(peerType, mediaCategory: mediaCategory))
                        }
                    }

                    if mediaCategory == .video || mediaCategory == .file {
                        Picker("最大大小", selection: Binding(
                            get: { automaticDownloadCategory(network: network, mediaCategory: mediaCategory).sizeLimit },
                            set: { updateAutomaticDownload(network: network, mediaCategory: mediaCategory, sizeLimit: $0) }
                        )) {
                            ForEach(automaticDownloadSizeOptions(currentSize: category.sizeLimit)) { option in
                                Text(option.title).tag(option.bytes)
                            }
                        }
                    }

                    if mediaCategory == .video {
                        Toggle(isOn: Binding(
                            get: { automaticDownloadCategory(network: network, mediaCategory: .video).predownload },
                            set: { updateAutomaticDownload(network: network, mediaCategory: .video, predownload: $0) }
                        )) {
                            Text("预载较大视频")
                        }
                        .disabled(category.sizeLimit <= 2 * 1024 * 1024)
                    }
                } label: {
                    HStack {
                        Label(mediaCategory.title, systemImage: automaticDownloadMediaIcon(mediaCategory))
                        Spacer()
                        Text(automaticDownloadPeerSummary(mediaCategory: mediaCategory, category: category))
                            .font(.footnote)
                            .foregroundStyle(HSTheme.secondaryText)
                    }
                }
            }
        }
    }

    private func refresh() async {
        refreshLocalCacheStats()
        guard let session = authStore.session else {
            return
        }
        do {
            settings = try await authStore.api.storageSettings(session: session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshLocalCacheStats() {
        do {
            localCacheStats = try HSMediaCacheStore.shared.applyAutomaticEviction(policy: cachePolicy)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearLocalMediaCache() async {
        isClearingCache = true
        defer { isClearingCache = false }
        do {
            try HSMediaCacheStore.shared.clear()
            localCacheStats = try HSMediaCacheStore.shared.statistics()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var cacheSizeLimitOptions: [HSMediaCacheSizeLimitOption] {
        var options = HSMediaCachePolicy.sizeLimitOptions()
        if let currentValue = cachePolicy.sizeLimitGigabytes,
           !options.contains(where: { $0.gigabytes == currentValue }) {
            options.insert(HSMediaCacheSizeLimitOption(gigabytes: currentValue), at: 0)
        }
        return options
    }

    private func updateKeepDuration(_ duration: HSMediaCacheKeepDuration) {
        var updated = cachePolicy
        updated.keepDuration = duration
        updateCachePolicy(updated)
    }

    private func updateSizeLimit(_ gigabytes: Int?) {
        var updated = cachePolicy
        updated.sizeLimitGigabytes = gigabytes
        updateCachePolicy(updated)
    }

    private func updateCachePolicy(_ policy: HSMediaCachePolicy) {
        guard policy != cachePolicy else {
            return
        }
        cachePolicy = policy
        policy.save()
        isApplyingCachePolicy = true
        defer { isApplyingCachePolicy = false }
        refreshLocalCacheStats()
    }

    private func updateAutomaticDownload(network: HSMediaAutoDownloadNetwork, enabled: Bool) {
        var updated = autoDownloadSettings
        switch network {
        case .wifi:
            updated.wifi.enabled = enabled
        case .cellular:
            updated.cellular.enabled = enabled
        }
        updateAutomaticDownloadSettings(updated)
    }

    private func updateAutomaticDownload(network: HSMediaAutoDownloadNetwork, preset: HSMediaAutoDownloadPreset) {
        var updated = autoDownloadSettings
        switch network {
        case .wifi:
            updated.wifi.setPreset(preset)
        case .cellular:
            updated.cellular.setPreset(preset)
        }
        updateAutomaticDownloadSettings(updated)
    }

    private func updateAutomaticDownload(
        network: HSMediaAutoDownloadNetwork,
        mediaCategory: HSMediaAutoDownloadMediaCategory,
        peerType: HSMediaAutoDownloadPeerType,
        enabled: Bool
    ) {
        var updated = autoDownloadSettings
        switch network {
        case .wifi:
            updated.wifi.setPeerEnabled(enabled, peerType: peerType, mediaCategory: mediaCategory)
        case .cellular:
            updated.cellular.setPeerEnabled(enabled, peerType: peerType, mediaCategory: mediaCategory)
        }
        updateAutomaticDownloadSettings(updated)
    }

    private func updateAutomaticDownload(
        network: HSMediaAutoDownloadNetwork,
        mediaCategory: HSMediaAutoDownloadMediaCategory,
        sizeLimit: Int64
    ) {
        var updated = autoDownloadSettings
        switch network {
        case .wifi:
            updated.wifi.updateCategory(for: mediaCategory) { $0.sizeLimit = sizeLimit }
        case .cellular:
            updated.cellular.updateCategory(for: mediaCategory) { $0.sizeLimit = sizeLimit }
        }
        updateAutomaticDownloadSettings(updated)
    }

    private func updateAutomaticDownload(
        network: HSMediaAutoDownloadNetwork,
        mediaCategory: HSMediaAutoDownloadMediaCategory,
        predownload: Bool
    ) {
        var updated = autoDownloadSettings
        switch network {
        case .wifi:
            updated.wifi.updateCategory(for: mediaCategory) { $0.predownload = predownload }
        case .cellular:
            updated.cellular.updateCategory(for: mediaCategory) { $0.predownload = predownload }
        }
        updateAutomaticDownloadSettings(updated)
    }

    private func updateAutomaticDownloadSettings(_ settings: HSMediaAutoDownloadSettings) {
        guard settings != autoDownloadSettings else {
            return
        }
        autoDownloadSettings = settings
        settings.save()
    }

    private func updateEnergyActivationThreshold(_ threshold: Int32) {
        var updated = autoDownloadSettings
        updated.energyUsageSettings.activationThreshold = max(4, min(96, threshold))
        updateAutomaticDownloadSettings(updated)
    }

    private func updateEnergyUsage(_ item: HSEnergySavingItem, enabled: Bool) {
        var updated = autoDownloadSettings
        updated.energyUsageSettings[keyPath: item.keyPath] = enabled
        updateAutomaticDownloadSettings(updated)
    }

    private var energySavingOptionsEnabled: Bool {
        let threshold = autoDownloadSettings.energyUsageSettings.clampedActivationThreshold
        if threshold <= 4 {
            return true
        }
        if threshold >= 96 {
            return false
        }
        return !autoDownloadSettings.energyUsageSettings.isPowerSavingActive()
    }

    private var energySavingThresholdText: String {
        let threshold = autoDownloadSettings.energyUsageSettings.clampedActivationThreshold
        if threshold <= 4 {
            return "永不"
        }
        if threshold >= 96 {
            return "始终"
        }
        return "电量低于 \(threshold)%"
    }

    private func energySavingToggleValue(_ item: HSEnergySavingItem) -> Bool {
        autoDownloadSettings.energyUsageSettings[keyPath: item.keyPath] && energySavingOptionsEnabled
    }

    private func automaticDownloadCategory(
        network: HSMediaAutoDownloadNetwork,
        mediaCategory: HSMediaAutoDownloadMediaCategory
    ) -> HSMediaAutoDownloadCategory {
        autoDownloadSettings.connection(for: network).categories.category(for: mediaCategory)
    }

    private func automaticDownloadNetworkIcon(_ network: HSMediaAutoDownloadNetwork) -> String {
        switch network {
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        }
    }

    private func automaticDownloadMediaIcon(_ mediaCategory: HSMediaAutoDownloadMediaCategory) -> String {
        switch mediaCategory {
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .file:
            return "doc"
        case .story:
            return "circle.dashed"
        }
    }

    private func automaticDownloadPeerTypes(
        for mediaCategory: HSMediaAutoDownloadMediaCategory,
        category: HSMediaAutoDownloadCategory
    ) -> [HSMediaAutoDownloadPeerType] {
        if mediaCategory == .story {
            return category.contacts ? [.contact, .otherPrivate] : [.contact]
        }
        return HSMediaAutoDownloadPeerType.allCases
    }

    private func automaticDownloadPeerTitle(
        _ peerType: HSMediaAutoDownloadPeerType,
        mediaCategory: HSMediaAutoDownloadMediaCategory
    ) -> String {
        if mediaCategory == .story, peerType == .otherPrivate {
            return "已归档联系人"
        }
        return peerType.title
    }

    private func automaticDownloadPeerSummary(
        mediaCategory: HSMediaAutoDownloadMediaCategory,
        category: HSMediaAutoDownloadCategory
    ) -> String {
        if mediaCategory == .story {
            if category.contacts && category.otherPrivate {
                return "全部来源"
            }
            return category.contacts ? "联系人" : "关闭"
        }
        if category.contacts && category.otherPrivate && category.groups && category.channels {
            return "全部来源"
        }
        let titles = category.enabledPeerTitles
        return titles.isEmpty ? "关闭" : titles.joined(separator: "、")
    }

    private func automaticDownloadSizeOptions(currentSize: Int64) -> [HSMediaAutoDownloadSizeOption] {
        let kb: Int64 = 1024
        let mb: Int64 = 1024 * 1024
        var options = [
            HSMediaAutoDownloadSizeOption(bytes: 512 * kb),
            HSMediaAutoDownloadSizeOption(bytes: 1 * mb),
            HSMediaAutoDownloadSizeOption(bytes: Int64(2.5 * Double(mb))),
            HSMediaAutoDownloadSizeOption(bytes: 10 * mb),
            HSMediaAutoDownloadSizeOption(bytes: 100 * mb),
            HSMediaAutoDownloadSizeOption(bytes: 1536 * mb)
        ]
        if !options.contains(where: { $0.bytes == currentSize }) {
            options.insert(HSMediaAutoDownloadSizeOption(bytes: currentSize), at: 0)
        }
        return options
    }

    private func byteText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private struct HSMediaAutoDownloadSizeOption: Identifiable, Hashable {
    let bytes: Int64

    var id: Int64 { bytes }

    var title: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private enum HSEnergySavingItem: String, CaseIterable, Identifiable {
    case autoplayVideo
    case autoplayGif
    case loopStickers
    case loopEmoji
    case fullTranslucency
    case autodownloadInBackground
    case extendBackgroundWork

    var id: String { rawValue }

    var keyPath: WritableKeyPath<HSEnergyUsageSettings, Bool> {
        switch self {
        case .autoplayVideo:
            return \.autoplayVideo
        case .autoplayGif:
            return \.autoplayGif
        case .loopStickers:
            return \.loopStickers
        case .loopEmoji:
            return \.loopEmoji
        case .fullTranslucency:
            return \.fullTranslucency
        case .autodownloadInBackground:
            return \.autodownloadInBackground
        case .extendBackgroundWork:
            return \.extendBackgroundWork
        }
    }

    var title: String {
        switch self {
        case .autoplayVideo:
            return "自动播放视频"
        case .autoplayGif:
            return "自动播放 GIF"
        case .loopStickers:
            return "循环播放贴纸"
        case .loopEmoji:
            return "循环播放表情"
        case .fullTranslucency:
            return "完整透明效果"
        case .autodownloadInBackground:
            return "后台自动下载媒体"
        case .extendBackgroundWork:
            return "延长后台工作"
        }
    }

    var iconName: String {
        switch self {
        case .autoplayVideo:
            return "play.rectangle"
        case .autoplayGif:
            return "sparkles.rectangle.stack"
        case .loopStickers:
            return "face.smiling"
        case .loopEmoji:
            return "sparkles"
        case .fullTranslucency:
            return "square.on.square"
        case .autodownloadInBackground:
            return "arrow.down.circle"
        case .extendBackgroundWork:
            return "clock.arrow.circlepath"
        }
    }
}
