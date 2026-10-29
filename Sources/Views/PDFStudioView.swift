import SwiftUI
import PDFKit
import UIKit

/// Desktop-grade PDF studio and reader using Apple's native PDFKit framework ("TrollPDF").
struct PDFStudioView: View {
    let documentURL: URL
    @Environment(\.dismiss) private var dismiss

    @State private var pdfDocument: PDFDocument?
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1
    @State private var searchQuery: String = ""
    @State private var searchResults: [PDFSelection] = []
    @State private var currentMatchIndex: Int = 0
    @State private var isShowingSearch: Bool = false
    @State private var isSharing: Bool = false
    @State private var pdfViewRef = PDFView()

    var body: some View {
        VStack(spacing: 0) {
            // PDF Studio Top Toolbar
            topBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.sheet)

            Divider().background(Theme.rule)

            // Search Bar (if active)
            if isShowingSearch {
                searchBarView
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.paper)

                Divider().background(Theme.rule)
            }

            // PDF Canvas
            PDFKitRepresentedView(document: pdfDocument, pdfView: pdfViewRef, onPageChanged: { page, total in
                self.currentPage = page
                self.totalPages = total
            })
            .edgesIgnoringSafeArea(.bottom)

            Divider().background(Theme.rule)

            // Bottom Navigation & Page Scrubber Bar
            bottomBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.sheet)
        }
        .onAppear(perform: loadPDF)
        .sheet(isPresented: $isSharing) {
            ShareSheetView(activityItems: [documentURL])
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Done")
                        .font(Theme.sans(12))
                }
                .foregroundColor(Theme.inkSecondary)
            }

            Spacer()

            Text(documentURL.lastPathComponent)
                .font(Theme.mono(10.5, weight: .bold))
                .foregroundColor(Theme.ink)
                .lineLimit(1)

            Spacer()

            // Search Toggle
            Button(action: { withAnimation { isShowingSearch.toggle() } }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(isShowingSearch ? Theme.accent : Theme.inkSecondary)
            }

            // Share Button
            Button(action: { isSharing = true }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.inkSecondary)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBarView: some View {
        HStack(spacing: 8) {
            TextField("Find in PDF...", text: $searchQuery)
                .font(Theme.sans(12))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Theme.desk)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onSubmit {
                    performSearch()
                }

            if !searchResults.isEmpty {
                Text("\(currentMatchIndex + 1) of \(searchResults.count)")
                    .font(Theme.mono(10))
                    .foregroundColor(Theme.inkSecondary)

                Button(action: previousMatch) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12))
                }

                Button(action: nextMatch) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                }
            } else if !searchQuery.isEmpty {
                Text("No matches")
                    .font(Theme.mono(10))
                    .foregroundColor(Theme.inkTertiary)
            }

            Button(action: performSearch) {
                Text("Find")
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundColor(Theme.accent)
            }
        }
    }

    // MARK: - Bottom Scrubber Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Button(action: goToPreviousPage) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(currentPage > 1 ? Theme.ink : Theme.inkTertiary)
            }
            .disabled(currentPage <= 1)

            Text("Page \(currentPage) of \(totalPages)")
                .font(Theme.mono(11, weight: .bold))
                .foregroundColor(Theme.ink)

            Button(action: goToNextPage) {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(currentPage < totalPages ? Theme.ink : Theme.inkTertiary)
            }
            .disabled(currentPage >= totalPages)

            Spacer()

            Button(action: zoomIn) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.inkSecondary)
            }

            Button(action: zoomOut) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.inkSecondary)
            }
        }
    }

    // MARK: - PDFKit Actions

    private func loadPDF() {
        if let doc = PDFDocument(url: documentURL) {
            self.pdfDocument = doc
            self.totalPages = doc.pageCount
        }
    }

    private func goToPreviousPage() {
        guard let doc = pdfDocument, currentPage > 1 else { return }
        currentPage -= 1
        if let page = doc.page(at: currentPage - 1) {
            pdfViewRef.go(to: page)
        }
    }

    private func goToNextPage() {
        guard let doc = pdfDocument, currentPage < totalPages else { return }
        currentPage += 1
        if let page = doc.page(at: currentPage - 1) {
            pdfViewRef.go(to: page)
        }
    }

    private func zoomIn() {
        pdfViewRef.zoomIn(nil)
    }

    private func zoomOut() {
        pdfViewRef.zoomOut(nil)
    }

    private func performSearch() {
        guard let doc = pdfDocument, !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        let selections = doc.findString(searchQuery, withOptions: [.caseInsensitive])
        searchResults = selections
        currentMatchIndex = 0
        if let first = selections.first {
            pdfViewRef.go(to: first)
            pdfViewRef.setCurrentSelection(first, animate: true)
        }
    }

    private func nextMatch() {
        guard !searchResults.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % searchResults.count
        let sel = searchResults[currentMatchIndex]
        pdfViewRef.go(to: sel)
        pdfViewRef.setCurrentSelection(sel, animate: true)
    }

    private func previousMatch() {
        guard !searchResults.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + searchResults.count) % searchResults.count
        let sel = searchResults[currentMatchIndex]
        pdfViewRef.go(to: sel)
        pdfViewRef.setCurrentSelection(sel, animate: true)
    }
}

// MARK: - PDFKit View Representable

struct PDFKitRepresentedView: UIViewRepresentable {
    let document: PDFDocument?
    let pdfView: PDFView
    var onPageChanged: (Int, Int) -> Void

    func makeUIView(context: Context) -> PDFView {
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = Theme.deskUIColor

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document != document {
            uiView.document = document
            uiView.autoScales = true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPageChanged: onPageChanged)
    }

    class Coordinator: NSObject {
        var onPageChanged: (Int, Int) -> Void

        init(onPageChanged: @escaping (Int, Int) -> Void) {
            self.onPageChanged = onPageChanged
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pv = notification.object as? PDFView,
                  let page = pv.currentPage,
                  let doc = pv.document else { return }
            let index = doc.index(for: page) + 1
            onPageChanged(index, doc.pageCount)
        }
    }
}
