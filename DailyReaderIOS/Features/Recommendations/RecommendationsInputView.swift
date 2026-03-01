import SwiftUI

struct RecommendationsInputView: View {
    @StateObject private var viewModel: RecommendationsViewModel
    @State private var showResults = false
    private let autoSearchOnAppear: Bool

    init(
        initialTopic: String = "",
        initialMinutes: Int = 10,
        autoSearchOnAppear: Bool = false
    ) {
        let model = RecommendationsViewModel()
        model.topic = initialTopic
        model.minutes = initialMinutes
        _viewModel = StateObject(wrappedValue: model)
        self.autoSearchOnAppear = autoSearchOnAppear
    }

    var body: some View {
        Form {
            Section("Subject") {
                TextField("What do you want to read?", text: $viewModel.topic)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
            }

            Section("Time") {
                Stepper(value: $viewModel.minutes, in: 1...120) {
                    Text("\(viewModel.minutes) minutes")
                }
                Text("About \(viewModel.maxWordsForSelectedTime) words at \(viewModel.effectiveWPM) wpm")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Filters") {
                Picker("License", selection: $viewModel.licenseFilter) {
                    ForEach(LicenseFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }

                TextField("Language", text: $viewModel.language)
                    .textInputAutocapitalization(.never)

                Toggle("Allow slightly over (+1 min)", isOn: $viewModel.allowSlightlyOver)
                Toggle("Prefer recent", isOn: $viewModel.preferRecent)
            }

            Section {
                Toggle("Use mock mode", isOn: $viewModel.useMockMode)
            } header: {
                Text("Testing")
            } footer: {
                Text("Mock mode returns deterministic results without network.")
            }

            Section {
                Button("Search free sources") {
                    Task {
                        await viewModel.search()
                        showResults = true
                    }
                }
            }
        }
        .navigationTitle("Find Articles")
        .navigationDestination(isPresented: $showResults) {
            RecommendationsResultsView(viewModel: viewModel)
        }
        .task {
            guard autoSearchOnAppear, !viewModel.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            await viewModel.search()
            showResults = true
        }
    }
}
