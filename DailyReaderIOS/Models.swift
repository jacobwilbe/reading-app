import Foundation

struct Topic: Identifiable, Hashable {
    let id: String
    let name: String
}

struct Article: Identifiable, Hashable {
    let id: String
    let title: String
    let sourceName: String
    let sourceURL: String
    let topicIDs: [String]
    let estimatedMinutes: Int
    let freshnessScore: Double
    let qualityScore: Double
    let summary: String
}

struct ReadingSession: Identifiable {
    let id: String
    let articleID: String
    let startedAt: Date
    let completedAt: Date?
    let minutesSpent: Int
    let status: Status

    enum Status: String {
        case started
        case completed
        case skipped
    }
}

struct RankedArticle: Identifiable {
    let id: String
    let article: Article
    let score: Double
    let topicMatch: Double
    let timeFit: Double
}

struct WeeklyWrap {
    let totalMinutes: Int
    let sessionsCompleted: Int
    let streakDays: Int
    let topTopics: [(topicID: String, minutes: Int)]
    let suggestions: [String]
}
