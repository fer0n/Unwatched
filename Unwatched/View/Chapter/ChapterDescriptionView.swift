//
//  ChapterSelection.swift
//  Unwatched
//

import SwiftUI

enum ChapterDescriptionPage {
    case description
    case chapters
}

struct ChapterDescriptionView: View {
    @Environment(\.dismiss) var dismiss

    let video: Video
    @Binding var page: ChapterDescriptionPage

    @State var selectedDetailPageTask: Task<ChapterDescriptionPage, Never>?
    @GestureState private var dragState: CGFloat = 0

    var body: some View {
        NavigationStack {
            let hasChapters = video.chapters?.isEmpty == false
            let hasDescription = video.videoDescription != nil

            ZStack {
                Color.backgroundColor.ignoresSafeArea(.all)

                ScrollView {
                    if page == .chapters && hasChapters {
                        ChapterList(video: video)
                            .padding(.horizontal)
                            .transition(.move(edge: .trailing))
                    } else {
                        DescriptionDetailView(video: video)
                            .transition(.move(edge: .leading))
                    }
                }
            }
            .highPriorityGesture(dragGesture(origin: page))
            .toolbar {
                if hasDescription && hasChapters {
                    ToolbarItem(placement: .principal) {
                        Picker("page", selection: $page) {
                            Text("description").tag(ChapterDescriptionPage.description)
                            Text("chapters").tag(ChapterDescriptionPage.chapters)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: .infinity)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: Const.clearSF)
                    }
                }
            }
            .tint(.neutralAccentColor)
            .myNavigationTitle()
        }
        .task(id: selectedDetailPageTask) {
            guard let task = selectedDetailPageTask else {
                return
            }
            let direction = await task.value
            withAnimation {
                page = direction
            }
        }
    }

    func dragGesture(origin: ChapterDescriptionPage) -> some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .updating($dragState) { value, state, _ in
                let hasChapters = video.chapters?.isEmpty == false
                let hasDescription = video.videoDescription != nil
                if origin == .chapters && !hasDescription || origin == .description && !hasChapters {
                    return
                }

                state = value.translation.width
                if (origin == .chapters && state > 30) || (origin == .description && state < -30) {
                    selectedDetailPageTask = Task.detached {
                        let direction: ChapterDescriptionPage = origin == .description ? .chapters : .description
                        return direction
                    }
                }
            }
    }
}

#Preview {
    ChapterDescriptionView(video: Video.getDummy(), page: .constant(.chapters))
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(RefreshManager())
        .environment(SubscribeManager())
        .environment(ImageCacheManager())
        .environment(SheetPositionReader())
}
