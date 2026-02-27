import SwiftUI
import UIKit

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var isLoading: Bool = true

    @Published var profile: UserProfile
    @Published var settings: ProfileSettings
    @Published var sessions: [ProfileReadingSession]
    @Published var currentReads: [CurrentRead]
    @Published var social: SocialStats
    @Published var averageWindow: AverageWindow = .sevenDays
    @Published var profileImage: UIImage?

    private let store = ProfileStore()

    init() {
        let seeded = ProfileLocalData.seed()
        profile = seeded.profile
        settings = seeded.settings
        sessions = seeded.sessions
        currentReads = seeded.currentReads
        social = seeded.social

        loadData()
    }

    var todayMinutes: Int {
        minutes(on: Date())
    }

    var todayPages: Int {
        pages(on: Date())
    }

    var allTimeMinutes: Int {
        sessions.reduce(0) { $0 + max($1.minutesRead, 0) }
    }

    var allTimePages: Int {
        sessions.reduce(0) { $0 + max($1.pagesRead, 0) }
    }

    var streakDays: Int {
        let calendar = Calendar.current
        let positiveDays = Set(
            sessions
                .filter { $0.minutesRead > 0 }
                .map { calendar.startOfDay(for: $0.date) }
        )

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())

        while positiveDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }

    var averageMinutesPerWindow: Double {
        let days = averageWindow.rawValue
        let total = totalMinutes(lastNDays: days)
        return Double(total) / Double(days)
    }

    var readingSpeedSummary: (wpm: Int, sampleCount: Int)? {
        let validSessions = sessions
            .filter { $0.durationSeconds > 0 && $0.wordCount > 0 }
            .sorted { $0.date > $1.date }

        let sample = Array(validSessions.prefix(10))
        guard !sample.isEmpty else { return nil }

        let wpmValues = sample.map { session -> Double in
            let minutes = Double(session.durationSeconds) / 60.0
            guard minutes > 0 else { return 0 }
            return Double(session.wordCount) / minutes
        }

        let average = wpmValues.reduce(0, +) / Double(sample.count)
        let clamped = Int(max(80, min(600, average)).rounded())
        return (wpm: clamped, sampleCount: sample.count)
    }

    var currentReadsPreview: [CurrentRead] {
        Array(currentReads.prefix(3))
    }

    var favoriteSubjectsTop3: [(subject: String, minutes: Int)] {
        var totals: [String: Int] = [:]

        for session in sessions where session.minutesRead > 0 {
            let tags = session.subjectTags.isEmpty ? ["General"] : session.subjectTags
            for tag in tags {
                totals[tag, default: 0] += session.minutesRead
            }
        }

        return totals
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { (subject: $0.key, minutes: $0.value) }
    }

    var todayGoalProgress: Double {
        let target = max(profile.goalAmount, 1)
        let value = profile.goalMode == .minutes ? todayMinutes : todayPages
        return min(1.0, Double(value) / Double(target))
    }

    var todayGoalLabel: String {
        let unit = profile.goalMode == .minutes ? "min" : "pages"
        let value = profile.goalMode == .minutes ? todayMinutes : todayPages
        return "\(value) / \(profile.goalAmount) \(unit)"
    }

    var activityLast7Days: [DayActivity] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0...6).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -6 + offset, to: today) else { return nil }
            let minutes = minutes(on: day)
            return DayActivity(
                id: day.formatted(date: .numeric, time: .omitted),
                date: day,
                minutes: minutes
            )
        }
    }

    var achievements: [AchievementProgress] {
        let anySession = sessions.contains { $0.minutesRead > 0 }
        let firstBookFinished = currentReads.contains { $0.progressPercent >= 100 }
        let totalMinutes = allTimeMinutes

        let streakMilestones = [3, 7, 14, 30].map { milestone in
            AchievementProgress(
                id: "streak-\(milestone)",
                title: "\(milestone)-day streak",
                description: "Read for \(milestone) consecutive days.",
                symbolName: "flame.fill",
                earned: streakDays >= milestone
            )
        }

        let minutesMilestones = [60, 300, 1000].map { milestone in
            AchievementProgress(
                id: "minutes-\(milestone)",
                title: "\(milestone) minutes",
                description: "Accumulate \(milestone) minutes of reading.",
                symbolName: "clock.fill",
                earned: totalMinutes >= milestone
            )
        }

        return [
            AchievementProgress(
                id: "first-session",
                title: "First session",
                description: "Complete your first reading session.",
                symbolName: "book.fill",
                earned: anySession
            ),
            AchievementProgress(
                id: "first-book",
                title: "First book finished",
                description: "Reach 100% on any current read.",
                symbolName: "checkmark.seal.fill",
                earned: firstBookFinished
            )
        ] + streakMilestones + minutesMilestones
    }

    func updateProfile(username: String, bio: String, goalMode: ReadingGoalMode, goalAmount: Int) {
        profile.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.goalMode = goalMode
        profile.goalAmount = max(1, goalAmount)
        saveData()
    }

    func updateTheme(_ theme: AppThemePreference) {
        settings.theme = theme
        saveData()
    }

    func updateNotifications(enabled: Bool) {
        settings.notificationsEnabled = enabled
        saveData()
    }

    func updateReminderTime(_ time: Date) {
        settings.reminderTime = time
        saveData()
    }

    func setProfilePhoto(data: Data) {
        guard let path = store.saveImageData(data) else { return }
        profile.profileImagePath = path
        profileImage = UIImage(data: data)
        saveData()
    }

    func logReadingSession(article: Article, durationSeconds: Int, wordCount: Int) {
        let safeDuration = max(1, durationSeconds)
        let minutesRead = max(1, Int(round(Double(safeDuration) / 60.0)))
        let pagesRead = max(1, Int(round(Double(max(wordCount, 0)) / 300.0)))

        let newSession = ProfileReadingSession(
            id: UUID().uuidString,
            date: Date(),
            minutesRead: minutesRead,
            pagesRead: pagesRead,
            durationSeconds: safeDuration,
            wordCount: max(0, wordCount),
            articleID: article.id,
            articleURL: article.sourceURL,
            subjectTags: article.topicIDs,
            bookID: nil
        )

        sessions.insert(newSession, at: 0)
        saveData()
    }

    private func loadData() {
        isLoading = true
        let payload = store.load()
        profile = payload.profile
        settings = payload.settings
        sessions = payload.sessions
        currentReads = payload.currentReads
        social = payload.social

        if let data = store.loadImageData(fromRelativePath: profile.profileImagePath) {
            profileImage = UIImage(data: data)
        }

        isLoading = false
    }

    private func saveData() {
        store.save(
            ProfileLocalData(
                profile: profile,
                settings: settings,
                sessions: sessions,
                currentReads: currentReads,
                social: social
            )
        )
    }

    private func minutes(on date: Date) -> Int {
        let calendar = Calendar.current
        return sessions
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + max($1.minutesRead, 0) }
    }

    private func pages(on date: Date) -> Int {
        let calendar = Calendar.current
        return sessions
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + max($1.pagesRead, 0) }
    }

    private func totalMinutes(lastNDays days: Int) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<days).reduce(0) { partial, offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return partial }
            return partial + minutes(on: day)
        }
    }
}

extension AppThemePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
