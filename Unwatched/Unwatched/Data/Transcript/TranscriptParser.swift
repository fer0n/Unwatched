//
//  TranscriptParser.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

class TranscriptParser: NSObject, XMLParserDelegate {
    private var transcripts = [TranscriptEntry]()
    private var currentText: String?
    private var currentStart: Double?
    private var currentDuration: Double?
    private var parsingError: Error?

    func parse(data: Data) throws -> [TranscriptEntry] {
        transcripts.removeAll()

        let parser = XMLParser(data: data)
        parser.delegate = self

        if parser.parse() {
            return transcripts
        } else if let error = parsingError {
            throw error
        } else {
            throw NSError(
                domain: "TranscriptParserDomain",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to parse transcript XML"]
            )
        }
    }

    // Helper method to decode HTML entities
    private func decodeHTMLEntities(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return string }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }
        return string
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "text" {
            currentText = ""
            currentStart = Double(attributeDict["start"] ?? "") ?? 0
            currentDuration = Double(attributeDict["dur"] ?? "") ?? 0
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText = (currentText ?? "") + string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "text", let text = currentText, let start = currentStart, let duration = currentDuration {
            // Decode HTML entities in the text
            let cleanedText = decodeHTMLEntities(text.trimmingCharacters(in: .whitespacesAndNewlines))

            let transcript = TranscriptEntry(
                start: start,
                duration: duration,
                text: cleanedText,
                isParagraphEnd: false
            )
            transcripts.append(transcript)

            currentText = nil
            currentStart = nil
            currentDuration = nil
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        parsingError = parseError
    }
}
