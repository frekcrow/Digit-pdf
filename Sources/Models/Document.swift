import Foundation

/// A document is a first-class, editable PDF manuscript.
struct Document: Identifiable, Codable, Equatable {
    var id: UUID
    var format: DocumentFormat
    var title: String
    var subtitle: String
    var author: String
    var content: RichText
    var page: PageSettings
    var typography: TypographySettings
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
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.format = .pdf
        self.title = title
        self.subtitle = subtitle
        self.author = author
        self.content = content
        self.page = page
        self.typography = typography
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Document" : trimmed
    }

    var displaySubtitle: String {
        subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var wordCount: Int {
        content.wordCount
    }

    /// Printed in the footer of the editor, e.g. "A4 / 342 words".
    var measureDescription: String {
        "\(page.size.title) • \(page.orientation.title) / \(wordCount) words"
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
        return "\(base).pdf"
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
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        format = .pdf
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        content = try container.decodeIfPresent(RichText.self, forKey: .content) ?? .empty
        page = try container.decodeIfPresent(PageSettings.self, forKey: .page) ?? PageSettings()
        typography = try container.decodeIfPresent(TypographySettings.self, forKey: .typography) ?? TypographySettings()
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}
