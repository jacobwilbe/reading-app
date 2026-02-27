import Foundation

struct ReaderArticleContent {
    let article: Article
    let fetchedAt: Date
    let blocks: [ArticleBlock]

    var bodyText: String {
        blocks.compactMap { block in
            switch block {
            case .heading(let heading):
                return heading
            case .paragraph(let paragraph):
                return paragraph
            case .image:
                return nil
            }
        }
        .joined(separator: "\n\n")
    }

    var wordCount: Int {
        bodyText
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }
}

struct ReaderPreparedDocument {
    let pdfURL: URL
    let bodyText: String
    let wordCount: Int
    let usedMockFallback: Bool
    let fallbackErrorMessage: String?
}

enum ReaderError: Error {
    case invalidURL
    case emptyBody
}

struct ArticleContentFetcher {
    func fetchContent(for article: Article) async throws -> ReaderArticleContent {
        if article.sourceURL.hasPrefix("mock://") || article.id == ArticleMockData.mockArticle.id {
            return ReaderArticleContent(
                article: article,
                fetchedAt: Date(),
                blocks: article.richBlocks ?? [.paragraph(ArticleMockData.mockBodyText)]
            )
        }

        guard let url = URL(string: article.sourceURL) else {
            throw ReaderError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let html = String(decoding: data, as: UTF8.self)
        let extracted = extractReadableText(from: html)

        guard !extracted.isEmpty else {
            throw ReaderError.emptyBody
        }

        return ReaderArticleContent(
            article: article,
            fetchedAt: Date(),
            blocks: textBlocks(from: extracted)
        )
    }

    private func textBlocks(from text: String) -> [ArticleBlock] {
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if paragraphs.isEmpty {
            return [.paragraph(text)]
        }

        return paragraphs.map { .paragraph($0) }
    }

    private func extractReadableText(from html: String) -> String {
        let primaryBlock =
            extractTagContent(from: html, tag: "article") ??
            extractTagContent(from: html, tag: "main") ??
            html

        let cleanedBlock = primaryBlock
            .replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<style[\\s\\S]*?</style>", with: " ", options: .regularExpression)

        let paragraphMatches = regexMatches(pattern: "<p[^>]*>([\\s\\S]*?)</p>", in: cleanedBlock)
        let paragraphText: String

        if paragraphMatches.isEmpty {
            paragraphText = cleanedBlock.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        } else {
            paragraphText = paragraphMatches.joined(separator: "\n\n")
        }

        return decodeHTMLEntities(in: paragraphText)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTagContent(from text: String, tag: String) -> String? {
        let pattern = "<\(tag)[^>]*>([\\s\\S]*?)</\(tag)>"
        guard let match = regexMatches(pattern: pattern, in: text).first else {
            return nil
        }
        return match
    }

    private func regexMatches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let valueRange = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[valueRange])
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        }
    }

    private func decodeHTMLEntities(in text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}

struct ReaderDocumentService {
    private let fetcher = ArticleContentFetcher()
    private let generator = PDFGenerator()

    func prepareDocument(for article: Article) async throws -> ReaderPreparedDocument {
        let settings = await MainActor.run { ReaderSettingsStore.shared.currentSettings }

        if let cached = generator.cachedDocument(for: article, settings: settings) {
            return ReaderPreparedDocument(
                pdfURL: cached.pdfURL,
                bodyText: cached.bodyText,
                wordCount: cached.wordCount,
                usedMockFallback: false,
                fallbackErrorMessage: nil
            )
        }

        do {
            let content = try await fetcher.fetchContent(for: article)
            let generated = try generator.generatePDF(from: content, settings: settings)

            return ReaderPreparedDocument(
                pdfURL: generated.pdfURL,
                bodyText: content.bodyText,
                wordCount: content.wordCount,
                usedMockFallback: false,
                fallbackErrorMessage: nil
            )
        } catch {
            let fallbackContent = ReaderArticleContent(
                article: Article(
                    id: article.id,
                    title: article.title,
                    sourceName: article.sourceName,
                    sourceURL: article.sourceURL,
                    topicIDs: article.topicIDs,
                    estimatedMinutes: article.estimatedMinutes,
                    freshnessScore: article.freshnessScore,
                    qualityScore: article.qualityScore,
                    summary: article.summary,
                    richBlocks: ArticleMockData.mockArticleBlocks
                ),
                fetchedAt: Date(),
                blocks: ArticleMockData.mockArticleBlocks
            )
            let generated = try generator.generatePDF(from: fallbackContent, settings: settings)

            return ReaderPreparedDocument(
                pdfURL: generated.pdfURL,
                bodyText: fallbackContent.bodyText,
                wordCount: fallbackContent.wordCount,
                usedMockFallback: true,
                fallbackErrorMessage: "Couldn't fetch this article, so a local demo article was opened instead."
            )
        }
    }
}
