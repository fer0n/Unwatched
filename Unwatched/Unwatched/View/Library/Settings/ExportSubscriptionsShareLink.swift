//
//  ExportSubscriptionsShareLink.swift
//  Unwatched
//

import SwiftUI

extension SubscriptionExportKind {
    var title: LocalizedStringKey {
        switch self {
        case .all: "exportSubscriptionsAll"
        case .youtube: "exportSubscriptionsYoutube"
        case .podcasts: "podcasts"
        }
    }
}

struct ExportSubscriptionsShareLink<Content: View>: View {
    var showsMenuTitle = true
    let content: () -> Content

    @State var isExporting = false
    @State var showEmptyAlert = false
    #if os(iOS) || os(visionOS)
    @State var shareURL: IdentifiableURL?
    #endif

    var body: some View {
        Menu {
            MenuSection(showsMenuTitle ? "exportSubscriptions" : nil) {
                ForEach(SubscriptionExportKind.allCases, id: \.self) { kind in
                    Button(kind.title) {
                        startExport(kind)
                    }
                }
            }
        } label: {
            #if os(macOS)
            content()
            #else
            if isExporting {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                content()
            }
            #endif
        }
        .disabled(isExporting)
        .alert("noSubscriptionsToExport", isPresented: $showEmptyAlert) {
            Button("ok", role: .cancel) {}
        }
        #if os(iOS) || os(visionOS)
        .sheet(item: $shareURL) { identifiable in
            ActivityView(url: identifiable.url)
                .ignoresSafeArea()
        }
        #endif
    }

    func startExport(_ kind: SubscriptionExportKind) {
        Task {
            await MainActor.run { isExporting = true }
            let urls = (try? await SubscriptionService.getAllFeedUrls(kind)) ?? []
            guard !urls.isEmpty else {
                await MainActor.run { isExporting = false; showEmptyAlert = true }
                return
            }
            let fileName = kind.fileName
            let task = Task.detached(priority: .userInitiated) {
                try generateOPMLFile(from: urls, fileName: fileName)
            }
            if let fileURL = try? await task.value {
                await MainActor.run { presentShare(url: fileURL) }
            }
            await MainActor.run { isExporting = false }
        }
    }

    @MainActor
    func presentShare(url: URL) {
        #if os(iOS) || os(visionOS)
        shareURL = IdentifiableURL(url: url)
        #elseif os(macOS)
        let picker = NSSharingServicePicker(items: [url])
        let view = NSApp.keyWindow?.contentView ?? NSApp.mainWindow?.contentView
        if let view {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
        #endif
    }
}

private func generateOPMLFile(from urls: [(title: String, link: URL?)], fileName: String) throws -> URL {
    let outlines = urls
        .compactMap { sub -> String? in
            guard let xmlUrl = sub.link?.absoluteString else { return nil }
            let title = sub.title
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "\"", with: "&quot;")
            return "    <outline text=\"\(title)\" title=\"\(title)\" type=\"rss\" xmlUrl=\"\(xmlUrl)\"/>"
        }
        .joined(separator: "\n")
    let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.1">
          <head><title>Subscriptions</title></head>
          <body>
        \(outlines)
          </body>
        </opml>
        """
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    try opml.write(to: url, atomically: true, encoding: .utf8)
    return url
}
