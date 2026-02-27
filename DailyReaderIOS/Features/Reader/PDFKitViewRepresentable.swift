import SwiftUI
import PDFKit

struct PDFKitViewRepresentable: UIViewRepresentable {
    let fileURL: URL
    let theme: ReaderTheme
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var zoomScale: Double
    @Binding var upwardScrollTick: Int

    private let minRelativeZoom: CGFloat = 0.8
    private let maxRelativeZoom: CGFloat = 2.5

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = false
        view.backgroundColor = theme.pageBackgroundColor
        view.usePageViewController(true, withViewOptions: nil)
        view.document = PDFDocument(url: fileURL)

        if let scrollView = view.subviews.compactMap({ $0 as? UIScrollView }).first {
            scrollView.contentInset = .zero
            scrollView.scrollIndicatorInsets = .zero
            scrollView.backgroundColor = .clear
            scrollView.alwaysBounceVertical = true
            scrollView.minimumZoomScale = 0.2
            scrollView.maximumZoomScale = 8.0
        }

        view.documentView?.backgroundColor = .clear
        context.coordinator.attach(to: view)
        context.coordinator.updatePageState()
        context.coordinator.configureScaleBounds()
        context.coordinator.applyZoomScale()
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        let previousURL = uiView.document?.documentURL
        if previousURL != fileURL {
            uiView.document = PDFDocument(url: fileURL)
            uiView.layoutDocumentView()
        }

        uiView.backgroundColor = theme.pageBackgroundColor
        uiView.documentView?.backgroundColor = .clear

        context.coordinator.parent = self
        context.coordinator.updatePageState()

        DispatchQueue.main.async {
            if previousURL != self.fileURL {
                self.ensureScaledToFit(uiView, coordinator: context.coordinator)
            }
            context.coordinator.configureScaleBounds()
            context.coordinator.applyZoomScale()
        }
    }

    private func ensureScaledToFit(_ pdfView: PDFView, coordinator: Coordinator) {
        pdfView.autoScales = true
        pdfView.layoutDocumentView()
        coordinator.configureScaleBounds()
    }

    final class Coordinator: NSObject {
        var parent: PDFKitViewRepresentable
        private weak var pdfView: PDFView?
        private var offsetObservation: NSKeyValueObservation?
        private var defaultScaleFactor: CGFloat = 1.0
        private var isApplyingScale = false
        private var lastObservedOffsetY: CGFloat = 0

        init(parent: PDFKitViewRepresentable) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
            offsetObservation?.invalidate()
        }

        func attach(to pdfView: PDFView) {
            self.pdfView = pdfView
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handlePageChange),
                name: Notification.Name.PDFViewPageChanged,
                object: pdfView
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleScaleChange),
                name: Notification.Name.PDFViewScaleChanged,
                object: pdfView
            )
            observeScrollEvents(from: pdfView)
        }

        private func observeScrollEvents(from pdfView: PDFView) {
            offsetObservation?.invalidate()
            guard let scrollView = pdfView.subviews.compactMap({ $0 as? UIScrollView }).first else { return }
            lastObservedOffsetY = scrollView.contentOffset.y
            offsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
                self?.handleOffsetChange(scrollView.contentOffset.y)
            }
        }

        private func handleOffsetChange(_ newOffsetY: CGFloat) {
            let delta = newOffsetY - lastObservedOffsetY
            lastObservedOffsetY = newOffsetY
            guard delta < -0.75 else { return }

            DispatchQueue.main.async {
                self.parent.upwardScrollTick += 1
            }
        }

        func configureScaleBounds() {
            guard let pdfView else { return }

            let fittedScale = max(pdfView.scaleFactorForSizeToFit, 0.01)
            if defaultScaleFactor <= 0 || abs(defaultScaleFactor - fittedScale) > 0.001 {
                defaultScaleFactor = fittedScale
            }

            pdfView.minScaleFactor = defaultScaleFactor * parent.minRelativeZoom
            pdfView.maxScaleFactor = defaultScaleFactor * parent.maxRelativeZoom
        }

        func applyZoomScale() {
            guard let pdfView else { return }
            let clampedMultiplier = CGFloat(min(max(parent.zoomScale, Double(parent.minRelativeZoom)), Double(parent.maxRelativeZoom)))
            let target = min(max(defaultScaleFactor * clampedMultiplier, pdfView.minScaleFactor), pdfView.maxScaleFactor)

            guard abs(pdfView.scaleFactor - target) > 0.001 else { return }
            isApplyingScale = true
            pdfView.scaleFactor = target
            isApplyingScale = false
        }

        @objc private func handlePageChange() {
            updatePageState()
        }

        @objc private func handleScaleChange() {
            guard let pdfView, !isApplyingScale else { return }
            guard defaultScaleFactor > 0 else { return }

            let rawMultiplier = pdfView.scaleFactor / defaultScaleFactor
            let clamped = min(max(rawMultiplier, parent.minRelativeZoom), parent.maxRelativeZoom)

            DispatchQueue.main.async {
                self.parent.zoomScale = Double(clamped)
            }
        }

        func updatePageState() {
            guard let pdfView else { return }
            let total = pdfView.document?.pageCount ?? 1
            let current: Int

            if
                let page = pdfView.currentPage,
                let document = pdfView.document
            {
                current = document.index(for: page) + 1
            } else {
                current = 1
            }

            DispatchQueue.main.async {
                self.parent.totalPages = max(1, total)
                self.parent.currentPage = max(1, min(current, total))
            }
        }
    }
}
