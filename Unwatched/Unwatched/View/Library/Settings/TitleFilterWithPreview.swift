//
//  TitleFilterView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct TitleFilterView: View {
    @CloudStorage(Const.filterVideoTitleText) var filterVideoTitleText: String = ""

    var body: some View {
        MySection(footer: "videoTitleFilterFooter") {
            TextField("keywords", text: $filterVideoTitleText)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
            #endif
        }
    }
}

struct TitleFilterWithPreview: View {
    @CloudStorage(Const.filterVideoTitleText) var filterVideoTitleText: String = ""
    @State var videoListVM = VideoListVM(initialBatchSize: 500)
    @State private var task: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            List {
                VStack {
                    TextField("keywords", text: $filterVideoTitleText)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                    #endif

                    Text("videoTitleFilterFooter")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
                .padding(10)
                .background(Color.insetBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .listRowBackground(Color.backgroundColor)
                .listRowSeparator(.hidden)
                .padding(.bottom, 15)

                VideoListViewAsync(videoListVM: $videoListVM)

                if !videoListVM.isLoading && !filterStrings.isEmpty {
                    HiddenEntriesInfo("hiddenEntriesManualFilter \(videoListVM.initialBatchSize)")
                }

                AsyncPlaceholderWorkaround(videoListVM: $videoListVM)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .myNavigationTitle("videoTitleFilter")
        }
        .task {
            updateFilterStrings()
            let sorting = [SortDescriptor<Video>(\.publishedDate, order: .reverse)]
            videoListVM.setSorting(sorting)
            await videoListVM.updateData()
        }
        .onChange(of: filterVideoTitleText) { _, _ in
            task?.cancel()
            task = Task {
                do {
                    try await Task.sleep(for: .milliseconds(800))
                    updateFilterStrings()
                    await videoListVM.updateData(force: true)
                } catch { }
            }
        }
    }

    func updateFilterStrings() {
        let filterStrings = filterStrings
        videoListVM.manualFilter = { video in
            filterStrings.contains(where: { filter in
                video.title.localizedStandardContains(filter)
            })
        }
    }

    var filterStrings: [String] {
        VideoService.getVideoTitleFilter(filterVideoTitleText)
    }
}

#Preview {
    TitleFilterWithPreview()
        .modelContainer(DataProvider.previewContainerFilled)
        .environment(NavigationManager.getDummy(false))
        .environment(PlayerManager.getDummy())
        .environment(ImageCacheManager())
}
