import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var preferredMinutes: Int = 10
    @Published var selectedTopicID: String = "ai"
    @Published var selectedTopicLabel: String = "Artificial Intelligence"
    @Published var topicPrompt: String = ""
    @Published var randomTopicMode: Bool = false
    @Published var sessions: [ReadingSession] = []

    let topics: [Topic] = [
        Topic(id: "ai", name: "Artificial Intelligence"),
        Topic(id: "history", name: "History"),
        Topic(id: "health", name: "Health"),
        Topic(id: "design", name: "Design"),
        Topic(id: "space", name: "Space")
    ]

    let articles: [Article] = [
        Article(
            id: "a1",
            title: "How Small Language Models Win on Edge Devices",
            sourceName: "Tech Brief",
            sourceURL: "https://example.com/edge-llms",
            topicIDs: ["ai"],
            estimatedMinutes: 8,
            freshnessScore: 0.92,
            qualityScore: 0.85,
            summary: "A practical look at where compact AI models outperform larger hosted systems."
        ),
        Article(
            id: "a2",
            title: "Roman Roads and the Logistics Revolution",
            sourceName: "History Weekly",
            sourceURL: "https://example.com/roman-roads",
            topicIDs: ["history"],
            estimatedMinutes: 12,
            freshnessScore: 0.63,
            qualityScore: 0.88,
            summary: "How Roman road design changed trade, military movement, and administration."
        ),
        Article(
            id: "a3",
            title: "A Beginner's Guide to Zone 2 Training",
            sourceName: "Health Lab",
            sourceURL: "https://example.com/zone2",
            topicIDs: ["health"],
            estimatedMinutes: 7,
            freshnessScore: 0.80,
            qualityScore: 0.84,
            summary: "What Zone 2 actually means and how to build a realistic weekly routine."
        ),
        Article(
            id: "a4",
            title: "Color Systems That Make UI Work at Scale",
            sourceName: "Product Craft",
            sourceURL: "https://example.com/color-systems",
            topicIDs: ["design"],
            estimatedMinutes: 10,
            freshnessScore: 0.76,
            qualityScore: 0.91,
            summary: "A framework for creating robust color tokens across products."
        ),
        Article(
            id: "a5",
            title: "Why Pulsars Matter in Modern Astronomy",
            sourceName: "Orbit Journal",
            sourceURL: "https://example.com/pulsars",
            topicIDs: ["space"],
            estimatedMinutes: 9,
            freshnessScore: 0.73,
            qualityScore: 0.83,
            summary: "How pulsars help scientists measure cosmic distance and time."
        ),
        Article(
            id: "a6",
            title: "Prompt Evaluation Without Guesswork",
            sourceName: "Tech Brief",
            sourceURL: "https://example.com/prompt-eval",
            topicIDs: ["ai", "design"],
            estimatedMinutes: 11,
            freshnessScore: 0.95,
            qualityScore: 0.90,
            summary: "A repeatable process for testing prompts and measuring quality drift."
        ),
        Article(
            id: "a7",
            title: "The Public Health Story of Clean Water",
            sourceName: "Health Lab",
            sourceURL: "https://example.com/clean-water",
            topicIDs: ["health", "history"],
            estimatedMinutes: 13,
            freshnessScore: 0.58,
            qualityScore: 0.86,
            summary: "A short history of sanitation and why it transformed life expectancy."
        ),
        Article(
            id: "a8",
            title: "Satellite Constellations and Daily Life",
            sourceName: "Orbit Journal",
            sourceURL: "https://example.com/constellations",
            topicIDs: ["space", "ai"],
            estimatedMinutes: 6,
            freshnessScore: 0.89,
            qualityScore: 0.82,
            summary: "How low-earth orbit networks influence navigation, weather, and internet coverage."
        )
    ]

    private let userTopicWeights: [String: Double] = [
        "ai": 0.95,
        "design": 0.65,
        "space": 0.40,
        "history": 0.35,
        "health": 0.25
    ]

    func recommendations() -> [RankedArticle] {
        let seenIDs = Set(sessions.map { $0.articleID })
        let topicForScoring = randomTopicMode ? randomTopicID() : selectedTopicID

        let ranked = articles.map { article in
            let topicMatch = topicScore(for: article, topicID: topicForScoring)
            let timeFit = timeFitScore(for: article)
            let userInterest = userInterestScore(for: article)
            let novelty = seenIDs.contains(article.id) ? 0.10 : 0.95
            let freshness = article.freshnessScore

            let score = 0.40 * topicMatch
                + 0.25 * timeFit
                + 0.20 * userInterest
                + 0.10 * novelty
                + 0.05 * freshness

            return RankedArticle(
                id: article.id,
                article: article,
                score: score,
                topicMatch: topicMatch,
                timeFit: timeFit
            )
        }
        .sorted { $0.score > $1.score }

        var sourceCount: [String: Int] = [:]
        var results: [RankedArticle] = []

        for candidate in ranked {
            let count = sourceCount[candidate.article.sourceName, default: 0]
            if count >= 2 {
                continue
            }
            sourceCount[candidate.article.sourceName] = count + 1
            results.append(candidate)
            if results.count == 6 {
                break
            }
        }

        return results
    }

    func markArticleCompleted(_ article: Article) {
        let now = Date()
        sessions.insert(
            ReadingSession(
                id: UUID().uuidString,
                articleID: article.id,
                startedAt: now,
                completedAt: now,
                minutesSpent: article.estimatedMinutes,
                status: .completed
            ),
            at: 0
        )
    }

    func weeklyWrap() -> WeeklyWrap {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -6, to: now) ?? now

        let completedThisWeek = sessions.filter {
            $0.status == .completed && $0.startedAt >= weekAgo && $0.startedAt <= now
        }

        let totalMinutes = completedThisWeek.reduce(0) { $0 + $1.minutesSpent }
        let days = Set(completedThisWeek.map { dayKey(for: $0.startedAt) })

        var minutesByTopic: [String: Int] = [:]
        for session in completedThisWeek {
            guard let article = articles.first(where: { $0.id == session.articleID }) else { continue }
            for topicID in article.topicIDs {
                minutesByTopic[topicID, default: 0] += session.minutesSpent
            }
        }

        let topTopics = minutesByTopic
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { (topicID: $0.key, minutes: $0.value) }

        let topTopic = topTopics.first?.topicID ?? "ai"
        let fallbackTopic = topics.first(where: { $0.id != topTopic })?.name ?? "History"

        let suggestions = [
            "Keep momentum with one \(topicName(for: topTopic)) article under 10 minutes.",
            "Try one adjacent topic this week: \(fallbackTopic).",
            "Use random mode once for discovery."
        ]

        return WeeklyWrap(
            totalMinutes: totalMinutes,
            sessionsCompleted: completedThisWeek.count,
            streakDays: days.count,
            topTopics: topTopics,
            suggestions: suggestions
        )
    }

    func topicName(for id: String) -> String {
        topics.first(where: { $0.id == id })?.name ?? id.capitalized
    }

    func applyTopicPrompt() {
        let trimmed = topicPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()

        if normalized.isEmpty {
            randomTopicMode = true
            selectedTopicLabel = "Random"
            return
        }

        if normalized == "random" || normalized.contains("surprise") {
            randomTopicMode = true
            selectedTopicLabel = "Random"
            return
        }

        randomTopicMode = false
        selectedTopicLabel = trimmed

        if let directMatch = topics.first(where: {
            normalized == $0.id || normalized == $0.name.lowercased()
        }) {
            selectedTopicID = directMatch.id
            return
        }

        if let containsMatch = topics.first(where: {
            normalized.contains($0.id) || normalized.contains($0.name.lowercased())
        }) {
            selectedTopicID = containsMatch.id
            return
        }

        let keywordMap: [(String, String)] = [
            ("history", "history"),
            ("roman", "history"),
            ("ancient", "history"),
            ("sleep", "health"),
            ("fitness", "health"),
            ("health", "health"),
            ("design", "design"),
            ("ui", "design"),
            ("space", "space"),
            ("nasa", "space"),
            ("ai", "ai"),
            ("machine learning", "ai"),
            ("technology", "ai")
        ]

        if let mapped = keywordMap.first(where: { normalized.contains($0.0) }) {
            selectedTopicID = mapped.1
        }
    }

    private func topicScore(for article: Article, topicID: String) -> Double {
        article.topicIDs.contains(topicID) ? 1.0 : 0.0
    }

    private func timeFitScore(for article: Article) -> Double {
        let delta = abs(article.estimatedMinutes - preferredMinutes)
        let raw = 1.0 - (Double(delta) / max(Double(preferredMinutes), 1.0))
        return max(0.0, min(1.0, raw))
    }

    private func userInterestScore(for article: Article) -> Double {
        let total = article.topicIDs.reduce(0.0) { partial, topic in
            partial + (userTopicWeights[topic] ?? 0.2)
        }
        return max(0.0, min(1.0, total / Double(article.topicIDs.count)))
    }

    private func randomTopicID() -> String {
        topics.randomElement()?.id ?? selectedTopicID
    }

    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
