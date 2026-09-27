import Cocoa

final class OverlayWindowController: NSWindowController {

    let screen: NSScreen
    let overlayView: ClickEffectsView

    init(screen: NSScreen) {
        self.screen = screen
        self.overlayView = ClickEffectsView(frame: screen.frame)

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver          // floats above nearly everything
        window.ignoresMouseEvents = true      // never intercepts real clicks
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.contentView = overlayView

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
