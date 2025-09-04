//
//  ContentView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/17/24.
//

import SwiftUI

struct HomeView: View {
    @State private var vm = NewsListViewModel.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    @State private var targetNews: NeutralNews?
    
    @Namespace private var animationNamespace
    @ObservedObject var config: AppConfig
    
    var body: some View {
        Group {
            if config.isInMaintenance {
                MaintenanceView(config: config)
            } else {
                NavigationStack {
                    newsContentView
                        .navigationTitle(vm.isShowingAllDays ? "Noticias" : vm.daySelected.dayName)
                        // TODO: Mirar que opción es mejor para el title
                        .toolbarTitleDisplayMode(.inlineLarge)
                        .myNavigationSubtitle(vm.isShowingAllDays ? "Últimos 7 días" : vm.daySelected.formattedDateShort)
                        .searchable(text: $vm.searchText, placement: .toolbar, prompt: "Buscar")
                        .searchScopes(vm.isShowingAllDays ? .constant(.lastSevenDays) : $vm.searchScope, activation: .onSearchPresentation) {
                            if !vm.isShowingAllDays {
                                Text(vm.daySelected.dayName).tag(SearchScope.daySelected)
                                Text("Últimos 7 días").tag(SearchScope.lastSevenDays)
                            }
                        }
                        .toolbar {
                            HomeToolbar(vm: vm).content
                        }
                        .navigationDestination(item: $targetNews) { news in
                            NeutralNewsView(news: news, relatedNews: vm.getRelatedNews(from: news), namespace: animationNamespace)
                        }
                        .accentGradientBackground
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    hasSeenOnboarding = true
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
            }
        }
        .animation(.default, value: config.isInMaintenance)
    }
    
    // MARK: - Content Views
    
    private var newsContentView: some View {
        ScrollView {
            if !vm.searchText.isEmpty && vm.newsToShow.isEmpty && !vm.isLoadingNeutralNews {
                noResultsView
            } else if vm.searchText.isEmpty && vm.newsToShow.isEmpty && !vm.isLoadingNeutralNews {
                noNewsYetView
            } else {
                newsListView
            }
        }
        .refreshable {
            await vm.refreshNews()
        }
    }
    
    private var newsListView: some View {
        LazyVStack {
            ForEach(vm.newsToShow) { neutralNews in
                NavigationLink {
                    NeutralNewsView(news: neutralNews, relatedNews: vm.getRelatedNews(from: neutralNews), namespace: animationNamespace)
                        .navigationTransition(.zoom(sourceID: neutralNews.id, in: animationNamespace))
                } label: {
                    NewsImageView(news: neutralNews, imageUrl: neutralNews.imageUrl)
                        .padding(.vertical, 4)
                        .matchedTransitionSource(id: neutralNews.id, in: animationNamespace)
                }
                .buttonStyle(.plain)
            }
            .animation(.default, value: vm.newsToShow)
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
}

// MARK: - View Extensions

extension View {
    var accentGradientBackground: some View {
        background {
            Color("nn-background")
                .ignoresSafeArea()
            
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(0.5),
                    Color.clear
                ]),
                center: .top,
                startRadius: -300,
                endRadius: 500
            )
            .ignoresSafeArea()
        }
    }
    
    @ViewBuilder
    func myNavigationSubtitle(_ subtitle: String) -> some View {
        if #available(iOS 26.0, *) { self.navigationSubtitle(subtitle) } else { self }
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
