//
//  VideoCrawlerTests.swift
//  Unwatched
//

import XCTest

class VideoCrawlerTests: XCTestCase {

    func testParsingVideos() {
        let rssFeedData = VideoCrawlerTestData.rssFeedContent.data(using: .utf8)!
        let delegate = VideoCrawler.parseFeedData(data: rssFeedData, limitVideos: nil)

        // video count
        let videos = delegate.videos
        XCTAssertEqual(videos.count, 2)

        // date parsing
        let firstVideo = videos[0]
        let dateFormatter = ISO8601DateFormatter()
        let publishedDate = dateFormatter.date(from: "2024-08-01T17:00:36+00:00")
        let updatedDate = dateFormatter.date(from: "2024-08-01T17:16:10+00:00")
        XCTAssertEqual(firstVideo.publishedDate, publishedDate)
        XCTAssertEqual(firstVideo.updatedDate, updatedDate)

    }
}

// swiftlint:disable all
struct VideoCrawlerTestData {
    static let rssFeedContent = """
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns:media="http://search.yahoo.com/mrss/" xmlns="http://www.w3.org/2005/Atom">
 <link rel="self" href="http://www.youtube.com/feeds/videos.xml?channel_id=UCnrAvt4i_2WV3yEKWyEUMlg"/>
 <id>yt:channel:nrAvt4i_2WV3yEKWyEUMlg</id>
 <yt:channelId>nrAvt4i_2WV3yEKWyEUMlg</yt:channelId>
 <title>Gamertag VR</title>
 <link rel="alternate" href="https://www.youtube.com/channel/UCnrAvt4i_2WV3yEKWyEUMlg"/>
 <author>
  <name>Gamertag VR</name>
  <uri>https://www.youtube.com/channel/UCnrAvt4i_2WV3yEKWyEUMlg</uri>
 </author>
 <published>2013-07-01T19:18:30+00:00</published>
 <entry>
  <id>yt:video:XBluFg9mSWQ</id>
  <yt:videoId>XBluFg9mSWQ</yt:videoId>
  <yt:channelId>UCnrAvt4i_2WV3yEKWyEUMlg</yt:channelId>
  <title>ZERO CALIBER 2 Review // The New Best VR FPS? (Meta Quest 3 Gameplay)</title>
  <link rel="alternate" href="https://www.youtube.com/watch?v=XBluFg9mSWQ"/>
  <author>
   <name>Gamertag VR</name>
   <uri>https://www.youtube.com/channel/UCnrAvt4i_2WV3yEKWyEUMlg</uri>
  </author>
  <published>2024-08-01T17:00:36+00:00</published>
  <updated>2024-08-01T17:16:10+00:00</updated>
  <media:group>
   <media:title>ZERO CALIBER 2 Review // The New Best VR FPS? (Meta Quest 3 Gameplay)</media:title>
   <media:content url="https://www.youtube.com/v/XBluFg9mSWQ?version=3" type="application/x-shockwave-flash" width="640" height="390"/>
   <media:thumbnail url="https://i1.ytimg.com/vi/XBluFg9mSWQ/hqdefault.jpg" width="480" height="360"/>
   <media:description>ZERO CALIBER 2 Review - The New Best VR FPS? (Meta Quest 3 Gameplay) Zero Caliber 2 is now released on Meta Quest 2 and Meta Quest 3 and with a flood vr first person shooters available, some of which are very good, where does Zero Caliber 2 fit in the grand scheme of it all?

Join the GT Champions today for exclusive benefits👇
⭐️ VIP Discord lounge
⭐️ Stand out from the crowd with a GT badge
⭐️ Exclusive chat emojis
GT Champion sign up 👉:https://www.youtube.com/channel/UCnrAvt4i_2WV3yEKWyEUMlg/join

Support the channel by drinking GFuel Energy and using my code 'GTVR' to save 20% on all your purchases at checkout👉 https://gfuel.com

VR Gaming,Virtual Reality Gaming,VR Games,Virtual Reality Games,Meta Quest,Meta Quest 2,Oculus Rift,Oculus Quest,HTC Vive,PlayStation VR,PlayStation VR 2,PSVR 2,Valve Index,VR Action Games,VR Adventure Games,VR Puzzle Games,VR Horror Games,VR Simulation Games,Immersive VR Full-Body VR,VR Presence,VR Immersion,VR Multiplayer Games,Virtual Reality Co-op,VR PvP Games,Beat Saber,Half-Life: Alyx,Superhot VR,The Walking Dead Saints &amp; Sinners,VRChat,VR Graphics,VR Performance,VR Motion Sickness,VR Hardware,VR 360,Best VR Games,Top VR Games,Top VR Experiences,VR Game Reviews,VR Controllers,VR Headsets,VR Accessories,Upcoming VR Games,VR Game Releases,VR Gameplay Tips,VR Controls Guide,VR Setup,VR Gaming Community,VR Gaming,VR tuber,New Games,Gaming,Gamertag VR, VR mods, PCVR, Steam VR, VR Jumpscares,

#explorewithquest #metaquest3 #metaquest2</media:description>
   <media:community>
    <media:starRating count="224" average="5.00" min="1" max="5"/>
    <media:statistics views="5869"/>
   </media:community>
  </media:group>
 </entry>
 <entry>
  <id>yt:video:DtNjqAm0TkI</id>
  <yt:videoId>DtNjqAm0TkI</yt:videoId>
  <yt:channelId>UCnrAvt4i_2WV3yEKWyEUMlg</yt:channelId>
  <title>So Much Is Happening In VR Right Now! New Headsets, Games &amp; News 2024</title>
  <link rel="alternate" href="https://www.youtube.com/watch?v=DtNjqAm0TkI"/>
  <author>
   <name>Gamertag VR</name>
   <uri>https://www.youtube.com/channel/UCnrAvt4i_2WV3yEKWyEUMlg</uri>
  </author>
  <published>2024-07-13T15:30:30+00:00</published>
  <updated>2024-07-16T04:05:45+00:00</updated>
  <media:group>
   <media:title>So Much Is Happening In VR Right Now! New Headsets, Games &amp; News 2024</media:title>
   <media:content url="https://www.youtube.com/v/DtNjqAm0TkI?version=3" type="application/x-shockwave-flash" width="640" height="390"/>
   <media:thumbnail url="https://i1.ytimg.com/vi/DtNjqAm0TkI/hqdefault.jpg" width="480" height="360"/>
   <media:description>So Much Is Happening In VR Right Now! New Headsets, Games &amp; News 2024. A quick VR News video going over all the vr news going on right now for all vr headsets. A brand new vr game shsowcase is coming Join the GT Champions today for exclusive benefits👇
⭐️ VIP Discord lounge
⭐️ Stand out from the crowd with a GT badge
⭐️ Exclusive chat emojis
GT Champion sign up 👉:https://www.youtube.com/channel/UCnrAvt4i_2WV3yEKWyEUMlg/join

Support the channel by drinking GFuel Energy and using my code 'GTVR' to save 20% on all your purchases at checkout👉 https://gfuel.com

VR Gaming,Virtual Reality Gaming,VR Games,Virtual Reality Games,Meta Quest,Meta Quest 2,Oculus Rift,Oculus Quest,HTC Vive,PlayStation VR,PlayStation VR 2,PSVR 2,Valve Index,VR Action Games,VR Adventure Games,VR Puzzle Games,VR Horror Games,VR Simulation Games,Immersive VR Full-Body VR,VR Presence,VR Immersion,VR Multiplayer Games,Virtual Reality Co-op,VR PvP Games,Beat Saber,Half-Life: Alyx,Superhot VR,The Walking Dead Saints &amp; Sinners,VRChat,VR Graphics,VR Performance,VR Motion Sickness,VR Hardware,VR 360,Best VR Games,Top VR Games,Top VR Experiences,VR Game Reviews,VR Controllers,VR Headsets,VR Accessories,Upcoming VR Games,VR Game Releases,VR Gameplay Tips,VR Controls Guide,VR Setup,VR Gaming Community,VR Gaming,VR tuber,New Games,Gaming,Gamertag VR, VR mods, PCVR, Steam VR, VR Jumpscares,

#explorewithquest #psvr2 #virtualreality</media:description>
   <media:community>
    <media:starRating count="575" average="5.00" min="1" max="5"/>
    <media:statistics views="9737"/>
   </media:community>
  </media:group>
 </entry>
</feed>
"""

}
// swiftlint:enable all
