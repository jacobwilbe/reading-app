import SwiftUI

struct RecommendationsResultsView: View {
    @ObservedObject var viewModel: RecommendationsViewModel

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Topic")
                    Spacer()
                    Text(viewModel.topic)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Time available")
                    Spacer()
                    Text("\(viewModel.minutes) min")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Reading speed")
                    Spacer()
                    Text("\(viewModel.effectiveWPM) wpm")
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.isLoading {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Searching free sources...")
                    }
                }
            } else if viewModel.hasNoResults {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No matches under \(viewModel.minutes) minutes.")
                            .font(.headline)
                        Text("Try a broader topic or increase time.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(viewModel.suggestedMinutes, id: \.self) { suggestion in
                                Button("\(suggestion) min") {
                                    viewModel.minutes = suggestion
                                    Task { await viewModel.search() }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Section("Top 3") {
                    ForEach(viewModel.result.topThree) { candidate in
                        RecommendationResultCardView(
                            candidate: candidate,
                            estimatedMinutes: viewModel.estimatedMinutes(for: candidate),
                            onOpen: {
                                Task { await viewModel.openInBrowser(candidate: candidate) }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }
            }

            Section {
                Button("Try again") {
                    Task { await viewModel.tryAgain() }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .navigationTitle("Best Matches")
        .sheet(item: $viewModel.presentedURLItem) { item in
            InAppBrowserView(url: item.url)
                .ignoresSafeArea()
        }
        .alert("Recommendations", isPresented: Binding(get: {
            viewModel.errorMessage != nil || viewModel.linkNotice != nil
        }, set: { presented in
            if !presented {
                viewModel.errorMessage = nil
                viewModel.linkNotice = nil
            }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? viewModel.linkNotice ?? "")
        }
    }
}
