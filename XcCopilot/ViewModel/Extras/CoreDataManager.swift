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
    
    static func insert<T>(element: T) async throws {
        try await sharedContext.perform {
            sharedContext.insert(element as! NSManagedObject)
            try sharedContext.save()
        }
    }
    
    static func fetchSingleFlight(withIgcID igcId: String) async throws -> Flight {
        let result = try await CoreDataManager.sharedContext.perform {
            let request = Flight.fetchRequest()
            request.predicate = NSPredicate(format: "igcID == %@", igcId)
            let results = try CoreDataManager.sharedContext.fetch(request)
            
            if results.isEmpty {
                throw CdError.noRecordsFound("No stored flight found")
            } else {
                return results.first!
            }
        }
        
        return result
    }
    
    static func fetchAllFlights() async throws -> [Flight] {
        let request = Flight.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "startDate", ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        let result = try await sharedContext.perform {
            return try CoreDataManager.sharedContext.fetch(request)
        }
        
        return result
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
