import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Reader")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Build a daily reading habit around topics you care about")
                        .font(.title)
                        .fontWeight(.bold)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Daily Time")
                        .font(.headline)
                    Stepper(value: $store.preferredMinutes, in: 5...90, step: 1) {
                        Text("\(store.preferredMinutes) minutes")
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Topic")
                        .font(.headline)
                    Picker("Topic", selection: $store.selectedTopicID) {
                        ForEach(store.topics) { topic in
                            Text(topic.name).tag(topic.id)
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle("Random topic mode", isOn: $store.randomTopicMode)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                NavigationLink {
                    DailyFeedView()
                } label: {
                    Text("Generate today’s reading list")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)

                Text("Tip: Read one article per day. Consistency beats volume.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Plan")
    }
}
