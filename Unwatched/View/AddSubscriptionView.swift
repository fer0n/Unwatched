//
//  AddSubscriptionView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct AddSubscriptionView: View {
    @Environment(SubscriptionManager.self) var subscriptionManager
    @Environment(VideoManager.self) var videoManager
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @State var errorMessage: String?
    @State var text: String = ""
    @State var isLoading: Bool = false
    @State var subscription: Subscription?
    @FocusState private var textIsFocused: Bool

    func saveSubscription(_ subscription: Subscription) {
        modelContext.insert(subscription)
        // TODO: avoid adding an existing subscription
    }

    func addSubscription() {
        Task {
            errorMessage = nil
            isLoading = true
            do {
                if let sub = try await subscriptionManager.getSubscription(url: text) {
                    self.saveSubscription(sub)
                    // TODO: load all new videos here
                    dismiss()
                }
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
                    .focused($textIsFocused)

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
        .onAppear {
            textIsFocused = true
        }
        .padding(.horizontal)
    }
}

#Preview {
    AddSubscriptionView()
}
