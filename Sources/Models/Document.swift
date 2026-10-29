import Foundation

/// A document is a first-class, editable object. The files TrollDocs exports are
/// impressions of this model, never the source of truth, which is what makes
/// every document re-editable long after it was written.
struct Document: Identifiable, Codable, Equatable {
    var id: UUID
    var format: DocumentFormat
    var title: String
    var subtitle: String
    var author: String
    var content: RichText
    var page: PageSettings
    var typography: TypographySettings
    var spreadsheet: SpreadsheetData?
    var presentation: PresentationDeck?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        format: DocumentFormat = .pdf,
        title: String = "",
        subtitle: String = "",
        author: String = "",
        content: RichText = .empty,
        page: PageSettings = PageSettings(),
        typography: TypographySettings = TypographySettings(),
        spreadsheet: SpreadsheetData? = nil,
        presentation: PresentationDeck? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.format = format
        self.title = title
        self.subtitle = subtitle
        self.author = author
        self.content = content
        self.page = page
        self.typography = typography
        self.createdAt = createdAt
        self.updatedAt = updatedAt

        if format.isSpreadsheet {
            self.spreadsheet = spreadsheet ?? SpreadsheetData.defaultTemplate()
            self.presentation = nil
        } else if format.isPresentation {
            self.presentation = presentation ?? PresentationDeck.defaultDeck()
            self.spreadsheet = nil
        } else {
            self.spreadsheet = spreadsheet
            self.presentation = presentation
        }
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    var displaySubtitle: String {
        subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var wordCount: Int {
        if format.isSpreadsheet {
            return spreadsheetData.rowCount * spreadsheetData.columnCount
        } else if format.isPresentation {
            return presentationDeck.slides.reduce(0) { sum, slide in
                sum + slide.title.split(separator: " ").count + slide.bulletPoints.joined(separator: " ").split(separator: " ").count
            }
        }
        return content.wordCount
    }

    var spreadsheetData: SpreadsheetData {
        get { spreadsheet ?? SpreadsheetData.defaultTemplate() }
        set { spreadsheet = newValue }
    }

    var presentationDeck: PresentationDeck {
        get { presentation ?? PresentationDeck.defaultDeck() }
        set { presentation = newValue }
    }

    /// Printed in the footer of the editor, e.g. "A4 / 342 words" or "8 rows x 5 cols".
    var measureDescription: String {
        if format.isSpreadsheet {
            return "\(spreadsheetData.rowCount) rows × \(spreadsheetData.columnCount) cols"
        } else if format.isPresentation {
            return "\(presentationDeck.slideCount) slides"
        }
        return "\(page.size.title) / \(wordCount) words"
    }

    var fileName: String {
        var base = displayTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "|", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if base.isEmpty { base = "Untitled" }
        if base.count > 120 { base = String(base.prefix(120)) }
        return "\(base).\(format.fileExtension)"
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case id
        case format
        case title
        case subtitle
        case author
        case content
        case page
        case typography
        case spreadsheet
        case presentation
        case createdAt
        case updatedAt
    }

    /// Decoding is deliberately forgiving so a document written by an older
    /// build never disappears from the library after an update.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        format = try container.decodeIfPresent(DocumentFormat.self, forKey: .format) ?? .pdf
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        content = try container.decodeIfPresent(RichText.self, forKey: .content) ?? .empty
        page = try container.decodeIfPresent(PageSettings.self, forKey: .page) ?? PageSettings()
        typography = try container.decodeIfPresent(TypographySettings.self, forKey: .typography) ?? TypographySettings()
        spreadsheet = try container.decodeIfPresent(SpreadsheetData.self, forKey: .spreadsheet)
        presentation = try container.decodeIfPresent(PresentationDeck.self, forKey: .presentation)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt

        if format.isSpreadsheet && spreadsheet == nil {
            spreadsheet = SpreadsheetData.fromCSV(content.plainText)
        }
        if format.isPresentation && presentation == nil {
            presentation = PresentationDeck.defaultDeck()
        }
    }
}
