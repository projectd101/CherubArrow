import SwiftUI

@main
struct CherubArrowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window — this is a menu-bar-only utility.
        // The Settings scene keeps SwiftUI happy without showing anything.
        Settings {
            EmptyView()
        }
    }
}
