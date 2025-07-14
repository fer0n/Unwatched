//
//  GenerationService.swift
//  Unwatched
//

import FoundationModels
import UnwatchedShared
import Playgrounds

// swiftlint:disable all
struct GenerationService {
    public static func extractChaptersFromTranscripts(
        _ videoTitle: String,
        _ transcript: [TranscriptEntry]
    ) async throws -> [SendableChapter]? {
        let transcriptRepresentation = transcript.map(\.minimalTextRepresentation).joined(separator: "\n")
        // TODO: split it up into managable chunks if the transcript is too long

        let instructions = """
        Break the transcript into a few broad, well-sized sections (based on the timestamps in seconds). Each section should reflect a natural break or shift in topic, pacing, or structure. Use short, general-purpose titles like “Intro,” “Hands-On Impressions,” “Gameplay,” “Final Thoughts,” or similar — not detailed summaries. Avoid combining unrelated topics or making the chapters too short.
        """
        let session = LanguageModelSession(instructions: instructions)

        let prompt = """
            # Video title
            '\(videoTitle)'

            # Transcript
            \(transcriptRepresentation)
            """
        print("prompt", prompt)
        let response = try await session.respond(to: prompt, generating: ChapterGeneration.self)
        var sendable = response.content.chapters.map { $0.toSendableChapter }
        if !sendable.isEmpty {
            // first chapter should always start at 0
            sendable[0].startTime = 0
        }
        return sendable
    }
}


#Playground {
    let instructions = """
    Break the transcript into a few broad, well-sized sections (based on the timestamps in seconds). Each section should reflect a natural break or shift in topic, pacing, or structure. Use short, general-purpose titles like “Intro,” “Hands-On Impressions,” “Gameplay,” “Final Thoughts,” or similar — not detailed summaries. Avoid combining unrelated topics or making the chapters too short.
    """


    //    let instructions = """
    //
    //    """

    let session = LanguageModelSession(instructions: instructions)

    let response = try await session.respond(to: prompt, generating: ChapterGeneration.self)

    print(response.content.chapters)

    for entry in response.content.chapters {
        print(entry)
    }
}

let prompt = """
# Video title
'This Might Be The Best VR Pirate Game EVER! The Pirate: Republic of Nassau Meta Quest 3'

# Transcript
0.08: After yesterday's best of 2025 VR games
3.12: video, I wanted to take a day off. But
4.88: then I discovered a game called The
6.24: Pirate Republic of NASU on Quest thanks
8.80: to our community Discord. And since this
10.80: game is being made by Home Games, the
12.88: developers of the Warplane series, which
15.04: is a very awesome series, by the way, if
17.04: you've never heard of it, I felt
18.40: obligated to check this one out. And
20.16: even though it's early access and very
22.16: confusing to play at first, after about
24.16: 45 minutes, I was absolutely hooked. And
26.88: I've been playing all day. Over the
28.88: years in VR, we've had a few pirate ship
30.64: style games, and they mostly focus on
32.80: sea battles, which is obviously what
34.72: everyone wants, but this game also has a
37.44: lot more going on. And once you learn
39.20: the controls and the recipe of how to
41.12: become a successful pirate, altogether
43.52: makes this game actually pretty awesome.
45.76: Firstly, I want to talk about the
47.36: presentation, which is both really good
49.28: and a little bit average. The ships,
51.36: that's right, I said ships, because you
53.04: eventually will control a fleet. The
54.64: crew, your cabin, and your environment
56.48: look nice, and the water effects are
58.40: decent. Actually, it looks shockingly
60.96: nice, if I'm completely honest. When it
62.72: comes to the islands themselves, they
64.48: look a bit N64ish, but still pretty
66.88: detailed, and there's an odd frame skip
69.20: every now and again for reasons I don't
70.80: yet understand. The music somehow never
73.12: gets on your nerves, even though it's
74.64: always there, and is actually pretty
76.56: good.
86.80: Who has no
90.48: captain rescuing two sailors?
92.56: So, as far as graphics go, it's not
94.56: going to make people swoon or be
96.32: something you want to show off, but it's
98.48: definitely good enough for you to enjoy
100.16: and be immersed. As you sail the seas,
102.40: you'll find the odd spots where you can
104.16: actually go diving looking for treasure.
106.16: And you'll be welcomed by tons of exotic
108.88: fish where you can extract pearls from
111.04: oysters. You'll also find shipwrecks to
113.36: explore and look for gold coins.
116.22: [Music]
122.40: There's an absolutely colossal map to
124.88: explore and it seems completely empty
127.12: when you start the game. But by visiting
129.36: taverns and paying for info, the map
131.52: very soon starts to get filled up with
133.60: locations with new towns and within
136.00: those towns, merchants to visit where
137.92: you can buy and sell items. And you can
140.08: also make deals with other pirates. And
142.40: all of this is combined with your drive
144.16: to become the ultimate feared pirate of
146.32: the seven seas. The game's name, Nazaru,
149.04: at least I think that's how it's
150.16: pronounced, is your main hub town where
152.24: you'll be investing all your riches to
154.16: make it into an awesome place where you
156.00: can also make your money. You'll first
158.00: build somewhere to store your goods
159.52: because your ships have a weightbearing
161.36: limit. So, after getting into the game
163.12: and getting past lots of text boxes,
165.44: you'll be off on your first sea battle.
167.44: And these sea battles are incredibly
169.52: satisfying. Once you get your enemy's
171.44: health down to a certain percent, which
172.96: I think was 50 or a bit less, they'll
174.88: hoist the white flag and admit defeat.
177.20: And then you can board the ship, capture
178.80: it, and take all the loot and resources
180.64: they have. And then you can either sell
182.24: the ship or keep it with you and hire
183.84: more pirates to work on it. And then
185.36: load it up with more cannons. To be
187.12: clear, this is a mobile game in VR. It's
190.08: meant to keep you playing for hours on
192.08: end. And and it cleverly masks the
194.16: repetitive gameplay with story and
196.40: objectives to motivate you. And again,
198.32: like their other games, it completely
199.92: works. Earlier today, I met a governor
201.92: of a town and they needed some help. So,
204.00: we teamed up to destroy another town's
206.24: fortress. And being the mercenary I am,
208.56: I not only had fun destroying the fleet
210.64: that protected the town, I obliterated
212.64: all the ships, collected all the
214.08: resources they had on board, and then
216.00: put the survivors to work on my own
217.84: ships, and I made 500 coins in the
220.16: process. And this roughly took about 30
222.40: minutes, but it absolutely went by in a
224.32: flash. The sea combat does take some
226.24: getting used to, though, especially when
227.92: you have more than one ship to take
229.20: control of, and the AI, in all honesty,
231.76: can be pretty
232.88: We can start the attack now. We should
235.28: focus on the fort first.
241.44: And this just makes your life that
242.88: little bit harder. But thanks to the
244.56: third person overview camera and the
246.80: ability to speed up time when sailing,
248.72: all in all, it's just not that bad and
250.56: you end up just having a good time. I
252.48: put 4 hours into this game already
254.32: today, and it went by extremely fast,
256.80: and that's why I wanted to raise some
258.64: awareness for it. It's still very
260.24: unfinished, though. I discovered a
261.76: treasure map earlier today while
263.28: searching through another shipwreck. And
264.72: when I traveled to the location, I got a
266.88: message from the developer actually
268.40: saying that this feature has not yet
270.48: been added to the game. And they're very
272.00: sorry. But to be honest, I wasn't mad. I
274.40: just moved on to the next objective to
276.32: earn more money, gather more resources,
278.40: to build up my town, and overall, I
280.72: absolutely recommend this game if you're
282.32: looking for a VR game based on being a
284.40: pirate captain. Well, that's all I've
286.16: got for you today. Check out my best VR
288.24: games of 2025, which I'll link here.
290.16: Remember to like and subscribe for more
291.92: VR content.
"""

// swiftlint:enable all
