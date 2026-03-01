import Foundation

struct WikipediaConnector: RecommendationsConnector {
    let source: RecommendationSource = .wikipedia
    private let http = ConnectorHTTPClient()

    func fetchCandidates(query: String, language: String) async throws -> [ArticleCandidate] {
        let lang = language.lowercased().isEmpty ? "en" : language.lowercased()
        var comps = URLComponents(string: "https://\(lang).wikipedia.org/w/api.php")
        comps?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "search"),
            URLQueryItem(name: "srsearch", value: query),
            URLQueryItem(name: "srlimit", value: "10"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "utf8", value: "1")
        ]
        guard let url = comps?.url else { throw ConnectorError.badURL }

        let data = try await http.data(from: url)
        let decoded = try JSONDecoder().decode(MediaWikiSearchResponse.self, from: data)

        return decoded.query.search.map { item in
            let articleURL = "https://\(lang).wikipedia.org/wiki?curid=\(item.pageid)"
            return ArticleCandidate(
                id: "wikipedia-\(item.pageid)",
                title: item.title,
                url: articleURL,
                source: .wikipedia,
                date: nil,
                snippet: item.snippet.strippingHTMLTags(),
                licenseType: .creativeCommons,
                language: lang,
                wordCount: nil,
                rawLengthFields: [:],
                extractionFailed: false
            )
        }
    }
}
