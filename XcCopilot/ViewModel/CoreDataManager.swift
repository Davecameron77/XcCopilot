//
//  CoreDataManager.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-07-07.
//

import CoreData
import Foundation

class CoreDataManager {
    static let shared = CoreDataManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "XCCopilot")
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Core Data error")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
}
