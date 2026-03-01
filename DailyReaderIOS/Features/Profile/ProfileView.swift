import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var viewModel: ProfileViewModel

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showEditProfile = false
    @State private var showReaderAppearance = false
    @ObservedObject private var readerSettings = ReaderSettingsStore.shared
    @AppStorage(RecommendationsUserSettings.wpmKey) private var recommendationsWPM: Int = ReadingSpeedSettings.defaultWPM

    var body: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading profile...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection
                        goalAndStatsSection
                        activitySection
                        currentReadsSection
                        favoriteSubjectsSection
                        achievementsSection
                        settingsSection
                        friendsSection
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $showEditProfile) {
            NavigationStack {
                EditProfileView()
            }
            .environmentObject(viewModel)
        }
        .sheet(isPresented: $showReaderAppearance) {
            ReaderAppearanceSettingsView(settingsStore: readerSettings, onApplyFormatting: nil)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.setProfilePhoto(data: data)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Group {
                        if let image = viewModel.profileImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color(.tertiarySystemFill))
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(width: 84, height: 84)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(.separator), lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.profile.username.isEmpty ? "Reader" : viewModel.profile.username)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(viewModel.profile.bio.isEmpty ? "No bio yet." : viewModel.profile.bio)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer()
            }

            Button("Edit profile") {
                showEditProfile = true
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var goalAndStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's goal")
                .font(.headline)

            HStack(spacing: 16) {
                ProgressRing(progress: viewModel.todayGoalProgress)
                    .frame(width: 78, height: 78)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.todayGoalLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Streak: \(viewModel.streakDays) day\(viewModel.streakDays == 1 ? "" : "s")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricCard(title: "Today's minutes", value: "\(viewModel.todayMinutes)")
                metricCard(title: "All-time minutes", value: "\(viewModel.allTimeMinutes)")
                metricCard(title: "Today's pages", value: "\(viewModel.todayPages)")
                metricCard(title: "All-time pages", value: "\(viewModel.allTimePages)")
            }

            VStack(alignment: .leading, spacing: 8) {
                Picker("Average window", selection: $viewModel.averageWindow) {
                    ForEach(AverageWindow.allCases) { window in
                        Text(window.label).tag(window)
                    }
                }
                .pickerStyle(.segmented)

                Text("Average: \(viewModel.averageMinutesPerWindow, specifier: "%.1f") min/day")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Estimated reading speed")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let summary = viewModel.readingSpeedSummary {
                    Text("\(summary.wpm) wpm")
                        .font(.headline)
                    Text("Based on your last \(summary.sampleCount) read\(summary.sampleCount == 1 ? "" : "s").")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not enough data yet")
                        .font(.subheadline)
                    Text("Read 1-2 articles in the in-app reader to estimate your speed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last 7 days")
                .font(.headline)
            ActivityBarChart(days: viewModel.activityLast7Days)
                .frame(height: 140)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var currentReadsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current reads")
                .font(.headline)

            if viewModel.currentReadsPreview.isEmpty {
                Text("No current reads yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.currentReadsPreview) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(item.author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ProgressView(value: Double(item.progressPercent), total: 100)
                        Text("\(item.progressPercent)%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var favoriteSubjectsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Favorite subjects")
                .font(.headline)

            if viewModel.favoriteSubjectsTop3.isEmpty {
                Text("Not enough reading data yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.favoriteSubjectsTop3, id: \.subject) { item in
                    HStack {
                        Text(item.subject)
                        Spacer()
                        Text("\(item.minutes) min")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                Spacer()
                NavigationLink("See all") {
                    AchievementsView(achievements: viewModel.achievements)
                }
                .font(.footnote)
            }

            let earnedCount = viewModel.achievements.filter { $0.earned }.count
            Text("\(earnedCount) / \(viewModel.achievements.count) earned")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)

            Picker("Theme", selection: Binding(
                get: { viewModel.settings.theme },
                set: { viewModel.updateTheme($0) }
            )) {
                ForEach(AppThemePreference.allCases) { theme in
                    Text(theme.label).tag(theme)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Notifications", isOn: Binding(
                get: { viewModel.settings.notificationsEnabled },
                set: { viewModel.updateNotifications(enabled: $0) }
            ))

            DatePicker(
                "Reminder",
                selection: Binding(
                    get: { viewModel.settings.reminderTime },
                    set: { viewModel.updateReminderTime($0) }
                ),
                displayedComponents: .hourAndMinute
            )

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Reading speed baseline")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Slider(value: Binding(
                    get: { Double(recommendationsWPM) },
                    set: { recommendationsWPM = Int($0.rounded()) }
                ), in: 120...400, step: 5)
                Text("\(recommendationsWPM) words per minute")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Reader appearance")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(readerSettings.fontFamily.displayName) · \(Int(readerSettings.fontSize)) pt · \(readerSettings.theme.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Open reader settings") {
                showReaderAppearance = true
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var friendsSection: some View {
        FriendsPlaceholderView(
            followers: viewModel.social.followers,
            following: viewModel.social.following
        )
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EditProfileView: View {
    @EnvironmentObject private var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var goalMode: ReadingGoalMode = .minutes
    @State private var goalAmount: Int = 20

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Username", text: $username)
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(3...4)
            }

            Section("Reading goal") {
                Picker("Goal type", selection: $goalMode) {
                    ForEach(ReadingGoalMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Stepper(value: $goalAmount, in: 1...300) {
                    Text("\(goalAmount) \(goalMode == .minutes ? "minutes" : "pages")")
                }
            }
        }
        .navigationTitle("Edit Profile")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    viewModel.updateProfile(
                        username: username,
                        bio: bio,
                        goalMode: goalMode,
                        goalAmount: goalAmount
                    )
                    dismiss()
                }
            }
        }
        .onAppear {
            username = viewModel.profile.username
            bio = viewModel.profile.bio
            goalMode = viewModel.profile.goalMode
            goalAmount = viewModel.profile.goalAmount
        }
    }
}

struct AchievementsView: View {
    let achievements: [AchievementProgress]

    var body: some View {
        List {
            ForEach(achievements) { achievement in
                HStack(spacing: 12) {
                    Image(systemName: achievement.symbolName)
                        .foregroundStyle(achievement.earned ? Color.green : Color.secondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(achievement.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(achievement.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(achievement.earned ? "Earned" : "Locked")
                        .font(.caption)
                        .foregroundStyle(achievement.earned ? Color.green : Color.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Achievements")
    }
}

struct FriendsPlaceholderView: View {
    let followers: Int
    let following: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Friends")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Followers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(followers)")
                        .font(.headline)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Following")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(following)")
                        .font(.headline)
                }
            }

            Text("Coming soon")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("• Friend activity feed")
            Text("• Shared reading challenges")
            Text("• Follow recommendations")
        }
        .font(.footnote)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct ActivityBarChart: View {
    let days: [DayActivity]

    var body: some View {
        let maxMinutes = max(days.map(\.minutes).max() ?? 0, 1)

        HStack(alignment: .bottom, spacing: 10) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.accentColor.opacity(0.9))
                        .frame(height: max(4, CGFloat(day.minutes) / CGFloat(maxMinutes) * 90))
                    Text(shortLabel(for: day.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(day.minutes) minutes")
            }
        }
    }

    private func shortLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }
}

struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(0.0, min(progress, 1.0)))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
