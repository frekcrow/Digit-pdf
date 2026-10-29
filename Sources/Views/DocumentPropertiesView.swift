import SwiftUI

/// Desktop-style File Properties and Metadata Inspector for TrollDocs documents.
struct DocumentPropertiesView: View {
    let document: Document
    let store: DocumentStore
    var onRename: () -> Void
    var onDuplicate: () -> Void
    var onExport: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                // Section 1: Identity & Format
                Section(header: Text("FILE IDENTITY").font(Theme.mono(9, weight: .bold))) {
                    HStack {
                        Image(systemName: document.format.systemIcon)
                            .foregroundColor(document.format.tint)
                            .font(.system(size: 24))
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(document.fileName)
                                .font(Theme.mono(13, weight: .bold))
                                .foregroundColor(Theme.ink)
                            Text(document.format.title)
                                .font(Theme.sans(11))
                                .foregroundColor(Theme.inkSecondary)
                        }
                    }
                    .padding(.vertical, 4)

                    infoRow(title: "Display Title", value: document.displayTitle)
                    if !document.author.isEmpty {
                        infoRow(title: "Author", value: document.author)
                    }
                    infoRow(title: "Format Category", value: document.format.categoryTitle)
                    infoRow(title: "Target Extension", value: ".\(document.format.fileExtension)")
                }

                // Section 2: Storage & File System
                Section(header: Text("STORAGE & PATHS").font(Theme.mono(9, weight: .bold))) {
                    let internalURL = store.libraryDirectory.appendingPathComponent("\(document.id.uuidString).tdoc")
                    let exportURL = store.documentsDirectory.appendingPathComponent(document.fileName)

                    infoRow(title: "Export Location", value: "Documents/\(document.fileName)")
                    infoRow(title: "Storage ID", value: document.id.uuidString)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("iOS Files Visibility")
                            .font(Theme.mono(10, weight: .semibold))
                            .foregroundColor(Theme.inkSecondary)
                        Text("Visible in Files app under 'On My iPhone → TrollDocs' via UIFileSharingEnabled")
                            .font(Theme.sans(11))
                            .foregroundColor(Theme.inkTertiary)
                    }
                    .padding(.vertical, 2)
                }

                // Section 3: Content Metrics
                Section(header: Text("CONTENT METRICS").font(Theme.mono(9, weight: .bold))) {
                    if document.format.isSpreadsheet {
                        infoRow(title: "Table Dimensions", value: "\(document.spreadsheetData.rowCount) rows × \(document.spreadsheetData.columnCount) columns")
                        infoRow(title: "Total Cells", value: "\(document.spreadsheetData.rowCount * document.spreadsheetData.columnCount)")
                    } else if document.format.isPresentation {
                        infoRow(title: "Total Slides", value: "\(document.presentationDeck.slideCount)")
                        infoRow(title: "Current Theme", value: document.presentationDeck.currentSlide.theme.rawValue)
                    } else {
                        infoRow(title: "Word Count", value: "\(document.wordCount) words")
                        infoRow(title: "Paragraphs", value: "\(document.content.paragraphs.count)")
                        infoRow(title: "Page Preset", value: "\(document.page.size.title) (\(document.page.orientation.title))")
                    }
                }

                // Section 4: Timestamps
                Section(header: Text("TIMESTAMPS").font(Theme.mono(9, weight: .bold))) {
                    infoRow(title: "Created", value: formatDate(document.createdAt))
                    infoRow(title: "Last Modified", value: formatDate(document.updatedAt))
                }

                // Section 5: Actions
                Section(header: Text("FILE OPERATIONS").font(Theme.mono(9, weight: .bold))) {
                    Button(action: {
                        dismiss()
                        onRename()
                    }) {
                        Label("Rename Document", systemImage: "pencil")
                            .font(Theme.sans(13))
                    }

                    Button(action: {
                        dismiss()
                        onDuplicate()
                    }) {
                        Label("Duplicate (Make a Copy)", systemImage: "doc.on.doc")
                            .font(Theme.sans(13))
                    }

                    Button(action: {
                        dismiss()
                        onExport()
                    }) {
                        Label("Export & Share Impression", systemImage: "square.and.arrow.up")
                            .font(Theme.sans(13))
                    }
                }
            }
            .navigationTitle("Document Properties")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(Theme.mono(11))
                .foregroundColor(Theme.inkSecondary)
            Spacer()
            Text(value)
                .font(Theme.mono(11, weight: .medium))
                .foregroundColor(Theme.ink)
                .lineLimit(1)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
