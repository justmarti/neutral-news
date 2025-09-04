//
//  HomeToolbar.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI

struct HomeToolbar {
    let vm: NewsListViewModel
    
    @ToolbarContentBuilder
    var content: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            orderMenu
            filterMenu
        }
        
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        
        ToolbarItemGroup(placement: .topBarTrailing) {
            dayMenu
        }
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
            } label: {
                Label("Hora", systemImage: vm.orderBy == .hour ? "clock.fill" : "clock")
                Text("Últimas noticias")
            }
            Button {
                vm.orderBy = .relevance
            } label: {
                Label("Relevancia", systemImage: vm.orderBy == .relevance ? "bolt.fill" : "bolt")
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
