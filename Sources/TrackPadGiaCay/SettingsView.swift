import SwiftUI
import ApplicationServices

// MARK: - Gesture row
struct GestureRow: View {
    let label: String
    let icon: String
    @Binding var action: GestureAction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .frame(minWidth: 60, alignment: .leading)

            Spacer()

            Picker("", selection: $action) {
                ForEach(GestureAction.allCases) { a in
                    HStack {
                        Image(systemName: a.icon)
                        Text(a.rawValue)
                    }
                    .tag(a)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 220, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Permission row
struct PermissionRow: View {
    let title: String
    let description: String
    let icon: String
    let granted: Bool
    let settingsURL: String
    let buttonLabel: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Status icon
            ZStack {
                Circle()
                    .fill(granted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(granted ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.callout.bold())
                    Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(granted ? .green : .orange)
                        .font(.callout)
                    Text(granted ? "Đã cấp" : "Chưa cấp")
                        .font(.caption)
                        .foregroundStyle(granted ? .green : .orange)
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !granted {
                    Button {
                        NSWorkspace.shared.open(URL(string: settingsURL)!)
                    } label: {
                        Label(buttonLabel, systemImage: "arrow.up.right.square")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .padding(.top, 2)
                } else {
                    Button {
                        NSWorkspace.shared.open(URL(string: settingsURL)!)
                    } label: {
                        Label(buttonLabel, systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                    .buttonStyle(.link)
                    .controlSize(.mini)
                    .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(granted ? Color.green.opacity(0.3) : Color.orange.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

// MARK: - Permissions tab
struct PermissionsView: View {
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var inputMonitoringGranted = GestureEngine.shared.isRunning
    @State private var timer: Timer? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cần cấp đủ 1 quyền bắt buộc bên dưới để gesture hoạt động.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)

            PermissionRow(
                title: "Accessibility",
                description: "Bắt buộc — theo dõi chuột giữa và chuyển app.",
                icon: "figure.walk.circle",
                granted: accessibilityGranted,
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
                buttonLabel: "Mở Accessibility Settings"
            )

            PermissionRow(
                title: "Input Monitoring",
                description: "Tùy chọn — nếu chuột giữa của bạn không detect được.",
                icon: "keyboard",
                granted: inputMonitoringGranted,
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
                buttonLabel: "Mở Input Monitoring Settings"
            )

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise.circle")
                    .foregroundStyle(.secondary)
                Text("Tự động cập nhật mỗi 2 giây.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .onAppear {
            refreshAll()
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                refreshAll()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func refreshAll() {
        accessibilityGranted   = AXIsProcessTrusted()
        inputMonitoringGranted = GestureEngine.shared.isRunning
    }
}

// MARK: - Main settings view
struct SettingsView: View {
    @ObservedObject private var store = GestureConfigStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TrackPadGiaCay")
                        .font(.headline)
                    Text("Middle mouse gesture settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            // ── Tabs ────────────────────────────────────────────────────
            TabView {
                // Tab 1: Gestures
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Gestures
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Gestures", systemImage: "hand.draw.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 4)

                            GestureRow(label: "← Kéo trái",  icon: "arrow.left",  action: $store.config.dragLeft)
                            GestureRow(label: "→ Kéo phải",  icon: "arrow.right", action: $store.config.dragRight)
                            GestureRow(label: "↑ Kéo lên",   icon: "arrow.up",    action: $store.config.dragUp)
                            GestureRow(label: "↓ Kéo xuống", icon: "arrow.down",  action: $store.config.dragDown)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)

                        Divider()

                        // Threshold
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Sensitivity", systemImage: "slider.horizontal.3")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                Text("Cần kéo xa:")
                                    .foregroundStyle(.secondary)
                                    .font(.callout)
                                Slider(value: $store.config.threshold, in: 30...250, step: 5)
                                Text("\(Int(store.config.threshold)) px")
                                    .monospacedDigit()
                                    .frame(width: 52, alignment: .trailing)
                                    .font(.callout)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)

                        Divider()

                        // Launch at login
                        Toggle(isOn: $store.config.launchAtLogin) {
                            Label("Tự khởi động cùng hệ thống", systemImage: "power.circle")
                                .font(.callout)
                        }
                        .toggleStyle(.switch)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .onChange(of: store.config.launchAtLogin) { newVal in
                            LaunchAtLogin.set(enabled: newVal)
                        }
                    }
                }
                .tabItem { Label("Gestures", systemImage: "hand.draw.fill") }

                // Tab 2: Permissions
                PermissionsView()
                    .tabItem { Label("Permissions", systemImage: "lock.shield.fill") }
            }

            Divider()

            // ── Footer ───────────────────────────────────────────────────
            HStack {
                Spacer()
                Button("Quit TrackPadGiaCay") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 500, height: 480)
    }
}
