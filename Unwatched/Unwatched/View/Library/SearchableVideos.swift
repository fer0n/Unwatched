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
        EmptyView()
            #if os(iOS)
            .searchable(text: $text.val,
                        isPresented: Binding(
                            get: {
                                navManager.searchFocused
                            },
                            set: {  newValue in
                                if navManager.searchFocused != newValue {
                                    navManager.searchFocused = newValue
                                }
                            }),
                        placement: .navigationBarDrawer(displayMode: .always))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .keyboardType(.webSearch)
        #endif
    }
}

#Preview {
    @Previewable @State var text = DebouncedText()

    SearchableVideos(text: $text)
        .environment(NavigationManager())
}
