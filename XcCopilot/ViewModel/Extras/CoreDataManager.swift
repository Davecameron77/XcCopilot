//
//  CoreDataManager.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-08-14.
//

import CoreData
import Foundation

actor CoreDataManager {
    static var inMemory = false
    
    private static var container: NSPersistentContainer = {
        
        if inMemory {
            return TestCoreDataStack().persistentContainer
        }
        
        let container = NSPersistentContainer(name: "XCCopilot")
        
        let mom: NSManagedObjectModel
        if let model = NSManagedObjectModel.mergedModel(from: [Bundle.main]) {
             mom = model
        } else {
             mom = NSManagedObjectModel()
             print("CoreData Error: Failed to load managed object model. Initializing with an empty model.")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        return container
        
    }()
    
    static var sharedContext: NSManagedObjectContext {
        return Self.container.viewContext
    }
}

class TestCoreDataStack: NSObject {
    lazy var persistentContainer: NSPersistentContainer = {
        
        let description = NSPersistentStoreDescription()
        description.url = URL(fileURLWithPath: "/dev/null")
        
        let container = NSPersistentContainer(name: "XCCopilot")
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        
        return container
    }()
}
