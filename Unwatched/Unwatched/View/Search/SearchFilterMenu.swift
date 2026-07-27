//
//  SearchFilterMenu.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Toolbar menu that narrows search results by upload date (mirrors YouTube's /
/// SmartTube's "Upload date" search filter) and picks which sources are searched —
/// YouTube plus anything already stored in the app. Any change re-runs the active
/// search via `SearchVM`.
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

            Section("searchSources") {
                ForEach(SearchSource.allCases) { source in
                    Toggle(isOn: binding(for: source)) {
                        Label {
                            source.label
                        } icon: {
                            Image(systemName: source.systemImage)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: isFiltering
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease")
        }
        .menuOrder(.fixed)
        .accessibilityLabel("searchSortUploadDate")
    }

    private func binding(for source: SearchSource) -> Binding<Bool> {
        Binding(
            get: { vm.isEnabled(source) },
            set: { vm.setEnabled(source, $0) }
        )
    }

    private var isFiltering: Bool {
        vm.uploadDate != .anytime || vm.enabledSources != SearchSource.all
    }
}
