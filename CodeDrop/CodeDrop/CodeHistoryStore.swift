import SwiftUI
import UserNotifications

struct VerificationCode: Identifiable {
    let id = UUID()
    let code: String
    let sender: String
    let timestamp: Date
}

@MainActor
class CodeHistoryStore: ObservableObject {
    @Published var isMonitoring = false
    @Published var remainingSeconds = 0
    @Published var recentCodes: [VerificationCode] = []
    @Published var errorMessage: String?
    @Published var hasAccess = true

    private let monitor = SMSMonitor()
    private var timer: Timer?
    private let monitorDuration = 180 // 3 minutes
    private let pollInterval: TimeInterval = 3

    var countdownText: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    init() {
        requestNotificationPermission()
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }

        guard monitor.checkAccess() else {
            hasAccess = false
            errorMessage = "需要「完全磁盘访问权限」"
            return
        }

        hasAccess = true
        errorMessage = nil
        isMonitoring = true
        remainingSeconds = monitorDuration

        monitor.initializeBaseline()

        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        sendNotification(title: "CodeDrop", body: "验证码监听已开启，持续 3 分钟")
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        remainingSeconds = 0
    }

    private func tick() {
        remainingSeconds -= Int(pollInterval)

        if remainingSeconds <= 0 {
            stopMonitoring()
            sendNotification(title: "CodeDrop", body: "监听已结束")
            return
        }

        // Poll for new messages
        let messages = monitor.fetchNewMessages()
        for msg in messages {
            if let code = SMSMonitor.extractCode(from: msg.text) {
                let entry = VerificationCode(
                    code: code,
                    sender: msg.sender.isEmpty ? "未知号码" : msg.sender,
                    timestamp: Date()
                )
                recentCodes.insert(entry, at: 0)

                // Copy to clipboard
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)

                // Send notification
                let senderDisplay = entry.sender
                sendNotification(title: "收到验证码", body: "\(code)（来自 \(senderDisplay)）")
            }
        }
    }

    // MARK: - Notifications

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - History

    func clearHistory() {
        recentCodes.removeAll()
    }

    func copyCode(_ code: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
    }
}
