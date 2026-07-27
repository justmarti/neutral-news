import SwiftUI
import ImageIO
import WidgetKit


struct DailyBriefingEntry: TimelineEntry {
    let date: Date
    let items: [WidgetNewsItem]
    let region: String
    let imageDataByItemID: [String: Data]
    let imageFocusPointByItemID: [String: ImageFocusPoint]
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
        imageFocusPointByItemID: [:],
        isPlaceholder: false,
        isPremiumLocked: false
    )
}

struct DailyBriefingProvider: TimelineProvider, Sendable {
    private static let storyRotationInterval: TimeInterval = 60 * 60
    private static let maximumTimelineEntryCount = 2
    private let store = WidgetSnapshotStore()
    private let imageStore = WidgetImageStore()
    private let remoteClient = WidgetRemoteSnapshotClient()

    func placeholder(in context: Context) -> DailyBriefingEntry {
        DailyBriefingEntry(
            date: .now,
            items: placeholderItems(for: context.family),
            region: "US",
            imageDataByItemID: [:],
            imageFocusPointByItemID: [:],
            isPlaceholder: true,
            isPremiumLocked: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (DailyBriefingEntry) -> Void) {
        let family = context.family
        let isPreview = context.isPreview

        Task {
            if isPreview {
                completion(await makePreviewEntry(for: family))
            } else {
                completion(await makeCurrentEntry(for: family))
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<DailyBriefingEntry>) -> Void) {
        let family = context.family

        Task {
            completion(await makeTimeline(for: family))
        }
    }

    private func makePreviewEntry(for family: WidgetFamily) async -> DailyBriefingEntry {
        guard let snapshot = try? await store.readSnapshot(), !snapshot.items.isEmpty else {
            return DailyBriefingEntry(
                date: .now,
                items: placeholderItems(for: family),
                region: "US",
                imageDataByItemID: [:],
                imageFocusPointByItemID: [:],
                isPlaceholder: true,
                isPremiumLocked: false
            )
        }

        let rotationIndex = currentRotationIndex(for: snapshot, date: .now)
        let imageDataByItemID = await cachedImageData(for: snapshot.items)
        let imageFocusPointByItemID = await cachedFocusPoints(for: snapshot.items)
        return makeEntry(
            from: snapshot,
            family: family,
            startingAt: rotationIndex,
            region: snapshot.region,
            date: .now,
            imageDataByItemID: imageDataByItemID,
            imageFocusPointByItemID: imageFocusPointByItemID
        )
    }

    private func makeCurrentEntry(for family: WidgetFamily) async -> DailyBriefingEntry {
        let region = WidgetRegionResolver.currentRegion()

        if shouldLockPremiumContent(for: family) {
            return makePremiumLockedEntry(for: family, region: region, date: .now)
        }

        guard let snapshot = await loadSnapshot(
            for: region,
            minimumItemCount: visibleItemCount(for: family)
        ) else {
            return DailyBriefingEntry(
                date: .now,
                items: placeholderItems(for: family),
                region: region,
                imageDataByItemID: [:],
                imageFocusPointByItemID: [:],
                isPlaceholder: true,
                isPremiumLocked: false
            )
        }

        let rotationIndex = currentRotationIndex(for: snapshot, date: .now)
        _ = await WidgetImageCache.cacheImages(for: snapshot, store: imageStore)
        let imageDataByItemID = await cachedImageData(for: snapshot.items)
        let imageFocusPointByItemID = await cachedFocusPoints(for: snapshot.items)
        return makeEntry(
            from: snapshot,
            family: family,
            startingAt: rotationIndex,
            region: snapshot.region,
            date: .now,
            imageDataByItemID: imageDataByItemID,
            imageFocusPointByItemID: imageFocusPointByItemID
        )
    }

    private func makeEntry(
        from snapshot: WidgetNewsSnapshot,
        family: WidgetFamily,
        startingAt index: Int = 0,
        region: String,
        date: Date,
        imageDataByItemID: [String: Data],
        imageFocusPointByItemID: [String: ImageFocusPoint]
    ) -> DailyBriefingEntry {
        let itemCount = visibleItemCount(for: family)
        let selectedItems = snapshot.rotatingItems(startingAt: index, count: itemCount)

        if selectedItems.isEmpty {
            return DailyBriefingEntry(
                date: date,
                items: placeholderItems(for: family),
                region: region,
                imageDataByItemID: [:],
                imageFocusPointByItemID: [:],
                isPlaceholder: true,
                isPremiumLocked: false
            )
        }

        return DailyBriefingEntry(
            date: date,
            items: selectedItems,
            region: region,
            imageDataByItemID: imageDataByItemID,
            imageFocusPointByItemID: imageFocusPointByItemID,
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

        guard let snapshot = await loadSnapshot(
            for: region,
            minimumItemCount: visibleItemCount(for: family)
        ) else {
            let entry = DailyBriefingEntry(
                date: now,
                items: placeholderItems(for: family),
                region: region,
                imageDataByItemID: [:],
                imageFocusPointByItemID: [:],
                isPlaceholder: true,
                isPremiumLocked: false
            )
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60)))
        }

        _ = await WidgetImageCache.cacheImages(for: snapshot, store: imageStore)
        let imageDataByItemID = await cachedImageData(for: snapshot.items)
        let imageFocusPointByItemID = await cachedFocusPoints(for: snapshot.items)
        let entries = timelineEntries(
            from: snapshot,
            family: family,
            startingAt: now,
            imageDataByItemID: imageDataByItemID,
            imageFocusPointByItemID: imageFocusPointByItemID
        )
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func makePremiumLockedEntry(for family: WidgetFamily, region: String, date: Date) -> DailyBriefingEntry {
        DailyBriefingEntry(
            date: date,
            items: placeholderItems(for: family),
            region: region,
            imageDataByItemID: [:],
            imageFocusPointByItemID: [:],
            isPlaceholder: false,
            isPremiumLocked: true
        )
    }

    private func currentRotationIndex(for snapshot: WidgetNewsSnapshot, date: Date) -> Int {
        guard !snapshot.items.isEmpty else { return 0 }
        let rotationPeriod = Int(date.timeIntervalSinceReferenceDate / Self.storyRotationInterval)
        let remainder = rotationPeriod % snapshot.items.count
        return remainder >= 0 ? remainder : remainder + snapshot.items.count
    }

    private func cachedImageData(for items: [WidgetNewsItem]) async -> [String: Data] {
        var imageDataByItemID: [String: Data] = [:]

        for item in items {
            if let data = await imageStore.readImageData(for: item) {
                imageDataByItemID[item.id] = data
            }
        }

        return imageDataByItemID
    }

    private func cachedFocusPoints(for items: [WidgetNewsItem]) async -> [String: ImageFocusPoint] {
        var imageFocusPointByItemID: [String: ImageFocusPoint] = [:]

        for item in items {
            if let focusPoint = await imageStore.readFocusPoint(for: item) {
                imageFocusPointByItemID[item.id] = focusPoint
            }
        }

        return imageFocusPointByItemID
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

    private func loadSnapshot(for region: String, minimumItemCount: Int) async -> WidgetNewsSnapshot? {
        if let cachedSnapshot = await cachedSnapshot(
            matching: region,
            requireFresh: true,
            minimumItemCount: minimumItemCount
        ) {
            return cachedSnapshot
        }

        if let remoteSnapshot = try? await remoteClient.fetchSnapshot(for: region),
           remoteSnapshot.items.count >= minimumItemCount {
            _ = try? await store.writeSnapshot(remoteSnapshot)
            return remoteSnapshot
        }

        if let staleRegionalSnapshot = await cachedSnapshot(
            matching: region,
            minimumItemCount: minimumItemCount
        ) {
            return staleRegionalSnapshot
        }

        return await cachedSnapshot(minimumItemCount: minimumItemCount)
    }

    private func cachedSnapshot(
        matching region: String? = nil,
        requireFresh: Bool = false,
        minimumItemCount: Int = 1
    ) async -> WidgetNewsSnapshot? {
        guard let snapshot = try? await store.readSnapshot(),
              snapshot.isUsableForWidget,
              snapshot.items.count >= minimumItemCount else {
            return nil
        }

        guard !requireFresh || snapshot.isFresh() else {
            return nil
        }

        if let region, snapshot.region.uppercased() != region.uppercased() {
            return nil
        }

        return snapshot
    }

    private func timelineEntries(
        from snapshot: WidgetNewsSnapshot,
        family: WidgetFamily,
        startingAt date: Date,
        imageDataByItemID: [String: Data],
        imageFocusPointByItemID: [String: ImageFocusPoint]
    ) -> [DailyBriefingEntry] {
        let entryCount = Self.maximumTimelineEntryCount

        return (0..<entryCount).map { offset in
            let entryDate = date.addingTimeInterval(TimeInterval(offset) * Self.storyRotationInterval)
            let rotationIndex = currentRotationIndex(for: snapshot, date: entryDate)
            return makeEntry(
                from: snapshot,
                family: family,
                startingAt: rotationIndex,
                region: snapshot.region,
                date: entryDate,
                imageDataByItemID: imageDataByItemID,
                imageFocusPointByItemID: imageFocusPointByItemID
            )
        }
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
                focusPoint: focusPoint(for: entry.item),
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
        }
        .padding(multiStoryPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func multiStoryTile(for item: WidgetNewsItem?) -> some View {
        DailyBriefingStoryTile(
            item: item,
            imageData: imageData(for: item),
            focusPoint: focusPoint(for: item),
            isPlaceholder: entry.isPlaceholder,
            family: .systemMedium
        )
        .clipShape(RoundedRectangle(cornerRadius: multiStoryCornerRadius, style: .continuous))
    }

    private func imageData(for item: WidgetNewsItem?) -> Data? {
        guard let item else { return nil }
        return entry.imageDataByItemID[item.id]
    }

    private func focusPoint(for item: WidgetNewsItem?) -> ImageFocusPoint? {
        guard let item else { return nil }
        return entry.imageFocusPointByItemID[item.id]
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
    let focusPoint: ImageFocusPoint?
    let isPlaceholder: Bool
    let family: WidgetFamily

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                backgroundImage(containerSize: proxy.size)

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
    private func backgroundImage(containerSize: CGSize) -> some View {
        if isPlaceholder {
            Color(.tertiarySystemFill)
        } else if let imageData,
           let image = Self.image(from: imageData) {
            let metrics = ImageCrop.metrics(
                imageSize: CGSize(width: image.width, height: image.height),
                containerSize: containerSize,
                focusPoint: focusPoint,
                focusTargetY: ImageFocusConfiguration.headlineOverlayFocusTargetY
            )

            Image(decorative: image, scale: 1, orientation: .up)
                .resizable()
                .frame(width: metrics.renderedSize.width, height: metrics.renderedSize.height)
                .offset(x: metrics.offset.width, y: metrics.offset.height)
                .frame(width: containerSize.width, height: containerSize.height)
                .clipped()
        } else {
            Color(.tertiarySystemFill)
        }
    }

    private static func image(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(source, 0, nil)
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
