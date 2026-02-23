import Cocoa
import SwiftUI

// MARK: - Launch at Login helper
enum LaunchAtLogin {
    static func set(enabled: Bool) {
        // SMAppService (macOS 13+) gerader Weg:
        // Wir verwenden ein einfaches launchd plist approach via shell hier
        // In einer echten Distribution würde man SMAppService nutzen.
        // Hier schreiben wir direkt die LaunchAgent plist.
        let plistDir  = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        let plistPath = plistDir.appendingPathComponent("com.w3leee.TrackPadGiaCay.plist")
        let binary    = Bundle.main.executablePath
                     ?? ProcessInfo.processInfo.arguments[0]

        if enabled {
            try? FileManager.default.createDirectory(at: plistDir, withIntermediateDirectories: true)
            let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
              "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>com.w3leee.TrackPadGiaCay</string>
                <key>ProgramArguments</key>
                <array><string>\(binary)</string></array>
                <key>RunAtLoad</key><true/>
                <key>KeepAlive</key><true/>
                <key>StandardOutPath</key>
                <string>\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/Logs/TrackPadGiaCay.log</string>
                <key>StandardErrorPath</key>
                <string>\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/Logs/TrackPadGiaCay.log</string>
            </dict>
            </plist>
            """
            try? xml.write(to: plistPath, atomically: true, encoding: .utf8)
            Process.launchedProcess(launchPath: "/bin/launchctl",
                arguments: ["load", plistPath.path])
        } else {
            if FileManager.default.fileExists(atPath: plistPath.path) {
                Process.launchedProcess(launchPath: "/bin/launchctl",
                    arguments: ["unload", plistPath.path])
                try? FileManager.default.removeItem(at: plistPath)
            }
        }
    }
}

// MARK: - AppDelegate
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Không hiện dock icon
        NSApp.setActivationPolicy(.accessory)

        // Khởi tracker ngay
        _ = AppHistoryTracker.shared

        // Kiểm tra accessibility
        checkAndStartEngine()

        // Menu bar icon
        setupStatusItem()
    }

    // MARK: - Status bar
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem?.button {
            btn.image = NSImage(systemSymbolName: "computermouse.fill",
                               accessibilityDescription: "TrackPadGiaCay")
            btn.action = #selector(statusBarClicked(_:))
            btn.target = self
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleSettingsWindow()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit TrackPadGiaCay", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openSettings() {
        toggleSettingsWindow()
    }

    // MARK: - Settings window
    private func toggleSettingsWindow() {
        if let w = settingsWindow, w.isVisible {
            w.orderOut(nil)
            return
        }

        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let win = NSPanel(
                contentRect: .zero,
                styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            win.title = "TrackPadGiaCay"
            win.contentViewController = hosting
            win.titlebarAppearsTransparent = true
            win.isMovableByWindowBackground = true
            win.level = .floating
            win.isReleasedWhenClosed = false
            win.center()
            settingsWindow = win
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Accessibility check
    private func checkAndStartEngine() {
        if AXIsProcessTrusted() {
            GestureEngine.shared.start()
            probeAutomationPermission()
        } else {
            // Hiện cửa sổ onboarding ngay trước mặt user
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                OnboardingWindowController.shared.showIfNeeded()
            }
            pollForAccessibility()
        }
    }

    /// Chạy osascript 1 lần ngay khi start để macOS hỏi quyền Automation sớm,
    /// thay vì hỏi giữa lúc user đang dùng gesture.
    private func probeAutomationPermission() {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.5) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments    = ["-e", "tell application \"System Events\" to return name of first process"]
            try? proc.run()
            proc.waitUntilExit()
            let ok = proc.terminationStatus == 0
            print("[TrackPadGiaCay] Automation probe: \(ok ? "✅ granted" : "⏳ pending/denied")")
        }
    }

    /// Polling KHÔNG hiện dialog — chỉ check trạng thái
    private func pollForAccessibility() {
        if AXIsProcessTrusted() {
            print("[TrackPadGiaCay] ✅ Accessibility OK — đang khởi động GestureEngine...")
            GestureEngine.shared.start()
            probeAutomationPermission()
        } else {
            print("[TrackPadGiaCay] ⏳ Chờ Accessibility permission...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.pollForAccessibility()
            }
        }
    }
}
