import SwiftUI

/// TrollDocs is exclusively a native PDF document creator and studio.
enum DocumentFormat: String, CaseIterable, Codable, Identifiable, Hashable {
    case pdf

    var id: String { rawValue }
    var abbreviation: String { "PDF" }
    var title: String { "PDF Document" }
    var detail: String { "Print-ready document with running heads, folios, and annotations." }
    var fileExtension: String { "pdf" }
    var systemIcon: String { "doc.richtext" }
    var tint: Color { Theme.accent }

    static func from(url: URL) -> DocumentFormat? {
        let ext = url.pathExtension.lowercased()
        return ext == "pdf" ? .pdf : nil
    }
}
