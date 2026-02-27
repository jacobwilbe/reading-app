import SwiftUI

struct ReadSessionView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    let article: Article

    @State private var logged = false
    @State private var isLoadingDocument = false
    @State private var preparedDocument: ReaderPreparedDocument?
    @State private var showPDFReader = false
    @State private var activeAlert: ReaderAlert?

    private let readerService = ReaderDocumentService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 10) {
                    Label("\(article.estimatedMinutes) min", systemImage: "clock")
                    Label(article.sourceName, systemImage: "newspaper")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text(article.summary)
                    .font(.body)

                Button {
                    Task { await openArticleInApp() }
                } label: {
                    HStack {
                        if isLoadingDocument {
                            ProgressView()
                        }
                        Text(isLoadingDocument ? "Preparing reader..." : "Read in app")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingDocument)

                Button {
                    store.markArticleCompleted(article)
                    logged = true
                } label: {
                    Text(logged ? "Logged for today" : "Mark as read")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(logged)
            }
            .padding()
        }
        .navigationTitle("Reading")
        .fullScreenCover(isPresented: $showPDFReader) {
            if let preparedDocument {
                PDFReaderView(
                    fileURL: preparedDocument.pdfURL,
                    articleTitle: article.title,
                    onSessionComplete: { durationSeconds in
                        store.logInAppRead(
                            article: article,
                            durationSeconds: durationSeconds,
                            wordCount: preparedDocument.wordCount
                        )
                        profileViewModel.logReadingSession(
                            article: article,
                            durationSeconds: durationSeconds,
                            wordCount: preparedDocument.wordCount
                        )
                    },
                    onRefreshFormatting: {
                        await refreshReaderFormatting()
                    }
                )
            } else {
                Text("Unable to open reader.")
            }
        }
        .alert(item: $activeAlert) { alert in
            let title = alert.kind == .error ? "Reader error" : "Using fallback article"
            return Alert(
                title: Text(title),
                message: Text(alert.message),
                dismissButton: .cancel(Text("OK"))
            )
        }
    }

    private func openArticleInApp() async {
        isLoadingDocument = true
        defer { isLoadingDocument = false }

        do {
            let prepared = try await readerService.prepareDocument(for: article)
            preparedDocument = prepared
            if prepared.usedMockFallback, let message = prepared.fallbackErrorMessage {
                activeAlert = ReaderAlert(kind: .fallback, message: message)
            }
            showPDFReader = true
        } catch {
            activeAlert = ReaderAlert(
                kind: .error,
                message: "Could not prepare the in-app reader."
            )
        }
    }

    private func refreshReaderFormatting() async -> URL? {
        do {
            let prepared = try await readerService.prepareDocument(for: article)
            preparedDocument = prepared
            if prepared.usedMockFallback, let message = prepared.fallbackErrorMessage {
                activeAlert = ReaderAlert(kind: .fallback, message: message)
            }
            return prepared.pdfURL
        } catch {
            activeAlert = ReaderAlert(
                kind: .error,
                message: "Could not regenerate this article with the current settings."
            )
            return nil
        }
    }
}

private struct ReaderAlert: Identifiable {
    enum Kind {
        case error
        case fallback
    }

    let id = UUID()
    let kind: Kind
    let message: String
}
