//
//  SearchLinkRow.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SearchLinkRow: View {
    @Environment(NavigationManager.self) var navManager

    let vm: SearchVM
    let link: String
    var onTap: () -> Void = {}

    var body: some View {
        let lookup = vm.linkLookup?.link == link ? vm.linkLookup : nil
        let kind = SearchVM.LinkKind(link)

        Button {
            onTap()
            vm.openLinkIfPresent(in: link, navManager)
        } label: {
            HStack(spacing: 12) {
                Group {
                    if lookup?.isLoading == true {
                        ProgressView()
                    } else {
                        Image(systemName: kind.systemImage)
                            .font(.title3)
                    }
                }
                .foregroundStyle(.secondary)
                .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.headline)
                    Text(verbatim: link)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let error = lookup?.error {
                        Text(verbatim: error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(lookup?.isLoading == true)
    }
}

extension SearchVM.LinkKind {
    var title: LocalizedStringKey {
        switch self {
        case .video: "mediaTypeVideo"
        case .channel: "channel"
        case .playlist: "playlist"
        case .podcast: "mediaTypePodcast"
        case .other: "linkKindOther"
        }
    }

    var systemImage: String {
        switch self {
        case .video: "play.rectangle"
        case .channel: "person.crop.circle"
        case .playlist: "list.bullet"
        case .podcast: "antenna.radiowaves.left.and.right"
        case .other: "link"
        }
    }
}
