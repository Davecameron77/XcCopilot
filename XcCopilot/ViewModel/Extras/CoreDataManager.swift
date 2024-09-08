//
//  CoreDataManager.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-08-14.
//

import CoreData
import CoreLocation
import CoreMotion
import Foundation

class CoreDataManager {
    static let shared = CoreDataManager()
    private let persistentContainer: NSPersistentContainer
    var privateContext: NSManagedObjectContext
    var viewContext: NSManagedObjectContext { persistentContainer.viewContext }
    
    private init() {
        persistentContainer = NSPersistentContainer(name: "XCCopilot")
        persistentContainer.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateContext.parent = persistentContainer.viewContext
    }
}
