import SwiftUI

struct ReadSessionView: View {
    @EnvironmentObject private var store: AppStore
    let article: Article

    @State private var logged = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 10) {
                    Label("\(article.estimatedMinutes) min", systemImage: "clock")
                    Label(article.sourceName, systemImage: "newspaper")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text(article.summary)
                    .font(.body)

                if let url = URL(string: article.sourceURL) {
                    Link("Open original article", destination: url)
                        .buttonStyle(.bordered)
                }

                Button {
                    store.markArticleCompleted(article)
                    logged = true
                } label: {
                    Text(logged ? "Logged for today" : "Mark as read")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(logged)
            }
            .padding()
        }
        .navigationTitle("Reading")
    }
}
