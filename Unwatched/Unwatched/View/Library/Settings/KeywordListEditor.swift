//
//  KeywordListEditor.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Edits the comma-separated keyword string as one row per keyword. Storage stays a single
/// string; a comma typed or pasted into a row splits it into separate keywords.
struct KeywordListEditor: View {
    @Binding var text: String
    /// Set when the rows sit in a hand-drawn card rather than a Form section: draws the separators
    /// and gives each row a Form row's height.
    var showsDividers = false

    static let cardRowHeight: CGFloat = 44

    @State private var keywords: [Keyword] = []
    @FocusState private var focused: UUID?
    /// Focused from the row's onAppear (a Form cell doesn't exist yet when appended); spared by the
    /// empty-row cleanup until focus lands.
    @State private var pendingFocus: UUID?

    var body: some View {
        // bound by id, not index: a row can be removed while its field is still ending its edit
        ForEach(keywords) { keyword in
            HStack {
                TextField("keyword", text: binding(for: keyword.id))
                    .labelsHidden()
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.next)
                    #endif
                    .focused($focused, equals: keyword.id)
                    .onSubmit { submitted(keyword.id) }
                    .onAppear {
                        if pendingFocus == keyword.id { focused = keyword.id }
                    }

                Button("remove", systemImage: "minus.circle.fill") {
                    remove(keyword.id)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .frame(minHeight: showsDividers ? Self.cardRowHeight : nil)
            if showsDividers {
                Divider()
            }
        }

        Button("addKeyword", systemImage: "plus") {
            add()
        }
        .buttonStyle(.borderless)
        .frame(maxWidth: .infinity, minHeight: showsDividers ? Self.cardRowHeight : nil, alignment: .leading)
        .onAppear {
            // List re-creates this row when the keyboard resizes the sheet; a plain reload would drop the new empty row
            if !rowsMatchText { load() }
        }
        .onChange(of: text) {
            // the synced store can echo back an older value while typing; only outside changes reload
            if focused == nil && !rowsMatchText { load() }
        }
        .onChange(of: focused) {
            guard focused == nil else {
                pendingFocus = nil
                return
            }
            withAnimation {
                keywords.removeAll { $0.trimmed.isEmpty && $0.id != pendingFocus }
            }
            if !rowsMatchText { load() }
        }
        .onChange(of: keywords) {
            splitCommas()
            if !rowsMatchText { text = Self.serialize(keywords) }
        }
    }

    private var rowsMatchText: Bool {
        Self.serialize(text.commaSeparatedKeywords) == Self.serialize(keywords)
    }

    private func binding(for id: UUID) -> Binding<String> {
        Binding(
            get: { keywords.first { $0.id == id }?.text ?? "" },
            set: { value in
                guard let index = keywords.firstIndex(where: { $0.id == id }) else { return }
                keywords[index].text = value
            }
        )
    }

    private func load() {
        let current = keywords.filter { !$0.trimmed.isEmpty }
        let pending = keywords.first { $0.id == pendingFocus }
        keywords = text.commaSeparatedKeywords.enumerated().map { index, value in
            index < current.count ? Keyword(id: current[index].id, text: value) : Keyword(text: value)
        }
        if let pending, pending.trimmed.isEmpty { keywords.append(pending) }
    }

    private func add() {
        if let empty = keywords.first(where: { $0.trimmed.isEmpty }) {
            focused = empty.id
            return
        }
        let keyword = Keyword(text: "")
        pendingFocus = keyword.id
        withAnimation {
            keywords.append(keyword)
        }
    }

    private func remove(_ id: UUID) {
        withAnimation {
            keywords.removeAll { $0.id == id }
        }
    }

    private func submitted(_ id: UUID) {
        guard let keyword = keywords.first(where: { $0.id == id }) else { return }
        if keyword.trimmed.isEmpty {
            remove(id)
            focused = nil
        } else if keywords.last?.id == id {
            add()
        } else {
            focused = nil
        }
    }

    private func splitCommas() {
        guard let index = keywords.firstIndex(where: { $0.text.contains(",") }) else { return }
        let parts = keywords[index].text.split(separator: ",", omittingEmptySubsequences: false)
            .map { Keyword(text: String($0)).trimmed }
        keywords[index].text = parts[0]
        let rest = parts.dropFirst().map { Keyword(text: $0) }
        pendingFocus = rest.last?.id
        withAnimation {
            keywords.insert(contentsOf: rest, at: index + 1)
        }
    }

    static func serialize(_ keywords: [Keyword]) -> String {
        serialize(keywords.map(\.trimmed))
    }

    static func serialize(_ keywords: [String]) -> String {
        keywords.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    struct Keyword: Identifiable, Equatable {
        var id = UUID()
        var text: String

        var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
