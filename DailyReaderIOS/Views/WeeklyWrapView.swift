import SwiftUI

struct WeeklyWrapView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        let wrap = store.weeklyWrap()

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Weekly Wrapped")
                    .font(.title)
                    .fontWeight(.bold)

                HStack(spacing: 12) {
                    metricCard(title: "Minutes", value: "\(wrap.totalMinutes)")
                    metricCard(title: "Sessions", value: "\(wrap.sessionsCompleted)")
                    metricCard(title: "Streak", value: "\(wrap.streakDays)")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top topics")
                        .font(.headline)
                    ForEach(wrap.topTopics, id: \.topicID) { item in
                        Text("• \(store.topicName(for: item.topicID)): \(item.minutes) min")
                    }
                    if wrap.topTopics.isEmpty {
                        Text("No completed sessions yet this week.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggestions")
                        .font(.headline)
                    ForEach(wrap.suggestions, id: \.self) { suggestion in
                        Text("• \(suggestion)")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
        .navigationTitle("Weekly")
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
