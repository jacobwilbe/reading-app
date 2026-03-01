import Foundation

struct WikisourceConnector: RecommendationsConnector {
    let source: RecommendationSource = .wikisource
    private let http = ConnectorHTTPClient()

    func fetchCandidates(query: String, language: String) async throws -> [ArticleCandidate] {
        let lang = language.lowercased().isEmpty ? "en" : language.lowercased()
        var comps = URLComponents(string: "https://\(lang).wikisource.org/w/api.php")
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
            let articleURL = "https://\(lang).wikisource.org/wiki?curid=\(item.pageid)"
            return ArticleCandidate(
                id: "wikisource-\(item.pageid)",
                title: item.title,
                url: articleURL,
                source: .wikisource,
                date: nil,
                snippet: item.snippet.strippingHTMLTags(),
                licenseType: .publicDomain,
                language: lang,
                wordCount: nil,
                rawLengthFields: ["license_note": "Public Domain / varies"],
                extractionFailed: false
            )
        }
    }
}
