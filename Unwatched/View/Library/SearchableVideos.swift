//
//  SearchableVideos.swift
//  Unwatched
//

import Foundation
import SwiftUI

struct SearchableVideos: View {
    @Binding var text: DebouncedText
    @Environment(NavigationManager.self) var navManager

    var body: some View {
        @Bindable var navManager = navManager
        EmptyView()
            .searchable(text: $text.val,
                        isPresented: $navManager.searchFocused,
                        placement: .navigationBarDrawer(displayMode: .always))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .keyboardType(.alphabet)
    }
}
