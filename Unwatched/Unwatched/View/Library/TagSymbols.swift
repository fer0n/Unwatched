//
//  TagSymbols.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

extension TagSymbolPicker {
    struct SymbolGroup: Identifiable {
        /// The localization key doubles as the id; `LocalizedStringKey` isn't `Hashable`.
        let id: String
        let symbols: [String]

        var title: LocalizedStringKey { LocalizedStringKey(id) }
    }

    /// Grouped by topic so a tag's symbol can be found by browsing instead of scanning.
    /// Symbols already in use must never be dropped from here, or an existing tag's symbol
    /// becomes unselectable.
    static let groups: [SymbolGroup] = [
        SymbolGroup(id: "symbolGroupBasics", symbols: [
            "tag.fill",
            "tag.slash",
            Const.untaggedSF,
            "star.fill",
            "heart.fill",
            "bookmark.fill",
            "flag.fill",
            "pin.fill",
            "bell.fill",
            "bolt.fill",
            "flame.fill",
            "sparkles",
            "crown.fill",
            "trophy.fill",
            "checkmark.seal.fill",
            "lightbulb.fill",
            "eye.fill",
            "folder.fill",
            "hourglass.bottomhalf.filled",
            "rectangle.stack.fill",
            "mail.stack.fill"
        ]),
        SymbolGroup(id: "symbolGroupMedia", symbols: [
            "film.fill",
            "tv.fill",
            "play.rectangle.fill",
            "video.fill",
            "popcorn.fill",
            "theatermasks.fill",
            "camera.fill",
            "photo.fill",
            "photo.stack.fill",
            "film.stack.fill",
            "music.note.square.stack.fill",
            "paintbrush.fill",
            "paintpalette.fill",
            "gamecontroller.fill",
            "dice.fill",
            "puzzlepiece.fill",
            "music.note",
            "guitars.fill",
            "pianokeys",
            "headphones",
            "headphones.over.ear",
            "mic.fill",
            "waveform",
            "radio.fill",
            "microphone.dynamic.on.stand"
        ]),
        SymbolGroup(id: "symbolGroupReading", symbols: [
            "book.fill",
            "books.vertical.fill",
            "text.book.closed.fill",
            "graduationcap.fill",
            "newspaper.fill",
            "pencil",
            "text.bubble.fill",
            "quote.bubble.fill",
            "bubble.left.and.bubble.right.fill",
            "megaphone.fill"
        ]),
        SymbolGroup(id: "symbolGroupTech", symbols: [
            "laptopcomputer",
            "desktopcomputer",
            "iphone",
            "cpu.fill",
            "keyboard.fill",
            "terminal.fill",
            "chevron.left.forwardslash.chevron.right",
            "network",
            "antenna.radiowaves.left.and.right",
            "ipod",
            "flipphone",
            "applewatch",
            "vision.pro"
        ]),
        SymbolGroup(id: "symbolGroupWork", symbols: [
            "briefcase.fill",
            "building.2.fill",
            "chart.line.uptrend.xyaxis",
            "chart.pie.fill",
            "dollarsign.circle.fill",
            "creditcard.fill",
            "cart.fill",
            "shippingbox.fill",
            "wrench.and.screwdriver.fill",
            "hammer.fill",
            "gearshape.fill",
            "scissors"
        ]),
        SymbolGroup(id: "symbolGroupHome", symbols: [
            "house.fill",
            "fan.desk",
            "globe.desk",
            "bed.double.fill",
            "sofa.fill",
            "fork.knife",
            "cup.and.saucer.fill",
            "wineglass.fill",
            "carrot.fill",
            "birthday.cake.fill",
            "takeoutbag.and.cup.and.straw.fill",
            "tshirt.fill",
            "hanger",
            "person.2.fill",
            "person.3.fill",
            "person.crop.rectangle.stack.fill",
            "face.smiling",
            "hand.thumbsup.fill"
        ]),
        SymbolGroup(id: "symbolGroupSports", symbols: [
            "figure.run",
            "figure.walk",
            "figure.strengthtraining.traditional",
            "figure.yoga",
            "figure.pool.swim",
            "dumbbell.fill",
            "sportscourt.fill",
            "soccerball",
            "basketball.fill",
            "tennis.racket",
            "bicycle",
            "skateboard",
            "surfboard.fill",
            "stethoscope",
            "cross.case.fill",
            "pills.fill"
        ]),
        SymbolGroup(id: "symbolGroupTravel", symbols: [
            "airplane",
            "car.fill",
            "bus.fill",
            "tram.fill",
            "ferry.fill",
            "sailboat.fill",
            "fuelpump.fill",
            "bolt.car",
            "steeringwheel",
            "map.fill",
            "globe.europe.africa.fill",
            "signpost.right.fill",
            "suitcase.fill",
            "tent.fill",
            "beach.umbrella.fill",
            "binoculars.fill"
        ]),
        SymbolGroup(id: "symbolGroupNature", symbols: [
            "leaf.fill",
            "tree.fill",
            "mountain.2.fill",
            "pawprint.fill",
            "fish.fill",
            "bird.fill",
            "ant.fill",
            "lizard.fill",
            "dog.fill",
            "cat.fill",
            "sun.max.fill",
            "moon.fill",
            "cloud.fill",
            "snowflake",
            "drop.fill",
            "atom",
            "testtube.2",
            "microbe.fill",
            "brain.head.profile"
        ])
    ]
}
