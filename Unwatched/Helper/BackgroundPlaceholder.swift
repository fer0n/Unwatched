//
//  BackgroundPlaceholder.swift
//  Unwatched
//

import SwiftUI

struct BackgroundPlaceholder: View {
    var systemName: String

    var body: some View {
        Image(systemName: systemName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(60)
            .opacity(0.07)
    }
}
