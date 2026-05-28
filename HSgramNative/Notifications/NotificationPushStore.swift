import SwiftUI
import UIKit
import UserNotifications

extension Notification.Name {
    static let hsPushDeviceTokenDidChange = Notification.Name("HSPushDeviceTokenDidChange")
    static let hsPushDeviceTokenDidFail = Notification.Name("HSPushDeviceTokenDidFail")
    static let hsRemoteNotificationDidArrive = Notification.Name("HSRemoteNotificationDidArrive")
    static let hsRemoteNotificationDidOpen = Notification.Name("HSRemoteNotificationDidOpen")
    static let hsNativeSyncDidChange = Notification.Name("HSNativeSyncDidChange")
    static let hsChatLocalOutboxDidChange = Notification.Name("HSChatLocalOutboxDidChange")
}

enum HSChatLocalOutboxNotification {
    static let dialogID = "dialog_id"
    static let messageID = "message_id"
    static let preview = "preview"
    static let deliveryState = "delivery_state"
    static let updatedAt = "updated_at"
    static let isClear = "is_clear"
}

enum HSInputActivityNotification {
    static let inputActivities = "input_activities"

    static func activities(from notification: Notification) -> [HSInputActivity] {
        notification.userInfo?[inputActivities] as? [HSInputActivity] ?? []
    }

    static func isTypingOnly(_ notification: Notification) -> Bool {
        let fullRefresh = notification.userInfo?["full_refresh"] as? Bool ?? false
        return !activities(from: notification).isEmpty
            && !fullRefresh
            && notification.userInfo?["dialog_ids"] == nil
            && notification.userInfo?["read_outbox_max_ids"] == nil
    }
}

private enum HSRemoteNotificationRelay {
    static func post(_ name: Notification.Name, userInfo: [AnyHashable: Any]) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
        }
    }
}

private enum HSNotificationCategories {
    static func register() {
        let reply = UNTextInputNotificationAction(
            identifier: "reply",
            title: "Reply",
            options: [],
            textInputButtonTitle: "Reply",
            textInputPlaceholder: "Message"
        )
        let categories: Set<UNNotificationCategory> = [
            UNNotificationCategory(identifier: "unknown", actions: [], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: "r", actions: [reply], intentIdentifiers: [], options: [.allowInCarPlay]),
            UNNotificationCategory(identifier: "m", actions: [reply], intentIdentifiers: [], options: [.allowInCarPlay]),
            UNNotificationCategory(identifier: "gr", actions: [reply], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: "gm", actions: [reply], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: "c", actions: [], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: "t", actions: [], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: "st", actions: [], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: "str", actions: [], intentIdentifiers: [], options: [])
        ]
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
}

final class HSAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        HSNotificationCategories.register()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationCenter.default.post(
            name: .hsPushDeviceTokenDidChange,
            object: deviceToken.map { String(format: "%02x", $0) }.joined()
        )
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .hsPushDeviceTokenDidFail, object: error.localizedDescription)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        HSRemoteNotificationRelay.post(.hsRemoteNotificationDidArrive, userInfo: userInfo)
        completionHandler(.newData)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        HSRemoteNotificationRelay.post(.hsRemoteNotificationDidOpen, userInfo: response.notification.request.content.userInfo)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        HSRemoteNotificationRelay.post(.hsRemoteNotificationDidArrive, userInfo: notification.request.content.userInfo)
        completionHandler([.banner, .list, .sound, .badge])
    }
}

@MainActor
final class NotificationPushStore: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var deviceToken: String?
    @Published private(set) var isRegistering = false
    @Published private(set) var lastStatusMessage: String?
    @Published private(set) var lastErrorMessage: String?

    private let api: HSAPIClient
    private let defaults: UserDefaults
    private var pendingSession: HSUserSession?
    private var pendingOtherUserIDs: [Int64] = []

    init(api: HSAPIClient = .shared, defaults: UserDefaults = .standard) {
        self.api = api
        self.defaults = defaults
        self.deviceToken = defaults.string(forKey: "HSPushDeviceToken")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceTokenDidChange(_:)),
            name: .hsPushDeviceTokenDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceTokenDidFail(_:)),
            name: .hsPushDeviceTokenDidFail,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var authorizationLabel: String {
        switch authorizationStatus {
        case .authorized:
            return "Allowed"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Asked"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Temporary"
        @unknown default:
            return "Unknown"
        }
    }

    var shortDeviceToken: String {
        guard let deviceToken, deviceToken.count > 16 else {
            return deviceToken ?? "None"
        }
        return "\(deviceToken.prefix(8))...\(deviceToken.suffix(8))"
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorizationAndRegister(session: HSUserSession?, savedAccounts: [HSUserSession]) async {
        pendingSession = session
        pendingOtherUserIDs = otherUserIDs(current: session, savedAccounts: savedAccounts)
        registerNotificationCategories()
        isRegistering = true
        lastErrorMessage = nil
        lastStatusMessage = "Requesting notification permission."
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: authorizationOptions)
            await refreshAuthorizationStatus()
            guard granted else {
                isRegistering = false
                lastStatusMessage = nil
                lastErrorMessage = "System notification permission was not granted."
                return
            }
            UIApplication.shared.registerForRemoteNotifications()
            lastStatusMessage = "Waiting for APNs device token."
            if deviceToken != nil {
                await syncRegistration(session: session, savedAccounts: savedAccounts, userInitiated: true)
            }
        } catch {
            isRegistering = false
            lastStatusMessage = nil
            lastErrorMessage = error.localizedDescription
        }
    }

    func syncRegistration(session: HSUserSession?, savedAccounts: [HSUserSession], userInitiated: Bool = false) async {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral else {
            if userInitiated {
                lastErrorMessage = "System notification permission is not enabled."
            }
            isRegistering = false
            return
        }
        guard let session else {
            if userInitiated {
                lastErrorMessage = "Sign in before registering this device for push notifications."
            }
            isRegistering = false
            return
        }
        guard let deviceToken else {
            if userInitiated {
                lastErrorMessage = "APNs has not returned a device token yet."
            }
            isRegistering = false
            return
        }

        isRegistering = true
        lastErrorMessage = nil
        do {
            _ = try await api.registerPushToken(
                token: deviceToken,
                tokenType: 1,
                sandbox: Self.isSandboxBuild,
                otherUserIDs: otherUserIDs(current: session, savedAccounts: savedAccounts),
                session: session
            )
            lastStatusMessage = "Push token registered for this device."
        } catch {
            if userInitiated {
                lastErrorMessage = error.localizedDescription
            }
            lastStatusMessage = "APNs token is ready, but server registration failed."
        }
        isRegistering = false
    }

    func clearBadge() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    @objc private func deviceTokenDidChange(_ notification: Notification) {
        guard let token = notification.object as? String, !token.isEmpty else {
            return
        }
        deviceToken = token
        defaults.set(token, forKey: "HSPushDeviceToken")
        lastStatusMessage = "APNs token received."
        if let pendingSession {
            Task {
                await syncRegistration(
                    session: pendingSession,
                    savedAccounts: [pendingSession] + pendingOtherUserIDs.map {
                        HSUserSession(token: "", userID: $0, displayName: "", email: "")
                    },
                    userInitiated: true
                )
            }
        } else {
            isRegistering = false
        }
    }

    @objc private func deviceTokenDidFail(_ notification: Notification) {
        lastErrorMessage = notification.object as? String ?? "APNs device token registration failed."
        lastStatusMessage = nil
        isRegistering = false
    }

    private func registerNotificationCategories() {
        HSNotificationCategories.register()
    }

    private var authorizationOptions: UNAuthorizationOptions {
        var options: UNAuthorizationOptions = [.alert, .badge, .sound, .carPlay]
        options.insert(.providesAppNotificationSettings)
        return options
    }

    private func otherUserIDs(current: HSUserSession?, savedAccounts: [HSUserSession]) -> [Int64] {
        savedAccounts
            .filter { $0.userID != current?.userID }
            .map(\.userID)
    }

    private static var isSandboxBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}
