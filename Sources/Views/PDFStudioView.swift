import SwiftUI
import PDFKit
import UIKit

/// Desktop-grade PDF studio and editor using Apple's native PDFKit framework ("TrollPDF").
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
    @State private var isShowingMarkupToolbar: Bool = true
    @State private var isShowingPageOrganizer: Bool = false
    @State private var isShowingSignatureManager: Bool = false
    @State private var isShowingDrawingCanvas: Bool = false
    @State private var isShowingAddTextAlert: Bool = false
    @State private var newAnnotationText: String = ""
    @State private var isSharing: Bool = false
    @State private var shareItems: [Any] = []
    @State private var isShowingSaveToast: Bool = false
    @State private var pdfViewRef = PDFView()

    @AppStorage("app_appearance") private var appearanceRaw: String = AppAppearance.system.rawValue

    private var currentAppearance: AppAppearance {
        AppAppearance(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar
            topBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
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

            // Markup Toolbar (if active)
            if isShowingMarkupToolbar {
                markupToolbarView
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Theme.paper)

                Divider().background(Theme.rule)
            }

            // PDF Canvas
            ZStack(alignment: .top) {
                PDFKitRepresentedView(document: pdfDocument, pdfView: pdfViewRef, onPageChanged: { page, total in
                    self.currentPage = page
                    self.totalPages = total
                })
                .edgesIgnoringSafeArea(.bottom)

                // Save feedback toast
                if isShowingSaveToast {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Changes Saved")
                            .font(Theme.sans(12, weight: .semibold))
                            .foregroundColor(Theme.ink)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.sheet)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            Divider().background(Theme.rule)

            // Bottom Navigation & Page Scrubber Bar
            bottomBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.sheet)
        }
        .onAppear(perform: loadPDF)
        .preferredColorScheme(currentAppearance.colorScheme)
        .sheet(isPresented: $isSharing) {
            ShareSheetView(activityItems: shareItems)
        }
        .sheet(isPresented: $isShowingPageOrganizer) {
            PDFPageOrganizerView(documentURL: documentURL) {
                loadPDF()
            }
        }
        .sheet(isPresented: $isShowingSignatureManager) {
            SignatureManagerSheet { signatureImage in
                stampSignature(signatureImage)
            }
        }
        .sheet(isPresented: $isShowingDrawingCanvas) {
            if let doc = pdfDocument, currentPage > 0, currentPage <= doc.pageCount,
               let page = doc.page(at: currentPage - 1) {
                PageMarkupCanvasView(page: page, pageIndex: currentPage - 1) {
                    refreshCurrentPage()
                }
            }
        }
        .alert("Add Text Box", isPresented: $isShowingAddTextAlert) {
            TextField("Enter annotation text", text: $newAnnotationText)
            Button("Add") {
                if !newAnnotationText.isEmpty {
                    addTextBox(newAnnotationText)
                    newAnnotationText = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newAnnotationText = ""
            }
        } message: {
            Text("Enter text to place onto the active page.")
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 8) {
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Done")
                        .font(Theme.sans(12))
                }
                .foregroundColor(Theme.inkSecondary)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Done, close PDF studio")

            Spacer()

            Text(documentURL.lastPathComponent)
                .font(Theme.mono(10.5, weight: .bold))
                .foregroundColor(Theme.ink)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            // Page Organizer Toggle
            Button(action: { isShowingPageOrganizer = true }) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.inkSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Page Organizer")
            .accessibilityHint("Manage, rotate, reorder, or delete pages")

            // Markup Toolbar Toggle
            Button(action: { withAnimation { isShowingMarkupToolbar.toggle() } }) {
                Image(systemName: "pencil.tip.crop.circle")
                    .font(.system(size: 15))
                    .foregroundColor(isShowingMarkupToolbar ? Theme.accent : Theme.inkSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Markup toolbar")
            .accessibilityAddTraits(isShowingMarkupToolbar ? .isSelected : [])

            // Search Toggle
            Button(action: { withAnimation { isShowingSearch.toggle() } }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(isShowingSearch ? Theme.accent : Theme.inkSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Search in PDF")
            .accessibilityAddTraits(isShowingSearch ? .isSelected : [])

            // Actions & Export Menu
            Menu {
                Button(action: saveInPlace) {
                    Label("Save Changes In-Place", systemImage: "square.and.arrow.down")
                }

                Button(action: exportFlattenedPDF) {
                    Label("Export Flattened PDF (Baked)", systemImage: "doc.badge.gearshape")
                }

                Button(action: shareStandardPDF) {
                    Label("Share Original PDF", systemImage: "square.and.arrow.up")
                }

                Divider()

                Picker("Appearance", selection: $appearanceRaw) {
                    ForEach(AppAppearance.allCases) { item in
                        Label(item.title, systemImage: item.iconName)
                            .tag(item.rawValue)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.inkSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More document actions and export")
        }
    }

    // MARK: - Markup Toolbar

    private var markupToolbarView: some View {
        HStack(spacing: 6) {
            // Draw on Page
            Button(action: { isShowingDrawingCanvas = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                    Text("Draw")
                }
                .font(Theme.sans(11, weight: .medium))
                .foregroundColor(Theme.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Theme.accentWash)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Draw freehand annotations on page")

            // Text Box
            Button(action: { isShowingAddTextAlert = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "character.textbox")
                    Text("Text")
                }
                .font(Theme.sans(11, weight: .medium))
                .foregroundColor(Theme.ink)
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Add text box")

            // Signature
            Button(action: { isShowingSignatureManager = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "signature")
                    Text("Sign")
                }
                .font(Theme.sans(11, weight: .medium))
                .foregroundColor(Theme.ink)
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Insert saved signature")

            Divider().frame(height: 18).background(Theme.rule)

            // Text Selection Markup
            Button(action: applyHighlight) {
                Image(systemName: "highlighter")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.inkSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Highlight selected text")

            Button(action: applyStrikeout) {
                Image(systemName: "strikethrough")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.inkSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Strikeout selected text")

            Button(action: applyUnderline) {
                Image(systemName: "underline")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.inkSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Underline selected text")

            Spacer()

            // Undo Last Annotation
            Button(action: undoLastAnnotation) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.inkSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Undo last annotation")
        }
    }

    // MARK: - Search Bar

    private var searchBarView: some View {
        HStack(spacing: 6) {
            TextField("Find in PDF...", text: $searchQuery)
                .font(Theme.sans(12))
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
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
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Previous match")

                Button(action: nextMatch) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Next match")
            } else if !searchQuery.isEmpty {
                Text("No matches")
                    .font(Theme.mono(10))
                    .foregroundColor(Theme.inkTertiary)
            }

            Button(action: performSearch) {
                Text("Find")
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Search")
        }
    }

    // MARK: - Bottom Scrubber Bar

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button(action: goToPreviousPage) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(currentPage > 1 ? Theme.ink : Theme.inkTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(currentPage <= 1)
            .accessibilityLabel("Previous page")

            Text("Page \(currentPage) of \(totalPages)")
                .font(Theme.mono(11, weight: .bold))
                .foregroundColor(Theme.ink)

            Button(action: goToNextPage) {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(currentPage < totalPages ? Theme.ink : Theme.inkTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(currentPage >= totalPages)
            .accessibilityLabel("Next page")

            Spacer()

            Button(action: zoomIn) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.inkSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Zoom in")

            Button(action: zoomOut) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.inkSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Zoom out")
        }
    }

    // MARK: - PDFKit Actions & Annotations

    private func loadPDF() {
        if let doc = PDFDocument(url: documentURL) {
            self.pdfDocument = doc
            self.totalPages = doc.pageCount
        }
    }

    private func refreshCurrentPage() {
        if let current = pdfViewRef.currentPage {
            let index = (pdfDocument?.index(for: current) ?? 0) + 1
            self.currentPage = index
            pdfViewRef.layoutDocumentView()
        }
    }

    private func saveInPlace() {
        guard let doc = pdfDocument else { return }
        doc.write(to: documentURL)
        Haptics.success()

        withAnimation {
            isShowingSaveToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                isShowingSaveToast = false
            }
        }
    }

    private func exportFlattenedPDF() {
        guard let doc = pdfDocument else { return }
        let flattenedData = PDFAnnotationHelper.flatten(document: doc)

        let baseName = documentURL.deletingPathExtension().lastPathComponent
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(baseName)_Flattened.pdf")

        do {
            try flattenedData.write(to: tempURL)
            Haptics.success()
            shareItems = [tempURL]
            isSharing = true
        } catch {
            print("Flattening export failed: \(error)")
        }
    }

    private func shareStandardPDF() {
        // Save current changes first
        pdfDocument?.write(to: documentURL)
        shareItems = [documentURL]
        isSharing = true
    }

    private func stampSignature(_ image: UIImage) {
        guard let page = pdfViewRef.currentPage else { return }
        PDFAnnotationHelper.addSignature(to: page, image: image)
        pdfViewRef.layoutDocumentView()
    }

    private func addTextBox(_ text: String) {
        guard let page = pdfViewRef.currentPage else { return }
        PDFAnnotationHelper.addFreeText(to: page, text: text, color: Theme.inkUIColor)
        pdfViewRef.layoutDocumentView()
    }

    private func applyHighlight() {
        guard let sel = pdfViewRef.currentSelection else { return }
        PDFAnnotationHelper.addHighlight(selection: sel)
        pdfViewRef.clearSelection()
        pdfViewRef.layoutDocumentView()
    }

    private func applyStrikeout() {
        guard let sel = pdfViewRef.currentSelection else { return }
        PDFAnnotationHelper.addStrikeout(selection: sel)
        pdfViewRef.clearSelection()
        pdfViewRef.layoutDocumentView()
    }

    private func applyUnderline() {
        guard let sel = pdfViewRef.currentSelection else { return }
        PDFAnnotationHelper.addUnderline(selection: sel)
        pdfViewRef.clearSelection()
        pdfViewRef.layoutDocumentView()
    }

    private func undoLastAnnotation() {
        guard let page = pdfViewRef.currentPage, let last = page.annotations.last else { return }
        Haptics.destructive()
        page.removeAnnotation(last)
        pdfViewRef.layoutDocumentView()
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
        uiView.backgroundColor = Theme.deskUIColor
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
