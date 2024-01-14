//
//  SettingsView.swift
//  Unwatched
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) var modelContext
    @AppStorage("defaultEpisodePlacement") var defaultEpisodePlacement: VideoPlacement = .inbox
    @AppStorage("playVideoFullscreen") var playVideoFullscreen: Bool = false
    @AppStorage("autoplayVideos") var autoplayVideos: Bool = true
    @State private var showingDeleteEverythingAlert = false

    let writeReviewUrl = URL(string: "https://apps.apple.com/app/id6444704240?action=write-review")!
    let emailUrl = URL(string: "mailto:scores.templates@gmail.com")!
    let githubUrl = URL(string: "https://github.com/fer0n/SplitBill")!
    // TODO: fix links

    func deleteEverything() {
        VideoService.deleteEverything(modelContext)
    }

    var body: some View {
        VStack {
            List {
                Section {
                    Picker("New Episodes", selection: $defaultEpisodePlacement) {
                        ForEach(VideoPlacement.allCases.filter { $0 != .defaultPlacement }, id: \.self) {
                            Text($0.description(defaultPlacement: ""))
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Toggle(isOn: $playVideoFullscreen) {
                        Text("Start videos in fullscreen")
                    }
                    Toggle(isOn: $autoplayVideos) {
                        Text("Autoplay videos")
                    }
                }
                .tint(.teal)

                Section {
                    LinkItemView(destination: writeReviewUrl, label: "rateApp") {
                        Image(systemName: "star.fill")
                    }

                    LinkItemView(destination: emailUrl, label: "contact") {
                        Image(systemName: "envelope.fill")
                    }

                    LinkItemView(destination: githubUrl, label: "github") {
                        Image("github-logo")
                            .resizable()
                    }
                }

                Button("Delete Everything", role: .destructive) {
                    showingDeleteEverythingAlert = true
                }
            }
        }
        .toolbarBackground(Color.backgroundColor, for: .navigationBar)
        .navigationBarTitle("Settings", displayMode: .inline)
        .tint(.myAccentColor)
        .alert("Really Delete Everything?", isPresented: $showingDeleteEverythingAlert, actions: {
            Button("Clear All", role: .destructive) {
                deleteEverything()
            }
            Button("Cancel", role: .cancel) {}
        }, message: {
            Text("Are you sure you want to delete all data? This cannot be undone.")
        })
    }
}

enum PreviewDuration: Int, CaseIterable {
    case short
    case medium
    case long
    case tapAway

    var description: String {
        switch self {
        case .short: return String(localized: "short")
        case .medium: return String(localized: "medium")
        case .long: return String(localized: "long")
        case .tapAway: return String(localized: "tapAway")
        }
    }

    var timeInterval: TimeInterval? {
        switch self {
        case .short: return 0.5
        case .medium: return 2.5
        case .long: return 5
        case .tapAway: return nil
        }
    }
}

struct LinkItemView<Content: View>: View {
    let destination: URL
    let label: String
    let content: () -> Content

    var body: some View {
        Link(destination: destination) {
            HStack(spacing: 20) {
                content()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.myAccentColor)
                Text(LocalizedStringKey(label))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.myAccentColor)
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
}
