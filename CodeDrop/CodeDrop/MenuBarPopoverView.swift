import SwiftUI

// MARK: - Anthropic Design Tokens

private enum CDTheme {
    // Anthropic-inspired palette
    static let accent = Color(hex: "D97706")       // warm amber
    static let accentLight = Color(hex: "FEF3C7")   // light amber bg
    static let bg = Color(hex: "FAF9F6")            // warm cream
    static let bgCard = Color(hex: "FFFFFF")
    static let textPrimary = Color(hex: "1C1917")   // charcoal
    static let textSecondary = Color(hex: "78716C")  // warm gray
    static let textTertiary = Color(hex: "A8A29E")
    static let border = Color(hex: "E7E5E4")
    static let success = Color(hex: "059669")
    static let destructive = Color(hex: "DC2626")
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

// MARK: - Main View

struct MenuBarPopoverView: View {
    @EnvironmentObject var store: CodeHistoryStore

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            divider
            actionSection
            divider
            recentCodesSection
            divider
            footerSection
        }
        .frame(width: 320)
        .background(CDTheme.bg)
    }

    private var divider: some View {
        Rectangle()
            .fill(CDTheme.border)
            .frame(height: 0.5)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            // Logo circle
            ZStack {
                Circle()
                    .fill(CDTheme.accent.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image("MenuBarIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 16)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("CodeDrop")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(CDTheme.textPrimary)
                Text("验证码助手")
                    .font(.system(size: 11))
                    .foregroundColor(CDTheme.textTertiary)
            }
            Spacer()
            // Status dot
            if store.isMonitoring {
                HStack(spacing: 4) {
                    Circle()
                        .fill(CDTheme.success)
                        .frame(width: 6, height: 6)
                    Text("监听中")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(CDTheme.success)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(CDTheme.success.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Action

    private var actionSection: some View {
        VStack(spacing: 12) {
            if !store.hasAccess {
                accessWarning
            } else if store.isMonitoring {
                monitoringView
            } else {
                startButton
            }
        }
        .padding(16)
    }

    private var startButton: some View {
        VStack(spacing: 10) {
            Button(action: { store.startMonitoring() }) {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 14, weight: .medium))
                    Text("开始接收验证码")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundColor(.white)
                .background(CDTheme.accent)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Tip
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 9))
                Text("确保 iPhone 与 Mac 登录同一个 Apple ID")
                    .font(.system(size: 10))
            }
            .foregroundColor(CDTheme.textTertiary)
        }
    }

    private var monitoringView: some View {
        VStack(spacing: 14) {
            // Countdown ring
            ZStack {
                Circle()
                    .stroke(CDTheme.accent.opacity(0.15), lineWidth: 3)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: CGFloat(store.remainingSeconds) / 180.0)
                    .stroke(CDTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 3), value: store.remainingSeconds)
                Text(store.countdownText)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(CDTheme.textPrimary)
            }

            Text("正在监听新验证码…")
                .font(.system(size: 11))
                .foregroundColor(CDTheme.textSecondary)

            Button(action: { store.stopMonitoring() }) {
                Text("停止监听")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(CDTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(CDTheme.border.opacity(0.5))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    private var accessWarning: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 24))
                .foregroundColor(CDTheme.accent)

            Text("需要磁盘访问权限")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(CDTheme.textPrimary)

            Text("系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 添加 CodeDrop")
                .font(.system(size: 11))
                .foregroundColor(CDTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Button(action: {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                )
            }) {
                Text("打开系统设置")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(CDTheme.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(CDTheme.accent.opacity(0.1))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Recent Codes

    private var recentCodesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.recentCodes.isEmpty {
                emptyState
            } else {
                codeList
            }
        }
        .frame(minHeight: 80, maxHeight: 260)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 20))
                .foregroundColor(CDTheme.border)
            Text("暂无验证码")
                .font(.system(size: 12))
                .foregroundColor(CDTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }

    private var codeList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.recentCodes) { entry in
                    codeRow(entry)
                    if entry.id != store.recentCodes.last?.id {
                        Rectangle()
                            .fill(CDTheme.border)
                            .frame(height: 0.5)
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }

    private func codeRow(_ entry: VerificationCode) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.code)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(CDTheme.textPrimary)
                HStack(spacing: 4) {
                    Text(entry.sender)
                        .font(.system(size: 10))
                        .foregroundColor(CDTheme.textSecondary)
                    Text("·")
                        .foregroundColor(CDTheme.textTertiary)
                    Text(entry.timestamp, style: .relative)
                        .font(.system(size: 10))
                        .foregroundColor(CDTheme.textTertiary)
                }
            }
            Spacer()
            Button(action: { store.copyCode(entry.code) }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundColor(CDTheme.accent)
                    .padding(6)
                    .background(CDTheme.accent.opacity(0.1))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("复制验证码")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            store.copyCode(entry.code)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            if !store.recentCodes.isEmpty {
                Button(action: { store.clearHistory() }) {
                    Text("清除历史")
                        .font(.system(size: 11))
                        .foregroundColor(CDTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            Spacer()
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("退出")
                    .font(.system(size: 11))
                    .foregroundColor(CDTheme.textTertiary)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
