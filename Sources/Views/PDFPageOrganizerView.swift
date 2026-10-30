import SwiftUI
import PDFKit

/// Desktop-style visual page organizer: reorder, rotate, duplicate, delete, and insert pages.
struct PDFPageOrganizerView: View {
    let documentURL: URL
    var onCommit: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var workingDoc: PDFDocument?
    @State private var pageThumbnails: [UIImage] = []
    @State private var showingInsertPicker: Bool = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert: Bool = false

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Theme.paper.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 18) {
                            if let doc = workingDoc {
                                ForEach(0..<doc.pageCount, id: \.self) { index in
                                    pageCard(at: index)
                                }
                            }
                        }
                        .padding(16)
                    }

                    Divider().background(Theme.rule)

                    bottomToolbar
                }
            }
            .navigationTitle("Page Organizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.inkSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply Changes") {
                        applyChanges()
                    }
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundColor(Theme.accent)
                }
            }
            .onAppear(perform: loadWorkingCopy)
            .sheet(isPresented: $showingInsertPicker) {
                DocumentPickerView { pickedURL in
                    insertPages(from: pickedURL)
                }
            }
            .alert("Page Operation Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An error occurred.")
            }
        }
    }

    // MARK: - Page Card

    @ViewBuilder
    private func pageCard(at index: Int) -> some View {
        if let doc = workingDoc, index < doc.pageCount, let page = doc.page(at: index) {
            VStack(spacing: 8) {
                // Thumbnail
                ZStack {
                    Theme.sheet

                    if index < pageThumbnails.count {
                        Image(uiImage: pageThumbnails[index])
                            .resizable()
                            .scaledToFit()
                            .rotationEffect(.degrees(Double(page.rotation)))
                    } else {
                        ProgressView()
                    }
                }
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.ruleStrong, lineWidth: Theme.hairline)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)

                // Page label and controls
                HStack(spacing: 6) {
                    Text("\(index + 1)")
                        .font(Theme.mono(11, weight: .bold))
                        .foregroundColor(Theme.ink)

                    Spacer()

                    // Move left
                    Button {
                        movePage(from: index, to: index - 1)
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(index > 0 ? Theme.inkSecondary : Theme.inkTertiary.opacity(0.4))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(index <= 0)
                    .accessibilityLabel("Move page \(index + 1) left")

                    // Move right
                    Button {
                        movePage(from: index, to: index + 1)
                    } label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(index < doc.pageCount - 1 ? Theme.inkSecondary : Theme.inkTertiary.opacity(0.4))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(index >= doc.pageCount - 1)
                    .accessibilityLabel("Move page \(index + 1) right")

                    // Rotate 90
                    Button {
                        rotatePage(at: index)
                    } label: {
                        Image(systemName: "rotate.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.accent)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Rotate page \(index + 1) 90 degrees")

                    // Delete
                    Button {
                        deletePage(at: index)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(doc.pageCount > 1 ? Theme.accent : Theme.inkTertiary.opacity(0.4))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(doc.pageCount <= 1)
                    .accessibilityLabel("Delete page \(index + 1)")
                }
                .padding(.horizontal, 2)
            }
            .padding(8)
            .background(Theme.sheet)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.rule, lineWidth: Theme.hairline)
            )
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 16) {
            Button {
                addBlankPage()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.badge.plus")
                    Text("Add Blank Page")
                }
                .font(Theme.sans(12, weight: .medium))
                .foregroundColor(Theme.ink)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Add blank page")

            Spacer()

            Button {
                showingInsertPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down.on.square")
                    Text("Insert External PDF...")
                }
                .font(Theme.sans(12, weight: .semibold))
                .foregroundColor(Theme.accent)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Insert external PDF")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Theme.sheet)
    }

    // MARK: - Actions

    private func loadWorkingCopy() {
        guard let original = PDFDocument(url: documentURL),
              let data = original.dataRepresentation(),
              let copy = PDFDocument(data: data) else {
            return
        }
        self.workingDoc = copy
        refreshThumbnails()
    }

    private func refreshThumbnails() {
        guard let doc = workingDoc else { return }
        var thumbs: [UIImage] = []
        let size = CGSize(width: 140, height: 190)

        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i) {
                let thumb = page.thumbnail(of: size, for: .mediaBox)
                thumbs.append(thumb)
            }
        }
        self.pageThumbnails = thumbs
    }

    private func movePage(from source: Int, to destination: Int) {
        guard let doc = workingDoc,
              source >= 0, source < doc.pageCount,
              destination >= 0, destination < doc.pageCount else { return }

        doc.exchangePage(at: source, withPageAt: destination)
        refreshThumbnails()
    }

    private func rotatePage(at index: Int) {
        guard let doc = workingDoc, let page = doc.page(at: index) else { return }
        page.rotation = (page.rotation + 90) % 360
        refreshThumbnails()
    }

    private func deletePage(at index: Int) {
        guard let doc = workingDoc, doc.pageCount > 1, index < doc.pageCount else { return }
        Haptics.destructive()
        doc.removePage(at: index)
        refreshThumbnails()
    }

    private func addBlankPage() {
        guard let doc = workingDoc else { return }
        // Match size of first page or default A4
        let pageSize = doc.page(at: 0)?.bounds(for: .mediaBox).size ?? CGSize(width: 595.28, height: 841.89)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let blankData = renderer.pdfData { context in
            context.beginPage()
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: pageSize))
        }

        if let blankDoc = PDFDocument(data: blankData), let blankPage = blankDoc.page(at: 0) {
            doc.insert(blankPage, at: doc.pageCount)
            refreshThumbnails()
        }
    }

    private func insertPages(from url: URL) {
        guard let doc = workingDoc, let extDoc = PDFDocument(url: url) else {
            errorMessage = "Could not read pages from selected PDF."
            showingErrorAlert = true
            return
        }

        for i in 0..<extDoc.pageCount {
            if let page = extDoc.page(at: i) {
                doc.insert(page, at: doc.pageCount)
            }
        }
        refreshThumbnails()
    }

    private func applyChanges() {
        guard let doc = workingDoc else { return }
        doc.write(to: documentURL)
        Haptics.success()
        onCommit()
        dismiss()
    }
}
