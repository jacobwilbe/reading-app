import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showDailyFeed = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Reading time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper(value: $store.preferredMinutes, in: 5...90, step: 1) {
                    Text("\(store.preferredMinutes) minutes")
                        .font(.headline)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Spacer()

            Text("What do you want to read today?")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)

            Spacer()
        }
        .padding()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                TextField("Type a topic", text: $store.topicPrompt)
                    .textInputAutocapitalization(.sentences)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Button {
                    store.applyTopicPrompt()
                    showDailyFeed = true
                } label: {
                    Text("Generate")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(.ultraThinMaterial)
        }
        .navigationDestination(isPresented: $showDailyFeed) {
            DailyFeedView()
        }
        .navigationTitle("Plan")
    }
}
