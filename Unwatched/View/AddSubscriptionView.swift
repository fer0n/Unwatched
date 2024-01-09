//
//  AddSubscriptionView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct AddSubscriptionView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @State var errorMessage: String?
    @State var text: String = ""
    @State var isLoading: Bool = false

    func addSubscription() {
        Task {
            errorMessage = nil
            isLoading = true
            let urls = text.components(separatedBy: "\n")
            do {
                try await SubscriptionManager.addSubscriptions(from: urls,
                                                               modelContext: modelContext)
                dismiss()
            } catch {
                print("\(error)")
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    var body: some View {
        VStack {
            VStack(spacing: 0) {
                Image(systemName: "books.vertical.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                Text("Add Subscription")
                    .font(.system(size: 20, weight: .heavy))
                    .submitLabel(.done)
                    .onSubmit {
                        addSubscription()
                    }
            }
            .padding()

            HStack {
                TextField("Feed URL", text: $text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 15)
                    .background(Color.grayColor)
                    .clipShape(RoundedRectangle(cornerRadius: 15))

                Button {
                    addSubscription()
                } label: {
                    Image(systemName: "plus")
                        .bold()
                        .padding()
                }
                .background(Color.accentColor)
                .foregroundColor(.backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
            }

            if isLoading {
                ProgressView()
                    .padding()
            }

            Spacer()

            Button {
                text = UIPasteboard.general.string ?? ""
                if !text.isEmpty {
                    addSubscription()
                }
            } label: {
                Text("Paste URL")
                    .bold()
                    .padding(.horizontal, 25)
                    .padding(.vertical, 15)
            }
            .background(Color.accentColor)
            .foregroundColor(.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
            .padding()
        }
        .padding(.horizontal)
    }
}

#Preview {
    AddSubscriptionView()
}