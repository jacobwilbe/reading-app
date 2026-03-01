import Foundation
import os

private let recommendationsLogger = Logger(subsystem: "DailyReaderIOS", category: "Recommendations")

actor RecommendationsCache {
    private struct Entry {
        let expiresAt: Date
        let value: RecommendationResult
    }

    private var storage: [String: Entry] = [:]

    func value(for key: String) -> RecommendationResult? {
        guard let entry = storage[key] else { return nil }
        if entry.expiresAt < Date() {
            storage.removeValue(forKey: key)
            return nil
        }
        return entry.value
    }

    func insert(_ value: RecommendationResult, key: String, ttl: TimeInterval) {
        storage[key] = Entry(expiresAt: Date().addingTimeInterval(ttl), value: value)
    }
}

struct RecommendationsService {
    private let connectors: [RecommendationsConnector]
    private let cache: RecommendationsCache
    private let extractor = TextExtractor()
    private let http = ConnectorHTTPClient()

    init(connectors: [RecommendationsConnector] = [
        WikisourceConnector(),
        WikipediaConnector(),
        InternetArchiveConnector(),
        ChroniclingAmericaConnector()
        // The Conversation omitted for now: stable search endpoint is inconsistent without site-side changes.
    ], cache: RecommendationsCache = RecommendationsCache()) {
        self.connectors = connectors
        self.cache = cache
    }

    func search(request: RecommendationRequest) async -> RecommendationResult {
        if request.mockMode {
            return mockResult(for: request)
        }

        if let cached = await cache.value(for: request.cacheKey) {
            recommendationsLogger.info("Cache hit for topic=\(request.topic, privacy: .public)")
            return cached
        }

        let expandedQueries = expandQueries(for: request.topic)
        var allCandidates: [ArticleCandidate] = []

        await withTaskGroup(of: [ArticleCandidate].self) { group in
            for connector in connectors {
                for query in expandedQueries {
                    group.addTask {
                        await fetchWithTimeout(connector: connector, query: query, language: request.language)
                    }
                }
            }

            for await result in group {
                allCandidates.append(contentsOf: result)
            }
        }

        let deduped = deduplicate(candidates: allCandidates)
        let enriched = await enrichWithWordCounts(candidates: deduped, language: request.language)
        let filtered = filterByTimeLicenseAndExclusions(candidates: enriched, request: request)
        let ranked = rank(candidates: filtered, request: request)

        let top = Array(ranked.prefix(3))
        let backups = Array(ranked.dropFirst(3).prefix(10))
        let output = RecommendationResult(topThree: top, backups: backups)
        await cache.insert(output, key: request.cacheKey, ttl: 60 * 30)
        return output
    }

    private func expandQueries(for topic: String) -> [String] {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [""] }

        var set: Set<String> = [trimmed]
        if trimmed.hasSuffix("s") {
            set.insert(String(trimmed.dropLast()))
        } else {
            set.insert(trimmed + "s")
        }

        let synonyms: [String: String] = [
            "stoicism": "stoic philosophy",
            "ai": "artificial intelligence",
            "history": "historical",
            "fitness": "exercise",
            "space": "astronomy"
        ]

        if let synonym = synonyms[trimmed.lowercased()] {
            set.insert(synonym)
        }

        return Array(set)
    }

    private func deduplicate(candidates: [ArticleCandidate]) -> [ArticleCandidate] {
        var seenURLs: Set<String> = []
        var seenTitles: Set<String> = []
        var output: [ArticleCandidate] = []

        for candidate in candidates {
            let normalizedURL = candidate.url.lowercased()
            let normalizedTitle = normalizeTitle(candidate.title)
            if seenURLs.contains(normalizedURL) || seenTitles.contains(normalizedTitle) {
                continue
            }
            seenURLs.insert(normalizedURL)
            seenTitles.insert(normalizedTitle)
            output.append(candidate)
        }

        return output
    }

    private func normalizeTitle(_ title: String) -> String {
        title.lowercased().replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
    }

    private func filterByTimeLicenseAndExclusions(candidates: [ArticleCandidate], request: RecommendationRequest) -> [ArticleCandidate] {
        let allowance = request.allowSlightlyOver ? 1 : 0
        let excluded = Set(request.excludedURLs.map { $0.lowercased() })

        return candidates.filter { candidate in
            if excluded.contains(candidate.url.lowercased()) {
                return false
            }
            guard request.licenseFilter.allows(candidate.licenseType) else { return false }
            guard let words = candidate.wordCount else { return true }
            let estimate = ReadingSpeedSettings.estimatedMinutes(wordCount: words, wpm: request.wpm)
            return estimate <= request.minutes + allowance
        }
    }

    private func rank(candidates: [ArticleCandidate], request: RecommendationRequest) -> [ArticleCandidate] {
        let topicTokens = tokenSet(request.topic)

        return candidates.sorted { lhs, rhs in
            score(candidate: lhs, topicTokens: topicTokens, request: request) > score(candidate: rhs, topicTokens: topicTokens, request: request)
        }
    }

    private func score(candidate: ArticleCandidate, topicTokens: Set<String>, request: RecommendationRequest) -> Double {
        let textTokens = tokenSet(candidate.title + " " + candidate.snippet)
        let overlap = topicTokens.intersection(textTokens).count
        let topicScore = topicTokens.isEmpty ? 0 : Double(overlap) / Double(topicTokens.count)

        let fitScore: Double
        if let words = candidate.wordCount {
            let minutes = ReadingSpeedSettings.estimatedMinutes(wordCount: words, wpm: request.wpm)
            let delta = abs(request.minutes - minutes)
            fitScore = max(0, 1.0 - (Double(delta) / Double(max(request.minutes, 1))))
        } else {
            fitScore = 0.15
        }

        var quality = 0.0
        if !candidate.snippet.isEmpty { quality += 0.2 }
        if candidate.date != nil { quality += 0.1 }
        if candidate.licenseType != .unknown { quality += 0.1 }
        if !candidate.extractionFailed { quality += 0.1 }

        let sourceBoost: Double
        switch candidate.source {
        case .wikisource: sourceBoost = 0.08
        case .wikipedia: sourceBoost = 0.06
        case .internetArchive: sourceBoost = 0.05
        case .chroniclingAmerica: sourceBoost = 0.04
        }

        let recencyBoost: Double
        if request.preferRecent, let date = candidate.date {
            let days = Date().timeIntervalSince(date) / 86_400
            recencyBoost = max(0, 0.1 - min(days / 3650, 0.1))
        } else {
            recencyBoost = 0
        }

        return (0.45 * topicScore) + (0.35 * fitScore) + quality + sourceBoost + recencyBoost
    }

    private func tokenSet(_ input: String) -> Set<String> {
        let normalized = input.lowercased().replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
        return Set(normalized.split(separator: " ").map(String.init).filter { $0.count > 1 })
    }

    private func enrichWithWordCounts(candidates: [ArticleCandidate], language: String) async -> [ArticleCandidate] {
        await withTaskGroup(of: ArticleCandidate.self, returning: [ArticleCandidate].self) { group in
            for candidate in candidates {
                group.addTask {
                    await enrichCandidate(candidate, language: language)
                }
            }

            var enriched: [ArticleCandidate] = []
            for await candidate in group {
                enriched.append(candidate)
            }
            return enriched
        }
    }

    private func enrichCandidate(_ candidate: ArticleCandidate, language: String) async -> ArticleCandidate {
        var updated = candidate
        if updated.wordCount != nil {
            return updated
        }

        guard let url = URL(string: candidate.url) else {
            updated.extractionFailed = true
            return updated
        }

        do {
            let data = try await http.data(from: url, timeout: 8)
            let html = String(decoding: data, as: UTF8.self)
            let text = extractor.extractMainText(from: html)
            let words = WordCounter.countWords(in: text)
            if words > 0 {
                updated.wordCount = words
                updated.extractionFailed = false
                if updated.snippet.isEmpty {
                    updated = ArticleCandidate(
                        id: updated.id,
                        title: updated.title,
                        url: updated.url,
                        source: updated.source,
                        date: updated.date,
                        snippet: String(text.prefix(220)),
                        licenseType: updated.licenseType,
                        language: language,
                        wordCount: words,
                        rawLengthFields: updated.rawLengthFields,
                        extractionFailed: false
                    )
                }
            } else {
                updated.extractionFailed = true
            }
        } catch {
            updated.extractionFailed = true
        }

        return updated
    }

    private func mockResult(for request: RecommendationRequest) -> RecommendationResult {
        let words = ReadingSpeedSettings.maxWords(minutes: request.minutes, wpm: request.wpm)
        let topic = request.topic.isEmpty ? "reading" : request.topic

        var all: [ArticleCandidate] = []
        for index in 1...6 {
            let source: RecommendationSource = index.isMultiple(of: 2) ? .wikipedia : .wikisource
            let license: LicenseType = index.isMultiple(of: 2) ? .creativeCommons : .publicDomain
            let candidate = ArticleCandidate(
                id: "mock-\(index)",
                title: "\(topic.capitalized) primer \(index)",
                url: "https://example.com/mock/\(index)",
                source: source,
                date: Date().addingTimeInterval(-Double(index) * 86_400),
                snippet: "Deterministic mock result #\(index) for UI testing.",
                licenseType: license,
                language: request.language,
                wordCount: max(120, words - (index * 80)),
                rawLengthFields: [:],
                extractionFailed: false
            )
            all.append(candidate)
        }

        let filtered = filterByTimeLicenseAndExclusions(candidates: all, request: request)
        let ranked = rank(candidates: filtered, request: request)
        return RecommendationResult(topThree: Array(ranked.prefix(3)), backups: Array(ranked.dropFirst(3).prefix(10)))
    }
}

private func fetchWithTimeout(connector: RecommendationsConnector, query: String, language: String) async -> [ArticleCandidate] {
    await withTaskGroup(of: [ArticleCandidate].self, returning: [ArticleCandidate].self) { group in
        group.addTask {
            do {
                let result = try await connector.fetchCandidates(query: query, language: language)
                recommendationsLogger.info("Connector=\(connector.source.rawValue, privacy: .public) success count=\(result.count)")
                return result
            } catch {
                recommendationsLogger.error("Connector=\(connector.source.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                return []
            }
        }

        group.addTask {
            try? await Task.sleep(for: .seconds(8))
            return []
        }

        let first = await group.next() ?? []
        group.cancelAll()
        return first
    }
}
