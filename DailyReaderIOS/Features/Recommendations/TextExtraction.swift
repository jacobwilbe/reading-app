import Foundation

struct WordCounter {
    static func countWords(in text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }
}

struct TextExtractor {
    func extractMainText(from html: String) -> String {
        let lowered = html.lowercased()
        let scoped =
            extractTagContent(from: lowered, originalHTML: html, tag: "article") ??
            extractTagContent(from: lowered, originalHTML: html, tag: "main") ??
            html

        let withoutScripts = scoped
            .replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<style[\\s\\S]*?</style>", with: " ", options: .regularExpression)

        let paragraphMatches = regexMatches(pattern: "<p[^>]*>([\\s\\S]*?)</p>", in: withoutScripts)
        let base = paragraphMatches.isEmpty
            ? withoutScripts.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            : paragraphMatches.joined(separator: "\n\n")

        return decodeHTMLEntities(base)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTagContent(from loweredHTML: String, originalHTML: String, tag: String) -> String? {
        guard let startRange = loweredHTML.range(of: "<\(tag)") else { return nil }
        guard let closeStart = loweredHTML.range(of: "</\(tag)>", range: startRange.lowerBound..<loweredHTML.endIndex) else { return nil }
        guard let openEnd = loweredHTML.range(of: ">", range: startRange.lowerBound..<loweredHTML.endIndex) else { return nil }
        let contentStart = openEnd.upperBound
        let contentRange = contentStart..<closeStart.lowerBound
        guard let mappedStart = contentStart.samePosition(in: originalHTML),
              let mappedEnd = closeStart.lowerBound.samePosition(in: originalHTML)
        else { return nil }
        let _ = contentRange
        return String(originalHTML[mappedStart..<mappedEnd])
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
            return String(text[valueRange]).replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        }
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
