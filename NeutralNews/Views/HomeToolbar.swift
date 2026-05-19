//
//  HomeToolbar.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI

@MainActor
struct HomeToolbar {
    let vm: NewsListViewModel
    @Binding var showingSettings: Bool
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
                    Label("Exit saved", systemImage: "bookmark.fill")
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
            Label("Settings", systemImage: "gearshape")
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
                Label("All News", systemImage: !premiumManager.canViewAllDays ? "lock.fill" : (vm.isShowingAllDays ? "rectangle.stack.fill" : "rectangle.stack"))
                Text("Last 7 days")
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
            Label("Change day", systemImage: "calendar")
        }
    }
    
    private var filterMenu: some View {
        Menu {
            ForEach(vm.getCategoriesOfTheDay(), id: \.self) { category in
                Button {
                    vm.filterByCategory(category)
                } label: {
                    Label {
                        Label(category.title, systemImage: category.systemImageName)
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
                        Label("Clear filters", systemImage: "trash")
                    }
                }
            }
        } label: {
            Label("Filter", systemImage: vm.isAnyFilterEnabled ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }
}
