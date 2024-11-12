//
//  ChapterSelection.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

enum ChapterDescriptionPage {
    case description
    case chapters
}

struct ChapterDescriptionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(PlayerManager.self) var player

    let video: Video
    @Binding var page: ChapterDescriptionPage

    var body: some View {
        NavigationStack {
            let hasChapters = video.sortedChapters.isEmpty == false
            let hasDescription = video.videoDescription != nil

            ZStack {
                Color.backgroundColor.ignoresSafeArea(.all)

                ScrollViewReader { proxy in
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
                    .horizontalDragGesture(video: video, page: $page)
                    .onAppear {
                        if page == .chapters && hasChapters,
                           player.video == video {
                            proxy.scrollTo(player.currentChapter?.persistentModelID, anchor: .center)
                        }
                    }
                }
            }
            .horizontalDragGesture(video: video, page: $page)
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
                DismissToolbarButton()
            }
            .tint(.neutralAccentColor)
            .myNavigationTitle(showBack: false)
        }
    }
}

extension View {
    func horizontalDragGesture(
        video: Video,
        page: Binding<ChapterDescriptionPage>
    ) -> some View {
        self.modifier(HorizontalDragGestureModifier(video: video, page: page))
    }
}

struct HorizontalDragGestureModifier: ViewModifier {
    @State var selectedDetailPageTask: Task<ChapterDescriptionPage, Never>?
    @GestureState private var dragState: CGFloat = 0
    @State private var gestureCancelled = false

    let video: Video
    @Binding var page: ChapterDescriptionPage

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(dragGesture(origin: page))
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
                if gestureCancelled {
                    return
                }
                // Check if the drag is primarily horizontal
                let translation = value.translation
                if abs(translation.height) > abs(translation.width) {
                    gestureCancelled = true
                    return // Ignore the gesture if it's more vertical than horizontal
                }

                let hasChapters = !video.sortedChapters.isEmpty
                let hasDescription = video.videoDescription != nil
                if origin == .chapters && !hasDescription || origin == .description && !hasChapters {
                    return
                }

                state = translation.width
                if (origin == .chapters && state > 30) || (origin == .description && state < -30) {
                    selectedDetailPageTask = Task.detached {
                        let direction: ChapterDescriptionPage = origin == .description ? .chapters : .description
                        return direction
                    }
                }
            }
            .onEnded { _ in
                gestureCancelled = false
            }
    }
}

#Preview {
    ChapterDescriptionView(video: Video.getDummy(), page: .constant(.chapters))
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager())
        .environment(RefreshManager())
        .environment(SubscribeManager())
        .environment(ImageCacheManager())
        .environment(SheetPositionReader())
}
