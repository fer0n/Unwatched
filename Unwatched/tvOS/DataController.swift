//
//  DataController.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared

// swiftlint:disable all
extension DataController {
    public static let previewContainerFilled: ModelContainer = {
        var container = previewContainer
        let context = container.mainContext
        fillWithTestData(context)
        return container
    }()

    static func fillWithTestData(_ context: ModelContext) {
        let vid1 = Video(
            title: "MudRunner VR Review on Meta Quest 3: Where We're Going, We Don't Need Roads…",
            url: URL(string: "https://www.youtube.com/watch?v=lVvYJzKR9T8"),
            youtubeId: "lVvYJzKR9T8",
            thumbnailUrl: URL(string: "https://i1.ytimg.com/vi/lVvYJzKR9T8/hqdefault.jpg")
        )
        let vid2 = Video(
            title: "The Ocean Cleanup’s System 03 Captures Record Amounts of Plastic From the Pacific",
            url: URL(string: "https://www.youtube.com/watch?v=P8drUT_cZy8"),
            youtubeId: "P8drUT_cZy8",
            thumbnailUrl: URL(string: "https://i1.ytimg.com/vi/P8drUT_cZy8/hqdefault.jpg")
        )
        let vid3 = Video(
            title: "What Game Theory Reveals About Life, The Universe, and Everything",
            url: URL(string: "https://www.youtube.com/watch?v=mScpHTIi-kM"),
            youtubeId: "mScpHTIi-kM",
            thumbnailUrl: URL(string: "https://i2.ytimg.com/vi/mScpHTIi-kM/hqdefault.jpg")
        )
        let vid4 = Video(
            title: "Apple Vision Pro First Impressions From A VR Enthusiasts Perspective!",
            url: URL(string: "https://www.youtube.com/watch?v=Kda_2dM9bb0"),
            youtubeId: "Kda_2dM9bb0",
            thumbnailUrl: URL(string: "https://i4.ytimg.com/vi/Kda_2dM9bb0/hqdefault.jpg")
        )
        let vid5 = Video(
            title: "The future of game development... has no game engine?",
            url: URL(string: "https://www.youtube.com/watch?v=SBdDt4BUIW0"),
            youtubeId: "SBdDt4BUIW0",
            thumbnailUrl: URL(string: "https://i4.ytimg.com/vi/SBdDt4BUIW0/hqdefault.jpg")
        )
        let vid6 = Video(
            title: "Paying for software is stupid… 10 free and open-source SaaS replacements",
            url: URL(string: "https://www.youtube.com/watch?v=e5dhaQm_J6U"),
            youtubeId: "e5dhaQm_J6U",
            thumbnailUrl: URL(string: "https://i2.ytimg.com/vi/e5dhaQm_J6U/hqdefault.jpg")
        )
        let vid7 = Video(
            title: "Level up your SwiftUI – Easy improvements you can apply to any SwiftUI app",
            url: URL(string: "https://m.youtube.com/watch?v=l7eut-nYIUc"),
            youtubeId: "l7eut-nYIUc",
            thumbnailUrl: URL(string: "https://i.ytimg.com/vi/l7eut-nYIUc/mqdefault.jpg")
        )
        let vid8 = Video(
            title: "Orion Drift: The Greatest Driftball Match in IAA History",
            url: URL(string: "https://www.youtube.com/watch?v=0KHG86FmQ7g"),
            youtubeId: "0KHG86FmQ7g",
            thumbnailUrl: URL(string: "https://i1.ytimg.com/vi/0KHG86FmQ7g/hqdefault.jpg")
        )
        let vid9 = Video(
            title: "The Most In Disguise EV...",
            url: URL(string: "https://www.youtube.com/watch?v=q6BNg_kZ6Jc"),
            youtubeId: "q6BNg_kZ6Jc",
            thumbnailUrl: URL(string: "https://i2.ytimg.com/vi/q6BNg_kZ6Jc/hqdefault.jpg")
        )
        let vid10 = Video(
            title: "AirPods 4 Review: Which Ones To Get?",
            url: URL(string: "https://www.youtube.com/watch?v=WwjHonzRd4E"),
            youtubeId: "WwjHonzRd4E",
            thumbnailUrl: URL(string: "https://i4.ytimg.com/vi/WwjHonzRd4E/hqdefault.jpg")
        )
        let vid11 = Video(
            title: "2 Fancy 2 Furious: Wine",
            url: URL(string: "https://www.youtube.com/watch?v=y8cECtBdS8Q"),
            youtubeId: "y8cECtBdS8Q",
            thumbnailUrl: URL(string: "https://i2.ytimg.com/vi/y8cECtBdS8Q/hqdefault.jpg")
        )
        let vid12 = Video(
            title: "SwiftUI Performance for Demanding Apps by Aviel Gross - SwiftLeeds 2023",
            url: URL(string: "https://www.youtube.com/watch?v=WDRrsEAXvrE"),
            youtubeId: "WDRrsEAXvrE",
            thumbnailUrl: URL(string: "https://i.ytimg.com/vi/WDRrsEAXvrE/mqdefault.jpg")
        )

        let vid13 = Video(
            title: "iPhone 16/16 Pro Unboxing: End of an Era!",
            url: URL(string: "https://www.youtube.com/watch?v=h3BKjZMGoIw"),
            youtubeId: "h3BKjZMGoIw",
            thumbnailUrl: URL(string: "https://i1.ytimg.com/vi/h3BKjZMGoIw/hqdefault.jpg")
        )

        let vid14 = Video(
            title: "How screens actually affect your sleep",
            url: URL(string: "https://www.youtube.com/watch?v=isPxdnIND5k"),
            youtubeId: "isPxdnIND5k",
            thumbnailUrl: URL(string: "https://i2.ytimg.com/vi/isPxdnIND5k/hqdefault.jpg")
        )

        let vid15 = Video(
            title: "Is Water Bulletproof?",
            url: URL(string: "https://www.youtube.com/watch?v=Cm1Wkfkw4Bs"),
            youtubeId: "Cm1Wkfkw4Bs",
            thumbnailUrl: URL(string: "https://i.ytimg.com/vi/Cm1Wkfkw4Bs/mqdefault.jpg")
        )

        let vid16 = Video(
            title: "Orion Drift: Developer Snapshot 1",
            url: URL(string: "https://www.youtube.com/channel/UC-I4Tk3RHe2bFJr2aAWBp4w"),
            youtubeId: "8xjnw_skc9g",
            thumbnailUrl: URL(string: "https://i1.ytimg.com/vi/8xjnw_skc9g/hqdefault.jpg")
        )

        let vid17 = Video(
            title: "Food Delivery Apps: Last Week Tonight with John Oliver (HBO)",
            url: URL(string: "https://www.youtube.com/watch?v=aFsfJYWpqII"),
            youtubeId: "aFsfJYWpqII",
            thumbnailUrl: URL(string: "https://i2.ytimg.com/vi/aFsfJYWpqII/hqdefault.jpg")
        )

        let vid18 = Video(
            title: "Alles über ETFs in nur 15 Minuten: Index, Sparplan, Steuern",
            url: URL(string: "https://www.youtube.com/watch?v=r80NOOdFIn8"),
            youtubeId: "r80NOOdFIn8",
            thumbnailUrl: URL(string: "https://i.ytimg.com/vi/r80NOOdFIn8/mqdefault.jpg")
        )

        let vid19 = Video(
            title: "Apple Vision Pro is Missing Something...",
            url: URL(string: "https://www.youtube.com/watch?v=hOi8s2wkX4A"),
            youtubeId: "hOi8s2wkX4A",
            thumbnailUrl: URL(string: "https://i1.ytimg.com/vi/hOi8s2wkX4A/hqdefault.jpg")
        )

        let vid20 = Video(
            title: "HOW to MTB SUSPENSION FORK SERVICE | Btwin BIKE COIL shock #fork  #repair",
            url: URL(string: "https://www.youtube.com/watch?v=7rehAICrtvo"),
            youtubeId: "7rehAICrtvo",
            thumbnailUrl: URL(string: "https://i.ytimg.com/vi/7rehAICrtvo/mqdefault.jpg")
        )

        let vid21 = Video(
            title: "Waschmaschine pumpt nicht ab - Hauptgründe und Lösungen",
            url: URL(string: "https://www.youtube.com/watch?v=Ggz7IHpA7kQ"),
            youtubeId: "Ggz7IHpA7kQ",
            thumbnailUrl: URL(string: "https://i.ytimg.com/vi/Ggz7IHpA7kQ/mqdefault.jpg")
        )

        let vid22 = Video(
            title: "Coronavirus VII: Sports: Last Week Tonight with John Oliver (HBO)",
            url: URL(string: "https://www.youtube.com/watch?v=z4gBMw64aqk"),
            youtubeId: "z4gBMw64aqk",
            thumbnailUrl: URL(string: "https://i.ytimg.com/vi/z4gBMw64aqk/mqdefault.jpg")
        )

        let vid23 = Video(
            title: "WWDC24: A Swift Tour: Explore Swift’s features and design | Apple",
            url: URL(string: "https://www.youtube.com/watch?v=boiLzazJ9j4"),
            youtubeId: "boiLzazJ9j4",
            thumbnailUrl: URL(string: "https://i.ytimg.com/vi/boiLzazJ9j4/mqdefault.jpg")
        )

        let vid24 = Video(
            title: "Most Popular Instant Messengers: Data from 1998 to 2024",
            url: URL(string: "https://www.youtube.com/watch?v=kw9atgKVs7w"),
            youtubeId: "kw9atgKVs7w",
            thumbnailUrl: URL(string: "https://i4.ytimg.com/vi/kw9atgKVs7w/hqdefault.jpg")
        )

        let videos = [
            vid1,
            vid2,
            vid3,
            vid4,
            vid5,
            vid6,
            vid7,
            vid8,
            vid9,
            vid10,
            vid11,
            vid12,
            vid13,
            vid14,
            vid15,
            vid16,
            vid17,
            vid18,
            vid19,
            vid20,
            vid21,
            vid22,
            vid23,
            vid24
        ]

        // let queueEntry = QueueEntry(video: nil, order: 0)
        // context.insert(queueEntry)

        for (index, video) in videos.enumerated() {
            context.insert(video)
            let queueEntry = QueueEntry(video: video, order: index)
            context.insert(queueEntry)
        }

        try? context.save()
    }
}
// swiftlint:enable all
