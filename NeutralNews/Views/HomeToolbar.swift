//
//  HomeToolbar.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI

struct HomeToolbar {
    let vm: NewsListViewModel
    @Binding var showingPaywall: Bool
    @Binding var showingSafari: Bool
    @Binding var safariURL: URL?
    @AppStorage("isBackgroundColorEnabled") private var isBackgroundColorEnabled = true

    private let premiumManager = PremiumManager.shared
    
    @ToolbarContentBuilder
    var content: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            settingsMenu
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            filterMenu
        }

        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            if vm.isShowingSavedNews {
                Button {
                    withAnimation {
                        vm.toggleSavedNewsMode()
                    }
                } label: {
                    Label("Salir de guardadas", systemImage: "bookmark.fill")
                }
            } else {
                dayMenu
            }
        }
    }
    
    // MARK: - Menu Views
    
    private var settingsMenu: some View {
        Menu {
            if !premiumManager.isPremium {
                Button {
                    showingPaywall.toggle()
                } label: {
                    Label("Mejorar a Facts Pro", systemImage: "rosette")
                }

                Divider()
            }

            Button {
                if premiumManager.canSaveNews {
                    withAnimation {
                        vm.toggleSavedNewsMode()
                    }
                } else {
                    premiumManager.requirePremium(for: "view_saved_news") {
                        withAnimation {
                            vm.toggleSavedNewsMode()
                        }
                    }
                }
            } label: {
                Label("Noticias guardadas", systemImage: !premiumManager.canSaveNews ? "lock.fill" : (vm.isShowingSavedNews ? "bookmark.fill" : "bookmark"))
            }

            Button {
                withAnimation {
                    isBackgroundColorEnabled.toggle()
                }
            } label: {
                Label("Color de fondo", systemImage: isBackgroundColorEnabled ? "paintbrush.fill" : "paintbrush")
            }

            Divider()

            Button {
                safariURL = URL(string: "https://getfacts.app/privacy-policy")
                showingSafari = true
            } label: {
                Label("Política de Privacidad", systemImage: "hand.raised")
            }

            Button {
                safariURL = URL(string: "https://getfacts.app/terms-of-use")
                showingSafari = true
            } label: {
                Label("Términos de Uso", systemImage: "doc.text")
            }
        } label: {
            Label("Ajustes", systemImage: "gearshape")
        }
    }
    
    private var dayMenu: some View {
        Menu {
            Button {
                if premiumManager.canViewAllDays {
                    vm.changeToAllDays()
                } else {
                    premiumManager.requirePremium(for: "view_all_news") {
                        vm.changeToAllDays()
                    }
                }
            } label: {
                Label("Todas las noticias", systemImage: !premiumManager.canViewAllDays ? "lock.fill" : (vm.isShowingAllDays ? "rectangle.stack.fill" : "rectangle.stack"))
                Text("Últimos 7 días")
            }
            
            Divider()
            
            ForEach(vm.lastSevenDays) { day in
                Button {
                    if premiumManager.canViewDay(day) {
                        vm.changeDay(to: day)
                    } else {
                        premiumManager.requirePremium(for: "view_week_news") {
                            vm.changeDay(to: day)
                        }
                    }
                } label: {
                    Label(day.dayName, systemImage: !premiumManager.canViewDay(day) ? "lock.fill" : ((!vm.isShowingAllDays && day == vm.daySelected) ? "checkmark" : "\(day.dayNumber).calendar"))
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
            } label: {
                Label("Hora", systemImage: vm.orderBy == .hour ? "clock.fill" : "clock")
                Text("Últimas noticias")
            }
            Button {
                vm.orderBy = .relevance
            } label: {
                Label("Relevancia", systemImage: vm.orderBy == .relevance ? "megaphone.fill" : "megaphone")
                Text("Las más importantes")
            }
            Button {
                vm.orderBy = .popularity
            } label: {
                Label("Cobertura", systemImage: vm.orderBy == .popularity ? "flame.fill" : "flame")
                Text("Las más comentadas")
            }
        } label: {
            Label("Ordenar", systemImage: "arrow.up.arrow.down.circle")
        }
    }
    
    private var filterMenu: some View {
        Menu {
            ControlGroup {
                Button {
                    vm.orderBy = .hour
                } label: {
                    Label("Hora", systemImage: vm.orderBy == .hour ? "clock.fill" : "clock")
                }
                Button {
                    vm.orderBy = .relevance
                } label: {
                    Label("Relevancia", systemImage: vm.orderBy == .relevance ? "megaphone.fill" : "megaphone")
                }
                Button {
                    vm.orderBy = .popularity
                } label: {
                    Label("Cobertura", systemImage: vm.orderBy == .popularity ? "flame.fill" : "flame")
                }
            }
            
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
}
