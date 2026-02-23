import SwiftUI
import ApplicationServices

// MARK: - Gesture row
struct GestureRow: View {
    let label: String
    let icon: String
    let lang: AppLanguage
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
                        Text(a.displayName(lang: lang))
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
    let grantedText: String
    let notGrantedText: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
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
                    Text(granted ? grantedText : notGrantedText)
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
    let lang: AppLanguage
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var inputMonitoringGranted = GestureEngine.shared.isRunning
    @State private var timer: Timer? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang == .english
                 ? "At least 1 required permission must be granted for gestures to work."
                 : "Cần cấp đủ 1 quyền bắt buộc bên dưới để gesture hoạt động.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)

            PermissionRow(
                title: "Accessibility",
                description: lang == .english
                    ? "Required — track middle mouse button and switch apps."
                    : "Bắt buộc — theo dõi chuột giữa và chuyển app.",
                icon: "figure.walk.circle",
                granted: accessibilityGranted,
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
                buttonLabel: lang == .english ? "Open Accessibility Settings" : "Mở Accessibility Settings",
                grantedText: lang == .english ? "Granted" : "Đã cấp",
                notGrantedText: lang == .english ? "Not Granted" : "Chưa cấp"
            )

            PermissionRow(
                title: "Input Monitoring",
                description: lang == .english
                    ? "Optional — if your middle mouse button is not detected."
                    : "Tùy chọn — nếu chuột giữa của bạn không detect được.",
                icon: "keyboard",
                granted: inputMonitoringGranted,
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
                buttonLabel: lang == .english ? "Open Input Monitoring Settings" : "Mở Input Monitoring Settings",
                grantedText: lang == .english ? "Granted" : "Đã cấp",
                notGrantedText: lang == .english ? "Not Granted" : "Chưa cấp"
            )

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise.circle")
                    .foregroundStyle(.secondary)
                Text(lang == .english ? "Auto-refreshes every 2 seconds." : "Tự động cập nhật mỗi 2 giây.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .onAppear {
            refreshAll()
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in refreshAll() }
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

// MARK: - Language tab
struct LanguageView: View {
    @ObservedObject private var store = GestureConfigStore.shared

    var body: some View {
        let lang = store.config.language
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Label(lang == .english ? "App Language" : "Ngôn ngữ ứng dụng",
                      systemImage: "globe")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                Picker("", selection: $store.config.language) {
                    ForEach(AppLanguage.allCases) { l in
                        Text(l.displayName).tag(l)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(lang == .english
                     ? "Changes apply immediately to all interface text."
                     : "Thay đổi được áp dụng ngay cho toàn bộ giao diện.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)

            Spacer()
        }
    }
}

// MARK: - Main settings view
struct SettingsView: View {
    @ObservedObject private var store = GestureConfigStore.shared

    var body: some View {
        let lang = store.config.language

        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(spacing: 10) {
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TrackPadGiaCay")
                        .font(.headline)
                    Text(lang == .english
                         ? "Middle mouse gesture settings"
                         : "Cài đặt cử chỉ chuột giữa")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            // Tabs
            TabView {

                // Tab 1: Gestures
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        VStack(alignment: .leading, spacing: 6) {
                            Label(lang == .english ? "Gestures" : "Cử chỉ",
                                  systemImage: "hand.draw.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 4)

                            GestureRow(
                                label: lang == .english ? "← Drag Left"  : "← Kéo trái",
                                icon: "arrow.left",  lang: lang,
                                action: $store.config.dragLeft)
                            GestureRow(
                                label: lang == .english ? "→ Drag Right" : "→ Kéo phải",
                                icon: "arrow.right", lang: lang,
                                action: $store.config.dragRight)
                            GestureRow(
                                label: lang == .english ? "↑ Drag Up"    : "↑ Kéo lên",
                                icon: "arrow.up",    lang: lang,
                                action: $store.config.dragUp)
                            GestureRow(
                                label: lang == .english ? "↓ Drag Down"  : "↓ Kéo xuống",
                                icon: "arrow.down",  lang: lang,
                                action: $store.config.dragDown)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Label(lang == .english ? "Trigger Button" : "Nút kích hoạt",
                                  systemImage: "computermouse")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                Text(lang == .english ? "Button:" : "Nút kích hoạt:")
                                    .foregroundStyle(.secondary)
                                    .font(.callout)
                                Picker("", selection: $store.config.triggerButton) {
                                    ForEach(TriggerButton.allCases) { btn in
                                        Label(btn.label(lang: lang), systemImage: btn.icon)
                                            .tag(btn)
                                    }
                                }
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Label(lang == .english ? "Sensitivity" : "Độ nhạy",
                                  systemImage: "slider.horizontal.3")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                Text(lang == .english ? "Drag distance:" : "Cần kéo xa:")
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

                        Toggle(isOn: $store.config.launchAtLogin) {
                            Label(lang == .english ? "Launch at Login" : "Tự khởi động cùng hệ thống",
                                  systemImage: "power.circle")
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
                .tabItem {
                    Label(lang == .english ? "Gestures" : "Cử chỉ", systemImage: "hand.draw.fill")
                }

                // Tab 2: Permissions
                PermissionsView(lang: lang)
                    .tabItem {
                        Label(lang == .english ? "Permissions" : "Quyền", systemImage: "lock.shield.fill")
                    }

                // Tab 3: Language
                LanguageView()
                    .tabItem {
                        Label(lang == .english ? "Language" : "Ngôn ngữ", systemImage: "globe")
                    }
            }

            Divider()

            HStack {
                Spacer()
                Button(lang == .english ? "Quit TrackPadGiaCay" : "Thoát TrackPadGiaCay") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 500, height: 560)
    }
}
