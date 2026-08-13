import SwiftUI

@main
struct ClipStackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // ClipStack lives in the menu bar; there are no main windows.
        Settings {
            Text("ClipStack — settings coming soon.")
                .padding()
        }
    }
}
