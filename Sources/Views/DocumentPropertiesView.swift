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
                Section(header: Text("FILE IDENTITY").font(Theme.sans(11, weight: .bold))) {
                    HStack {
                        Image(systemName: document.format.systemIcon)
                            .foregroundColor(document.format.tint)
                            .font(.system(size: 24))
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(document.fileName)
                                .font(Theme.sans(14, weight: .semibold))
                                .foregroundColor(Theme.ink)
                            Text(document.format.title)
                                .font(Theme.sans(12))
                                .foregroundColor(Theme.inkSecondary)
                        }
                    }
                    .padding(.vertical, 4)

                    infoRow(title: "Display Title", value: document.displayTitle)
                    if !document.author.isEmpty {
                        infoRow(title: "Author", value: document.author)
                    }
                    infoRow(title: "Format", value: "Adobe PDF (.pdf)")
                }

                // Section 2: Storage & File System
                Section(header: Text("STORAGE & PATHS").font(Theme.sans(11, weight: .bold))) {
                    infoRow(title: "Export Location", value: "Documents/\(document.fileName)")
                    infoRow(title: "Storage ID", value: document.id.uuidString)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("iOS Files Visibility")
                            .font(Theme.sans(12, weight: .medium))
                            .foregroundColor(Theme.inkSecondary)
                        Text("Visible in Files app under 'On My iPhone → TrollDocs' via UIFileSharingEnabled")
                            .font(Theme.sans(12))
                            .foregroundColor(Theme.inkTertiary)
                    }
                    .padding(.vertical, 2)
                }

                // Section 3: Content Metrics
                Section(header: Text("CONTENT METRICS").font(Theme.sans(11, weight: .bold))) {
                    infoRow(title: "Word Count", value: "\(document.wordCount) words")
                    infoRow(title: "Paragraphs", value: "\(document.content.paragraphs.count)")
                    infoRow(title: "Page Preset", value: "\(document.page.size.title) (\(document.page.orientation.title))")
                    infoRow(title: "Margins", value: document.page.marginDetail)
                }

                // Section 4: Timestamps
                Section(header: Text("TIMESTAMPS").font(Theme.sans(11, weight: .bold))) {
                    infoRow(title: "Created", value: formatDate(document.createdAt))
                    infoRow(title: "Last Modified", value: formatDate(document.updatedAt))
                }

                // Section 5: Actions
                Section(header: Text("FILE OPERATIONS").font(Theme.sans(11, weight: .bold))) {
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
                .font(Theme.sans(14))
                .foregroundColor(Theme.inkSecondary)
            Spacer()
            Text(value)
                .font(Theme.sans(14, weight: .medium))
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
