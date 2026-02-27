import Foundation

struct Topic: Identifiable, Hashable {
    let id: String
    let name: String
}

enum ArticleBlock: Hashable {
    case heading(String)
    case paragraph(String)
    case image(name: String, caption: String)
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
    let richBlocks: [ArticleBlock]?

    init(
        id: String,
        title: String,
        sourceName: String,
        sourceURL: String,
        topicIDs: [String],
        estimatedMinutes: Int,
        freshnessScore: Double,
        qualityScore: Double,
        summary: String,
        richBlocks: [ArticleBlock]? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.topicIDs = topicIDs
        self.estimatedMinutes = estimatedMinutes
        self.freshnessScore = freshnessScore
        self.qualityScore = qualityScore
        self.summary = summary
        self.richBlocks = richBlocks
    }
}

struct ReadingSession: Identifiable {
    let id: String
    let articleID: String
    let articleURL: String?
    let startedAt: Date
    let completedAt: Date?
    let durationSeconds: Int
    let minutesSpent: Int
    let wordCount: Int
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
