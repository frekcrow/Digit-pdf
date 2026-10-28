import SwiftUI

/// View allowing users to specify format, metadata, content, and generate documents.
public struct CreateDocumentView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var fileManagerService: FileManagerService

    @State private var selectedFormat: DocumentFormat = .pdf
    @State private var fileName: String = ""
    @State private var documentTitle: String = ""
    @State private var documentContent: String = ""

    @State private var isGenerating: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert: Bool = false

    public init() {}

    public var body: some View {
        NavigationView {
            Form {
                // Section 1: Target Document Format
                Section(header: Text("Target Format")) {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(DocumentFormat.allCases) { format in
                            HStack {
                                Image(systemName: format.systemIcon)
                                    .foregroundColor(format.themeColor)
                                Text(format.displayName)
                            }
                            .tag(format)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    if !selectedFormat.isPhase1Ready {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                            Text("Phase 2 Preview: OpenXML generation will produce a structured starter file.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Section 2: File & Document Identity
                Section(header: Text("Document Details")) {
                    HStack {
                        Text("File Name:")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 80, alignment: .leading)
                        TextField("e.g. Quarterly_Report", text: $fileName)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                        Text(".\(selectedFormat.fileExtension)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Title:")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 80, alignment: .leading)
                        TextField("e.g. Quarterly Executive Summary", text: $documentTitle)
                    }
                }

                // Section 3: Quick Content Templates
                Section(header: Text("Quick Starter Templates")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            templateButton(title: "Report", icon: "doc.text") {
                                loadReportTemplate()
                            }

                            templateButton(title: "Meeting Notes", icon: "list.bullet") {
                                loadMeetingNotesTemplate()
                            }

                            templateButton(title: "Expense Table (CSV)", icon: "tablecells") {
                                loadCSVTemplate()
                            }

                            templateButton(title: "Checklist (TXT)", icon: "checkmark.square") {
                                loadChecklistTemplate()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Section 4: Document Body Content
                Section(header: Text("Document Content")) {
                    ZStack(alignment: .topLeading) {
                        if documentContent.isEmpty {
                            Text(placeholderTextForFormat)
                                .font(.system(size: 14))
                                .foregroundColor(Color(uiColor: .placeholderText))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }

                        TextEditor(text: $documentContent)
                            .font(.system(size: 14, design: selectedFormat == .csv ? .monospaced : .default))
                            .frame(minHeight: 180)
                    }
                }

                // Section 5: Action Button
                Section {
                    Button(action: generateAndSaveDocument) {
                        HStack {
                            Spacer()
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 6)
                                Text("Generating...")
                                    .fontWeight(.bold)
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generate & Save Document")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .disabled(isGenerating || fileName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("New Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("Generation Error"),
                    message: Text(errorMessage ?? "An unexpected error occurred while generating the document."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - Subviews & Actions

    private func templateButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12))
            .foregroundColor(.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var placeholderTextForFormat: String {
        switch selectedFormat {
        case .pdf:
            return "Type body paragraphs here. TrollDocs will automatically paginate across multiple pages..."
        case .txt:
            return "Enter plain text content..."
        case .csv:
            return "Enter comma or tab delimited rows (e.g., ID, Product, Quantity, Price)..."
        case .docx, .xlsx, .pptx:
            return "Enter body text or table content..."
        }
    }

    private func generateAndSaveDocument() {
        let cleanName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = documentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = cleanTitle.isEmpty ? cleanName : cleanTitle

        isGenerating = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try DocumentGeneratorService.shared.generate(
                    format: self.selectedFormat,
                    title: finalTitle,
                    content: self.documentContent,
                    metadata: ["created_by": "TrollDocs"]
                )

                try self.fileManagerService.saveDocument(
                    name: cleanName,
                    format: self.selectedFormat,
                    data: data
                )

                DispatchQueue.main.async {
                    self.isGenerating = false
                    self.presentationMode.wrappedValue.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isGenerating = false
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }

    // MARK: - Template Fillers

    private func loadReportTemplate() {
        selectedFormat = .pdf
        fileName = "Project_Status_Report"
        documentTitle = "Project Status & Milestone Report"
        documentContent = """
        Executive Summary:
        This report outlines the foundational phase of our project. All primary deliverables have been established and validated against system specifications.

        Key Accomplishments:
        1. Document Generation Engine initialized.
        2. Native multi-page pagination enabled via CoreText and UIGraphicsPDFRenderer.
        3. Local file sharing and iOS Files integration verified.

        Next Steps:
        - Extend OpenXML parser for Phase 2 DOCX/XLSX/PPTX outputs.
        - Implement batch document export and signing optimizations.
        """
    }

    private func loadMeetingNotesTemplate() {
        selectedFormat = .pdf
        fileName = "Meeting_Notes"
        documentTitle = "Team Sync & Planning Notes"
        documentContent = """
        Date: October 29, 2026
        Attendees: Engineering Team, Product Lead

        Discussion Topics:
        • TrollStore native container privileges and sandboxing toggle.
        • Document creation lifecycle, previewing with QuickLook, and local AirDrop sharing.

        Action Items:
        [ ] Deploy Phase 1 MVP to TrollStore via GitHub Actions.
        [ ] Verify QuickLook preview performance on large multi-page PDF documents.
        """
    }

    private func loadCSVTemplate() {
        selectedFormat = .csv
        fileName = "Monthly_Expenses"
        documentTitle = "Monthly Operating Expenses"
        documentContent = """
        Category,Item,Quantity,Unit Cost,Total
        Hosting,Cloud Server Cluster,1,120.00,120.00
        Domain,DNS Registration,2,15.00,30.00
        Software,CI/CD Runner Tokens,1,50.00,50.00
        Hardware,Test Devices,3,250.00,750.00
        """
    }

    private func loadChecklistTemplate() {
        selectedFormat = .txt
        fileName = "Deployment_Checklist"
        documentTitle = "Release & Verification Checklist"
        documentContent = """
        [X] Configure project.yml with deployment target iOS 15.0.
        [X] Create TrollStore entitlements with no-sandbox toggle.
        [X] Setup GitHub Actions with xcodegen and ldid.
        [ ] Download generated TrollDocs.ipa / TrollDocs.tipa.
        [ ] Install directly into TrollStore on device.
        """
    }
}
