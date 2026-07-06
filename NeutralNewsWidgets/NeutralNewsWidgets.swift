import SwiftUI
import UIKit
import WidgetKit


struct DailyBriefingEntry: TimelineEntry {
    let date: Date
    let items: [WidgetNewsItem]
    let region: String
    let imageDataByItemID: [String: Data]
    let isPlaceholder: Bool
    let isPremiumLocked: Bool

    var item: WidgetNewsItem? {
        items.first
    }

    var deepLinkURL: URL? {
        if isPremiumLocked {
            return WidgetDeepLink.proURL
        }

        if isPlaceholder {
            return WidgetDeepLink.appURL
        }

        guard let item else { return WidgetDeepLink.appURL }
        return WidgetDeepLink.url(for: item, region: region) ?? WidgetDeepLink.appURL
    }

    static let preview = DailyBriefingEntry(
        date: .now,
        items: [
            WidgetNewsItem(
                id: "preview-story",
                title: "Global leaders prepare for a new round of high-stakes talks",
                imageURL: nil,
                date: .now,
                relevance: 10
            ),
            WidgetNewsItem(
                id: "preview-story-2",
                title: "Markets react as policy makers outline new economic measures",
                imageURL: nil,
                date: .now,
                relevance: 9
            ),
            WidgetNewsItem(
                id: "preview-story-3",
                title: "Researchers report steady progress on clean energy storage",
                imageURL: nil,
                date: .now,
                relevance: 8
            )
        ],
        region: "US",
        imageDataByItemID: [:],
        isPlaceholder: false,
        isPremiumLocked: false
    )
}

struct DailyBriefingProvider: TimelineProvider {
    private static let storyRotationInterval: TimeInterval = 60 * 60
    private let store = WidgetSnapshotStore()
    private let imageStore = WidgetImageStore()
    private let remoteClient = WidgetRemoteSnapshotClient()

    func placeholder(in context: Context) -> DailyBriefingEntry {
        DailyBriefingEntry(
            date: .now,
            items: placeholderItems(for: context.family),
            region: "US",
            imageDataByItemID: [:],
            isPlaceholder: true,
            isPremiumLocked: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyBriefingEntry) -> Void) {
        Task {
            if context.isPreview {
                completion(await makePreviewEntry(for: context.family))
            } else {
                completion(await makeCurrentEntry(for: context.family))
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyBriefingEntry>) -> Void) {
        Task {
            completion(await makeTimeline(for: context.family))
        }
    }

    private func makePreviewEntry(for family: WidgetFamily) async -> DailyBriefingEntry {
        guard let snapshot = try? store.readSnapshot(), !snapshot.items.isEmpty else {
            return DailyBriefingEntry(
                date: .now,
                items: placeholderItems(for: family),
                region: "US",
                imageDataByItemID: [:],
                isPlaceholder: true,
                isPremiumLocked: false
            )
        }

        let rotationIndex = currentRotationIndex(for: snapshot, date: .now)
        let imageDataByItemID = cachedImageData(for: snapshot.items)
        return makeEntry(
            from: snapshot,
            family: family,
            startingAt: rotationIndex,
            region: snapshot.region,
            date: .now,
            imageDataByItemID: imageDataByItemID
        )
    }

    private func makeCurrentEntry(for family: WidgetFamily) async -> DailyBriefingEntry {
        let region = WidgetRegionResolver.currentRegion()

        if shouldLockPremiumContent(for: family) {
            return makePremiumLockedEntry(for: family, region: region, date: .now)
        }

        guard let snapshot = await loadSnapshot(for: region), !snapshot.items.isEmpty else {
            return DailyBriefingEntry(
                date: .now,
                items: placeholderItems(for: family),
                region: region,
                imageDataByItemID: [:],
                isPlaceholder: true,
                isPremiumLocked: false
            )
        }

        let rotationIndex = currentRotationIndex(for: snapshot, date: .now)
        let imageDataByItemID = cachedImageData(for: snapshot.items)
        return makeEntry(
            from: snapshot,
            family: family,
            startingAt: rotationIndex,
            region: snapshot.region,
            date: .now,
            imageDataByItemID: imageDataByItemID
        )
    }

    private func makeEntry(
        from snapshot: WidgetNewsSnapshot,
        family: WidgetFamily,
        startingAt index: Int = 0,
        region: String,
        date: Date,
        imageDataByItemID: [String: Data]
    ) -> DailyBriefingEntry {
        let itemCount = visibleItemCount(for: family)
        let candidates = candidateItems(from: snapshot, startingAt: index)
        let itemsWithLoadedImages = candidates.filter { imageDataByItemID[$0.id] != nil }
        let selectedItems: [WidgetNewsItem]

        if itemsWithLoadedImages.count >= itemCount {
            selectedItems = Array(itemsWithLoadedImages.prefix(itemCount))
        } else {
            let loadedItemIDs = Set(itemsWithLoadedImages.map(\.id))
            selectedItems = Array(
                (itemsWithLoadedImages + candidates.filter { !loadedItemIDs.contains($0.id) })
                    .prefix(itemCount)
            )
        }

        if selectedItems.isEmpty {
            return DailyBriefingEntry(
                date: date,
                items: placeholderItems(for: family),
                region: region,
                imageDataByItemID: [:],
                isPlaceholder: true,
                isPremiumLocked: false
            )
        }

        return DailyBriefingEntry(
            date: date,
            items: selectedItems,
            region: region,
            imageDataByItemID: imageDataByItemID,
            isPlaceholder: false,
            isPremiumLocked: false
        )
    }

    private func makeTimeline(for family: WidgetFamily) async -> Timeline<DailyBriefingEntry> {
        let now = Date()
        let region = WidgetRegionResolver.currentRegion()

        if shouldLockPremiumContent(for: family) {
            let entry = makePremiumLockedEntry(for: family, region: region, date: now)
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(Self.storyRotationInterval)))
        }

        guard let snapshot = await loadSnapshot(for: region), !snapshot.items.isEmpty else {
            let entry = DailyBriefingEntry(
                date: now,
                items: placeholderItems(for: family),
                region: region,
                imageDataByItemID: [:],
                isPlaceholder: true,
                isPremiumLocked: false
            )
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60)))
        }

        let rotationIndex = currentRotationIndex(for: snapshot, date: now)
        let imageDataByItemID = cachedImageData(for: snapshot.items)
        let entry = makeEntry(
            from: snapshot,
            family: family,
            startingAt: rotationIndex,
            region: snapshot.region,
            date: now,
            imageDataByItemID: imageDataByItemID
        )
        return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(Self.storyRotationInterval)))
    }

    private func makePremiumLockedEntry(for family: WidgetFamily, region: String, date: Date) -> DailyBriefingEntry {
        DailyBriefingEntry(
            date: date,
            items: placeholderItems(for: family),
            region: region,
            imageDataByItemID: [:],
            isPlaceholder: false,
            isPremiumLocked: true
        )
    }

    private func candidateItems(from snapshot: WidgetNewsSnapshot, startingAt index: Int) -> [WidgetNewsItem] {
        let sourceItems = snapshot.items.filter { $0.imageURL != nil }
        let items = sourceItems.isEmpty ? snapshot.items : sourceItems
        guard !items.isEmpty else { return [] }

        return items.indices.map { offset in
            items[(index + offset) % items.count]
        }
    }

    private func currentRotationIndex(for snapshot: WidgetNewsSnapshot, date: Date) -> Int {
        guard !snapshot.items.isEmpty else { return 0 }
        let elapsed = max(0, date.timeIntervalSince(snapshot.generatedAt))
        return Int(elapsed / Self.storyRotationInterval) % snapshot.items.count
    }

    private func cachedImageData(for items: [WidgetNewsItem]) -> [String: Data] {
        Dictionary(uniqueKeysWithValues: items.compactMap { item in
            guard let data = imageStore.readImageData(for: item) else {
                return nil
            }

            return (item.id, data)
        })
    }

    private func visibleItemCount(for family: WidgetFamily) -> Int {
        if family == .systemLarge {
            return 2
        }

        if WidgetFamily.isNeutralNewsExtraLarge(family) {
            return 3
        }

        return 1
    }

    private func shouldLockPremiumContent(for family: WidgetFamily) -> Bool {
        guard family == .systemLarge || WidgetFamily.isNeutralNewsExtraLarge(family) else {
            return false
        }

        return WidgetPremiumAccessStore.currentValue() == false
    }

    private func placeholderItems(for family: WidgetFamily) -> [WidgetNewsItem] {
        (0..<visibleItemCount(for: family)).map { index in
            WidgetNewsItem(
                id: "placeholder-story-\(index)",
                title: Self.placeholderTitles[index % Self.placeholderTitles.count],
                imageURL: nil,
                date: .now,
                relevance: 0
            )
        }
    }

    private func loadSnapshot(for region: String) async -> WidgetNewsSnapshot? {
        if let cachedSnapshot = cachedSnapshot(matching: region) {
            return cachedSnapshot
        }

        if let remoteSnapshot = try? await remoteClient.fetchSnapshot(for: region) {
            _ = try? store.writeSnapshot(remoteSnapshot)
            return remoteSnapshot
        }

        return cachedSnapshot()
    }

    private func cachedSnapshot(matching region: String? = nil) -> WidgetNewsSnapshot? {
        guard let snapshot = try? store.readSnapshot(),
              snapshot.isUsableForWidget else {
            return nil
        }

        if let region, snapshot.region.uppercased() != region.uppercased() {
            return nil
        }

        return snapshot
    }

    private static let placeholderTitles = [
        "Global leaders prepare for a new round of high-stakes talks",
        "Markets react as policy makers outline new economic measures",
        "Researchers report steady progress on clean energy storage"
    ]
}

struct NeutralNewsWidgetsEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyBriefingEntry

    var body: some View {
        content
        .overlay {
            ContainerRelativeShape()
                .strokeBorder(Color(.separator), lineWidth: 1)
        }
        .containerBackground(for: .widget) {
            widgetBackground
        }
        .widgetURL(entry.deepLinkURL)
    }

    private var widgetBackground: some View {
        Color(.secondarySystemBackground)
    }

    @ViewBuilder
    private var content: some View {
        if entry.isPremiumLocked {
            PremiumLockedWidgetView()
        } else if family == .systemLarge {
            multiStoryContent(itemCount: 2)
        } else if WidgetFamily.isNeutralNewsExtraLarge(family) {
            multiStoryContent(itemCount: 3)
        } else {
            DailyBriefingStoryTile(
                item: entry.item,
                imageData: imageData(for: entry.item),
                isPlaceholder: entry.isPlaceholder,
                family: family
            )
        }
    }

    private func multiStoryContent(itemCount: Int) -> some View {
        VStack(spacing: multiStorySpacing) {
            ForEach(Array(entry.items.prefix(itemCount))) { item in
                if entry.isPlaceholder {
                    multiStoryTile(for: item)
                } else if let url = WidgetDeepLink.url(for: item, region: entry.region) ?? WidgetDeepLink.appURL {
                    Link(destination: url) {
                        multiStoryTile(for: item)
                    }
                    .buttonStyle(.plain)
                } else {
                    multiStoryTile(for: item)
                }
            }

            if entry.items.isEmpty {
                multiStoryTile(for: nil)
            }
        }
        .padding(multiStoryPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func multiStoryTile(for item: WidgetNewsItem?) -> some View {
        DailyBriefingStoryTile(
            item: item,
            imageData: imageData(for: item),
            isPlaceholder: entry.isPlaceholder,
            family: .systemMedium
        )
        .clipShape(RoundedRectangle(cornerRadius: multiStoryCornerRadius, style: .continuous))
    }

    private func imageData(for item: WidgetNewsItem?) -> Data? {
        guard let item else { return nil }
        return entry.imageDataByItemID[item.id]
    }

    private var multiStoryPadding: CGFloat {
        10
    }

    private var multiStorySpacing: CGFloat {
        8
    }

    private var multiStoryCornerRadius: CGFloat {
        22
    }
}

private struct PremiumLockedWidgetView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Facts Pro")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Unlock larger widgets")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DailyBriefingStoryTile: View {
    let item: WidgetNewsItem?
    let imageData: Data?
    let isPlaceholder: Bool
    let family: WidgetFamily

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                backgroundImage
                    .frame(width: proxy.size.width, height: proxy.size.height)

                if !isPlaceholder {
                    bottomGradient
                        .frame(height: proxy.size.height * gradientHeightRatio)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }

                titleContent
                    .frame(width: proxy.size.width, alignment: .bottomLeading)
            }
            .clipped()
        }
    }

    @ViewBuilder
    private var backgroundImage: some View {
        if isPlaceholder {
            Color(.tertiarySystemFill)
        } else if let imageData,
           let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            Color(.tertiarySystemFill)
        }
    }

    private var bottomGradient: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .mask(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.2),
                        Color.black.opacity(0.8),
                        Color.black.opacity(0.9),
                        Color.black.opacity(1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    @ViewBuilder
    private var titleContent: some View {
        if isPlaceholder {
            Text(item?.title ?? Self.placeholderTitle)
                .font(.system(size: titleFontSize, weight: .semibold, design: .serif))
                .foregroundStyle(.secondary)
                .lineLimit(titleLineLimit)
                .minimumScaleFactor(0.86)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(contentInsets)
                .redacted(reason: .placeholder)
        } else if let item {
            Text(item.title)
                .font(.system(size: titleFontSize, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .lineLimit(titleLineLimit)
                .minimumScaleFactor(0.86)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(contentInsets)
                .shadow(color: .black.opacity(0.55), radius: 5, x: 0, y: 1)
                .unredacted()
        } else {
            Text("Open Facts")
                .font(.system(size: emptyStateFontSize, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(contentInsets)
                .unredacted()
        }
    }

    private static let placeholderTitle = "Global leaders prepare for a new round of high-stakes talks"

    private var titleFontSize: CGFloat {
        family == .systemMedium ? 16 : 12
    }

    private var emptyStateFontSize: CGFloat {
        family == .systemMedium ? 15 : 12
    }

    private var titleLineLimit: Int {
        family == .systemMedium ? 3 : 4
    }

    private var gradientHeightRatio: CGFloat {
        family == .systemMedium ? 0.74 : 0.82
    }

    private var contentInsets: EdgeInsets {
        if family == .systemMedium {
            EdgeInsets(top: 42, leading: 18, bottom: 15, trailing: 18)
        } else {
            EdgeInsets(top: 20, leading: 14, bottom: 13, trailing: 14)
        }
    }
}

struct NeutralNewsWidgets: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshotConstants.widgetKind, provider: DailyBriefingProvider()) { entry in
            NeutralNewsWidgetsEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Briefing")
        .description("Top stories from today's Facts briefing.")
        .supportedFamilies(Self.supportedFamilies)
        .contentMarginsDisabled()
    }

    private static var supportedFamilies: [WidgetFamily] {
        var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]

        if #available(iOSApplicationExtension 27.0, *) {
            families.append(.systemExtraLargePortrait)
        }

        return families
    }
}

private extension WidgetFamily {
    static func isNeutralNewsExtraLarge(_ family: WidgetFamily) -> Bool {
        if family == .systemExtraLarge {
            return true
        }

        if #available(iOSApplicationExtension 27.0, *), family == .systemExtraLargePortrait {
            return true
        }

        return false
    }
}

#Preview(as: .systemSmall) {
    NeutralNewsWidgets()
} timeline: {
    DailyBriefingEntry.preview
}

#Preview(as: .systemMedium) {
    NeutralNewsWidgets()
} timeline: {
    DailyBriefingEntry.preview
}

#Preview(as: .systemLarge) {
    NeutralNewsWidgets()
} timeline: {
    DailyBriefingEntry.preview
}

#Preview(as: .systemExtraLarge) {
    NeutralNewsWidgets()
} timeline: {
    DailyBriefingEntry.preview
}
