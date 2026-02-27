import SwiftUI

struct PDFReaderView: View {
    let articleTitle: String
    let onSessionComplete: (Int) -> Void
    let onRefreshFormatting: () async -> URL?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var readerSettings = ReaderSettingsStore.shared

    @State private var activeStart: Date = Date()
    @State private var accumulatedSeconds: TimeInterval = 0
    @State private var hasLoggedSession = false
    @State private var isTrackingActive = true
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var fileURL: URL
    @State private var upwardScrollTick = 0
    @State private var showCloseButton = false
    @State private var closeButtonVisibilityToken = 0

    init(
        fileURL: URL,
        articleTitle: String,
        onSessionComplete: @escaping (Int) -> Void,
        onRefreshFormatting: @escaping () async -> URL?
    ) {
        self._fileURL = State(initialValue: fileURL)
        self.articleTitle = articleTitle
        self.onSessionComplete = onSessionComplete
        self.onRefreshFormatting = onRefreshFormatting
    }

    var body: some View {
        GeometryReader { proxy in
            PDFKitViewRepresentable(
                fileURL: fileURL,
                theme: readerSettings.theme,
                currentPage: $currentPage,
                totalPages: $totalPages,
                zoomScale: $readerSettings.zoomScalePreference,
                upwardScrollTick: $upwardScrollTick
            )
            .ignoresSafeArea()
            .overlay(alignment: .topTrailing) {
                Button {
                    finishSessionIfNeeded()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(readerSettings.theme.overlayText)
                        .frame(width: 36, height: 36)
                        .background(readerSettings.theme.overlayBackground)
                        .clipShape(Circle())
                }
                .padding(.top, proxy.safeAreaInsets.top + 8)
                .padding(.trailing, 12)
                .opacity(showCloseButton ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: showCloseButton)
                .allowsHitTesting(showCloseButton)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        if value.translation.height < -12 {
                            revealCloseButton()
                        }
                    }
            )
            .onChange(of: upwardScrollTick) { _, _ in
                revealCloseButton()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .inactive:
                    pauseSessionTimer()
                case .background:
                    finishSessionIfNeeded()
                case .active:
                    resumeSessionTimer()
                @unknown default:
                    break
                }
            }
            .onDisappear {
                finishSessionIfNeeded()
            }
        }
    }

    private func revealCloseButton() {
        closeButtonVisibilityToken += 1
        let token = closeButtonVisibilityToken
        showCloseButton = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard token == closeButtonVisibilityToken else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                showCloseButton = false
            }
        }
    }

    private func pauseSessionTimer() {
        guard isTrackingActive else { return }
        let elapsed = Date().timeIntervalSince(activeStart)
        accumulatedSeconds += max(0, elapsed)
        isTrackingActive = false
    }

    private func resumeSessionTimer() {
        guard !isTrackingActive else { return }
        activeStart = Date()
        isTrackingActive = true
    }

    private func finishSessionIfNeeded() {
        guard !hasLoggedSession else { return }
        pauseSessionTimer()
        let seconds = max(1, Int(accumulatedSeconds.rounded()))
        onSessionComplete(seconds)
        hasLoggedSession = true
    }
}
