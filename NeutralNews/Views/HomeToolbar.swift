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
    @AppStorage("isBackgroundColorEnabled") private var isBackgroundColorEnabled = true

    private let premiumManager = PremiumManager.shared
    
    @ToolbarContentBuilder
    var content: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            settingsMenu
        }
        
        if !vm.isShowingSavedNews {
            ToolbarItemGroup(placement: .topBarTrailing) {
//                orderMenu
                filterMenu
            }
        }

        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        
        ToolbarItemGroup(placement: .topBarTrailing) {
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
            Button {
                showingPaywall.toggle()
            } label: {
                Label("Facts Pro", systemImage: "rosette")
            }
            
            Divider()
            
            Button {
                if premiumManager.canSaveNews {
                    withAnimation {
                        vm.toggleSavedNewsMode()
                    }
                } else {
                    premiumManager.requirePremium(for: "view_saved_news")
                }
            } label: {
                Label("Noticias guardadas", systemImage: vm.isShowingSavedNews ? "bookmark.fill" : "bookmark")
            }

            Button {
                withAnimation {
                    isBackgroundColorEnabled.toggle()
                }
            } label: {
                Label("Color de fondo", systemImage: isBackgroundColorEnabled ? "paintbrush.fill" : "paintbrush")
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
                    premiumManager.requirePremium(for: "view_all_news")
                }
            } label: {
                Label("Todas las noticias", systemImage: vm.isShowingAllDays ? "rectangle.stack.fill" : "rectangle.stack")
                Text("Últimos 7 días")
            }
            
            Divider()
            
            ForEach(vm.lastSevenDays) { day in
                Button {
                    if premiumManager.canViewDay(day) {
                        vm.changeDay(to: day)
                    } else {
                        premiumManager.requirePremium(for: "view_week_news")
                    }
                } label: {
                    // TODO: Usar number.calendar ?
                    Label(day.dayName, systemImage: (!vm.isShowingAllDays && day == vm.daySelected) ? "\(day.dayNumber).square.fill" : "\(day.dayNumber).square")
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
                Label("Popularidad", systemImage: vm.orderBy == .popularity ? "flame.fill" : "flame")
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
                    Label("Popularidad", systemImage: vm.orderBy == .popularity ? "flame.fill" : "flame")
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
