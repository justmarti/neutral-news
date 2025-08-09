//
//  ContentView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/17/24.
//

import SwiftUI

struct HomeView: View {
    @State private var vm = NewsListViewModel.shared
    @State private var showOnboarding = !UserDefaults.hasSeenOnboarding
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
                        .navigationTitle(vm.daySelected.dayName)
                        .myNavigationSubtitle(vm.daySelected.formattedDateShort)
                        .searchable(text: $vm.searchText, placement: .toolbar, prompt: "Buscar")
                        .searchScopes($vm.searchScope, activation: .onSearchPresentation) {
                            Text(vm.daySelected.dayName).tag(SearchScope.daySelected)
                            Text("Últimos 7 días").tag(SearchScope.lastSevenDays)
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) { dayMenu }
                            ToolbarItem(placement: .topBarTrailing) { orderMenu }
                            ToolbarItem(placement: .topBarTrailing) { filterMenu }
                        }
                        .navigationDestination(item: $targetNews) { news in
                            NeutralNewsView(news: news, relatedNews: vm.getRelatedNews(from: news), namespace: animationNamespace)
                        }
                        .background(Color("nn-background"))
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    UserDefaults.hasSeenOnboarding = true
                } content: {
                    OnboardingView(isPresented: $showOnboarding)
                }
                .onChange(of: vm.deepLinkTargetNews) { oldValue, newValue in
                    if let news = newValue {
                        print("🎯 Vista recibió noticia objetivo: \(news.neutralTitle)")
                        targetNews = news
                        
                        // Retrasar limpieza para asegurar navegación
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            vm.deepLinkTargetNews = nil
                        }
                    }
                }
                .onAppear {
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
    
    // MARK: - Menu Views
    
    private var dayMenu: some View {
        Menu {
            ForEach(vm.lastSevenDays) { day in
                Button {
                    vm.changeDay(to: day)
                } label: {
                    Label(day.dayName, systemImage: day == vm.daySelected ? "\(day.dayNumber).square.fill" : "\(day.dayNumber).square")
                }
            }
        } label: {
            Label("Cambiar día", systemImage: "calendar")
        }
    }
    
    private var orderMenu: some View {
        Menu {
            Button {
                vm.orderBy = .hour
            } label: { Label("Hora", systemImage: vm.orderBy == .hour ? "clock.fill" : "clock") }
            Button {
                vm.orderBy = .relevance
            } label: { Label("Relevancia", systemImage: vm.orderBy == .relevance ? "bolt.fill" : "bolt") }
            Button {
                vm.orderBy = .popularity
            } label: { Label("Popularidad", systemImage: vm.orderBy == .popularity ? "flame.fill" : "flame") }
        } label: {
            Label("Ordenar", systemImage: "arrow.up.arrow.down.circle")
        }
    }
    
    private var filterMenu: some View {
        Menu {
            ForEach(vm.getCategoriesOfTheDay(), id: \.self) { category in
                Button {
                    vm.filterByCategory(category)
                } label: {
                    Label {
                        Label(category.rawValue, systemImage: category.systemImageName)
                    } icon: {
                        if vm.categoryFilter.contains(category) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            if vm.isAnyFilterEnabled {
                Section {
                    Button(role: .destructive) {
                        vm.clearFilters()
                    } label: {
                        Label("Borrar filtros", systemImage: "trash")
                    }
                }
            }
        } label: {
            Label("Filtrar", systemImage: vm.isAnyFilterEnabled ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
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
