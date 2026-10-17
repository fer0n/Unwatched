//
//  SearchRecommendationsTip.swift
//  Unwatched
//

import TipKit
import UnwatchedShared

struct SearchRecommendationsTip: Tip {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    static let enableActionId = "enable"

    var title: Text {
        Text("searchRecommendationsTip")
    }

    var message: Text? {
        Text("searchRecommendationsTipMessage")
    }

    var image: Image? {
        Image(systemName: "sparkles")
    }

    // the first action is the prominent one
    var actions: [Action] {
        Action {
            Text("searchRecommendationsTipNo")
                .foregroundStyle(theme.contrastColor)
        }
        // macOS ignores the tint here
        Action(id: Self.enableActionId) {
            Text("searchRecommendationsTipYes")
                .foregroundStyle(theme.color)
        }
    }
}

struct SearchRecommendationsTipView: View {
    @AppStorage(Const.showSearchRecommendations) var showRecommendations: Bool = false
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    let onEnable: () -> Void

    private let tip = SearchRecommendationsTip()

    var body: some View {
        TipView(tip) { action in
            if action.id == SearchRecommendationsTip.enableActionId {
                showRecommendations = true
                onEnable()
            }
            tip.invalidate(reason: .actionPerformed)
        }
        .listRowSeparator(.hidden)
        #if os(macOS)
        .tipBackground(Color.insetBackgroundColor)
        .listRowBackground(Color.clear)
        .tint(theme.color.mix(with: .black, by: 0.2))
        #else
        .listRowTip()
        .tint(theme.color)
        #endif
    }
}

#Preview {
    List {
        SearchRecommendationsTipView {}
    }
    .task {
        try? Tips.resetDatastore()
        try? Tips.configure([.displayFrequency(.immediate)])
    }
}
