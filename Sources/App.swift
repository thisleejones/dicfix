import SwiftUI

@main
struct DictationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene so SwiftUI doesn't create its own window
        Settings {}
    }
}
