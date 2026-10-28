import SwiftUI

/// Represents the document formats supported by TrollDocs.
public enum DocumentFormat: String, CaseIterable, Identifiable, Codable, Hashable {
    case pdf = "pdf"
    case txt = "txt"
    case csv = "csv"
    case docx = "docx"
    case xlsx = "xlsx"
    case pptx = "pptx"

    public var id: String { rawValue }

    /// Human-readable title of the document format.
    public var displayName: String {
        switch self {
        case .pdf:  return "PDF Document"
        case .txt:  return "Plain Text"
        case .csv:  return "CSV Spreadsheet"
        case .docx: return "Word Document (DOCX)"
        case .xlsx: return "Excel Workbook (XLSX)"
        case .pptx: return "PowerPoint (PPTX)"
        }
    }

    /// Uppercase short extension name.
    public var shortName: String {
        rawValue.uppercased()
    }

    /// Standard file extension without leading dot.
    public var fileExtension: String {
        rawValue
    }

    /// SF Symbol icon name suitable for iOS 15+.
    public var systemIcon: String {
        switch self {
        case .pdf:  return "doc.richtext.fill"
        case .txt:  return "doc.plaintext.fill"
        case .csv:  return "tablecells.fill"
        case .docx: return "doc.text.fill"
        case .xlsx: return "tablecells"
        case .pptx: return "rectangle.fill.on.rectangle.fill"
        }
    }

    /// Standard MIME content type.
    public var mimeType: String {
        switch self {
        case .pdf:  return "application/pdf"
        case .txt:  return "text/plain"
        case .csv:  return "text/csv"
        case .docx: return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .xlsx: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case .pptx: return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        }
    }

    /// Whether full document compilation is implemented in Phase 1 MVP.
    public var isPhase1Ready: Bool {
        switch self {
        case .pdf, .txt, .csv:
            return true
        case .docx, .xlsx, .pptx:
            return false
        }
    }

    /// Accent badge color for UI indicators.
    public var themeColor: Color {
        switch self {
        case .pdf:  return Color.red
        case .txt:  return Color.gray
        case .csv:  return Color.green
        case .docx: return Color.blue
        case .xlsx: return Color(red: 0.1, green: 0.6, blue: 0.3)
        case .pptx: return Color.orange
        }
    }

    /// Identifies the format from a file URL.
    public static func from(url: URL) -> DocumentFormat? {
        let ext = url.pathExtension.lowercased()
        return DocumentFormat(rawValue: ext)
    }

    /// Identifies the format from a raw extension string.
    public static func from(extension ext: String) -> DocumentFormat? {
        let cleanExt = ext.replacingOccurrences(of: ".", with: "").lowercased()
        return DocumentFormat(rawValue: cleanExt)
    }
}
