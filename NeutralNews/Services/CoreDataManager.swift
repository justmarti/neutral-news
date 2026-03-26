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

        // Explicitly set CloudKit container identifier for cross-device sync
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.dev.itram.news"
        )

        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { storeDescription, error in
            if let error = error {
                print("❌ Failed to load Core Data store: \(error)")
                fatalError("Failed to load Core Data store: \(error)")
            } else {
#if DEBUG
                print("✅ Core Data + CloudKit container loaded successfully")
                print("📍 Store URL: \(storeDescription.url?.absoluteString ?? "unknown")")
                print("🔄 CloudKit enabled: \(storeDescription.cloudKitContainerOptions != nil)")
                print("📦 CloudKit container: \(storeDescription.cloudKitContainerOptions?.containerIdentifier ?? "none")")
#endif
            }
        }

        // Configure merge policy to handle sync conflicts properly
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Monitor CloudKit sync events for debugging
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main
        ) { notification in
            if let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event {
                self.handleCloudKitEvent(event)
            }
        }

        // Initialize CloudKit schema by triggering a save
        do {
            try container.viewContext.save()
#if DEBUG
            print("🔄 CloudKit schema initialization save successful")
            print("📡 CloudKit is now ready - schema will be created on first save")
#endif
        } catch {
            print("⚠️ CloudKit schema initialization save failed: \(error)")
        }

        return container
    }

    // Monitor CloudKit sync events for debugging
    private func handleCloudKitEvent(_ event: NSPersistentCloudKitContainer.Event) {
        if event.type == .import, event.endDate != nil, event.error == nil {
            SavedNewsService.shared.invalidatePreparedStore()
        }

#if DEBUG
        let eventType: String
        switch event.type {
        case .setup:
            eventType = "Setup"
        case .import:
            eventType = "Import"
        case .export:
            eventType = "Export"
        @unknown default:
            eventType = "Unknown"
        }

        if event.endDate == nil {
            print("☁️ CloudKit \(eventType) started")
        } else {
            if let error = event.error {
                print("❌ CloudKit \(eventType) failed: \(error.localizedDescription)")
            } else {
                print("✅ CloudKit \(eventType) completed successfully")
            }
        }
#endif
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
