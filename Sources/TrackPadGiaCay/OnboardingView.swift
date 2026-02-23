import SwiftUI
import ApplicationServices

// MARK: - Onboarding Window Controller
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?

    func showIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        guard window == nil else { return }

        // Tạm thời hiện dock icon để user thấy app
        NSApp.setActivationPolicy(.regular)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "Cấp quyền cho TrackPadGiaCay"
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.center()

        let hosting = NSHostingController(rootView: OnboardingView {
            self.dismiss()
        })
        win.contentViewController = hosting
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    var onDone: () -> Void

    @State private var granted = AXIsProcessTrusted()
    @State private var timer: Timer?
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulse ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                    Image(systemName: "computermouse.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.blue)
                }
                .onAppear { pulse = true }

                Text("TrackPadGiaCay cần 1 quyền")
                    .font(.title2.bold())
                Text("Cho phép app theo dõi chuột giữa để gesture hoạt động.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            .padding(.horizontal, 32)

            Divider().padding(.vertical, 24)

            // Steps
            VStack(alignment: .leading, spacing: 16) {
                StepRow(number: "1", text: "Nhấn nút bên dưới để mở **System Settings**")
                StepRow(number: "2", text: "Tìm **TrackPadGiaCay** trong danh sách")
                StepRow(number: "3", text: "Nếu chưa có → nhấn **+** rồi chọn app trên Desktop")
                StepRow(number: "4", text: "Bật **toggle** cạnh TrackPadGiaCay → Done!")
            }
            .padding(.horizontal, 36)

            Spacer()

            // Status + button
            VStack(spacing: 12) {
                if granted {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                        Text("Đã cấp quyền! Cửa sổ này sẽ tự đóng...")
                            .foregroundStyle(.green)
                            .font(.callout.bold())
                    }
                    .transition(.opacity.combined(with: .scale))
                } else {
                    Button {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        )
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                            Text("Mở Accessibility Settings →")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 36)

                    Text("Sau khi bật toggle, cửa sổ này tự đóng")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: granted)
            .padding(.bottom, 28)
        }
        .frame(width: 520, height: 420)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                let ok = AXIsProcessTrusted()
                withAnimation { granted = ok }
                if ok {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onDone()
                    }
                    timer?.invalidate()
                    timer = nil
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - Step row
struct StepRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 26, height: 26)
                Text(number)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(LocalizedStringKey(text))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
        }
    }
}
