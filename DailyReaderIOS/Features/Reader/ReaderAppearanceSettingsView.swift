import SwiftUI

struct ReaderAppearanceSettingsView: View {
    @ObservedObject var settingsStore: ReaderSettingsStore
    let onApplyFormatting: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Font Size") {
                    VStack(alignment: .leading, spacing: 8) {
                        Slider(value: $settingsStore.fontSize, in: 14...24, step: 1)
                        Text("\(Int(settingsStore.fontSize)) pt")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Font Type") {
                    Picker("Font", selection: $settingsStore.fontFamily) {
                        ForEach(ReaderFontFamily.allCases) { family in
                            Text(family.displayName).tag(family)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Theme") {
                    Picker("Theme", selection: $settingsStore.theme) {
                        ForEach(ReaderTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let onApplyFormatting {
                    Section {
                        Button("Update Formatting") {
                            onApplyFormatting()
                        }
                    } footer: {
                        Text("Apply these settings to regenerate the current article with the new style.")
                    }
                }
            }
            .navigationTitle("Reader Appearance")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
