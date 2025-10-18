//
//  SearchableContentView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 18/10/25.
//

import SwiftUI

/// Child view that has access to isSearching environment value
/// Must be a child of .searchable modifier for isSearching to work
struct SearchableContentView: View {
    @Bindable var vm: NewsListViewModel
    @Environment(\.isSearching) private var isSearching

    var body: some View {
        EmptyView()
            .onChange(of: isSearching) { oldValue, newValue in
                // When user exits search mode, reset to day scope
                // This handles: Cancel button, dismissing search
                if oldValue && !newValue && vm.searchScope == .lastSevenDays {
                    vm.searchScope = .daySelected
                }
            }
    }
}
