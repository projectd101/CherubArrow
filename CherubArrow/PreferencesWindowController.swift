import Cocoa
import SwiftUI

/// Hosts PreferencesView in a plain AppKit window. The app itself is
/// AppKit/menu-bar driven (see AppDelegate), so this is a thin SwiftUI-in-AppKit
/// bridge rather than a full SwiftUI App scene.
final class PreferencesWindowController: NSWindowController {

    convenience init(ttsManager: TTSManager) {
        let hosting = NSHostingController(rootView: PreferencesView(ttsManager: ttsManager))
        let window = NSWindow(contentViewController: hosting)
        window.title = "CherubArrow Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 980, height: 640))
        window.minSize = NSSize(width: 820, height: 520)
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
