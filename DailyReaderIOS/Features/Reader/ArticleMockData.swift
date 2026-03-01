import Foundation

enum ArticleMockData {
    static let mockArticleBlocks: [ArticleBlock] = {
        let opening = [
            ArticleBlock.heading("Why Reading Still Matters"),
            ArticleBlock.paragraph("Reading remains one of the most reliable ways to train attention in a distracted world. A good page asks for steady focus, and in return it builds the habit of following an idea all the way to its conclusion."),
            ArticleBlock.paragraph("Researchers often describe deep reading as a full-stack exercise for the mind: comprehension, memory, inference, and emotional simulation all happen at once. The more frequently that stack runs, the easier it becomes to think clearly under pressure."),
            ArticleBlock.image(name: "reading-focus", caption: "A short daily session builds long-term concentration."),
            ArticleBlock.heading("Build a Sustainable Reading Ritual"),
            ArticleBlock.paragraph("Most people fail at reading goals for one simple reason: they plan heroic sessions and ignore ordinary days. A ten-minute ritual, repeated on weekdays and weekends, beats an ambitious two-hour plan that only happens twice a month."),
            ArticleBlock.paragraph("Start by anchoring reading to an existing trigger. Read after coffee. Read before commuting. Read after dinner. The exact trigger matters less than consistency. Over time, your brain learns to expect that transition and starts the session with less resistance."),
            ArticleBlock.image(name: "reading-routine", caption: "Ritual design makes reading automatic instead of motivational.")
        ]

        let cycleParagraphs = [
            "When a book feels difficult, reduce friction before reducing ambition. Increase line spacing. Lower visual clutter. Choose a calmer environment. Difficulty is not always intellectual; often it is ergonomic.",
            "Progress compounds when you keep retrieval active. At the end of each session, write one sentence about what changed in your understanding. This tiny recap improves retention and gives tomorrow's session a better starting point.",
            "Reading speed is not the target. Reading quality is. Slow down around dense sections, then speed up through familiar material. Flexible pacing is usually more effective than maintaining one constant speed for every page.",
            "Discussion sharpens interpretation. If you can explain an argument to another person, you probably understand it. If you cannot explain it yet, you have a useful signal about where to reread.",
            "Many readers underestimate the effect of format. Some topics are easier in print-like layouts, while others work well on screens. The best format is the one that preserves your attention from first paragraph to final sentence.",
            "A weekly review is enough for most people. Look back at what you read, identify one idea worth applying, and schedule one next reading block. This closes the loop from information to action."
        ]

        var repeated: [ArticleBlock] = []
        for index in 0..<7 {
            repeated.append(.heading("Practical Strategy \(index + 1)"))
            repeated.append(.paragraph(cycleParagraphs[index % cycleParagraphs.count]))
            repeated.append(.paragraph(cycleParagraphs[(index + 1) % cycleParagraphs.count]))
            if index == 2 {
                repeated.append(.image(name: "reading-notes", caption: "Simple notes improve recall and reflection."))
            }
            if index == 5 {
                repeated.append(.image(name: "reading-night", caption: "Low-light evening reading can still be comfortable with the right theme."))
            }
        }

        let ending = [
            ArticleBlock.heading("From Pages to Practice"),
            ArticleBlock.paragraph("The purpose of reading is not to finish more pages. It is to think better, decide better, and live with more intention. When your reading habit is aligned with real decisions in your week, it stops feeling optional and starts feeling essential."),
            ArticleBlock.paragraph("Use this article as a template: choose one idea, test it for seven days, and record what changed. Repeat that cycle and your reading life will keep paying dividends long after the chapter ends.")
        ]

        return opening + repeated + ending
    }()

    static let mockArticle = Article(
        id: "mock-local-reader",
        title: "The Better Reading System",
        sourceName: "Daily Reader Lab",
        sourceURL: "mock://daily-reader/rich-reader-demo-v2",
        topicIDs: ["history", "design", "health"],
        estimatedMinutes: 28,
        freshnessScore: 1.0,
        qualityScore: 0.95,
        summary: "A long-form local demo article about reading habits, with multiple pages and inline images for reader testing.",
        richBlocks: mockArticleBlocks
    )

    static let mockBodyText: String = {
        textBlocks(from: mockArticleBlocks).joined(separator: "\n\n")
    }()

    static func textBlocks(from blocks: [ArticleBlock]) -> [String] {
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
    }
}
