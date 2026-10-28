import Foundation
import UIKit
import CoreText

// MARK: - Error Types

public enum DocumentGeneratorError: LocalizedError {
    case emptyTitle
    case encodingFailed
    case renderFailed(String)
    case unsupportedFormat(DocumentFormat)

    public var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Document title cannot be empty."
        case .encodingFailed:
            return "Failed to encode document text into UTF-8 data."
        case .renderFailed(let reason):
            return "Document rendering failed: \(reason)"
        case .unsupportedFormat(let format):
            return "\(format.displayName) generation is reserved for Phase 2."
        }
    }
}

// MARK: - Generator Protocol

public protocol DocumentGeneratorProtocol {
    func generate(
        format: DocumentFormat,
        title: String,
        content: String,
        metadata: [String: String]
    ) throws -> Data
}

// MARK: - PDF Document Generator

/// Generates multi-page PDF documents using UIGraphicsPDFRenderer and CoreText pagination.
public final class PDFDocumentGenerator {
    public static let shared = PDFDocumentGenerator()

    private let pageWidth: CGFloat = 612.0   // Standard US Letter Width (72 dpi)
    private let pageHeight: CGFloat = 792.0  // Standard US Letter Height (72 dpi)
    private let margin: CGFloat = 40.0

    public init() {}

    public func renderPDF(title: String, content: String, metadata: [String: String] = [:]) throws -> Data {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            throw DocumentGeneratorError.emptyTitle
        }

        let pageBounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let format = UIGraphicsPDFRendererFormat()

        // Configure PDF document metadata dictionary
        let pdfInfo: [String: Any] = [
            kCGPDFContextTitle as String: cleanTitle,
            kCGPDFContextCreator as String: "TrollDocs iOS Utility",
            kCGPDFContextAuthor as String: metadata["author"] ?? "TrollDocs User"
        ]
        format.documentInfo = pdfInfo

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: format)

        // Prepare attributed string for body content
        let bodyParagraphStyle = NSMutableParagraphStyle()
        bodyParagraphStyle.lineSpacing = 4.0
        bodyParagraphStyle.lineBreakMode = .byWordWrapping

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11.5, weight: .regular),
            .foregroundColor: UIColor.label,
            .paragraphStyle: bodyParagraphStyle
        ]

        let cleanContent = content.isEmpty ? "(This document was created with TrollDocs without body text.)" : content
        let attributedBody = NSAttributedString(string: cleanContent, attributes: bodyAttributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedBody as CFAttributedString)

        let printableWidth = pageWidth - (margin * 2)

        let data = renderer.pdfData { context in
            var textLocation = 0
            let totalLength = attributedBody.length
            var pageIndex = 1

            // Pre-calculate body frame limits per page
            while textLocation < totalLength || pageIndex == 1 {
                context.beginPage()
                let cgContext = context.cgContext

                let isFirstPage = (pageIndex == 1)
                let headerTop: CGFloat = margin
                var bodyTop: CGFloat = 0.0

                if isFirstPage {
                    // Page 1: Draw Large Title Banner & Metadata
                    let titleStyle = NSMutableParagraphStyle()
                    titleStyle.lineBreakMode = .byWordWrapping

                    let titleAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                        .foregroundColor: UIColor.label,
                        .paragraphStyle: titleStyle
                    ]

                    let titleRect = CGRect(x: margin, y: headerTop, width: printableWidth, height: 60)
                    (cleanTitle as NSString).draw(in: titleRect, withAttributes: titleAttrs)

                    // Subtitle metadata: Date & App Branding
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .long
                    dateFormatter.timeStyle = .short
                    let dateString = "Generated on \(dateFormatter.string(from: Date())) • TrollDocs"

                    let subAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9.5, weight: .medium),
                        .foregroundColor: UIColor.secondaryLabel
                    ]
                    let subRect = CGRect(x: margin, y: headerTop + 42, width: printableWidth, height: 16)
                    (dateString as NSString).draw(in: subRect, withAttributes: subAttrs)

                    // Accent rule line
                    let ruleY = headerTop + 64
                    cgContext.saveGState()
                    cgContext.setStrokeColor(UIColor.systemRed.withAlphaComponent(0.6).cgColor)
                    cgContext.setLineWidth(1.5)
                    cgContext.move(to: CGPoint(x: margin, y: ruleY))
                    cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: ruleY))
                    cgContext.strokePath()
                    cgContext.restoreGState()

                    bodyTop = ruleY + 16
                } else {
                    // Subsequent Pages: Running Minimal Header
                    let runningTitleAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                        .foregroundColor: UIColor.secondaryLabel
                    ]
                    let runningRect = CGRect(x: margin, y: headerTop, width: printableWidth, height: 14)
                    (cleanTitle as NSString).draw(in: runningRect, withAttributes: runningTitleAttrs)

                    let ruleY = headerTop + 18
                    cgContext.saveGState()
                    cgContext.setStrokeColor(UIColor.separator.cgColor)
                    cgContext.setLineWidth(0.5)
                    cgContext.move(to: CGPoint(x: margin, y: ruleY))
                    cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: ruleY))
                    cgContext.strokePath()
                    cgContext.restoreGState()

                    bodyTop = ruleY + 14
                }

                // Footer Area
                let footerHeight: CGFloat = 30.0
                let footerY = pageHeight - margin - footerHeight

                // Draw Footer Rule Line
                cgContext.saveGState()
                cgContext.setStrokeColor(UIColor.separator.cgColor)
                cgContext.setLineWidth(0.5)
                cgContext.move(to: CGPoint(x: margin, y: footerY))
                cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: footerY))
                cgContext.strokePath()
                cgContext.restoreGState()

                // Footer Left: Branding
                let footerAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 8.5, weight: .regular),
                    .foregroundColor: UIColor.tertiaryLabel
                ]
                let footerBrandRect = CGRect(x: margin, y: footerY + 6, width: printableWidth / 2, height: 16)
                ("TrollDocs • iOS Document Utility" as NSString).draw(in: footerBrandRect, withAttributes: footerAttrs)

                // Footer Right: Page Number
                let pageStr = "Page \(pageIndex)"
                let pageNumStyle = NSMutableParagraphStyle()
                pageNumStyle.alignment = .right
                var rightAttrs = footerAttrs
                rightAttrs[.paragraphStyle] = pageNumStyle
                let footerPageRect = CGRect(x: pageWidth - margin - (printableWidth / 2), y: footerY + 6, width: printableWidth / 2, height: 16)
                (pageStr as NSString).draw(in: footerPageRect, withAttributes: rightAttrs)

                // Calculate printable body rectangle in top-left coordinates
                let bodyHeight = max(10, footerY - bodyTop - 10)
                let bodyRect = CGRect(x: margin, y: bodyTop, width: printableWidth, height: bodyHeight)

                // Render Paginated Body Text using CoreText
                if textLocation < totalLength {
                    cgContext.saveGState()
                    // CoreText uses flipped coordinates (origin at bottom-left)
                    cgContext.translateBy(x: 0, y: pageHeight)
                    cgContext.scaleBy(x: 1.0, y: -1.0)

                    // Translate bodyRect into flipped CoreText coordinate system
                    let flippedY = pageHeight - bodyRect.maxY
                    let flippedBodyRect = CGRect(
                        x: bodyRect.origin.x,
                        y: flippedY,
                        width: bodyRect.width,
                        height: bodyRect.height
                    )

                    let path = CGMutablePath()
                    path.addRect(flippedBodyRect)

                    let frame = CTFramesetterCreateFrame(
                        framesetter,
                        CFRange(location: textLocation, length: 0),
                        path,
                        nil
                    )

                    CTFrameDraw(frame, cgContext)
                    cgContext.restoreGState()

                    let visibleRange = CTFrameGetVisibleStringRange(frame)
                    if visibleRange.length == 0 {
                        // Avoid infinite loop if remaining text cannot fit on page
                        break
                    }
                    textLocation += visibleRange.length
                }

                pageIndex += 1
            }
        }

        return data
    }
}

// MARK: - Plain Text Document Generator

public final class PlainTextDocumentGenerator {
    public static let shared = PlainTextDocumentGenerator()

    public init() {}

    public func renderTXT(title: String, content: String) throws -> Data {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var output = ""

        if !cleanTitle.isEmpty {
            output += "\(cleanTitle)\n"
            let divider = String(repeating: "=", count: max(cleanTitle.count, 40))
            output += "\(divider)\n"
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            output += "Date: \(dateFormatter.string(from: Date()))\n\n"
        }

        output += content

        guard let data = output.data(using: .utf8) else {
            throw DocumentGeneratorError.encodingFailed
        }
        return data
    }
}

// MARK: - CSV Document Generator

public final class CSVDocumentGenerator {
    public static let shared = CSVDocumentGenerator()

    public init() {}

    public func renderCSV(title: String, content: String) throws -> Data {
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        var csvString = ""

        if cleanContent.isEmpty {
            // Provide a clean starter template if content is empty
            csvString = """
            "ID","Item Name","Category","Quantity","Unit Price","Total"
            "1","Sample Item A","Supplies","5","12.50","62.50"
            "2","Sample Item B","Electronics","2","89.99","179.98"
            "3","Sample Item C","Services","1","150.00","150.00"
            """
        } else {
            // Normalize lines and ensure standard RFC 4180 CSV escaping
            let rawLines = cleanContent.components(separatedBy: .newlines)
            var formattedLines: [String] = []

            for line in rawLines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }

                // Check if user entered comma-separated values, semicolon, or tab
                let delimiter: Character
                if trimmed.contains("\t") {
                    delimiter = "\t"
                } else if trimmed.contains(";") && !trimmed.contains(",") {
                    delimiter = ";"
                } else {
                    delimiter = ","
                }

                let cells = trimmed.split(separator: delimiter, omittingEmptySubsequences: false).map { String($0) }
                let escapedCells = cells.map { cell -> String in
                    let clean = cell.trimmingCharacters(in: .whitespaces)
                    if clean.contains(",") || clean.contains("\"") || clean.contains("\n") {
                        let escaped = clean.replacingOccurrences(of: "\"", with: "\"\"")
                        return "\"\(escaped)\""
                    }
                    return clean
                }
                formattedLines.append(escapedCells.joined(separator: ","))
            }
            csvString = formattedLines.joined(separator: "\r\n")
        }

        guard let data = csvString.data(using: .utf8) else {
            throw DocumentGeneratorError.encodingFailed
        }
        return data
    }
}

// MARK: - Phase 2 OpenXML Generator Scaffolding

/// Extensible protocol for Phase 2 OpenXML document generation (DOCX, XLSX, PPTX).
public protocol OpenXMLGeneratable {
    var format: DocumentFormat { get }
    func generatePackage(title: String, content: String, metadata: [String: String]) throws -> Data
}

public final class DOCXGenerator: OpenXMLGeneratable {
    public let format: DocumentFormat = .docx

    public init() {}

    public func generatePackage(title: String, content: String, metadata: [String: String]) throws -> Data {
        // Phase 2 OpenXML Packaging Scaffolding
        // In Phase 2, this packages standard OpenXML parts (word/document.xml, [Content_Types].xml, _rels/.rels).
        // For Phase 1 foundational build, we generate a structured placeholder template.
        let template = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <!-- TrollDocs Phase 2 OpenXML Word Document Structure -->
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            <w:p>
              <w:r><w:t>\(title)</w:t></w:r>
            </w:p>
            <w:p>
              <w:r><w:t>\(content)</w:t></w:r>
            </w:p>
          </w:body>
        </w:document>
        """
        guard let data = template.data(using: .utf8) else {
            throw DocumentGeneratorError.encodingFailed
        }
        return data
    }
}

public final class XLSXGenerator: OpenXMLGeneratable {
    public let format: DocumentFormat = .xlsx

    public init() {}

    public func generatePackage(title: String, content: String, metadata: [String: String]) throws -> Data {
        let template = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <!-- TrollDocs Phase 2 OpenXML Spreadsheet Structure -->
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            <row r="1">
              <c r="A1" t="inlineStr"><is><t>\(title)</t></is></c>
            </row>
            <row r="2">
              <c r="A2" t="inlineStr"><is><t>\(content)</t></is></c>
            </row>
          </sheetData>
        </worksheet>
        """
        guard let data = template.data(using: .utf8) else {
            throw DocumentGeneratorError.encodingFailed
        }
        return data
    }
}

public final class PPTXGenerator: OpenXMLGeneratable {
    public let format: DocumentFormat = .pptx

    public init() {}

    public func generatePackage(title: String, content: String, metadata: [String: String]) throws -> Data {
        let template = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <!-- TrollDocs Phase 2 OpenXML Presentation Structure -->
        <p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:cSld>
            <p:spTree>
              <p:sp>
                <p:txBody>
                  <a:p xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                    <a:r><a:t>\(title)</a:t></a:r>
                  </a:p>
                  <a:p xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                    <a:r><a:t>\(content)</a:t></a:r>
                  </a:p>
                </p:txBody>
              </p:sp>
            </p:spTree>
          </p:cSld>
        </p:sld>
        """
        guard let data = template.data(using: .utf8) else {
            throw DocumentGeneratorError.encodingFailed
        }
        return data
    }
}

// MARK: - Unified Document Generator Service

public final class DocumentGeneratorService: DocumentGeneratorProtocol {
    public static let shared = DocumentGeneratorService()

    private let pdfGenerator = PDFDocumentGenerator()
    private let txtGenerator = PlainTextDocumentGenerator()
    private let csvGenerator = CSVDocumentGenerator()
    private let docxGenerator = DOCXGenerator()
    private let xlsxGenerator = XLSXGenerator()
    private let pptxGenerator = PPTXGenerator()

    public init() {}

    /// Generates file data for the designated format, title, and body content.
    public func generate(
        format: DocumentFormat,
        title: String,
        content: String,
        metadata: [String: String] = [:]
    ) throws -> Data {
        switch format {
        case .pdf:
            return try pdfGenerator.renderPDF(title: title, content: content, metadata: metadata)
        case .txt:
            return try txtGenerator.renderTXT(title: title, content: content)
        case .csv:
            return try csvGenerator.renderCSV(title: title, content: content)
        case .docx:
            return try docxGenerator.generatePackage(title: title, content: content, metadata: metadata)
        case .xlsx:
            return try xlsxGenerator.generatePackage(title: title, content: content, metadata: metadata)
        case .pptx:
            return try pptxGenerator.generatePackage(title: title, content: content, metadata: metadata)
        }
    }
}
