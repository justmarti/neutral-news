//
//  CoreDataManager.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 23/9/25.
//

import Foundation
import CoreData

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()

    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "SavedNews")

        // Configure CloudKit options BEFORE loading stores
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }

        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { storeDescription, error in
            if let error = error {
                print("❌ Failed to load Core Data store: \(error)")
                fatalError("Failed to load Core Data store: \(error)")
            } else {
                print("✅ Core Data + CloudKit container loaded successfully")
                print("📍 Store URL: \(storeDescription.url?.absoluteString ?? "unknown")")
                print("🔄 CloudKit enabled: \(storeDescription.options[NSPersistentHistoryTrackingKey] != nil)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true

        // Initialize CloudKit schema by triggering a save
        do {
            try container.viewContext.save()
            print("🔄 CloudKit schema initialization save successful")
            print("📡 CloudKit is now ready - schema will be created on first save")
        } catch {
            print("⚠️ CloudKit schema initialization save failed: \(error)")
        }

        return container
    }()

    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    private init() {}
}