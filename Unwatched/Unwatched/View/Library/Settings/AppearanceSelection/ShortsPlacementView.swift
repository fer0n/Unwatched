//
//  ShortsPlacementView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ShortsPlacementView: View {
    @AppStorage(Const.shortsPlacement) var shortsPlacement: ShortsPlacement = .show
    @Environment(\.modelContext) var modelContext

    @State var showDiscardShortsConfirmation = false
    @State var oldShortsPlacement: ShortsPlacement?

    var body: some View {
        MySection("shortsSettings", footer: "shortsSettingsHelper") {
            Picker("shortsPlacement", selection: $shortsPlacement) {
                ForEach(ShortsPlacement.allCases, id: \.self) {
                    Text($0.description)
                }
            }
            .pickerStyle(.menu)
        }
        .discardShortsActionSheet(isPresented: $showDiscardShortsConfirmation, onCancel: {
            if let oldSetting = oldShortsPlacement,
               shortsPlacement != oldSetting {
                shortsPlacement = oldSetting
            }
        })
        .onAppear {
            oldShortsPlacement = shortsPlacement
        }
        .onChange(of: shortsPlacement) {
            if shortsPlacement == .discard {
                showDiscardShortsConfirmation = true
            } else {
                oldShortsPlacement = shortsPlacement
            }
        }
    }
}

struct DiscardShortsActionSheetModifier: ViewModifier {
    @AppStorage(Const.shortsPlacement) var shortsPlacement: ShortsPlacement = .show
    @Environment(\.modelContext) var modelContext

    @Binding var isPresented: Bool
    var onCancel: (() -> Void)?
    var onDelete: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .actionSheet(isPresented: $isPresented) {
                ActionSheet(
                    title: Text("discardShortsConfirmationTitle"),
                    message: Text("discardShortsConfirmationMessage"),
                    buttons: [
                        .destructive(Text("discardShortsNow")) { deleteShorts() },
                        .cancel { onCancel?() }
                    ]
                )
            }
    }

    func deleteShorts() {
        shortsPlacement = .discard
        VideoService.clearAllYtShortsFromInbox(modelContext)
        VideoService.deleteShorts(modelContext)
        onDelete?()
    }
}

extension View {
    func discardShortsActionSheet(
        isPresented: Binding<Bool>,
        onCancel: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) -> some View {
        self.modifier(DiscardShortsActionSheetModifier(isPresented: isPresented, onDelete: onDelete))
    }
}

#Preview {
    ShortsPlacementView()
        .modelContainer(DataController.previewContainer)
}
