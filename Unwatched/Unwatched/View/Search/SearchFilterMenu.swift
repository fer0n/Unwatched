//
//  SearchFilterMenu.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Toolbar menu that lets the user narrow search results by upload date
/// (mirrors YouTube's / SmartTube's "Upload date" search filter). Selecting a
/// value re-runs the active search via `SearchVM`.
struct SearchFilterMenu: View {
    @Bindable var vm: SearchVM

    var body: some View {
        Menu {
            Picker(selection: $vm.uploadDate) {
                ForEach(SearchFilter.UploadDate.allCases, id: \.self) { date in
                    Text(date.label).tag(date)
                }
            } label: {
                Text("searchSortUploadDate")
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: isFiltering
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease")
        }
        .menuOrder(.fixed)
        .accessibilityLabel("searchSortUploadDate")
    }

    private var isFiltering: Bool {
        vm.uploadDate != .anytime
    }
}
