import SwiftUI
import UIKit

/// The document formats supported by TrollDocs desktop-class office suite.
enum DocumentFormat: String, CaseIterable, Codable, Identifiable, Hashable {
    case pdf
    case txt
    case csv
    case docx
    case xlsx
    case pptx

    var id: String { rawValue }

    var abbreviation: String { rawValue.uppercased() }

    var title: String {
        switch self {
        case .pdf: return "PDF Document"
        case .txt: return "Plain Text"
        case .csv: return "CSV Spreadsheet"
        case .docx: return "Word Document"
        case .xlsx: return "Excel Workbook"
        case .pptx: return "PowerPoint Deck"
        }
    }

    var detail: String {
        switch self {
        case .pdf: return "Print-ready document with running heads, folios, and annotations."
        case .txt: return "Lightweight UTF-8 text with line numbering and find & replace."
        case .csv: return "Interactive 2D spreadsheet with formulas, row/col operations, and auto-sum."
        case .docx: return "Full rich document processor with desktop typography and formatting."
        case .xlsx: return "Spreadsheet workbook with formula evaluation and financial styling."
        case .pptx: return "Multi-slide presentation studio with layout themes and slideshow mode."
        }
    }

    var fileExtension: String { rawValue }

    var systemIcon: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .txt: return "doc.plaintext"
        case .csv: return "tablecells"
        case .docx: return "doc.text"
        case .xlsx: return "tablecells"
        case .pptx: return "rectangle.fill.on.rectangle.fill"
        }
    }

    var editorName: String {
        switch self {
        case .pdf, .docx: return "TrollWord"
        case .csv, .xlsx: return "TrollSheets"
        case .pptx: return "TrollSlides"
        case .txt: return "TrollText"
        }
    }

    var categoryTitle: String {
        switch self {
        case .pdf, .docx, .txt: return "Documents"
        case .csv, .xlsx: return "Spreadsheets"
        case .pptx: return "Presentations"
        }
    }

    var tint: Color {
        switch self {
        case .pdf: return Theme.accent
        case .txt: return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: 0x9C9486) : UIColor(hex: 0x5B574E)
        })
        case .csv: return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: 0x8FA894) : UIColor(hex: 0x3C5949)
        })
        case .docx: return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: 0x8FA3B5) : UIColor(hex: 0x324A5C)
        })
        case .xlsx: return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: 0x8FA894) : UIColor(hex: 0x3C5949)
        })
        case .pptx: return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: 0xB59A7E) : UIColor(hex: 0x80552F)
        })
        }
    }

    /// All 6 formats are now fully supported with dedicated desktop-class editors!
    var isAvailable: Bool { true }

    static var creatable: [DocumentFormat] {
        allCases
    }

    var isSpreadsheet: Bool { self == .csv || self == .xlsx }
    var isPresentation: Bool { self == .pptx }
    var isWordDocument: Bool { self == .pdf || self == .docx }
    var isPlainText: Bool { self == .txt }

    var supportsRichText: Bool { self == .pdf || self == .docx }
    var supportsPageLayout: Bool { self == .pdf || self == .docx }

    var bodyPlaceholder: String {
        switch self {
        case .pdf, .docx:
            return "Begin writing. Headings, quotes, and body text are composed with desktop typography as you write."
        case .txt:
            return "Plain text editor with line numbers and find & replace."
        case .csv, .xlsx:
            return "Interactive 2D spreadsheet with cells, formula calculation, and column formatting."
        case .pptx:
            return "Slide canvas for title, bullet points, speaker notes, and presentation themes."
        }
    }

    static func from(url: URL) -> DocumentFormat? {
        let ext = url.pathExtension.lowercased()
        return DocumentFormat(rawValue: ext)
    }
}
