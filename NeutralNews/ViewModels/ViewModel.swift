//
//  ViewModel.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 1/4/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

@Observable
final class ViewModel: NSObject {
    // MARK: - Properties
    var allNews = [News]()
    var filteredNews = [NeutralNews]()
    
    var todayNews = Set<NeutralNews>()
    var yesterdayNews = Set<NeutralNews>()
    var threeDaysAgoNews = Set<NeutralNews>()
    var fourDaysAgoNews = Set<NeutralNews>()
    var fiveDaysAgoNews = Set<NeutralNews>()
    var sixDaysAgoNews = Set<NeutralNews>()
    var sevenDaysAgoNews = Set<NeutralNews>()
    
    var lastExecutionDate: Date?
    
    var orderBy: OrderBy = .hour {
        didSet {
            withAnimation {
                applyFilters()
            }
        }
    }
    
    // MARK: - Background Loading Properties
    private var backgroundLoadingTask: Task<Void, Never>?
    private var loadedDays = Set<Date>()
    private var loadedNews = Set<News>()
    private var loadedNeutralNews = Set<NeutralNews>()
    
    // MARK: - UI State
    var daySelected: DayInfo = .today {
        didSet {
            updateNewsToShow(withFilters: true)
        }
    }
    var newsToShow = [NeutralNews]()
    var isLoadingNeutralNews = false
    
    // MARK: - Search and Filter
    var searchText: String = "" {
        didSet {
            if searchText != oldValue {
                withAnimation {
                    applyFilters()
                }
            }
        }
    }
    
    var categoryFilter: Set<Category> = []
    var isAnyFilterEnabled: Bool {
        !categoryFilter.isEmpty
    }
    
    // MARK: - Data Collections
    var groupsOfNews = [[News]]()
    var neutralNews = [NeutralNews]()
    
    // MARK: - Computed Properties
    var lastSevenDays: [DayInfo] {
        let calendar = Calendar.current
        let dayFormatter = DateFormatter()
        let monthFormatter = DateFormatter()
        
        dayFormatter.locale = Locale(identifier: "es_ES")
        dayFormatter.dateFormat = "EEEE"
        
        monthFormatter.locale = Locale(identifier: "es_ES")
        monthFormatter.dateFormat = "MMMM"
        
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { return nil }
            
            let dayNumber = calendar.component(.day, from: date)
            let monthName = monthFormatter.string(from: date)
            
            let dayName: String
            switch offset {
            case 0: dayName = "Hoy"
            case 1: dayName = "Ayer"
            default: dayName = dayFormatter.string(from: date).capitalized
            }
            
            return DayInfo(
                dayName: dayName,
                dayNumber: dayNumber,
                monthName: monthName,
                date: date
            )
        }
    }
    
    var newsByDay: [DayInfo: Set<NeutralNews>] {
        let allNews = [
            todayNews,
            yesterdayNews,
            threeDaysAgoNews,
            fourDaysAgoNews,
            fiveDaysAgoNews,
            sixDaysAgoNews,
            sevenDaysAgoNews
        ]
        return Dictionary(uniqueKeysWithValues: zip(lastSevenDays, allNews))
    }
    
    var daySelectedNews: [NeutralNews] {
        let calendar = Calendar.current
        
        return neutralNews.filter { news in
            return calendar.isDate(news.date, inSameDayAs: daySelected.date)
        }.sorted { ($0.date) > ($1.date) }
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        fetchNews(from: .today)
        setupDayChangeTimer()
        startProgressiveLoading()
    }
    
    deinit {
        backgroundLoadingTask?.cancel()
    }
    
    // MARK: - Progressive Loading Methods
    private func startProgressiveLoading() {
        // Cancelar tarea anterior si existe
        backgroundLoadingTask?.cancel()
        
        backgroundLoadingTask = Task(priority: .utility) {
            await loadRemainingDays()
        }
    }
    
    @MainActor
    private func loadRemainingDays() async {
        let calendar = Calendar.current
        let today = Date()
        
        // Cargar días en orden de prioridad (empezar por ayer, luego el resto)
        let priorityOrder = [1, 2, 3, 4, 5, 6] // días hacia atrás
        
        for dayOffset in priorityOrder {
            // Verificar si la tarea fue cancelada
            if Task.isCancelled { return }
            
            guard let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: today),
                  !loadedDays.contains(calendar.startOfDay(for: dayDate)) else {
                continue
            }
            
            let dayInfo = createDayInfo(for: dayDate)
            
            // Pequeña pausa para no saturar la red
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 segundos
            
            if Task.isCancelled { return }
            
            await loadNewsForDayInBackground(dayInfo)
        }
    }
    
    private func createDayInfo(for date: Date) -> DayInfo {
        let calendar = Calendar.current
        let dayFormatter = DateFormatter()
        let monthFormatter = DateFormatter()
        
        dayFormatter.locale = Locale(identifier: "es_ES")
        dayFormatter.dateFormat = "EEEE"
        
        monthFormatter.locale = Locale(identifier: "es_ES")
        monthFormatter.dateFormat = "MMMM"
        
        let dayNumber = calendar.component(.day, from: date)
        let monthName = monthFormatter.string(from: date)
        let dayName = dayFormatter.string(from: date).capitalized
        
        return DayInfo(
            dayName: dayName,
            dayNumber: dayNumber,
            monthName: monthName,
            date: date
        )
    }
    
    private func loadNewsForDayInBackground(_ dayInfo: DayInfo) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: dayInfo.date)
        
        // Marcar como cargado para evitar duplicados
        loadedDays.insert(startOfDay)
        
        // Realizar carga en paralelo de neutral news y news
        async let neutralNewsTask = loadNeutralNewsInBackground(for: dayInfo)
        async let newsTask = loadNewsInBackground(for: dayInfo)
        
        let (neutralNews, news) = await (neutralNewsTask, newsTask)
        
        // Actualizar en el hilo principal
        await MainActor.run {
            if !neutralNews.isEmpty {
                self.neutralNews.append(contentsOf: neutralNews)
                self.classifyNewsByDate()
            }
            
            if !news.isEmpty {
                self.allNews.append(contentsOf: news)
                self.filterGroupedNews()
            }
        }
    }
    
    private func loadNeutralNewsInBackground(for dayInfo: DayInfo) async -> [NeutralNews] {
        return await withCheckedContinuation { continuation in
            let db = Firestore.firestore()
            let start = Calendar.current.startOfDay(for: dayInfo.date)
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
            
            db.collection("neutral_news")
                .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: start))
                .whereField("date", isLessThan: Timestamp(date: end))
                .getDocuments { snapshot, error in
                    guard error == nil,
                          let documents = snapshot?.documents else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let fetchedNews = documents.compactMap { doc -> NeutralNews? in
                        let data = doc.data()
                        
                        guard let neutralTitle = data["neutral_title"] as? String,
                              let neutralDescription = data["neutral_description"] as? String,
                              let category = data["category"] as? String,
                              let relevance = data["relevance"] as? Int,
                              let imageUrl = data["image_url"] as? String,
                              let imageMedium = data["image_medium"] as? String,
                              let date = data["date"] as? Timestamp,
                              let createdAt = data["created_at"] as? Timestamp,
                              let updatedAt = data["updated_at"] as? Timestamp,
                              let group = data["group"] as? Int
                        else { return nil }
                        
                        return NeutralNews(
                            neutralTitle: neutralTitle,
                            neutralDescription: neutralDescription,
                            category: category,
                            relevance: relevance,
                            imageUrl: imageUrl,
                            imageMedium: imageMedium,
                            date: date.dateValue(),
                            createdAt: createdAt.dateValue(),
                            updatedAt: updatedAt.dateValue(),
                            group: group
                        )
                    }
                    
                    continuation.resume(returning: fetchedNews)
                }
        }
    }
    
    private func loadNewsInBackground(for dayInfo: DayInfo) async -> [News] {
        return await withCheckedContinuation { continuation in
            let db = Firestore.firestore()
            let start = Calendar.current.startOfDay(for: dayInfo.date)
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
            
            db.collection("news")
                .whereField("pub_date", isGreaterThanOrEqualTo: Timestamp(date: start))
                .whereField("pub_date", isLessThan: Timestamp(date: end))
                .whereField("group", isGreaterThan: -1)
                .getDocuments { snapshot, error in
                    guard error == nil,
                          let documents = snapshot?.documents else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let fetchedNews = documents.compactMap { doc -> News? in
                        let data = doc.data()
                        
                        guard let title = data["title"] as? String,
                              let description = data["description"] as? String,
                              let group = data["group"] as? Int,
                              let category = data["category"] as? String,
                              let link = data["link"] as? String,
                              let pubDate = data["pub_date"] as? Timestamp,
                              let createdAt = data["created_at"] as? Timestamp,
                              let updatedAt = data["updated_at"] as? Timestamp,
                              let neutralScore = data["neutral_score"] as? Int,
                              let sourceMediumRaw = data["source_medium"] as? String,
                              let sourceMedium = Media(rawValue: sourceMediumRaw)
                        else { return nil }
                        
                        let scrappedDescription = data["scrapped_description"] as? String
                        let imageUrl = data["image_url"] as? String
                        let embedding = data["embedding"] as? [Double] ?? []
                        
//                        let excludedMedia: Set<String> = ["El Mundo", "Expansión", "elMundo", "expansion"]
//                        if excludedMedia.contains(sourceMediumRaw) {
//                            return nil
//                        }
                        
                        return News(
                            title: title,
                            description: description,
                            scrappedDescription: scrappedDescription,
                            category: category,
                            imageUrl: imageUrl,
                            link: link,
                            pubDate: pubDate.dateValue(),
                            createdAt: createdAt.dateValue(),
                            updatedAt: updatedAt.dateValue(),
                            sourceMedium: sourceMedium,
                            neutralScore: neutralScore,
                            group: group,
                            embedding: embedding
                        )
                    }
                    
                    continuation.resume(returning: fetchedNews)
                }
        }
    }
    
    // MARK: - Firestore Methods
    func fetchNews(from day: DayInfo) {
        fetchNeutralNewsFromFirestore(from: day)
        fetchNewsFromFirestore(from: day)
    }
    
    func fetchNeutralNewsFromFirestore(from day: DayInfo) {
        isLoadingNeutralNews = true
        
        let db = Firestore.firestore()
        let start = Calendar.current.startOfDay(for: day.date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        
        db.collection("neutral_news")
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: start))
            .whereField("date", isLessThan: Timestamp(date: end))
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching neutral news: \(error.localizedDescription)")
                    self.isLoadingNeutralNews = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No neutral news found in Firestore")
                    self.isLoadingNeutralNews = false
                    return
                }
                
                let fetchedNeutralNews = documents.compactMap { doc -> NeutralNews? in
                    let data = doc.data()
                    let docID = doc.documentID
                    
                    guard let neutralTitle = data["neutral_title"] as? String,
                          let neutralDescription = data["neutral_description"] as? String,
                          let category = data["category"] as? String,
                          let relevance = data["relevance"] as? Int,
                          let imageUrl = data["image_url"] as? String,
                          let imageMedium = data["image_medium"] as? String,
                          let date = data["date"] as? Timestamp,
                          let createdAt = data["created_at"] as? Timestamp,
                          let updatedAt = data["updated_at"] as? Timestamp,
                          let group = data["group"] as? Int
                    else {
                        print("Error parsing neutral news document: \(docID)")
                        return nil
                    }
                    
                    return NeutralNews(
                        neutralTitle: neutralTitle,
                        neutralDescription: neutralDescription,
                        category: category,
                        relevance: relevance,
                        imageUrl: imageUrl,
                        imageMedium: imageMedium,
                        date: date.dateValue(),
                        createdAt: createdAt.dateValue(),
                        updatedAt: updatedAt.dateValue(),
                        group: group
                    )
                }
                
                DispatchQueue.main.async {
                    let newNeutralNews = fetchedNeutralNews.filter { news in
                        !self.loadedNeutralNews.contains(news)
                    }
                    
                    // Solo añadir noticias nuevas
                    if !newNeutralNews.isEmpty {
                        self.neutralNews.append(contentsOf: newNeutralNews)
                        self.loadedNeutralNews.formUnion(newNeutralNews)
                        
                        self.neutralNews.sort { $0.createdAt > $1.createdAt }
                    }
                    
                    self.classifyNewsByDate()
                    
                    // Marcar día como cargado
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: day.date)
                    self.loadedDays.insert(startOfDay)
                    
                    self.filterGroupedNews()
                    self.updateNewsToShow(withFilters: false)
                    
                    self.isLoadingNeutralNews = false
                }
            }
    }
    
    func fetchNewsFromFirestore(from day: DayInfo) {
        let db = Firestore.firestore()
        let start = Calendar.current.startOfDay(for: day.date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        
        db.collection("news")
            .whereField("pub_date", isGreaterThanOrEqualTo: Timestamp(date: start))
            .whereField("pub_date", isLessThan: Timestamp(date: end))
            .whereField("group", isGreaterThan: -1)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching news: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No news found in Firestore")
                    return
                }
                
                let fetchedNews = documents.compactMap { doc -> News? in
                    let data = doc.data()
                    let docID = doc.documentID
                    
                    guard let title = data["title"] as? String,
                          let description = data["description"] as? String,
                          let scrappedDescription = data["scrapped_description"] as? String?,
                          let group = data["group"] as? Int,
                          let category = data["category"] as? String,
                          let imageUrl = data["image_url"] as? String?,
                          let link = data["link"] as? String,
                          let pubDate = data["pub_date"] as? Timestamp,
                          let createdAt = data["created_at"] as? Timestamp,
                          let updatedAt = data["updated_at"] as? Timestamp,
                          let neutralScore = data["neutral_score"] as? Int,
                          let sourceMediumRaw = data["source_medium"] as? String,
                          let sourceMedium = Media(rawValue: sourceMediumRaw),
                          let embedding = data["embedding"] as? [Double]?
                    else {
                        print("Error parsing news document: \(docID)")
                        return nil
                    }
                    
                    // TODO: Arreglar El Mundo y Expansión?
//                    let excludedMedia: Set<String> = ["El Mundo", "Expansión", "elMundo", "expansion"]
//                    if excludedMedia.contains(sourceMediumRaw) {
//                        return nil
//                    }
                    
                    return News(
                        title: title,
                        description: description,
                        scrappedDescription: scrappedDescription,
                        category: category,
                        imageUrl: imageUrl,
                        link: link,
                        pubDate: pubDate.dateValue(),
                        createdAt: createdAt.dateValue(),
                        updatedAt: updatedAt.dateValue(),
                        sourceMedium: sourceMedium,
                        neutralScore: neutralScore,
                        group: group,
                        embedding: embedding ?? []
                    )
                }
                
                DispatchQueue.main.async {
                    // Filtrar solo noticias nuevas
                    let newNews = fetchedNews.filter { news in
                        !self.loadedNews.contains(news)
                    }
                    
                    // Solo añadir noticias nuevas
                    if !newNews.isEmpty {
                        self.allNews.append(contentsOf: newNews)
                        self.loadedNews.formUnion(newNews) // Más eficiente que forEach
                    }
                    
                    self.filterGroupedNews()
                    self.updateNewsToShow(withFilters: false)
                }
            }
    }
    
    // MARK: - News Processing
    func getRelatedNews(from neutralNews: NeutralNews) -> [News] {
        groupsOfNews.first(where: { $0.first?.group == neutralNews.group }) ?? []
    }
    
    func filterGroupedNews() {
        let groupedNews = Dictionary(grouping: allNews.compactMap { $0 }, by: { $0.group })
        let filteredGroups = groupedNews.filter { $0.value.count > 1 && $0.key != -1}
        
        let sortedGroups = filteredGroups.sorted { group1, group2 in
            guard let latestNews1 = group1.value.first, let latestNews2 = group2.value.first else {
                return false
            }
            return latestNews1.pubDate > latestNews2.pubDate
        }
        
        groupsOfNews = sortedGroups.map { $0.value }
    }
    
    func setupDayChangeTimer() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        guard let tomorrow = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) else { return }
        
        let timeInterval = tomorrow.timeIntervalSince(Date())
        
        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            self?.handleDayChange()
            self?.setupDayChangeTimer()
        }
    }
    
    func handleDayChange() {
        sevenDaysAgoNews.removeAll()
        sixDaysAgoNews = sevenDaysAgoNews
        fiveDaysAgoNews = sixDaysAgoNews
        fourDaysAgoNews = fiveDaysAgoNews
        threeDaysAgoNews = fourDaysAgoNews
        yesterdayNews = todayNews
        todayNews.removeAll()
        
        lastExecutionDate = Date()
        
        classifyNewsByDate()
        
        if daySelected.dayName == "Hoy" || daySelected.dayName == "Ayer" || lastSevenDays.contains(daySelected) {
            updateNewsToShow(withFilters: true)
        }
        
        // Reiniciar carga progresiva para el nuevo día
        startProgressiveLoading()
    }
    
    func classifyNewsByDate() {
        let currentDate = Date()
        let calendar = Calendar.current
        
        let shouldChangeDay = isAnotherDay(currentDate: currentDate)
        
        if shouldChangeDay {
            todayNews.removeAll()
            yesterdayNews.removeAll()
            threeDaysAgoNews.removeAll()
            fourDaysAgoNews.removeAll()
            fiveDaysAgoNews.removeAll()
            sixDaysAgoNews.removeAll()
            sevenDaysAgoNews.removeAll()
            
            lastExecutionDate = currentDate
        }
        
        for news in neutralNews {
            guard let daysOfDifference = calendar.dateComponents([.day], from: news.date, to: currentDate).day else {
                continue
            }
            
            switch daysOfDifference {
            case 0:
                todayNews.insert(news)
            case 1:
                yesterdayNews.insert(news)
            case 2:
                threeDaysAgoNews.insert(news)
            case 3:
                fourDaysAgoNews.insert(news)
            case 4:
                fiveDaysAgoNews.insert(news)
            case 5:
                sixDaysAgoNews.insert(news)
            case 6:
                sevenDaysAgoNews.insert(news)
            default:
                break
            }
        }
    }
    
    func isAnotherDay(currentDate: Date) -> Bool {
        guard let lastDate = lastExecutionDate else {
            return true
        }
        
        let calendar = Calendar.current
        let isSameDay = calendar.isDate(lastDate, inSameDayAs: currentDate)
        return !isSameDay
    }
    
    // MARK: - UI Methods
    func changeDay(to dayInfo: DayInfo) {
        if daySelected != dayInfo {
            daySelected = dayInfo
            
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: dayInfo.date)
            
            // Solo hacer fetch si no está cargado
            if !loadedDays.contains(startOfDay) {
                fetchNews(from: dayInfo)
            }
        }
    }
    
    func updateNewsToShow(withFilters: Bool) {
        withAnimation {
            if withFilters {
                applyFilters()
            } else {
                newsToShow = daySelectedNews
            }
        }
    }
    
    // MARK: - Filtering Methods
    func getCategoriesOfTheDay() -> [Category] {
        let categoriesSet = daySelectedNews.compactMap{ Category(rawValue: $0.category) }
        return Category.allCases.filter { categoriesSet.contains($0) }
    }
    
    func filterByCategory(_ category: Category) {
        if categoryFilter.contains(category) {
            categoryFilter.remove(category)
        } else {
            categoryFilter.insert(category)
        }
        
        withAnimation {
            applyFilters()
        }
    }
    
    func applyFilters() {
        var newsToFilter = daySelectedNews
        
        if !categoryFilter.isEmpty {
            newsToFilter = newsToFilter.filter { news in
                let matchesCategory = categoryFilter.isEmpty || categoryFilter.contains { category in
                    news.category.normalized() == category.rawValue.normalized()
                }
                return matchesCategory
            }
        }
        
        if !searchText.isEmpty {
            let normalizedQuery = searchText.normalizedSearchString()
            newsToFilter = newsToFilter.filter {
                $0.neutralTitle.normalizedSearchString().contains(normalizedQuery) ||
                $0.neutralDescription.normalizedSearchString().contains(normalizedQuery)
            }
        }
        
        newsToShow = newsToFilter.sorted { news1, news2 in
            if !searchText.isEmpty {
                let normalizedQuery = searchText.normalizedSearchString()
                let title1ContainsQuery = news1.neutralTitle.normalizedSearchString().contains(normalizedQuery)
                let title2ContainsQuery = news2.neutralTitle.normalizedSearchString().contains(normalizedQuery)
                
                if title1ContainsQuery && !title2ContainsQuery {
                    return true
                } else if !title1ContainsQuery && title2ContainsQuery {
                    return false
                }
            }
            
            switch orderBy {
            case .hour:
                return (news1.date) > (news2.date)
            case .relevance:
                return (news1.relevance) > (news2.relevance)
            case .popularity:
                return (getRelatedNews(from: news1).count) > (getRelatedNews(from: news2).count)
            }
        }
    }
    
    func clearFilters() {
        categoryFilter.removeAll()
        withAnimation {
            applyFilters()
        }
    }
    
    func allCategories() -> Set<String> {
        Set(allNews.map(\.category))
    }
}

// MARK: - Authentication Extension
extension ViewModel {
    // TODO: Aun no está implementado, ¿implementarlo?
    func authenticateAnonymously() {
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                print("Error de autenticación: \(error.localizedDescription)")
                return
            }
            
            guard let user = authResult?.user else {
                print("No se obtuvo un usuario anónimo válido")
                return
            }
            
            user.getIDToken { token, error in
                if let error = error {
                    print("Error al obtener el token: \(error.localizedDescription)")
                    return
                }
                
                guard token != nil else {
                    print("No se pudo obtener un token válido")
                    return
                }
            }
        }
    }
}

// MARK: - String Extensions
extension String {
    func normalized() -> String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "-")
    }
    
    func normalizedSearchString() -> String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: "", options: .regularExpression)
    }
    
    func toDate() -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return dateFormatter.date(from: self)
    }
}

// MARK: - Image Processing
@MainActor
func getDominantColor(from urlString: String?) async -> Color {
    guard let urlString = urlString, let url = URL(string: urlString) else { return .gray }
    
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return .gray }
        
        let originalWidth = cgImage.width
        let originalHeight = cgImage.height
        
        let width = min(10, originalWidth)
        let height = min(10, originalHeight)
        
        guard width > 0, height > 0 else { return .gray }
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return .gray
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return .gray }
        
        var r = 0, g = 0, b = 0
        let pixelCount = width * height
        
        for i in stride(from: 0, to: pixelCount * 4, by: 4) {
            r += Int(data.load(fromByteOffset: i, as: UInt8.self))
            g += Int(data.load(fromByteOffset: i + 1, as: UInt8.self))
            b += Int(data.load(fromByteOffset: i + 2, as: UInt8.self))
        }
        
        return Color(
            red: Double(r) / Double(255 * pixelCount),
            green: Double(g) / Double(255 * pixelCount),
            blue: Double(b) / Double(255 * pixelCount)
        )
    } catch {
        return .gray
    }
}
