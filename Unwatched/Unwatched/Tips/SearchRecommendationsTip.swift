//
//  SearchRecommendationsTip.swift
//  Unwatched
//

import TipKit
import UnwatchedShared

struct SearchRecommendationsTip: Tip {
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
        }
        Action(id: Self.enableActionId) {
            Text("searchRecommendationsTipYes")
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
        .tipBackground(Color.insetBackgroundColor)
        .listRowBackground(Color.backgroundColor)
        .tint(theme.color)
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
