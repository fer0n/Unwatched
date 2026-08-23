//
//  LocalizedStringKey.swift
//  Unwatched
//

import SwiftUI

extension LocalizedStringKey {
    /// Shows `text` as-is: interpolating it makes the key an argument rather than a lookup.
    static func verbatim(_ text: String) -> LocalizedStringKey {
        LocalizedStringKey("\(text)")
    }

    var stringKey: String? {
        Mirror(reflecting: self).children.first(where: { $0.label == "key" })?.value as? String
    }
}

extension String {
    static func localizedString(for key: String,
                                locale: Locale = .current) -> String {

        let languageIdentifier = locale.language.languageCode?.identifier
        guard let language = languageIdentifier else {
            return key
        }
        let path = Bundle.main.path(forResource: language, ofType: "lproj")!
        let bundle = Bundle(path: path)!
        let localizedString = NSLocalizedString(key, bundle: bundle, comment: "")

        return localizedString
    }
}

extension LocalizedStringKey {
    func stringValue(locale: Locale = .current) -> String {
        return .localizedString(for: self.stringKey ?? "", locale: locale)
    }
}
