//
//  SheetPosModifier.swift
//  Unwatched
//

import SwiftUI

struct SheetPosParentModifier: ViewModifier {
    @Environment(SheetPositionReader.self) private var sheetPos

    func body(content: Content) -> some View {
        content
            .frame(maxHeight: .infinity)
            .onSizeChange { size in
                sheetPos.parentheight = size.height
            }
    }
}

struct SheetPosContentModifier: ViewModifier {
    @Environment(SheetPositionReader.self) private var sheetPos

    func body(content: Content) -> some View {
        content
            .onSizeChange(action: sheetPos.handleSheetSizeUpdate)
    }
}

extension View {
    func sheetPosParent() -> some View {
        modifier(SheetPosParentModifier())
    }

    func sheetPosContent() -> some View {
        modifier(SheetPosContentModifier())
    }
}
