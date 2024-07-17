//
//  MyForm.swift
//  Unwatched
//

import SwiftUI

struct MyForm<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Form {
            content
        }
        .scrollContentBackground(.hidden)
    }
}
