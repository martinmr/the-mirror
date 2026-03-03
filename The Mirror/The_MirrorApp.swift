//
//  The_MirrorApp.swift
//  The Mirror
//
//  Created by Martin Martinez Rivera on 3/2/26.
//

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
