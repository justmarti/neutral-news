import Foundation
import Testing
@testable import NeutralNews

@Suite("Widget Snapshot Store Tests")
struct WidgetSnapshotStoreTests {
    @Test("Writes and reads a widget snapshot")
    func writesAndReadsSnapshot() async throws {
        let directoryURL = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(at: directoryURL) }

        let store = WidgetSnapshotStore(directoryURL: directoryURL)
        let snapshot = makeSnapshot()

        let didWrite = try await store.writeSnapshot(snapshot)
        let storedSnapshot = try await store.readSnapshot()

        #expect(didWrite)
        #expect(storedSnapshot == snapshot)
    }

    @Test("Skips an unchanged widget snapshot")
    func skipsUnchangedSnapshot() async throws {
        let directoryURL = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(at: directoryURL) }

        let store = WidgetSnapshotStore(directoryURL: directoryURL)
        let snapshot = makeSnapshot()

        _ = try await store.writeSnapshot(snapshot)
        let didWriteAgain = try await store.writeSnapshot(snapshot)

        #expect(didWriteAgain == false)
    }

    @Test("Rejects widget snapshots when the App Group is unavailable")
    func rejectsSnapshotWithoutAppGroup() async {
        let store = WidgetSnapshotStore(directoryURL: nil)

        do {
            _ = try await store.readSnapshot()
            Issue.record("Expected reading without an App Group to fail.")
        } catch WidgetSnapshotStore.StoreError.appGroupUnavailable {
        } catch {
            Issue.record("Expected appGroupUnavailable, received \(error).")
        }
    }

    @Test("Writes and reads image data")
    func writesAndReadsImageData() async throws {
        let directoryURL = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(at: directoryURL) }

        let store = WidgetImageStore(directoryURL: directoryURL)
        let item = makeItem()
        let imageData = Data([0x01, 0x02, 0x03])

        let didWrite = try await store.writeImageData(imageData, for: item)
        let storedImageData = await store.readImageData(for: item)

        #expect(didWrite)
        #expect(storedImageData == imageData)
    }

    @Test("Keeps the first image written for a story")
    func keepsFirstImageWrittenForStory() async throws {
        let directoryURL = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(at: directoryURL) }

        let store = WidgetImageStore(directoryURL: directoryURL)
        let item = makeItem()
        let firstImageData = Data([0x01])
        let secondImageData = Data([0x02])

        _ = try await store.writeImageData(firstImageData, for: item)
        let didWriteAgain = try await store.writeImageData(secondImageData, for: item)
        let storedImageData = await store.readImageData(for: item)

        #expect(didWriteAgain == false)
        #expect(storedImageData == firstImageData)
    }

    @Test("Serializes concurrent writes for the same image")
    func serializesConcurrentImageWrites() async {
        let directoryURL = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(at: directoryURL) }

        let store = WidgetImageStore(directoryURL: directoryURL)
        let item = makeItem()
        let imageData = Data([0x01, 0x02, 0x03])

        let writeResults = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for _ in 0..<10 {
                group.addTask {
                    (try? await store.writeImageData(imageData, for: item)) ?? false
                }
            }

            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }

            return results
        }

        #expect(writeResults.filter { $0 }.count == 1)
        #expect(await store.readImageData(for: item) == imageData)
    }

    @Test("Writes and reads an image focus point")
    func writesAndReadsImageFocusPoint() async throws {
        let directoryURL = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(at: directoryURL) }

        let store = WidgetImageStore(directoryURL: directoryURL)
        let item = makeItem()
        let focusPoint = ImageFocusPoint(x: 0.8, y: 0.3)

        let didWrite = try await store.writeFocusPoint(focusPoint, for: item)

        #expect(didWrite)
        #expect(await store.readFocusPoint(for: item) == focusPoint)
    }

    @Test("Persists a missing focus result")
    func persistsMissingFocusResult() async throws {
        let directoryURL = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(at: directoryURL) }

        let store = WidgetImageStore(directoryURL: directoryURL)
        let item = makeItem()

        #expect(await store.hasFocusRecord(for: item) == false)
        let didWrite = try await store.writeFocusPoint(nil, for: item)

        #expect(didWrite)
        #expect(await store.hasFocusRecord(for: item))
        #expect(await store.readFocusPoint(for: item) == nil)
    }
}

private func makeTemporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
}

private func removeTemporaryDirectory(at directoryURL: URL) {
    try? FileManager.default.removeItem(at: directoryURL)
}

private func makeSnapshot() -> WidgetNewsSnapshot {
    WidgetNewsSnapshot(
        generatedAt: Date(timeIntervalSince1970: 2_000_000),
        region: "US",
        items: [makeItem()]
    )
}

private func makeItem() -> WidgetNewsItem {
    WidgetNewsItem(
        id: "story-1",
        title: "Story One",
        imageURL: URL(string: "https://example.com/story-1.jpg"),
        date: Date(timeIntervalSince1970: 1_999_900),
        relevance: 9
    )
}
