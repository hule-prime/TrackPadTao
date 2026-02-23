import Cocoa
import SwiftUI

// MARK: - Animated overlay view
private struct SwipeOverlayView: View {
    let direction: GestureOverlay.Direction
    let boundary: Bool

    @State private var offsetX: CGFloat
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.82
    @State private var bounceOffset: CGFloat = 0

    init(direction: GestureOverlay.Direction, boundary: Bool) {
        self.direction = direction
        self.boundary = boundary
        // Start offset: arrow slides in from the swipe side
        _offsetX = State(initialValue: direction == .left ? 60 : -60)
    }

    var arrowIcon: String {
        if boundary {
            return direction == .left ? "arrow.left.to.line" : "arrow.right.to.line"
        }
        return direction == .left ? "arrow.left" : "arrow.right"
    }

    var body: some View {
        ZStack {
            // Frosted capsule background
            Capsule()
                .fill(.ultraThinMaterial)
                .frame(width: 104, height: 60)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            boundary
                                ? Color.orange.opacity(0.55)
                                : Color.white.opacity(0.18),
                            lineWidth: 1
                        )
                        .frame(width: 104, height: 60)
                )
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)

            Image(systemName: arrowIcon)
                .font(.system(size: 30, weight: boundary ? .semibold : .thin))
                .foregroundStyle(
                    boundary
                        ? Color.orange.opacity(0.9)
                        : Color.white.opacity(0.75)
                )
                .offset(x: bounceOffset)
        }
        .scaleEffect(scale)
        .offset(x: offsetX)
        .opacity(opacity)
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        // Phase 1: slide in + fade in
        withAnimation(.spring(response: 0.28, dampingFraction: 0.68)) {
            offsetX = 0
            scale = 1.0
            opacity = 1.0
        }

        if boundary {
            // Phase 2 (boundary): bounce the arrow back against the wall
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                let wall: CGFloat = direction == .left ? -10 : 10
                withAnimation(.spring(response: 0.15, dampingFraction: 0.35)) {
                    bounceOffset = wall
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        bounceOffset = 0
                    }
                }
            }
        }

        // Phase 3: fade out + continue sliding
        let holdDuration: Double = boundary ? 0.55 : 0.38
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
            let exitOffset: CGFloat = boundary ? 0 : (direction == .left ? -24 : 24)
            withAnimation(.easeIn(duration: 0.22)) {
                opacity = 0
                offsetX = exitOffset
                scale = 0.9
            }
        }
    }
}

// MARK: - Overlay controller (singleton)
final class GestureOverlay {
    enum Direction { case left, right }
    static let shared = GestureOverlay()

    private var window: NSWindow?
    private var hideWorkItem: DispatchWorkItem?

    private init() {}

    func show(_ direction: Direction, boundary: Bool = false) {
        DispatchQueue.main.async { [self] in
            hideWorkItem?.cancel()

            let win = window ?? makeWindow()
            window = win

            win.contentView = NSHostingView(
                rootView: SwipeOverlayView(direction: direction, boundary: boundary)
                    .frame(width: 128, height: 84)
            )

            if let screen = NSScreen.main {
                let sf = screen.visibleFrame
                win.setFrameOrigin(NSPoint(
                    x: sf.minX + (sf.width  - 128) / 2,
                    y: sf.minY + (sf.height - 84)  / 2
                ))
            }

            win.alphaValue = 1
            win.orderFrontRegardless()

            // Auto-remove after animation completes
            let totalDuration: Double = boundary ? 0.55 + 0.25 : 0.38 + 0.25
            let work = DispatchWorkItem { [weak self] in
                self?.window?.orderOut(nil)
            }
            hideWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.1, execute: work)
        }
    }

    private func makeWindow() -> NSWindow {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 128, height: 84),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.level = .floating + 1
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = true
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        win.isReleasedWhenClosed = false
        return win
    }
}
