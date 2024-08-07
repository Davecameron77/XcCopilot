//
//  XcCopilotApp.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import SwiftUI

@main
struct XcCopilotApp: App {
    
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
    
    init() {
        #if DEBUG
        print(URL.applicationSupportDirectory.path(percentEncoded: false))
        #endif
    }
}

