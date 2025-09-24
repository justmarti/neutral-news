//
//  HomeView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/17/24.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @State private var vm = NewsListViewModel.shared
    @Environment(\.modelContext) private var cacheContext
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("isBackgroundColorEnabled") private var isBackgroundColorEnabled = true
    @State private var showOnboarding = false
    @State private var targetNews: NeutralNews?
    @State private var showingSettingsSheet = false
    @State private var showingPaywall = false

    @Namespace private var animationNamespace
    var config: AppConfig

    // Premium manager for UI state
    private let premiumManager = PremiumManager.shared

    // Access to saved news container
    @State private var savedNewsContext: ModelContext?

    // MARK: - Computed Properties

    private var shouldShowPremiumBanner: Bool {
        vm.searchScope == .lastSevenDays && !premiumManager.isPremium
    }

    var body: some View {
        Group {
            if config.isInMaintenance {
                MaintenanceView(config: config)
            } else {
                NavigationStack {
                    newsContentView
                        .navigationTitle(vm.isShowingSavedNews ? "Guardadas" : (vm.isShowingAllDays ? "Todas las noticias" : vm.daySelected.dayName))
                        // TODO: Mirar que opción es mejor para el title
//                        .toolbarTitleDisplayMode(.inlineLarge)
                        .myNavigationSubtitle(vm.isShowingSavedNews ? "\(vm.savedNews.count) noticias" : (vm.isShowingAllDays ? "Últimos 7 días" : vm.daySelected.formattedDateShort))
                        .searchable(text: $vm.searchText, placement: .toolbar, prompt: "Buscar")
                        .searchScopes(vm.isShowingSavedNews ? .constant(.daySelected) : (vm.isShowingAllDays ? .constant(.lastSevenDays) : $vm.searchScope), activation: .onSearchPresentation) {
                            if !vm.isShowingAllDays && !vm.isShowingSavedNews {
                                Text(vm.daySelected.dayName).tag(SearchScope.daySelected)
                                Text("Últimos 7 días").tag(SearchScope.lastSevenDays)
                            }
                        }
                        .toolbar {
                            HomeToolbar(vm: vm, showingPaywall: $showingPaywall).content
                        }
                        .environment(\.isBackgroundColorEnabled, isBackgroundColorEnabled)
                        .animation(.default, value: vm.isShowingSavedNews)
                        .navigationDestination(item: $targetNews) { news in
                            NeutralNewsView(news: news, relatedNews: vm.getRelatedNews(from: news), namespace: animationNamespace)
                                .environment(\.isBackgroundColorEnabled, isBackgroundColorEnabled)
                                .onAppear {
                                    RatingManager.shared.incrementNewsReadCount()
                                    RatingManager.shared.requestRatingAfterPositiveInteraction()
                                }
                        }
                        .accentGradientBackground(isEnabled: isBackgroundColorEnabled)
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    hasSeenOnboarding = true
                    // User completed onboarding - good moment for rating
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
                        RatingManager.shared.requestRatingIfAppropriate()
                    }
                } content: {
                    OnboardingView(isPresented: $showOnboarding)
                }
                .onChange(of: vm.deepLinkTargetNews) { oldValue, newValue in
                    if let news = newValue {
#if DEBUG
                        print("🎯 View received target news: \(news.neutralTitle)")
#endif
                        targetNews = news
                        
                        // Retrasar limpieza para asegurar navegación
                        Task {
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                            vm.deepLinkTargetNews = nil
                        }
                    }
                }
                .onAppear {
                    showOnboarding = !hasSeenOnboarding
                    vm.checkPendingDeepLink()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task {
                        await vm.refreshNews()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .showPaywall)) { _ in
                    showingPaywall = true
                }
                .sheet(isPresented: $showingPaywall) {
                    PaywallView(isPresented: $showingPaywall)
                }
            }
        }
        .animation(.default, value: config.isInMaintenance)
    }
    
    // MARK: - Content Views
    
    private var newsContentView: some View {
        ScrollView {
            if vm.isShowingSavedNews {
                savedNewsContentView
            } else if !vm.searchText.isEmpty && vm.newsToShow.isEmpty && !vm.isLoadingNeutralNews {
                noResultsView
            } else if vm.searchText.isEmpty && vm.newsToShow.isEmpty && !vm.isLoadingNeutralNews {
                noNewsYetView
            } else {
                newsListView
            }
        }
        .refreshable {
            if vm.isShowingSavedNews {
                await vm.loadSavedNews()
            } else {
                await vm.refreshNews()
            }
        }
    }
    
    private var newsListView: some View {
        LazyVStack {
            // Premium search results banner
            if shouldShowPremiumBanner {
                premiumSearchBanner
            }

            ForEach(vm.newsToShow) { neutralNews in
                NavigationLink {
                    NeutralNewsView(news: neutralNews, relatedNews: vm.getRelatedNews(from: neutralNews), namespace: animationNamespace)
                        .environment(\.isBackgroundColorEnabled, isBackgroundColorEnabled)
                        .navigationTransition(.zoom(sourceID: neutralNews.id, in: animationNamespace))
                        .onAppear {
                            RatingManager.shared.incrementNewsReadCount()
                            RatingManager.shared.requestRatingAfterPositiveInteraction()
                        }
                } label: {
                    NewsImageView(news: neutralNews, imageUrl: neutralNews.imageUrl)
                        .padding(.vertical, 4)
                        .matchedTransitionSource(id: neutralNews.id, in: animationNamespace)
                }
                .buttonStyle(.plain)
                .onAppear {
                    if vm.shouldLoadMore(currentItem: neutralNews) {
                        vm.loadNextPage()
                    }
                }
            }
            .animation(.default, value: vm.newsToShow)
            
            // Loading indicator for pagination
            if vm.isLoadingMore {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Cargando más noticias...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }
    
    private var noResultsView: some View {
        ContentUnavailableView(
            "No hay resultados para \"\(vm.searchText)\" en noticias de \(vm.daySelected.dayName)",
            systemImage: "magnifyingglass",
            description: Text("Prueba con otra búsqueda o selecciona otro día.")
        )
        .containerRelativeFrame([.horizontal, .vertical])
    }
    
    private var noNewsYetView: some View {
        ContentUnavailableView(
            "No hay noticias de \(vm.daySelected.dayName) aún",
            systemImage: "newspaper",
            description: Text("Prueba en unos minutos o selecciona otro día.")
        )
        .containerRelativeFrame([.horizontal, .vertical])
    }

    private var savedNewsContentView: some View {
        Group {
            if vm.isLoadingSavedNews {
                ProgressView("Cargando noticias guardadas...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !vm.searchText.isEmpty && vm.newsToShow.isEmpty {
                ContentUnavailableView(
                    "No se encontraron resultados para \"\(vm.searchText)\"",
                    systemImage: "magnifyingglass",
                    description: Text("Prueba con otra búsqueda en tus noticias guardadas.")
                )
                .containerRelativeFrame([.horizontal, .vertical])
            } else if vm.savedNews.isEmpty {
                ContentUnavailableView(
                    "No tienes noticias guardadas",
                    systemImage: "bookmark.slash",
                    description: Text("Guarda noticias que te interesen para leerlas más tarde.")
                )
                .containerRelativeFrame([.horizontal, .vertical])
            } else {
                newsListView
            }
        }
    }

    private var premiumSearchBanner: some View {
        Button {
            showingPaywall.toggle()
        } label: {
            HStack {
                Image(systemName: "star")
                    .font(.title)
                    .foregroundStyle(.accent)
                
                VStack(alignment: .leading) {
                    Text("Mejores 5 resultados")
                        .font(.headline)
                    
                    Text("Desbloquea acceso completo con Facts Pro")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(.thinMaterial, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Extensions

extension View {
    func accentGradientBackground(isEnabled: Bool) -> some View {
        modifier(AccentGradientBackground(isEnabled: isEnabled))
    }

    @ViewBuilder
    func myNavigationSubtitle(_ subtitle: String) -> some View {
        if #available(iOS 26.0, *) { self.navigationSubtitle(subtitle) } else { self }
    }
}

// MARK: - Environment Keys

private struct BackgroundColorEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var isBackgroundColorEnabled: Bool {
        get { self[BackgroundColorEnabledKey.self] }
        set { self[BackgroundColorEnabledKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func mySearchToolbarMinimize() -> some View {
        if #available(iOS 26.0, *) { self.searchToolbarBehavior(.minimize) } else { self }
    }
}

extension View {
    @ViewBuilder
    func myToolbar() -> some View {
        if #available(iOS 26.0, *) {
            self.toolbar {
                ToolbarSpacer(.flexible, placement: .bottomBar)
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
            }
        } else { self }
    }
}

#Preview {
    HomeView(config: AppConfig(isTestMode: true))
}
