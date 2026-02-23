import Cocoa

/// Tracks MRU order of activated applications.
/// history[0] = most recently used (current), history[1] = previous, etc.
/// During gesture navigation history is FROZEN so cursor index stays valid.
final class AppHistoryTracker {
    static let shared = AppHistoryTracker()

    private var history: [NSRunningApplication] = []
    /// Current position in history. 0 = most recent app.
    private var switchCursor: Int = 0
    /// Bundle ID của app chúng ta vừa kích hoạt (gesture-triggered)
    private var pendingBundle: String? = nil
    /// Không reset cursor cho đến thời điểm này (dùng sau system gestures)
    private var suppressCursorResetUntil: Date = .distantPast
    private let lock = NSLock()

    /// Bundle ID của chính tool này — không bao giờ switch sang đây
    private let selfBundle = Bundle.main.bundleIdentifier ?? "com.w3leee.TrackPadGiaCay"

    private init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        // Seed lịch sử — sort theo activation time nếu có
        for app in NSWorkspace.shared.runningApplications
            where app.activationPolicy == .regular && app.bundleIdentifier != selfBundle {
            history.append(app)
        }
        // Đảm bảo app đang foreground ở đầu tiên
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != selfBundle {
            history.removeAll { $0.bundleIdentifier == front.bundleIdentifier }
            history.insert(front, at: 0)
        }
    }

    @objc private func appActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }
        guard app.bundleIdentifier != selfBundle else { return }
        guard app.activationPolicy == .regular else { return }
        // Loại bỏ các system helper process không phải app thật
        let blocklist = ["com.apple.UserNotificationCenter", "com.apple.Spotlight"]
        guard !blocklist.contains(app.bundleIdentifier ?? "") else { return }

        lock.lock()
        defer { lock.unlock() }

        let wasPending = (pendingBundle != nil && app.bundleIdentifier == pendingBundle)
        pendingBundle = nil

        if wasPending {
            // Gesture-triggered — ĐỪNG thay đổi history để cursor index vẫn đúng
            return
        }

        if suppressCursorResetUntil.timeIntervalSinceNow > 0 {
            // Trong suppress window (sau system gesture) — freeze cả history lẫn cursor
            // vì insert(at:0) sẽ dịch toàn bộ index làm cursor trỏ sai app
            return
        }

        // User tự switch — cập nhật history và reset cursor về 0
        history.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
        history.insert(app, at: 0)
        if history.count > 50 { history = Array(history.prefix(50)) }
        switchCursor = 0
    }

    // MARK: - Gọi trước khi fire system gestures (Mission Control, Show Desktop...)
    // Suppress cursor reset trong 2.5 giây — đủ để cover tất cả appActivated sau khi
    // Mission Control / Show Desktop đóng lại (có thể fire nhiều lần)
    func willFireSystemGesture() {
        lock.lock()
        suppressCursorResetUntil = Date().addingTimeInterval(2.5)
        lock.unlock()
    }

    // MARK: - Switch previous (đi sâu vào lịch sử, cursor+1)
    /// Returns false nếu đã ở cuối lịch sử (boundary)
    @discardableResult
    func switchToPrevious() -> Bool {
        lock.lock()
        let snapshot = history
        let cur = switchCursor
        lock.unlock()

        // Tìm app tiếp theo sau cursor còn đang chạy
        let next = snapshot.enumerated()
            .dropFirst(cur + 1)
            .first { !$0.element.isTerminated }

        guard let (idx, target) = next else {
            print("[TrackPadGiaCay] Đã đến cuối lịch sử.")
            return false
        }

        lock.lock(); pendingBundle = target.bundleIdentifier; switchCursor = idx; lock.unlock()
        print("[TrackPadGiaCay] ← \(target.localizedName ?? "?") [idx=\(idx)]")
        activateApp(target)
        return true
    }

    // MARK: - Switch next (quay lại app mới hơn, cursor-1)
    /// Returns false nếu đã ở app mới nhất (boundary)
    @discardableResult
    func switchToNext() -> Bool {
        lock.lock()
        let snapshot = history
        let cur = switchCursor
        lock.unlock()

        guard cur > 0 else {
            print("[TrackPadGiaCay] Đã ở app mới nhất.")
            return false
        }

        // Đi thẳng cursor-1 (ngược chiều với switchToPrevious)
        let idx = cur - 1
        let target = snapshot[idx]

        guard !target.isTerminated else {
            // App bị đóng, thử idx-1
            if idx > 0 {
                let fallback = snapshot[idx - 1]
                lock.lock(); pendingBundle = fallback.bundleIdentifier; switchCursor = idx - 1; lock.unlock()
                print("[TrackPadGiaCay] → \(fallback.localizedName ?? "?") [idx=\(idx - 1)]")
                activateApp(fallback)
                return true
            }
            return false
        }

        lock.lock(); pendingBundle = target.bundleIdentifier; switchCursor = idx; lock.unlock()
        print("[TrackPadGiaCay] → \(target.localizedName ?? "?") [idx=\(idx)]")
        activateApp(target)
        return true
    }

    // MARK: - Activate helper
    private func activateApp(_ app: NSRunningApplication) {
        guard let url = app.bundleURL else {
            // fallback: dùng activate() nếu không có bundleURL
            app.activate(options: .activateIgnoringOtherApps)
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, err in
            if let err = err {
                print("[TrackPadGiaCay] activateApp error: \(err.localizedDescription)")
                // last resort
                app.activate(options: .activateIgnoringOtherApps)
            }
        }
    }
}
