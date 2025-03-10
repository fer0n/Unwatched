//
//  DateSelectorSheet.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DateSelectorSheet: ViewModifier {
    @Environment(NavigationManager.self) var navManager
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    @State private var isPresented: Bool = false
    @State private var sheetHeight: CGFloat = .zero

    var show: Binding<Bool>?
    let video: Video?
    let detectedDate: Binding<IdentifiableDate?>?
    let onSuccess: (() -> Void)?

    init(
        show: (Binding<Bool>)? = nil,
        video: Video?,
        detectedDate: (Binding<IdentifiableDate?>)? = nil,
        onSuccess: (() -> Void)?) {
        self.show = show
        self.video = video
        self.detectedDate = detectedDate
        self.onSuccess = onSuccess
    }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, onDismiss: onDismiss) {
                DeferDateSelector(
                    video: video,
                    detectedDate: detectedDate,
                    onSuccess: onSuccess
                )
                .fixedSize(horizontal: false, vertical: true)
                .onSizeChange { size in
                    sheetHeight = size.height
                }
                .presentationDetents([.height(sheetHeight)])
                .tint(theme.color)
            }
            .onChange(of: show?.wrappedValue ?? false) {
                if let show {
                    isPresented = show.wrappedValue
                }
            }
            .onChange(of: detectedDate?.wrappedValue?.date) {
                if detectedDate?.wrappedValue?.date != nil {
                    isPresented = true
                }
            }
    }

    func onDismiss() {
        if !SheetPositionReader.shared.landscapeFullscreen {
            navManager.showMenu = true
        }
        detectedDate?.wrappedValue = nil
        show?.wrappedValue = false
    }
}

extension View {
    func dateSelectorSheet(
        show: Binding<Bool>? = nil,
        video: Video?,
        detectedDate: (Binding<IdentifiableDate?>)? = nil,
        onSuccess: (() -> Void)? = nil
    ) -> some View {
        self.modifier(
            DateSelectorSheet(
                show: show,
                video: video,
                detectedDate: detectedDate,
                onSuccess: onSuccess
            )
        )
    }
}
