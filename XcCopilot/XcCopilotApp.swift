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
    let container: ModelContainer
    
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(container)
    }
    
    init() {
        let schema = Schema([Flight.self])
        let config = ModelConfiguration("XcCopilot", schema: schema)
        
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not configure application storage")
        }
        
        print(URL.applicationSupportDirectory.path(percentEncoded: false))
    }
}

