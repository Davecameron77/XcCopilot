//
//  XcCopilotApp.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import SwiftUI

@main
struct XcCopilotApp: App {
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .active {
                        UIApplication.shared.isIdleTimerDisabled = true
                    } else if newPhase == .inactive {
                        UIApplication.shared.isIdleTimerDisabled = false
                    } else if newPhase == .background {
                        UIApplication.shared.isIdleTimerDisabled = false
                    }
                }
        }
    }
    
    init() {
#if DEBUG
        print(URL.applicationSupportDirectory.path(percentEncoded: false))
#endif
    }
}

