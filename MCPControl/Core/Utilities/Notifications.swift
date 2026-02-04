//
//  Notifications.swift
//  MCPControl
//
//  User notifications for server status changes
//

import Foundation
import UserNotifications

// MARK: - Notification Names

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let openAddServer = Notification.Name("openAddServer")
    static let openImport = Notification.Name("openImport")
    static let openBrowse = Notification.Name("openBrowse")
    static let openServerDetail = Notification.Name("openServerDetail")
    static let openStdioServerConfig = Notification.Name("openStdioServerConfig")
    static let serverRemoved = Notification.Name("serverRemoved")
}

class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func notifyServerFailed(serverName: String, message: String?) {
        let content = UNMutableNotificationContent()
        content.title = "MCP Server Failed"
        content.subtitle = serverName
        content.body = message ?? "The server is not responding"
        content.sound = .default
        content.categoryIdentifier = "SERVER_FAILURE"

        let request = UNNotificationRequest(
            identifier: "server-failure-\(serverName)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    func notifyAuthExpired(serverName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Authentication Required"
        content.subtitle = serverName
        content.body = "The server needs re-authentication"
        content.sound = .default
        content.categoryIdentifier = "AUTH_REQUIRED"

        let request = UNNotificationRequest(
            identifier: "auth-expired-\(serverName)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    func notifySyncCompleted(serverCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Sync Complete"
        content.body = "\(serverCount) server(s) synced successfully"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "sync-complete-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    func notifySyncFailed(error: String) {
        let content = UNMutableNotificationContent()
        content.title = "Sync Failed"
        content.body = error
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "sync-failed-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    func notifyServerRecovered(serverName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Server Recovered"
        content.subtitle = serverName
        content.body = "The server is now responding normally"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "server-recovered-\(serverName)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    func clearAllNotifications() {
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }

    func setupNotificationCategories() {
        let restartAction = UNNotificationAction(
            identifier: "RESTART_SERVER",
            title: "Restart",
            options: []
        )

        let viewAction = UNNotificationAction(
            identifier: "VIEW_DETAILS",
            title: "View Details",
            options: [.foreground]
        )

        let reAuthAction = UNNotificationAction(
            identifier: "RE_AUTHENTICATE",
            title: "Re-authenticate",
            options: [.foreground]
        )

        let failureCategory = UNNotificationCategory(
            identifier: "SERVER_FAILURE",
            actions: [restartAction, viewAction],
            intentIdentifiers: [],
            options: []
        )

        let authCategory = UNNotificationCategory(
            identifier: "AUTH_REQUIRED",
            actions: [reAuthAction, viewAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([failureCategory, authCategory])
    }
}

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    var onRestartServer: ((String) -> Void)?
    var onViewDetails: ((String) -> Void)?
    var onReAuthenticate: ((String) -> Void)?

    private override init() {
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let serverName = response.notification.request.content.subtitle

        switch response.actionIdentifier {
        case "RESTART_SERVER":
            onRestartServer?(serverName)
        case "VIEW_DETAILS":
            onViewDetails?(serverName)
        case "RE_AUTHENTICATE":
            onReAuthenticate?(serverName)
        case UNNotificationDefaultActionIdentifier:
            onViewDetails?(serverName)
        default:
            break
        }

        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
