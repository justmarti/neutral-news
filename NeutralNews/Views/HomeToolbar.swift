//
//  HomeToolbar.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI

struct HomeToolbar {
    let vm: NewsListViewModel
    @Binding var showingSettings: Bool
    let settingsTransitionNamespace: Namespace.ID
    private let premiumManager = PremiumManager.shared
    
    @ToolbarContentBuilder
    var content: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            settingsButton
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            filterMenu
        }

//        if #available(iOS 26.0, *) {
//            ToolbarSpacer(.fixed, placement: .topBarTrailing)
//        }
        
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
    
    private var settingsButton: some View {
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("Ajustes")
        .matchedTransitionSource(id: "settings-sheet", in: settingsTransitionNamespace)
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
