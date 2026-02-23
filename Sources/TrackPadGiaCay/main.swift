import Cocoa

// Disable stdout buffering so print() always flushes to log file immediately
setbuf(stdout, nil)
setbuf(stderr, nil)

// MARK: - Single instance guard (dùng lock file)
let lockPath = "/tmp/TrackPadGiaCay.lock"
let lockFd = open(lockPath, O_CREAT | O_RDWR, 0o600)
guard lockFd >= 0, flock(lockFd, LOCK_EX | LOCK_NB) == 0 else {
    print("[TrackPadGiaCay] Đã có instance đang chạy, thoát.")
    exit(0)
}
// Giữ fd mở suốt vòng đời process để lock được giữ
print("[TrackPadGiaCay] 🚀 Khởi động... PID=\(ProcessInfo.processInfo.processIdentifier)")

// MARK: - Entry point (menu bar app)
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
