import SwiftUI

struct DailyFeedView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(store.preferredMinutes) minute session")
                        .font(.headline)
                    Text(store.randomTopicMode ? "Random discovery mode" : "Focus: \(store.selectedTopicLabel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Recommendations") {
                ForEach(store.recommendations()) { ranked in
                    NavigationLink {
                        ReadSessionView(article: ranked.article)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(ranked.article.sourceName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(ranked.article.estimatedMinutes) min")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.tertiarySystemFill))
                                    .clipShape(Capsule())
                            }

                            Text(ranked.article.title)
                                .font(.headline)
                            Text(ranked.article.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)

                            Text("Topic \(Int(ranked.topicMatch * 100))% | Time fit \(Int(ranked.timeFit * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Daily")
    }
}
