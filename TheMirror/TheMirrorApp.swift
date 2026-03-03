import SwiftUI

@main
struct TheMirrorApp: App {

    init() {
        NotificationManager.shared.setUp()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
