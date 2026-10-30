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
        NavigationView {
            ZStack {
                Theme.paper.ignoresSafeArea()

                VStack(spacing: 0) {
                    if showingSearch {
                        searchField
                            .padding(.horizontal, Theme.gutter)
                            .padding(.top, 8)
                            .padding(.bottom, 6)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    content
                }
            }
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Appearance", selection: $appearanceRaw) {
                            ForEach(AppAppearance.allCases) { item in
                                Label(item.title, systemImage: item.iconName)
                                    .tag(item.rawValue)
                            }
                        }
                    } label: {
                        Image(systemName: currentAppearance.iconName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Theme.accent)
                            .frame(width: 36, height: 36)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Appearance theme: \(currentAppearance.title)")
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        toggleSearch()
                    } label: {
                        Image(systemName: showingSearch ? "xmark.circle.fill" : "magnifyingglass")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(showingSearch ? Theme.inkSecondary : Theme.accent)
                            .frame(width: 36, height: 36)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(showingSearch ? "Close search" : "Search documents")

                    Button {
                        showingImportPicker = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.accent)
                            .frame(width: 36, height: 36)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Import PDF document")

                    Button {
                        createNewPDFDocument()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Theme.accent)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Create new PDF document")
                }
            }
        }
        .navigationViewStyle(.stack)
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

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(Theme.inkSecondary)

            TextField("Search titles and authors...", text: $searchText)
                .font(Theme.sans(15))
                .foregroundColor(Theme.ink)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($searchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.inkSecondary)
                }
                .accessibilityLabel("Clear search text")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                        .listRowInsets(EdgeInsets(top: 6, leading: Theme.gutter, bottom: 6, trailing: Theme.gutter))
                        .listRowBackground(Color.clear)
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
                .font(Theme.sans(11, weight: .bold))
                .foregroundColor(Theme.inkSecondary)
            Spacer()
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .background(Theme.paper)
    }

    // MARK: - Empty States

    private var emptyLibrary: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Theme.accentWash)
                        .frame(width: 88, height: 88)

                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.accent)
                }

                Text("No PDF Documents")
                    .font(Theme.sans(24, weight: .bold))
                    .foregroundColor(Theme.ink)

                Text("Create a new typeset PDF with desktop typography, or import existing PDF files to read and annotate.")
                    .font(Theme.sans(14))
                    .foregroundColor(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)

                VStack(spacing: 12) {
                    Button {
                        createNewPDFDocument()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("New PDF Document")
                        }
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: 240)
                        .padding(.vertical, 14)
                        .background(Theme.accent)
                        .clipShape(Capsule())
                    }
                    .accessibilityLabel("Create new PDF document")

                    Button {
                        showingImportPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import Existing PDF")
                        }
                        .font(Theme.sans(13.5, weight: .medium))
                        .foregroundColor(Theme.accent)
                    }
                    .accessibilityLabel("Import existing PDF")
                }
                .padding(.top, 10)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
    }

    private var emptySearch: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 38, weight: .light))
                .foregroundColor(Theme.inkTertiary)
                .padding(.bottom, 6)

            Text("No Results Found")
                .font(Theme.sans(20, weight: .bold))
                .foregroundColor(Theme.ink)

            Text("No documents match '\(searchText)'. Try another search term or clear the filter.")
                .font(Theme.sans(13.5))
                .foregroundColor(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.horizontal, 36)

            Button {
                searchText = ""
            } label: {
                Text("Clear Search")
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.accentWash)
                    .clipShape(Capsule())
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Clear search")
            .padding(.top, 16)

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
        formatter.unitsStyle = .abbreviated
        let edited = formatter.localizedString(for: document.updatedAt, relativeTo: Date())

        return "\(document.measureDescription) • \(edited)"
    }

    var body: some View {
        HStack(spacing: 14) {
            // Document icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.accentWash)
                    .frame(width: 44, height: 44)

                Image(systemName: "doc.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(document.displayTitle)
                    .font(Theme.sans(16, weight: .semibold))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    CupertinoBadge(text: "PDF")

                    Text(metaLine)
                        .font(Theme.sans(12))
                        .foregroundColor(Theme.inkSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.inkTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.sheet)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .stroke(Theme.rule, lineWidth: Theme.hairline)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(document.displayTitle), PDF document, \(metaLine)")
        .accessibilityHint("Double tap to open in editor")
    }
}
