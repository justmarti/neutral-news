import ImageIO
import SwiftUI
import UIKit
import WidgetKit


struct DailyBriefingEntry: TimelineEntry {
    let date: Date
    let item: WidgetNewsItem?
    let region: String
    let imageData: Data?
    let isPlaceholder: Bool

    var deepLinkURL: URL? {
        guard let item else { return WidgetDeepLink.appURL }
        return WidgetDeepLink.url(for: item, region: region)
    }

    static let preview = DailyBriefingEntry(
        date: .now,
        item: WidgetNewsItem(
            id: "preview-story",
            title: "Global leaders prepare for a new round of high-stakes talks",
            imageURL: nil,
            date: .now,
            relevance: 10
        ),
        region: "US",
        imageData: nil,
        isPlaceholder: false
    )
}

struct DailyBriefingProvider: TimelineProvider {
    private let store = WidgetSnapshotStore()
    private let remoteClient = WidgetRemoteSnapshotClient()

    func placeholder(in context: Context) -> DailyBriefingEntry {
        DailyBriefingEntry(
            date: .now,
            item: Self.placeholderItem,
            region: "US",
            imageData: nil,
            isPlaceholder: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyBriefingEntry) -> Void) {
        Task {
            if context.isPreview {
                completion(await makePreviewEntry())
            } else {
                completion(await makeCurrentEntry())
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyBriefingEntry>) -> Void) {
        Task {
            completion(await makeTimeline())
        }
    }

    private func makePreviewEntry() async -> DailyBriefingEntry {
        guard let snapshot = try? store.readSnapshot(), let item = snapshot.items.first else {
            return DailyBriefingEntry(
                date: .now,
                item: Self.placeholderItem,
                region: "US",
                imageData: nil,
                isPlaceholder: false
            )
        }

        return await makeEntry(for: item, region: snapshot.region, date: .now, loadImage: true)
    }

    private func makeCurrentEntry() async -> DailyBriefingEntry {
        let region = WidgetRegionResolver.currentRegion()
        guard let snapshot = await loadSnapshot(for: region), let item = snapshot.items.first else {
            return DailyBriefingEntry(date: .now, item: nil, region: region, imageData: nil, isPlaceholder: false)
        }

        return await makeEntry(for: item, region: snapshot.region, date: .now, loadImage: true)
    }

    private func makeEntry(for item: WidgetNewsItem, region: String, date: Date, loadImage: Bool) async -> DailyBriefingEntry {
        DailyBriefingEntry(
            date: date,
            item: item,
            region: region,
            imageData: loadImage ? await WidgetImageLoader.imageData(from: item.imageURL) : nil,
            isPlaceholder: false
        )
    }

    private func makeTimeline() async -> Timeline<DailyBriefingEntry> {
        let now = Date()
        let region = WidgetRegionResolver.currentRegion()

        guard let snapshot = await loadSnapshot(for: region), !snapshot.items.isEmpty else {
            let entry = DailyBriefingEntry(date: now, item: nil, region: region, imageData: nil, isPlaceholder: false)
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(30 * 60)))
        }

        var entries: [DailyBriefingEntry] = []
        for (index, item) in snapshot.items.enumerated() {
            entries.append(
                await makeEntry(
                    for: item,
                    region: snapshot.region,
                    date: now.addingTimeInterval(TimeInterval(index) * 30 * 60),
                    loadImage: true
                )
            )
        }

        let refreshDate = now.addingTimeInterval(TimeInterval(snapshot.items.count) * 30 * 60)
        return Timeline(entries: entries, policy: .after(refreshDate))
    }

    private func loadSnapshot(for region: String) async -> WidgetNewsSnapshot? {
        if let remoteSnapshot = try? await remoteClient.fetchSnapshot(for: region) {
            _ = try? store.writeSnapshot(remoteSnapshot, skipUnchangedContent: false)
            return remoteSnapshot
        }

        guard let cachedSnapshot = try? store.readFreshSnapshot(),
              cachedSnapshot.region.uppercased() == region.uppercased() else {
            return nil
        }

        return cachedSnapshot
    }

    private static let placeholderItem = WidgetNewsItem(
        id: "preview-story",
        title: "Global leaders prepare for a new round of high-stakes talks",
        imageURL: nil,
        date: .now,
        relevance: 10
    )
}

private enum WidgetImageLoader {
    private static let maximumDownloadBytes = 15_000_000
    private static let thumbnailMaxPixelSize: CGFloat = 900

    static func imageData(from url: URL?) async -> Data? {
        guard let url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("NeutralNewsWidget/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  data.count <= maximumDownloadBytes else {
                return nil
            }
            return downsampledJPEGData(from: data)
        } catch {
            return nil
        }
    }

    private static func downsampledJPEGData(from data: Data) -> Data? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return nil
        }

        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }

        let image = UIImage(cgImage: cgImage)
        return image.jpegData(compressionQuality: 0.82)
    }
}

struct NeutralNewsWidgetsEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyBriefingEntry

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                backgroundImage
                    .frame(width: proxy.size.width, height: proxy.size.height)

                bottomGradient
                    .frame(height: proxy.size.height * gradientHeightRatio)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                titleContent
                    .frame(width: proxy.size.width, alignment: .bottomLeading)
            }
            .clipped()
        }
        .containerBackground(.black, for: .widget)
        .widgetURL(entry.deepLinkURL)
    }

    @ViewBuilder
    private var backgroundImage: some View {
        if let imageData = entry.imageData,
           let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.10),
                    Color(red: 0.18, green: 0.19, blue: 0.21)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
        if entry.isPlaceholder {
            EmptyView()
        } else if let item = entry.item {
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
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
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
