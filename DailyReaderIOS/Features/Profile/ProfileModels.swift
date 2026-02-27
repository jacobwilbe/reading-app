import Foundation

enum ReadingGoalMode: String, Codable, CaseIterable, Identifiable {
    case minutes
    case pages

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minutes:
            return "Minutes"
        case .pages:
            return "Pages"
        }
    }
}

enum AppThemePreference: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        rawValue.capitalized
    }
}

enum AverageWindow: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case thirtyDays = 30

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .sevenDays:
            return "7d"
        case .thirtyDays:
            return "30d"
        }
    }
}

struct UserProfile: Codable {
    var username: String
    var bio: String
    var goalMode: ReadingGoalMode
    var goalAmount: Int
    var profileImagePath: String?
}

struct ProfileReadingSession: Identifiable, Codable, Hashable {
    var id: String
    var date: Date
    var minutesRead: Int
    var pagesRead: Int
    var durationSeconds: Int
    var wordCount: Int
    var articleID: String?
    var articleURL: String?
    var subjectTags: [String]
    var bookID: String?

    init(
        id: String,
        date: Date,
        minutesRead: Int,
        pagesRead: Int,
        durationSeconds: Int,
        wordCount: Int,
        articleID: String?,
        articleURL: String?,
        subjectTags: [String],
        bookID: String?
    ) {
        self.id = id
        self.date = date
        self.minutesRead = minutesRead
        self.pagesRead = pagesRead
        self.durationSeconds = durationSeconds
        self.wordCount = wordCount
        self.articleID = articleID
        self.articleURL = articleURL
        self.subjectTags = subjectTags
        self.bookID = bookID
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case minutesRead
        case pagesRead
        case durationSeconds
        case wordCount
        case articleID
        case articleURL
        case subjectTags
        case bookID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        minutesRead = try container.decode(Int.self, forKey: .minutesRead)
        pagesRead = try container.decode(Int.self, forKey: .pagesRead)
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
            ?? max(60, minutesRead * 60)
        wordCount = try container.decodeIfPresent(Int.self, forKey: .wordCount) ?? 0
        articleID = try container.decodeIfPresent(String.self, forKey: .articleID)
        articleURL = try container.decodeIfPresent(String.self, forKey: .articleURL)
        subjectTags = try container.decodeIfPresent([String].self, forKey: .subjectTags) ?? []
        bookID = try container.decodeIfPresent(String.self, forKey: .bookID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(minutesRead, forKey: .minutesRead)
        try container.encode(pagesRead, forKey: .pagesRead)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(wordCount, forKey: .wordCount)
        try container.encodeIfPresent(articleID, forKey: .articleID)
        try container.encodeIfPresent(articleURL, forKey: .articleURL)
        try container.encode(subjectTags, forKey: .subjectTags)
        try container.encodeIfPresent(bookID, forKey: .bookID)
    }
}

struct CurrentRead: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var author: String
    var progressPercent: Int
    var totalPages: Int
    var subjects: [String]
}

struct ProfileSettings: Codable {
    var theme: AppThemePreference
    var notificationsEnabled: Bool
    var reminderTime: Date
}

struct SocialStats: Codable {
    var followers: Int
    var following: Int
}

struct ProfileLocalData: Codable {
    var profile: UserProfile
    var settings: ProfileSettings
    var sessions: [ProfileReadingSession]
    var currentReads: [CurrentRead]
    var social: SocialStats

    static func seed(now: Date = Date()) -> ProfileLocalData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        func day(_ offset: Int, hour: Int) -> Date {
            let base = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
        }

        let reminder = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now

        return ProfileLocalData(
            profile: UserProfile(
                username: "ReaderOne",
                bio: "Reading a little every day.",
                goalMode: .minutes,
                goalAmount: 20,
                profileImagePath: nil
            ),
            settings: ProfileSettings(
                theme: .system,
                notificationsEnabled: true,
                reminderTime: reminder
            ),
            sessions: [
                ProfileReadingSession(id: UUID().uuidString, date: day(-6, hour: 8), minutesRead: 14, pagesRead: 11, durationSeconds: 840, wordCount: 1820, articleID: "book-1", articleURL: nil, subjectTags: ["AI", "Technology"], bookID: "book-1"),
                ProfileReadingSession(id: UUID().uuidString, date: day(-5, hour: 19), minutesRead: 22, pagesRead: 18, durationSeconds: 1320, wordCount: 2920, articleID: "book-2", articleURL: nil, subjectTags: ["History"], bookID: "book-2"),
                ProfileReadingSession(id: UUID().uuidString, date: day(-4, hour: 7), minutesRead: 0, pagesRead: 0, durationSeconds: 0, wordCount: 0, articleID: nil, articleURL: nil, subjectTags: ["Health"], bookID: nil),
                ProfileReadingSession(id: UUID().uuidString, date: day(-3, hour: 20), minutesRead: 31, pagesRead: 27, durationSeconds: 1860, wordCount: 4180, articleID: "book-3", articleURL: nil, subjectTags: ["Design"], bookID: "book-3"),
                ProfileReadingSession(id: UUID().uuidString, date: day(-2, hour: 12), minutesRead: 18, pagesRead: 14, durationSeconds: 1080, wordCount: 2440, articleID: "book-4", articleURL: nil, subjectTags: ["Space", "Science"], bookID: "book-4"),
                ProfileReadingSession(id: UUID().uuidString, date: day(-1, hour: 21), minutesRead: 26, pagesRead: 20, durationSeconds: 1560, wordCount: 3560, articleID: "book-1", articleURL: nil, subjectTags: ["AI", "Design"], bookID: "book-1"),
                ProfileReadingSession(id: UUID().uuidString, date: day(0, hour: 9), minutesRead: 17, pagesRead: 13, durationSeconds: 1020, wordCount: 2260, articleID: "book-2", articleURL: nil, subjectTags: ["History", "Culture"], bookID: "book-2")
            ],
            currentReads: [
                CurrentRead(id: "book-1", title: "Designing Intelligent Interfaces", author: "M. Torres", progressPercent: 64, totalPages: 320, subjects: ["AI", "Design"]),
                CurrentRead(id: "book-2", title: "Cities of the Ancient World", author: "L. Harper", progressPercent: 38, totalPages: 410, subjects: ["History"]),
                CurrentRead(id: "book-3", title: "The Space Systems Handbook", author: "A. Nori", progressPercent: 82, totalPages: 280, subjects: ["Space", "Science"]),
                CurrentRead(id: "book-4", title: "Metabolic Health Basics", author: "C. Lin", progressPercent: 24, totalPages: 260, subjects: ["Health"])
            ],
            social: SocialStats(followers: 124, following: 67)
        )
    }
}

struct DayActivity: Identifiable {
    let id: String
    let date: Date
    let minutes: Int
}

struct AchievementProgress: Identifiable {
    let id: String
    let title: String
    let description: String
    let symbolName: String
    let earned: Bool
}
