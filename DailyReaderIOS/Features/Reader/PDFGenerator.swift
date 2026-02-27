import Foundation
import UIKit
import CryptoKit
import PDFKit

struct CachedReaderDocument {
    let pdfURL: URL
    let bodyText: String
    let wordCount: Int
}

private struct ReaderPDFMetadata: Codable {
    let sourceURL: String
    let wordCount: Int
    let bodyText: String
    let generatedAt: Date
    let settingsKey: String
}

struct GeneratedReaderDocument {
    let pdfURL: URL
}

struct PDFGenerator {
    private let layoutVersion = "v5_books_page_numbers"

    func cachedDocument(for article: Article, settings: ReaderSettings) -> CachedReaderDocument? {
        let urls = cacheURLs(for: article.sourceURL, settings: settings)

        guard
            FileManager.default.fileExists(atPath: urls.pdfURL.path),
            let data = try? Data(contentsOf: urls.metaURL),
            let metadata = try? JSONDecoder().decode(ReaderPDFMetadata.self, from: data)
        else {
            return nil
        }

        return CachedReaderDocument(pdfURL: urls.pdfURL, bodyText: metadata.bodyText, wordCount: metadata.wordCount)
    }

    func generatePDF(from content: ReaderArticleContent, settings: ReaderSettings) throws -> GeneratedReaderDocument {
        let urls = cacheURLs(for: content.article.sourceURL, settings: settings)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let screenBounds = UIScreen.main.bounds
        let pageWidth = min(screenBounds.width, screenBounds.height)
        let pageHeight = max(screenBounds.width, screenBounds.height)
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let sideMargin: CGFloat = 24
        let topMargin: CGFloat = 34
        let bottomMargin: CGFloat = 36
        let contentWidth = pageRect.width - (sideMargin * 2)
        let pageBottom = pageRect.height - bottomMargin

        let titleFont = settings.fontFamily.uiFont(size: min(CGFloat(settings.fontSize + 12), 34), weight: .bold)
        let metaFont = settings.fontFamily.uiFont(size: max(CGFloat(settings.fontSize - 2), 13), weight: .medium)
        let headingFont = settings.fontFamily.uiFont(size: CGFloat(settings.fontSize + 5), weight: .semibold)
        let bodyFont = settings.fontFamily.uiFont(size: CGFloat(settings.fontSize), weight: .regular)
        let captionFont = settings.fontFamily.uiFont(size: max(CGFloat(settings.fontSize - 3), 12), weight: .regular)

        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineBreakMode = .byWordWrapping
        bodyParagraph.lineSpacing = max(4, CGFloat(settings.fontSize) * 0.33)
        bodyParagraph.paragraphSpacing = max(10, CGFloat(settings.fontSize) * 0.62)

        let headingParagraph = NSMutableParagraphStyle()
        headingParagraph.lineBreakMode = .byWordWrapping
        headingParagraph.lineSpacing = 3
        headingParagraph.paragraphSpacing = 12

        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.lineBreakMode = .byWordWrapping
        titleParagraph.lineSpacing = 3
        titleParagraph.paragraphSpacing = 10

        let metaParagraph = NSMutableParagraphStyle()
        metaParagraph.lineBreakMode = .byWordWrapping
        metaParagraph.lineSpacing = 2
        metaParagraph.paragraphSpacing = 18

        let captionParagraph = NSMutableParagraphStyle()
        captionParagraph.lineBreakMode = .byWordWrapping
        captionParagraph.alignment = .center
        captionParagraph.lineSpacing = 2

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: settings.theme.textColor,
            .paragraphStyle: titleParagraph
        ]

        let metaAttributes: [NSAttributedString.Key: Any] = [
            .font: metaFont,
            .foregroundColor: settings.theme.secondaryTextColor,
            .paragraphStyle: metaParagraph
        ]

        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: headingFont,
            .foregroundColor: settings.theme.textColor,
            .paragraphStyle: headingParagraph
        ]

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: settings.theme.textColor,
            .paragraphStyle: bodyParagraph
        ]

        let captionAttributes: [NSAttributedString.Key: Any] = [
            .font: captionFont,
            .foregroundColor: settings.theme.secondaryTextColor,
            .paragraphStyle: captionParagraph
        ]

        let dateText = DateFormatter.localizedString(from: content.fetchedAt, dateStyle: .medium, timeStyle: .short)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        try renderer.writePDF(to: urls.pdfURL) { context in
            var currentY = topMargin
            var hasPage = false

            func beginNewPage() {
                context.beginPage()
                context.cgContext.setFillColor(settings.theme.pageBackgroundColor.cgColor)
                context.cgContext.fill(pageRect)
                currentY = topMargin
                hasPage = true
            }

            func drawAttributedBlock(_ attributed: NSAttributedString, extraSpacing: CGFloat) {
                var currentIndex = 0

                while currentIndex < attributed.length {
                    if !hasPage {
                        beginNewPage()
                    }

                    let availableHeight = pageBottom - currentY
                    if availableHeight < 40 {
                        beginNewPage()
                        continue
                    }

                    let drawingRect = CGRect(
                        x: sideMargin,
                        y: currentY,
                        width: contentWidth,
                        height: availableHeight
                    )
                    let remaining = attributed.attributedSubstring(
                        from: NSRange(location: currentIndex, length: attributed.length - currentIndex)
                    )
                    let fittingLength = maxFittingLength(for: remaining, width: contentWidth, maxHeight: availableHeight)
                    guard fittingLength > 0 else {
                        beginNewPage()
                        continue
                    }

                    let drawnSubstring = remaining.attributedSubstring(from: NSRange(location: 0, length: fittingLength))
                    drawnSubstring.draw(
                        with: drawingRect,
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )

                    let measuredHeight = measuredHeight(for: drawnSubstring, width: contentWidth)
                    currentY += measuredHeight + extraSpacing
                    currentIndex += fittingLength

                    if currentIndex < attributed.length {
                        beginNewPage()
                    }
                }
            }

            func drawImage(name: String, caption: String) {
                if !hasPage {
                    beginNewPage()
                }

                let sourceImage = placeholderImage(named: name, theme: settings.theme)
                let maxWidth = contentWidth
                let maxHeight = pageRect.height * 0.34
                let imageSize = fittedSize(for: sourceImage.size, maxWidth: maxWidth, maxHeight: maxHeight)

                let captionText = NSAttributedString(string: caption, attributes: captionAttributes)
                let captionHeight = measuredHeight(for: captionText, width: contentWidth)
                let requiredHeight = imageSize.height + 8 + captionHeight + 20

                if currentY + requiredHeight > pageBottom {
                    beginNewPage()
                }

                let imageRect = CGRect(
                    x: sideMargin + ((contentWidth - imageSize.width) / 2),
                    y: currentY,
                    width: imageSize.width,
                    height: imageSize.height
                )
                sourceImage.draw(in: imageRect)

                let captionRect = CGRect(
                    x: sideMargin,
                    y: imageRect.maxY + 8,
                    width: contentWidth,
                    height: captionHeight
                )
                captionText.draw(with: captionRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)

                currentY = captionRect.maxY + 16
            }

            let title = NSAttributedString(string: "\(content.article.title)\n", attributes: titleAttributes)
            let meta = NSAttributedString(string: "\(content.article.sourceName) · \(dateText)\n", attributes: metaAttributes)
            drawAttributedBlock(title, extraSpacing: 0)
            drawAttributedBlock(meta, extraSpacing: 8)

            for block in content.blocks {
                switch block {
                case .heading(let heading):
                    let headingText = NSAttributedString(string: "\(heading)\n", attributes: headingAttributes)
                    drawAttributedBlock(headingText, extraSpacing: 8)
                case .paragraph(let paragraph):
                    let paragraphText = NSAttributedString(string: "\(paragraph)\n", attributes: bodyAttributes)
                    drawAttributedBlock(paragraphText, extraSpacing: 8)
                case .image(let name, let caption):
                    drawImage(name: name, caption: caption)
                }
            }
        }
        addPageNumbers(to: urls.pdfURL, theme: settings.theme, font: captionFont)

        let metadata = ReaderPDFMetadata(
            sourceURL: content.article.sourceURL,
            wordCount: content.wordCount,
            bodyText: content.bodyText,
            generatedAt: Date(),
            settingsKey: settings.cacheKey
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadata)
        try data.write(to: urls.metaURL, options: .atomic)

        return GeneratedReaderDocument(pdfURL: urls.pdfURL)
    }

    private func addPageNumbers(to url: URL, theme: ReaderTheme, font: UIFont) {
        guard let document = PDFDocument(url: url) else { return }
        let totalPages = document.pageCount

        for index in 0..<totalPages {
            guard let page = document.page(at: index) else { continue }

            for annotation in page.annotations where annotation.userName == "reader-page-number" {
                page.removeAnnotation(annotation)
            }

            let label = "Page \(index + 1) of \(totalPages)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: theme.secondaryTextColor
            ]
            let textSize = (label as NSString).size(withAttributes: attributes)
            let pageBounds = page.bounds(for: .mediaBox)
            let rect = CGRect(
                x: (pageBounds.width - textSize.width - 16) / 2,
                y: 8,
                width: textSize.width + 16,
                height: textSize.height + 4
            )

            let annotation = PDFAnnotation(bounds: rect, forType: .freeText, withProperties: nil)
            annotation.userName = "reader-page-number"
            annotation.contents = label
            annotation.font = font
            annotation.fontColor = theme.secondaryTextColor
            annotation.color = .clear
            annotation.alignment = .center
            annotation.shouldDisplay = true
            annotation.shouldPrint = true
            page.addAnnotation(annotation)
        }

        _ = document.write(to: url)
    }

    private func fittedSize(for size: CGSize, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0 else {
            return CGSize(width: maxWidth, height: maxHeight * 0.6)
        }

        let widthRatio = maxWidth / size.width
        let heightRatio = maxHeight / size.height
        let ratio = min(widthRatio, heightRatio)
        return CGSize(width: size.width * ratio, height: size.height * ratio)
    }

    private func measuredHeight(for attributed: NSAttributedString, width: CGFloat) -> CGFloat {
        let rect = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(rect.height)
    }

    private func maxFittingLength(for attributed: NSAttributedString, width: CGFloat, maxHeight: CGFloat) -> Int {
        guard attributed.length > 0 else { return 0 }

        if measuredHeight(for: attributed, width: width) <= maxHeight {
            return attributed.length
        }

        var low = 1
        var high = attributed.length
        var best = 0

        while low <= high {
            let mid = (low + high) / 2
            let sample = attributed.attributedSubstring(from: NSRange(location: 0, length: mid))
            let height = measuredHeight(for: sample, width: width)

            if height <= maxHeight {
                best = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return best
    }

    private func placeholderImage(named name: String, theme: ReaderTheme) -> UIImage {
        let size = CGSize(width: 1200, height: 720)
        let renderer = UIGraphicsImageRenderer(size: size)

        let palette: [(UIColor, UIColor)] = [
            (UIColor(red: 0.33, green: 0.50, blue: 0.78, alpha: 1.0), UIColor(red: 0.21, green: 0.33, blue: 0.58, alpha: 1.0)),
            (UIColor(red: 0.76, green: 0.48, blue: 0.32, alpha: 1.0), UIColor(red: 0.58, green: 0.30, blue: 0.18, alpha: 1.0)),
            (UIColor(red: 0.29, green: 0.62, blue: 0.48, alpha: 1.0), UIColor(red: 0.17, green: 0.42, blue: 0.33, alpha: 1.0)),
            (UIColor(red: 0.56, green: 0.43, blue: 0.74, alpha: 1.0), UIColor(red: 0.36, green: 0.26, blue: 0.54, alpha: 1.0))
        ]

        let index = abs(name.hashValue) % palette.count
        let colors = palette[index]

        return renderer.image { ctx in
            let cgContext = ctx.cgContext

            let backgroundRect = CGRect(origin: .zero, size: size)
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [colors.0.cgColor, colors.1.cgColor] as CFArray,
                locations: [0, 1]
            )

            if let gradient {
                cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            } else {
                cgContext.setFillColor(colors.0.cgColor)
                cgContext.fill(backgroundRect)
            }

            if theme == .dark {
                cgContext.setFillColor(UIColor.black.withAlphaComponent(0.22).cgColor)
                cgContext.fill(backgroundRect)
            }

            let cardRect = CGRect(x: 110, y: 120, width: size.width - 220, height: size.height - 240)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 30)
            UIColor.white.withAlphaComponent(theme == .dark ? 0.12 : 0.22).setFill()
            cardPath.fill()

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 66, weight: .bold),
                .foregroundColor: UIColor.white
            ]

            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92)
            ]

            let title = name
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
            let subtitle = "Daily Reader Illustration"

            NSString(string: title).draw(
                in: CGRect(x: cardRect.minX + 52, y: cardRect.minY + 100, width: cardRect.width - 104, height: 120),
                withAttributes: titleAttributes
            )
            NSString(string: subtitle).draw(
                in: CGRect(x: cardRect.minX + 52, y: cardRect.minY + 210, width: cardRect.width - 104, height: 80),
                withAttributes: subtitleAttributes
            )
        }
    }

    private func cacheURLs(for url: String, settings: ReaderSettings) -> (pdfURL: URL, metaURL: URL) {
        let key = "\(layoutVersion)|\(settings.cacheKey)|\(url)"
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        let pdfURL = cacheDirectory.appendingPathComponent("\(hash).pdf")
        let metaURL = cacheDirectory.appendingPathComponent("\(hash).json")
        return (pdfURL, metaURL)
    }

    private var cacheDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("ReaderPDFCache", isDirectory: true)
    }
}
