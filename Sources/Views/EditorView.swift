import SwiftUI
import UIKit

struct EditorView: View {
    @EnvironmentObject private var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var model: EditorViewModel
    @StateObject private var richText = RichTextController()

    @State private var activeSheet: EditorSheet?
    @State private var showingDeleteConfirmation = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var exportedURL: URL?
    @State private var didDelete = false
    @FocusState private var titleFocused: Bool

    init(document: Document, store: DocumentStore) {
        _model = StateObject(wrappedValue: EditorViewModel(document: document, store: store))
    }

    var body: some View {
        ZStack {
            Theme.desk.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                if model.document.format.isSpreadsheet {
                    SpreadsheetEditorView(document: $model.document, onSave: { model.flush() })
                } else if model.document.format.isPresentation {
                    PresentationEditorView(document: $model.document, onSave: { model.flush() })
                } else {
                    manuscript
                    bottomBar
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .confirmationDialog(
            "Delete this document?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteDocument()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The editable source will be removed. Exported copies remain in the Files app.")
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            if exportedURL != nil {
                Button("Share") {
                    if let url = exportedURL {
                        activeSheet = .share(url)
                    }
                }
            }
            Button("OK", role: .cancel) {
                exportedURL = nil
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear(perform: prepareEditor)
        .onDisappear(perform: finishEditing)
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Library")
                            .font(Theme.sans(12))
                    }
                    .foregroundColor(Theme.inkSecondary)
                }
                .buttonStyle(QuietButtonStyle())

                Spacer()

                Text(model.document.format.abbreviation)
                    .font(Theme.mono(8.5, weight: .semibold))
                    .tracking(1.7)
                    .foregroundColor(Theme.accent)

                Spacer()

                if model.document.format == .pdf {
                    Button {
                        openPreview()
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Theme.inkSecondary)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(QuietButtonStyle())
                }

                menu
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 7)
            .background(Theme.paper)

            Hairline()
        }
    }

    private var menu: some View {
        Menu {
            Button {
                richText.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }

            Button {
                richText.redo()
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }

            Divider()

            Button {
                activeSheet = .properties
            } label: {
                Label("Properties (Get Info)", systemImage: "info.circle")
            }

            if model.document.format.supportsPageLayout {
                Button {
                    activeSheet = .inspector
                } label: {
                    Label("Page & Type", systemImage: "textformat.size")
                }
            }

            if model.document.format == .pdf {
                Button {
                    openPDFStudio()
                } label: {
                    Label("PDF Studio & Search", systemImage: "doc.viewfinder")
                }

                Button {
                    openPreview()
                } label: {
                    Label("Preview Page", systemImage: "doc.text.magnifyingglass")
                }
            }

            Divider()

            Button {
                saveToFiles()
            } label: {
                Label("Save to Files", systemImage: "folder")
            }

            Button {
                shareDocument()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Delete Document", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.inkSecondary)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
    }

    // MARK: - Manuscript

    private var manuscript: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    headerFields

                    ZStack(alignment: .topLeading) {
                        RichTextEditor(
                            documentID: model.document.id,
                            content: model.document.content,
                            typography: editorTypography,
                            baseSize: editorBaseSize,
                            color: Theme.inkUIColor,
                            controller: richText,
                            onChange: { text in
                                if model.document.content != text {
                                    model.document.content = text
                                }
                            }
                        )

                        if model.document.content.isEmpty {
                            Text(model.document.format.bodyPlaceholder)
                                .font(model.document.format == .csv
                                      ? Theme.mono(editorBaseSize)
                                      : Theme.serif(editorBaseSize))
                                .foregroundColor(Theme.inkTertiary)
                                .lineSpacing(4)
                                .allowsHitTesting(false)
                                .padding(.top, 3)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Theme.sheet)
                .overlay(
                    Rectangle().stroke(Theme.rule.opacity(0.9), lineWidth: Theme.hairline)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 5)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(width: min(proxy.size.width, 704))

                Spacer(minLength: 0)
            }
        }
    }

    private var headerFields: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Untitled", text: $model.document.title)
                .font(Theme.serif(28))
                .foregroundColor(Theme.ink)
                .textFieldStyle(PlainTextFieldStyle())
                .disableAutocorrection(true)
                .focused($titleFocused)

            if model.document.format.supportsRichText || model.document.format == .txt {
                TextField("Subtitle", text: $model.document.subtitle)
                    .font(Theme.serif(13).italic())
                    .foregroundColor(Theme.inkSecondary)
                    .textFieldStyle(PlainTextFieldStyle())
                    .disableAutocorrection(true)
                    .padding(.top, 1)
            }

            Hairline(color: Theme.ruleStrong)
                .padding(.top, 12)

            if let hint = formatHint {
                Text(hint.uppercased())
                    .font(Theme.mono(7.5))
                    .tracking(1.2)
                    .foregroundColor(Theme.inkTertiary)
                    .padding(.top, 9)
            }
        }
        .padding(.bottom, 14)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Hairline()

            if model.document.format.supportsRichText {
                richToolRow
            }

            Button {
                activeSheet = .inspector
            } label: {
                HStack(spacing: 8) {
                    Text(metricsLine)
                        .font(Theme.mono(8))
                        .tracking(1.1)
                        .foregroundColor(Theme.inkTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Text("SETUP")
                        .font(Theme.sans(8.5, weight: .semibold))
                        .tracking(1.4)
                        .foregroundColor(Theme.accent)
                }
                .padding(.horizontal, Theme.gutter)
                .frame(height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
        }
        .background(Theme.paper)
    }

    private var richToolRow: some View {
        HStack(spacing: 2) {
            ToolButton {
                richText.toggleBold()
            } label: {
                Text("B")
                    .font(Theme.serif(17, weight: .bold))
                    .foregroundColor(Theme.ink)
            }

            ToolButton {
                richText.toggleItalic()
            } label: {
                Text("I")
                    .font(Theme.serif(17).italic())
                    .foregroundColor(Theme.ink)
            }

            ToolButton {
                richText.toggleUnderline()
            } label: {
                Text("U")
                    .font(Theme.serif(17))
                    .underline()
                    .foregroundColor(Theme.ink)
            }

            BarDivider()

            paragraphMenu

            ToolButton {
                cycleAlignment()
            } label: {
                Image(systemName: model.document.typography.alignment.systemIcon)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Theme.inkSecondary)
            }

            Spacer(minLength: 0)

            ToolButton {
                activeSheet = .inspector
            } label: {
                Text("Aa")
                    .font(Theme.serif(15))
                    .foregroundColor(Theme.inkSecondary)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
    }

    private var paragraphMenu: some View {
        Menu {
            ForEach(ParagraphKind.allCases) { kind in
                Button {
                    richText.apply(kind: kind)
                } label: {
                    Text(kind.title)
                }
            }

            Divider()

            Button {
                richText.clearInlineFormatting()
            } label: {
                Text("Clear Formatting")
            }
        } label: {
            HStack(spacing: 3) {
                Text("¶")
                    .font(Theme.serif(17))
                    .foregroundColor(Theme.inkSecondary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundColor(Theme.inkTertiary)
            }
            .frame(width: 42, height: 42)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Derived

    private var editorBaseSize: CGFloat {
        model.document.format == .csv ? 14 : 16
    }

    private var editorTypography: TypographySettings {
        var settings = model.document.typography
        if model.document.format == .csv {
            settings.typeface = .menlo
            settings.bodySize = 14
            settings.leading = 1.55
            settings.alignment = .left
            settings.paragraphSpacing = 2
            settings.firstLineIndent = 0
        }
        return settings
    }

    private var formatHint: String? {
        switch model.document.format {
        case .csv:
            return "One row per line / columns separated by commas"
        case .txt:
            return "Plain text / styling is not written to the file"
        default:
            return nil
        }
    }

    private var metricsLine: String {
        switch model.document.format {
        case .pdf:
            let size = model.document.page.size.title.uppercased()
            let margin = model.document.page.marginDetail.uppercased()
            return "\(size) / \(margin) / \(model.document.wordCount) WORDS"
        case .csv:
            let rows = model.document.content.plainText
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .count
            return "\(rows) ROWS / COMMA SEPARATED"
        default:
            return "\(model.document.wordCount) WORDS / PLAIN TEXT"
        }
    }

    // MARK: - Actions

    private func prepareEditor() {
        richText.composition = editorTypography.composition(
            baseSize: editorBaseSize,
            color: Theme.inkUIColor
        )
        richText.onChange = { text in
            if model.document.content != text {
                model.document.content = text
            }
        }

        if model.document.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                titleFocused = true
            }
        }
    }

    private func finishEditing() {
        if !didDelete {
            model.flush()
        }
    }

    private func cycleAlignment() {
        let options = TextAlignmentOption.allCases
        let current = model.document.typography.alignment
        let index = options.firstIndex(of: current) ?? 0
        model.document.typography.alignment = options[(index + 1) % options.count]
    }

    private func openPreview() {
        model.flush()
        activeSheet = .preview
    }

    private func saveToFiles() {
        exportedURL = nil
        do {
            model.flush()
            let url = try store.export(model.document)
            exportedURL = url
            alertTitle = "Saved"
            alertMessage = "\(url.lastPathComponent) is now in the TrollDocs folder of the Files app."
            showingAlert = true
        } catch {
            alertTitle = "Could Not Save"
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }

    private func openPDFStudio() {
        do {
            model.flush()
            let url = try store.temporaryExportURL(for: model.document)
            activeSheet = .pdfStudio(url)
        } catch {
            alertTitle = "Could Not Open PDF Studio"
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }

    private func shareDocument() {
        do {
            model.flush()
            let url = try store.temporaryExportURL(for: model.document)
            activeSheet = .share(url)
        } catch {
            alertTitle = "Could Not Share"
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }

    private func deleteDocument() {
        model.discard()
        store.delete(model.document)
        didDelete = true
        dismiss()
    }

    @ViewBuilder
    private func sheetContent(for sheet: EditorSheet) -> some View {
        switch sheet {
        case .inspector:
            InspectorView(document: $model.document)
        case .preview:
            PreviewView(document: model.document)
        case .properties:
            DocumentPropertiesView(
                document: model.document,
                store: store,
                onRename: {},
                onDuplicate: {
                    store.duplicate(model.document)
                    dismiss()
                },
                onExport: {
                    saveToFiles()
                }
            )
        case .pdfStudio(let url):
            PDFStudioView(documentURL: url)
        case .share(let url):
            ShareSheetView(activityItems: [url])
        }
    }
}

private enum EditorSheet: Identifiable {
    case inspector
    case preview
    case properties
    case pdfStudio(URL)
    case share(URL)

    var id: String {
        switch self {
        case .inspector: return "inspector"
        case .preview: return "preview"
        case .properties: return "properties"
        case .pdfStudio(let url): return "pdfstudio-\(url.absoluteString)"
        case .share(let url): return "share-\(url.absoluteString)"
        }
    }
}
