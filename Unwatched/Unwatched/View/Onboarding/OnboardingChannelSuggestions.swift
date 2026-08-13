//
//  OnboardingChannelSuggestions.swift
//  Unwatched
//

import Foundation

/// Starter channels offered on the first onboarding page.
///
/// Avatar urls are the ones YouTube served at the time; a channel changing its picture falls the
/// row back to its monogram placeholder.
enum OnboardingChannelSuggestions {
    static let all: [YoutubeChannelSearchResult] = [
        channel("UCBJycsmduvYEL83R_U4JriQ", "Marques Brownlee", "mkbhd",
                "qu4TmIaYUlS41-dJ9gZ7DUR3nilvmB5_11i6OKSdvNnBNiyOusZP1bMN6ICnuxtjFBb6ioKgRQ"),
        channel("UCHnyfMqiRRG1u-2MsSQLbXA", "Veritasium", "veritasium",
                "7vCbvtCqtjQ3YLgsJt7Y952MQV1sBvhllSCSxHP8_sVZdcPCBrITfhkN2RdyCuwPnsByq-1GoA"),
        channel("UCsXVk37bltHxD1rDPwtNM8Q", "Kurzgesagt – In a Nutshell", "kurzgesagt",
                "ytc/AIdro_n1Ribd7LwdP_qKtqWL3ZDfIgv9M1d6g78VwpHGXVR2Ir4"),
        channel("UCBa659QWEk1AI4Tg--mrJ2A", "Tom Scott", "TomScottGo",
                "WxHs0Jf1Jp_4ZU84wxnRL0owNHkzaLUEiD-GIfgCrVjZ0JhgriPTdPfGrkf-U7zwIs5zQl9ccg"),
        channel("UCY1kMZp36IQSyNx_9h4mpCg", "Mark Rober", "MarkRober",
                "ytc/AIdro_ksXY2REjZ6gYKSgnWT5jC_zT9mX900vyFtVinR8KbHww"),
        channel("UCXuqSBlHAE6Xw-yeJA0Tunw", "Linus Tech Tips", "LinusTechTips",
                "gnvYLhXy8FAlPXZ2RTrkrgj-5kyt0vdE2FUGVOiKGdEZIa-wN5A-7nwZBlWJLzUMmoh1NWAU"),
        channel("UCYO_jab_esuFRV4b17AJtAw", "3Blue1Brown", "3blue1brown",
                "ytc/AIdro_nFzZFPLxPZRHcE3SSwzdrbuWqfoWYwLAu0_2iO6blQYAU"),
        channel("UC6107grRI4m0o2-emgoDnAA", "SmarterEveryDay", "smartereveryday",
                "ytc/AIdro_l59Ewmp0DHZBRWbY9dVqjd2_mWwvrn8ad0bJfmdbMRYcA"),
        channel("UCEIwxahdLz7bap-VDs9h35A", "Steve Mould", "SteveMould",
                "iX-akiHlJYuPDq4YVBO83cfjWW0aQefdewmI326XVhZkzxnS3MrqNVi49J33jLBw5LR_ZVyKFA"),
        channel("UCMOqf8ab-42UUQIdVoKwjlQ", "Practical Engineering", "PracticalEngineeringChannel",
                "ytc/AIdro_m1Y4p9FzWjJBIhIwbVt6Z1qGKa8eWUTzE3kizORZMFKf4"),
        channel("UCmGSJVG3mCRXVOP4yZrU1Dw", "Johnny Harris", "johnnyharris",
                "ytc/AIdro_kswBDn49WW5IneVE-5RlKyud5GvdzyQQ5SJQyVvJ4S3pk"),
        channel("UC9RM-iSvTu1uPJb8X5yp3EQ", "Wendover Productions", "Wendoverproductions",
                "OnFIYArpFofrmngLXAsDGHsoVUpPA-yW3oD2ug7J2tq7H4BUcnnQvyfaQ8vw6s5JCiXJu1hb5A"),
        channel("UCLXo7UDZvByw2ixzpQCufnA", "Vox", "Vox",
                "iak9xjDjDoQHn9UNWSvkobPuxAzK1ApefjPH7HGObwo71AbaiEqdafMjmUJCgOoBFWNKPS2t2eI"),
        channel("UCddiUEpeqJcYeBxX1IVBKvQ", "The Verge", "TheVerge",
                "ZIj_dq7beCkAkhufNqCid_SjWW4mkv4tqIDtv7_AAKzWdhBWI-rpsRXYXB9X3mB0s0zNzNtYdQ"),
        channel("UCsBjURrPoezykLs9EqgamOA", "Fireship", "Fireship",
                "3fPNbkf_xPyCleq77ZhcxyeorY97NtMHVNUbaAON_RBDH9ydL4hJkjxC8x_4mpuopkB8oI7Ct6Y"),
        channel("UCoxcjq-8xIDTYp3uz647V5A", "Numberphile", "Numberphile",
                "ytc/AIdro_nmbQSAGKk1OZCBBf_sPJqLoFfYOVDWRDzALocBjGQtHeI"),
        channel("UCpa-Zb0ZcQjTCPP1Dx_1M8Q", "LegalEagle", "LegalEagle",
                "ytc/AIdro_kwW7uBHNuJln3mwjAD39KvwvTbVKtoTONHGwiaAp3Njw"),
        channel("UCwmZiChSryoWQCZMIQezgTg", "BBC Earth", "BBCEarth",
                "4aOOdq9yagLxasYPhdG7qQEVP-nrcmqoFD74N-dxw9ctOxXZtuSTTZKGzNsx-Nn0OqzVGnPZUA"),
        channel("UCpVm7bg6pXKo1Pr6k5kxG9A", "National Geographic", "natgeo",
                "-FOFg8o1y4dAHDB2MvhORHnLMOaaOKnaNUNsrU-U57Eac6gjB5VO8sYJQC1KkULGQvKP2XpArA"),
        channel("UCLA_DiR1FfKNvjuUpBHmylQ", "NASA", "NASA",
                "eIf5fNPcIcj9ig-wZBeq4stFy1lgjWTW1nLT5dYlFkHZprZ03QBiMcbpwNMB6XSBjrSFGtAGQg"),
        channel("UCJHA_jMfCvEnv-3kRjTCQXw", "Binging with Babish", "bingingwithbabish",
                "AlCRk3X8JvmNqHC7R3c7yVDQaGyUvMAd3GXY77vTgzGS1Qa_vlVFY0ZNSH56otpeBKDq3gF-yw"),
        channel("UCIEv3lZ_tNXHzL3ox-_uUGQ", "Gordon Ramsay", "GordonRamsay",
                "iu8M-gugkNvz-lHxC1sMEfAlL7ONWbP91c5SM9bb98oCJAcYUl0HIAMZFFR2Dd-soGag1Y1y8A"),
        channel("UCX6OQ3DkcsbYNE6H8uQQuVA", "MrBeast", "MrBeast",
                "nxYrc_1_2f77DoBadyxMTmv7ZpRZapHR5jbuYe7PlPd5cIRJxtNNEYyOC0ZsxaDyJJzXrnJiuDE"),
        channel("UCRijo3ddMTht_IHyNSNXpNQ", "Dude Perfect", "DudePerfect",
                "nZRsCgyfOVFhBzY-YFV8AhdMcYAybNZ8uttjcsrUGOnGRSVF5yKqRh6XHIs_o03TcbixvlOZ"),
        channel("UCp68_FLety0O-n9QU6phsgw", "colinfurze", "colinfurze",
                "ytc/AIdro_nx0_jjIdix_fYOdMrts1Qk3GsxLzurlxZecRi93qEw-js"),
        channel("UCiDJtJKMICpb9B1qf7qjEOA", "Adam Savage’s Tested", "tested",
                "ytc/AIdro_lJNRS5W3nnMhU5L_V3Nl2zqoJTh1POU3hrHSYYIzLCycE"),
        channel("UC6nSFpj9HTCZ5t-N3Rm3-HA", "Vsauce", "Vsauce",
                "ytc/AIdro_mpYedipdXUXCKkwjQEeFrepFlDHZ0LiczqWeKyG0YmJvA"),
        channel("UCAuUUnT6oDeKwE6v1NGQxug", "TED", "TED",
                "ytc/AIdro_koIFcCOrvh0KThLNOiazAIDu6hcs8bjkGNwe1f6A_OYm8"),
        channel("UCoOae5nYA7VqaXzerajD0lg", "Ali Abdaal", "aliabdaal",
                "ytc/AIdro_m2xx6mCZwsyjARnkwBKJxEv0FqGxGS2NwWNkjWH__Smw"),
        channel("UCJquYOG5EL82sKTfH9aMA9Q", "Rick Beato", "RickBeato",
                "ZfDOigTWKzMkwaokreALniSPfAzaAq4v2T9hawgoFmjX4mHULaVyCcySqKjmvcBqvoPyWX7gsg"),
        channel("UCnrAvt4i_2WV3yEKWyEUMlg", "Gamertag VR", "GAMERTAGVR",
                "ih1Eh72V95CPzo5wRq6S0GtmrZpFrpAw78CYoCu9mqiJ66nP1t7wvEkjP3FdhQbt819P_4UQuw"),
        channel("UCVYamHliCI9rw1tHR1xbkfw", "Dave2D", "Dave2D",
                "ytc/AIdro_lltZkOAE5XVIlI8U5QVXmdASgYyJiJps-LkO-uQnTwLMQ"),
        channel("UC-FHoOa_jNSZy3IFctMEq2w", "habie147", "habie147",
                "ytc/AIdro_lO1dGNQA_KkLYNfUdZJYNbFA9FFTt0rsU1DC95T4A98Y0"),
        channel("UCi0_2sEpmT6FKn5-y6_W3cA", "Joanna Stern", "JoannaStern",
                "FElhAj-MUyoqxqKy-ZuKtbr1Zguqs7SONymOmIGjvEiXwlu31zEkujAqnYDAwvJx3JeONDrFs8k"),
        channel("UCEcrRXW3oEYfUctetZTAWLw", "WVFRM Podcast", "Waveform",
                "NmzjFJ3oFspQ47IkoaNT_tGAN0a9gI_YbW7Fs-VVchxeJ0a336-qarZ4CMboDAS0vw17cqEY")
    ]

    private static func channel(
        _ channelId: String,
        _ title: String,
        _ userName: String,
        _ imagePath: String
    ) -> YoutubeChannelSearchResult {
        YoutubeChannelSearchResult(
            channelId: channelId,
            title: title,
            userName: userName,
            thumbnailUrl: URL(
                string: "https://yt3.googleusercontent.com/\(imagePath)=s176-c-k-c0x00ffffff-no-rj"
            )
        )
    }
}
