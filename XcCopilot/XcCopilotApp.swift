//
//  XcCopilotApp.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import SwiftUI
import SwiftData

@main
struct XcCopilotApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: Glider.self)
    }
}
