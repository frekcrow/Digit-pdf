import SwiftUI

// MARK: - Library

struct LibraryView: View {
    @EnvironmentObject private var store: DocumentStore

    @State private var searchText = ""
    @State private var selectedFormat: DocumentFormat?
    @State private var showingSearch = false
    @State private var showingNewDocument = false
    @State private var showingImportPicker = false
    @State private var inspectingDocument: Document?
    @State private var renamingDocument: Document?
    @State private var renameTitle = ""
    @State private var showingRenameAlert = false
    @State private var sharingURLWrapper: ShareURLWrapper?
    @State private var editingDocument: Document?
    @State private var pendingDocument: Document?
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                masthead
                content
            }
        }
        .sheet(isPresented: $showingNewDocument, onDismiss: openPendingDocument) {
            NewDocumentSheet { format in
                pendingDocument = store.create(format: format)
                showingNewDocument = false
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
            Text("Enter a new title for this document.")
        }
        .fullScreenCover(item: $editingDocument) { document in
            EditorView(document: document, store: store)
                .environmentObject(store)
        }
    }

    // MARK: Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("TROLLDOCS")
                    .font(Theme.mono(9.5, weight: .medium))
                    .tracking(2.6)
                    .foregroundColor(Theme.accent)

                Spacer()

                Button {
                    toggleSearch()
                } label: {
                    Image(systemName: showingSearch ? "xmark" : "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.inkSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(QuietButtonStyle())

                Button {
                    showingImportPicker = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 9, weight: .semibold))
                        Text("IMPORT")
                            .font(Theme.sans(9.5, weight: .semibold))
                            .tracking(1.6)
                    }
                    .foregroundColor(Theme.inkSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .overlay(
                        Rectangle().stroke(Theme.ruleStrong, lineWidth: Theme.hairline)
                    )
                }
                .buttonStyle(QuietButtonStyle())

                Button {
                    showingNewDocument = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .semibold))
                        Text("NEW")
                            .font(Theme.sans(9.5, weight: .semibold))
                            .tracking(1.6)
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay(
                        Rectangle().stroke(Theme.ruleStrong, lineWidth: Theme.hairline)
                    )
                }
                .buttonStyle(QuietButtonStyle())
            }
            .padding(.top, 8)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Documents")
                    .font(Theme.serif(36))
                    .foregroundColor(Theme.ink)
                Text("\(store.documents.count)")
                    .font(Theme.serif(14))
                    .italic()
                    .foregroundColor(Theme.inkTertiary)
                Spacer()
            }
            .padding(.top, 0)

            Text(summaryLine)
                .font(Theme.mono(8.5))
                .tracking(1.3)
                .foregroundColor(Theme.inkTertiary)
                .padding(.top, 5)

            if showingSearch {
                searchField
                    .padding(.top, 14)
            }

            Hairline(color: Theme.ruleStrong)
                .padding(.top, 16)

            filterTabs
                .padding(.top, 12)
                .padding(.bottom, 6)
        }
        .padding(.horizontal, Theme.gutter)
    }

    private var summaryLine: String {
        let documents = store.documents.count
        if documents == 0 { return "NO DOCUMENTS YET" }
        let words = store.totalWordCount
        return "\(documents) \(documents == 1 ? "DOCUMENT" : "DOCUMENTS") / \(words) \(words == 1 ? "WORD" : "WORDS")"
    }

    private var searchField: some View {
        VStack(spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.inkTertiary)

                TextField("Search titles", text: $searchText)
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
                            .font(.system(size: 13))
                            .foregroundColor(Theme.inkTertiary)
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }
            Hairline(color: Theme.ruleStrong)
        }
    }

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                filterTab(title: "All", count: store.documents.count, format: nil)
                ForEach(DocumentFormat.creatable) { format in
                    filterTab(
                        title: format.abbreviation,
                        count: store.documents.filter { $0.format == format }.count,
                        format: format
                    )
                }
            }
        }
    }

    private func filterTab(title: String, count: Int, format: DocumentFormat?) -> some View {
        let selected = selectedFormat == format
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedFormat = format
            }
        } label: {
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(title.uppercased())
                        .font(Theme.sans(9.5, weight: selected ? .semibold : .regular))
                        .tracking(1.6)
                        .foregroundColor(selected ? Theme.ink : Theme.inkTertiary)
                    Text("\(count)")
                        .font(Theme.mono(8))
                        .foregroundColor(selected ? Theme.accent : Theme.inkTertiary)
                }
                Rectangle()
                    .fill(selected ? Theme.accent : Color.clear)
                    .frame(height: 1.5)
            }
        }
        .buttonStyle(QuietButtonStyle())
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if store.documents.isEmpty {
            emptyLibrary
        } else if filteredDocuments.isEmpty {
            emptySearch
        } else {
            documentList
        }
    }

    private var filteredDocuments: [Document] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.documents.filter { document in
            if let format = selectedFormat, document.format != format {
                return false
            }
            guard !query.isEmpty else { return true }
            return document.displayTitle.lowercased().contains(query)
                || document.displaySubtitle.lowercased().contains(query)
                || document.format.abbreviation.lowercased().contains(query)
        }
    }

    private var sections: [LibrarySection] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        var order: [String] = []
        var buckets: [String: [Document]] = [:]

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
                                Label("Export & Share", systemImage: "square.and.arrow.up")
                            }

                            Divider()

                            Button(role: .destructive) {
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
                .font(Theme.sans(8.5, weight: .semibold))
                .tracking(1.9)
                .foregroundColor(Theme.inkTertiary)
            Spacer()
        }
        .padding(.top, 18)
        .padding(.bottom, 6)
        .background(Theme.paper)
        .listRowInsets(EdgeInsets(top: 0, leading: Theme.gutter, bottom: 0, trailing: Theme.gutter))
    }

    private var emptyLibrary: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 30)

            ZStack {
                Rectangle()
                    .stroke(Theme.ruleStrong, lineWidth: Theme.hairline)
                    .frame(width: 64, height: 86)
                Text("¶")
                    .font(Theme.serif(25))
                    .foregroundColor(Theme.inkTertiary)
            }

            Text("The library is empty.")
                .font(Theme.serif(24))
                .foregroundColor(Theme.ink)
                .padding(.top, 26)

            Text("Every document begins as a blank page.\nChoose a format, then set the type.")
                .font(Theme.sans(12.5))
                .foregroundColor(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 10)

            Button {
                showingNewDocument = true
            } label: {
                Text("Compose a Document")
                    .font(Theme.sans(10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundColor(Theme.paper)
            }
            .buttonStyle(InkButtonStyle(filled: true))
            .padding(.top, 26)

            Spacer(minLength: 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    private var emptySearch: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Nothing matches.")
                .font(Theme.serif(24))
                .foregroundColor(Theme.ink)

            Text("Try another title, or clear the filters to see the whole library.")
                .font(Theme.sans(12.5))
                .foregroundColor(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 10)
                .padding(.horizontal, 30)

            Button {
                searchText = ""
                selectedFormat = nil
            } label: {
                Text("Clear Filters")
                    .font(Theme.sans(10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundColor(Theme.ink)
            }
            .buttonStyle(InkButtonStyle(filled: false))
            .padding(.top, 22)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
    }

    // MARK: Actions

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

    private func openPendingDocument() {
        guard let document = pendingDocument else { return }
        pendingDocument = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            editingDocument = document
        }
    }

    private func importFile(from url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        var format: DocumentFormat = .txt
        if let detected = DocumentFormat.from(url: url) {
            format = detected
        }

        var newDoc = Document(format: format, title: name)

        if format.isSpreadsheet {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                newDoc.spreadsheet = SpreadsheetData.fromCSV(content)
            }
        } else if format.isPresentation {
            newDoc.presentation = PresentationDeck.defaultDeck()
        } else {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                newDoc.content = RichText(paragraphs: content.components(separatedBy: .newlines).map { RichParagraph(text: $0) })
            }
        }

        store.save(newDoc)
        editingDocument = newDoc
    }
}

struct ShareURLWrapper: Identifiable {
    let id = UUID()
    let url: URL
}

private struct LibrarySection: Identifiable {
    let id: String
    let title: String
    let documents: [Document]
}

// MARK: - Row

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
                    Text(document.format.abbreviation)
                        .font(Theme.mono(8.5, weight: .semibold))
                        .tracking(1.3)
                        .foregroundColor(document.format.tint)
                    Rectangle()
                        .fill(document.format.tint)
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
                        .tracking(0.4)
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
    }
}

// MARK: - New document

struct NewDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (DocumentFormat) -> Void

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                SheetBar(title: "New document") {
                    dismiss()
                }

                Text("Choose a format")
                    .font(Theme.serif(30))
                    .foregroundColor(Theme.ink)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 6)

                Text("Each format is set for a different kind of page.")
                    .font(Theme.sans(12.5))
                    .foregroundColor(Theme.inkSecondary)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 6)

                Hairline()
                    .padding(.top, 20)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(DocumentFormat.creatable) { format in
                            formatRow(format)
                            Hairline()
                        }

                        Text("All document, spreadsheet and presentation formats are equipped with dedicated desktop-class office editors.")
                            .font(Theme.sans(11))
                            .foregroundColor(Theme.inkTertiary)
                            .lineSpacing(3)
                            .padding(.top, 22)
                    }
                    .padding(.horizontal, Theme.gutter)
                }
            }
        }
    }

    private func formatRow(_ format: DocumentFormat) -> some View {
        Button {
            onSelect(format)
        } label: {
            HStack(alignment: .top, spacing: 16) {
                Text(format.abbreviation)
                    .font(Theme.mono(9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(format.tint)
                    .frame(width: 42, alignment: .leading)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 5) {
                    Text(format.title)
                        .font(Theme.serif(21))
                        .foregroundColor(Theme.ink)
                    Text(format.detail)
                        .font(Theme.sans(12))
                        .foregroundColor(Theme.inkSecondary)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 10)

                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.inkTertiary)
                    .padding(.top, 7)
            }
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
    }
}
