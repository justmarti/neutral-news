//
//  CoreDataManager.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 23/9/25.
//

import Foundation
import CoreData

@Observable
class CoreDataManager {
    static let shared = CoreDataManager()

    private var _persistentContainer: NSPersistentCloudKitContainer?

    private func createPersistentContainer() -> NSPersistentCloudKitContainer {
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
#if DEBUG
                print("✅ Core Data + CloudKit container loaded successfully")
#endif
#if DEBUG
                print("📍 Store URL: \(storeDescription.url?.absoluteString ?? "unknown")")
#endif
#if DEBUG
                print("🔄 CloudKit enabled: \(storeDescription.options[NSPersistentHistoryTrackingKey] != nil)")
#endif
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true

        // Initialize CloudKit schema by triggering a save
        do {
            try container.viewContext.save()
#if DEBUG
            print("🔄 CloudKit schema initialization save successful")
#endif
#if DEBUG
            print("📡 CloudKit is now ready - schema will be created on first save")
#endif
        } catch {
            print("⚠️ CloudKit schema initialization save failed: \(error)")
        }

        return container
    }

    var persistentContainer: NSPersistentCloudKitContainer {
        if _persistentContainer == nil {
            _persistentContainer = createPersistentContainer()
        }
        return _persistentContainer!
    }

    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    private init() {}
}