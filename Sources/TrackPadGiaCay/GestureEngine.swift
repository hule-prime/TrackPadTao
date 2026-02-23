import Cocoa
import ApplicationServices

// MARK: - Direction
enum DragDirection {
    case left, right, up, down
}

// MARK: - Gesture Engine
final class GestureEngine {
    static let shared = GestureEngine()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// True nếu EventTap đang hoạt động
    var isRunning: Bool { eventTap != nil }

    // Per-press state
    private var isMiddleDown = false
    private var startX: CGFloat = 0
    private var startY: CGFloat = 0
    private var hasFired = false

    private var threshold: CGFloat {
        CGFloat(GestureConfigStore.shared.config.threshold)
    }

    private init() {}

    // MARK: - Start / Stop
    func start() {
        guard eventTap == nil else { return }

        let mask: CGEventMask =
            (1 << CGEventType.otherMouseDown.rawValue)
          | (1 << CGEventType.otherMouseUp.rawValue)
          | (1 << CGEventType.otherMouseDragged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                let engine = Unmanaged<GestureEngine>.fromOpaque(refcon!).takeUnretainedValue()
                engine.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[TrackPadGiaCay] ❌ Không tạo được event tap — kiểm tra quyền Accessibility.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[TrackPadGiaCay] ✅ Event tap đang chạy.")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Event handler
    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .otherMouseDown:
            if event.getIntegerValueField(.mouseEventButtonNumber) == 2 {
                isMiddleDown = true
                hasFired = false
                startX = event.location.x
                startY = event.location.y
            }

        case .otherMouseUp:
            if event.getIntegerValueField(.mouseEventButtonNumber) == 2 {
                isMiddleDown = false
                hasFired = false
            }

        case .otherMouseDragged:
            guard isMiddleDown, !hasFired else { return }
            let dx = event.location.x - startX
            let dy = event.location.y - startY
            let absDx = abs(dx)
            let absDy = abs(dy)
            guard max(absDx, absDy) >= threshold else { return }

            // Xác định hướng chủ đạo
            let direction: DragDirection
            // Yêu cầu hướng chủ đạo phải ít nhất 1.5x so với hướng phụ
            // → tránh trigger sai khi kéo chéo
            if absDx >= absDy * 1.5 {
                direction = dx < 0 ? .left : .right
            } else if absDy >= absDx * 1.5 {
                direction = dy > 0 ? .down : .up
            } else {
                // Quá chéo, bỏ qua
                return
            }

            hasFired = true
            DispatchQueue.main.async { [weak self] in
                self?.execute(direction: direction)
            }

        default:
            // Re-enable nếu tap bị suspend
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            }
        }
    }

    // MARK: - Execute action
    private func execute(direction: DragDirection) {
        let cfg = GestureConfigStore.shared.config
        let action: GestureAction
        switch direction {
        case .left:  action = cfg.dragLeft
        case .right: action = cfg.dragRight
        case .up:    action = cfg.dragUp
        case .down:  action = cfg.dragDown
        }
        print("[TrackPadGiaCay] \(dirEmoji(direction)) \(action.rawValue)")
        perform(action: action, direction: direction)
    }

    private func perform(action: GestureAction, direction: DragDirection) {
        switch action {
        case .none:
            break

        case .switchPrevApp:
            let ok = AppHistoryTracker.shared.switchToPrevious()
            GestureOverlay.shared.show(direction == .right ? .right : .left, boundary: !ok)

        case .switchNextApp:
            let ok = AppHistoryTracker.shared.switchToNext()
            GestureOverlay.shared.show(direction == .left ? .left : .right, boundary: !ok)

        case .missionControl:
            AppHistoryTracker.shared.willFireSystemGesture()
            // openApplication là cách duy nhất đáng tin từ LaunchAgent — không bị block
            let mcURL = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
            NSWorkspace.shared.openApplication(
                at: mcURL,
                configuration: NSWorkspace.OpenConfiguration()
            )

        case .appExpose:
            AppHistoryTracker.shared.willFireSystemGesture()
            // App Exposé: CGEvent Ctrl+Down — vẫn thử, fallback Mission Control
            postKey(keyCode: 125, flags: .maskControl)

        case .showDesktop:
            AppHistoryTracker.shared.willFireSystemGesture()
            // osascript chạy như subprocess riêng — không bị block bởi Automation TCC của app
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = ["-e", "tell application \"System Events\" to key code 103"]
            try? proc.run()

        case .launchpad:
            let lpURL = URL(fileURLWithPath: "/System/Applications/Launchpad.app")
            NSWorkspace.shared.openApplication(
                at: lpURL,
                configuration: NSWorkspace.OpenConfiguration()
            )

        case .switchSpaceLeft:
            postKey(keyCode: 123, flags: .maskControl)   // Ctrl+Left

        case .switchSpaceRight:
            postKey(keyCode: 124, flags: .maskControl)   // Ctrl+Right
        }
    }

    // MARK: - AppleScript helper — phải chạy trên main thread
    private func runAppleScript(_ source: String) {
        // NSAppleScript bắt buộc main thread, perform đang ở DispatchQueue.main rồi
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let err = error {
            print("[TrackPadGiaCay] AppleScript error: \(err)")
        }
    }

    // MARK: - Post synthetic key event
    // .cghidEventTap = HID level — đúng level để trigger system shortcuts (Mission Control, Show Desktop)
    private func postKey(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        print("[TrackPadGiaCay] postKey keyCode=\(keyCode) flags=\(flags.rawValue)")
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        down?.flags = flags
        up?.flags   = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func dirEmoji(_ d: DragDirection) -> String {
        switch d {
        case .left:  return "←"
        case .right: return "→"
        case .up:    return "↑"
        case .down:  return "↓"
        }
    }
}
