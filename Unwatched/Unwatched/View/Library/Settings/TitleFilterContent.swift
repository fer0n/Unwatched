//
//  TitleFilterContent.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TitleFilterContent: View {
    @Binding var filterText: String
    @Binding var videoListVM: VideoListVM

    var filter: Predicate<Video>?

    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack {
            TextField("keywords", text: $filterText)
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
        .task {
            updateFilterStrings()
            let sorting = [SortDescriptor<Video>(\.publishedDate, order: .reverse)]
            videoListVM.setSorting(sorting)
            videoListVM.filter = filter
            await videoListVM.updateData()
        }
        .onChange(of: filterText) { _, _ in
            task?.cancel()
            task = Task {
                do {
                    try await Task.sleep(for: .milliseconds(800))
                    updateFilterStrings()
                    await videoListVM.updateData(force: true)
                } catch { }
            }
        }

        VideoListViewAsync(videoListVM: $videoListVM)

        if !videoListVM.isLoading && !filterStrings.isEmpty {
            HiddenEntriesInfo("hiddenEntriesManualFilter \(videoListVM.initialBatchSize)")
        }

        AsyncPlaceholderWorkaround(videoListVM: $videoListVM)
            .listRowSeparator(.hidden)

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
        VideoService.getVideoTitleFilter(filterText)
    }
}
