import SwiftUI
import PDFKit

// MARK: - Library View (Exclusively PDF)

struct LibraryView: View {
    @EnvironmentObject private var store: DocumentStore

    @State private var searchText = ""
    @State private var showingSearch = false
    @State private var showingImportPicker = false
    @State private var inspectingDocument: Document?
    @State private var renamingDocument: Document?
    @State private var renameTitle = ""
    @State private var showingRenameAlert = false
    @State private var sharingURLWrapper: ShareURLWrapper?
    @State private var editingDocument: Document?
    @FocusState private var searchFocused: Bool
    @AppStorage("app_appearance") private var appearanceRaw: String = AppAppearance.system.rawValue

    private var currentAppearance: AppAppearance {
        AppAppearance(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                masthead
                content
            }
        }
        .sheet(isPresented: $showingImportPicker) {
            DocumentPickerView { pickedURL in
                importFile(from: pickedURL)
            }
        }
        .sheet(item: $inspectingDocument) { doc in
            DocumentPropertiesView(
                document: doc,
                store: store,
                onRename: {
                    renamingDocument = doc
                    renameTitle = doc.title
                    showingRenameAlert = true
                },
                onDuplicate: {
                    _ = store.duplicate(doc)
                },
                onExport: {
                    if let url = try? store.export(doc) {
                        sharingURLWrapper = ShareURLWrapper(url: url)
                    }
                }
            )
            .preferredColorScheme(currentAppearance.colorScheme)
        }
        .sheet(item: $sharingURLWrapper) { wrapper in
            ShareSheetView(activityItems: [wrapper.url])
        }
        .alert("Rename Document", isPresented: $showingRenameAlert) {
            TextField("Document Title", text: $renameTitle)
            Button("Save") {
                if let doc = renamingDocument {
                    var updated = doc
                    updated.title = renameTitle
                    store.save(updated)
                }
                renamingDocument = nil
            }
            Button("Cancel", role: .cancel) {
                renamingDocument = nil
            }
        } message: {
            Text("Enter a new title for this PDF document.")
        }
        .fullScreenCover(item: $editingDocument) { document in
            EditorView(document: document, store: store)
                .environmentObject(store)
                .preferredColorScheme(currentAppearance.colorScheme)
        }
        .preferredColorScheme(currentAppearance.colorScheme)
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("TROLLDOCS PDF")
                    .font(Theme.mono(9.5, weight: .bold))
                    .kerning(2.6)
                    .foregroundColor(Theme.accent)

                Spacer()

                Menu {
                    Picker("Appearance", selection: $appearanceRaw) {
                        ForEach(AppAppearance.allCases) { item in
                            Label(item.title, systemImage: item.iconName)
                                .tag(item.rawValue)
                        }
                    }
                } label: {
                    Image(systemName: currentAppearance.iconName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.inkSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel("Appearance theme: \(currentAppearance.title)")

                Button {
                    toggleSearch()
                } label: {
                    Image(systemName: showingSearch ? "xmark" : "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.inkSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel(showingSearch ? "Close search" : "Search documents")

                Button {
                    showingImportPicker = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 9.5, weight: .semibold))
                        Text("IMPORT")
                            .font(Theme.sans(9.5, weight: .semibold))
                            .kerning(1.6)
                    }
                    .foregroundColor(Theme.inkSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .overlay(
                        Rectangle().stroke(Theme.ruleStrong, lineWidth: Theme.hairline)
                    )
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel("Import PDF document")

                Button {
                    createNewPDFDocument()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 9.5, weight: .semibold))
                        Text("NEW PDF")
                            .font(Theme.sans(9.5, weight: .semibold))
                            .kerning(1.6)
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay(
                        Rectangle().stroke(Theme.ruleStrong, lineWidth: Theme.hairline)
                    )
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel("Create new PDF document")
            }
            .padding(.top, 8)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("PDF Documents")
                    .font(Theme.serif(34))
                    .foregroundColor(Theme.ink)
                Text("\(store.documents.count)")
                    .font(Theme.serif(14))
                    .italic()
                    .foregroundColor(Theme.inkTertiary)
                Spacer()
            }
            .padding(.top, 4)

            Text(summaryLine)
                .font(Theme.mono(8.5))
                .kerning(1.3)
                .foregroundColor(Theme.inkTertiary)
                .padding(.top, 4)

            if showingSearch {
                searchField
                    .padding(.top, 14)
            }

            Hairline(color: Theme.ruleStrong)
                .padding(.top, 14)
        }
        .padding(.horizontal, Theme.gutter)
    }

    private var summaryLine: String {
        let documents = store.documents.count
        if documents == 0 { return "NO PDF DOCUMENTS YET" }
        let words = store.totalWordCount
        return "\(documents) \(documents == 1 ? "DOCUMENT" : "DOCUMENTS") • \(words) WORDS TOTAL"
    }

    private var searchField: some View {
        VStack(spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.inkTertiary)

                TextField("Search titles and authors...", text: $searchText)
                    .font(Theme.serif(15))
                    .foregroundColor(Theme.ink)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($searchFocused)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.inkTertiary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityLabel("Clear search text")
                }
            }
            Hairline(color: Theme.ruleStrong)
        }
    }

    // MARK: - Content

    private var content: some View {
        Group {
            if store.documents.isEmpty {
                emptyLibrary
            } else if filteredDocuments.isEmpty {
                emptySearch
            } else {
                documentList
            }
        }
    }

    private var filteredDocuments: [Document] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return store.documents
        }
        return store.documents.filter { doc in
            doc.title.localizedCaseInsensitiveContains(trimmed) ||
            doc.subtitle.localizedCaseInsensitiveContains(trimmed) ||
            doc.author.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var sections: [LibrarySection] {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"

        var buckets: [String: [Document]] = [:]
        var order: [String] = []

        for document in filteredDocuments {
            let key = formatter.string(from: document.updatedAt)
            if buckets[key] == nil {
                order.append(key)
                buckets[key] = []
            }
            buckets[key]?.append(document)
        }

        return order.map { key in
            LibrarySection(id: key, title: key, documents: buckets[key] ?? [])
        }
    }

    private var documentList: some View {
        List {
            ForEach(sections) { section in
                Section(header: sectionHeader(section.title)) {
                    ForEach(section.documents) { document in
                        Button {
                            editingDocument = document
                        } label: {
                            DocumentRow(document: document)
                        }
                        .buttonStyle(QuietButtonStyle())
                        .listRowInsets(EdgeInsets(top: 0, leading: Theme.gutter, bottom: 0, trailing: Theme.gutter))
                        .listRowBackground(Theme.paper)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Haptics.destructive()
                                store.delete(document)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                _ = store.duplicate(document)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            .tint(Theme.inkSecondary)
                        }
                        .contextMenu {
                            Button {
                                editingDocument = document
                            } label: {
                                Label("Open in Editor", systemImage: "pencil")
                            }

                            Button {
                                inspectingDocument = document
                            } label: {
                                Label("Properties (Get Info)", systemImage: "info.circle")
                            }

                            Button {
                                renamingDocument = document
                                renameTitle = document.title
                                showingRenameAlert = true
                            } label: {
                                Label("Rename", systemImage: "character.cursor.ibeam")
                            }

                            Button {
                                _ = store.duplicate(document)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }

                            Button {
                                if let url = try? store.export(document) {
                                    sharingURLWrapper = ShareURLWrapper(url: url)
                                }
                            } label: {
                                Label("Export & Share PDF", systemImage: "square.and.arrow.up")
                            }

                            Divider()

                            Button(role: .destructive) {
                                Haptics.destructive()
                                store.delete(document)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .paperBackedList()
        .background(Theme.paper)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(Theme.mono(8.5, weight: .bold))
                .kerning(1.4)
                .foregroundColor(Theme.inkTertiary)
            Spacer()
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 18)
        .padding(.bottom, 6)
        .background(Theme.paper)
    }

    // MARK: - Empty States

    private var emptyLibrary: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.accentWash)
                        .frame(width: 80, height: 80)

                    Image(systemName: "doc.richtext")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(Theme.accent)
                }

                Text("No PDF Documents")
                    .font(Theme.serif(28))
                    .foregroundColor(Theme.ink)

                Text("Create a new typeset PDF with desktop typography, or import existing PDF files to read and annotate.")
                    .font(Theme.sans(13))
                    .foregroundColor(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 30)

                Button {
                    createNewPDFDocument()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Create First PDF")
                            .kerning(1.4)
                    }
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Theme.accent)
                    .clipShape(Capsule())
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Create first PDF")
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
    }

    private var emptySearch: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Nothing matches.")
                .font(Theme.serif(24))
                .foregroundColor(Theme.ink)

            Text("Try another title or author, or clear the search to see all documents.")
                .font(Theme.sans(12.5))
                .foregroundColor(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 10)
                .padding(.horizontal, 30)

            Button {
                searchText = ""
            } label: {
                Text("Clear Search")
                    .font(Theme.sans(10, weight: .semibold))
                    .kerning(1.6)
                    .foregroundColor(Theme.ink)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(InkButtonStyle(filled: false))
            .accessibilityLabel("Clear search")
            .padding(.top, 22)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
    }

    // MARK: - Actions

    private func createNewPDFDocument() {
        let newDoc = store.create(format: .pdf)
        editingDocument = newDoc
    }

    private func toggleSearch() {
        withAnimation(.easeInOut(duration: 0.18)) {
            showingSearch.toggle()
        }
        if showingSearch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                searchFocused = true
            }
        } else {
            searchText = ""
            searchFocused = false
        }
    }

    private func importFile(from url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        var newDoc = Document(format: .pdf, title: name)

        if let pdfDoc = PDFDocument(url: url) {
            var paragraphs: [RichParagraph] = []
            for p in 0..<pdfDoc.pageCount {
                if let page = pdfDoc.page(at: p), let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    for line in text.components(separatedBy: .newlines) {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            paragraphs.append(RichParagraph(text: trimmed))
                        }
                    }
                }
            }
            if !paragraphs.isEmpty {
                newDoc.content = RichText(paragraphs: paragraphs)
            }
        }

        store.save(newDoc)
        editingDocument = newDoc
    }
}

// MARK: - Row & Helper Types

struct ShareURLWrapper: Identifiable {
    let id = UUID()
    let url: URL
}

private struct LibrarySection: Identifiable {
    let id: String
    let title: String
    let documents: [Document]
}

struct DocumentRow: View {
    let document: Document

    private var metaLine: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let edited = formatter.localizedString(for: document.updatedAt, relativeTo: Date())

        return "\(document.measureDescription) / \(edited)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 15) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("PDF")
                        .font(Theme.mono(8.5, weight: .bold))
                        .kerning(1.3)
                        .foregroundColor(Theme.accent)
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: 18, height: 1)
                }
                .frame(width: 38, alignment: .leading)
                .padding(.top, 5)

                VStack(alignment: .leading, spacing: 5) {
                    Text(document.displayTitle)
                        .font(Theme.serif(18))
                        .foregroundColor(Theme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(metaLine)
                        .font(Theme.mono(8.5))
                        .kerning(0.4)
                        .foregroundColor(Theme.inkTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.inkTertiary)
                    .padding(.top, 7)
            }
            .padding(.vertical, 15)

            Hairline()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(document.displayTitle), PDF document, \(metaLine)")
        .accessibilityHint("Double tap to open in editor")
    }
}
