import Foundation
import UIKit
import CoreText

enum DocumentRendererError: LocalizedError {
    case unsupportedFormat(DocumentFormat)
    case encodingFailed
    case pageTooNarrow

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "\(format.title) output is reserved for the next edition."
        case .encodingFailed:
            return "The document could not be encoded as text."
        case .pageTooNarrow:
            return "The margins leave no room for the text."
        }
    }
}

/// Renders a `Document` into its exported impression.
///
/// The PDF engine is deliberately a typesetter, not a screenshot: it measures
/// the text, plans the pages, then draws running heads, folios and justified
/// body copy with CoreText.
final class DocumentRenderer {
    static let shared = DocumentRenderer()

    // Print colours are fixed. A exported page should look the same at noon and
    // at midnight, and must never inherit the app's dark appearance.
    private let inkColor = UIColor(hex: 0x17130F)
    private let secondaryColor = UIColor(hex: 0x5C5548)
    private let faintColor = UIColor(hex: 0x8C8270)
    private let ruleColor = UIColor(hex: 0xD6CCB9)
    private let accentColor = UIColor(hex: 0x7B2E29)

    private let footerSpace: CGFloat = 32
    private let headerSpace: CGFloat = 30

    private init() {}

    // MARK: - Public

    func data(for document: Document) throws -> Data {
        switch document.format {
        case .pdf:
            return try pdfData(for: document)
        case .txt:
            return try textData(for: document)
        case .csv:
            return try csvData(for: document)
        case .docx:
            return try docxData(for: document)
        case .xlsx:
            return try xlsxData(for: document)
        case .pptx:
            return try pptxData(for: document)
        }
    }

    // MARK: - PDF

    func pdfData(for document: Document) throws -> Data {
        if document.format.isSpreadsheet {
            return try pdfSpreadsheetData(for: document)
        } else if document.format.isPresentation {
            return try pdfPresentationData(for: document)
        }
        let pageSize = document.page.bounds
        let margin = document.page.marginPoints
        let printableWidth = pageSize.width - margin * 2

        guard printableWidth > 80 else {
            throw DocumentRendererError.pageTooNarrow
        }

        let composition = document.typography.composition(
            baseSize: document.typography.bodySize,
            color: inkColor
        )
        let attributed = document.content.compose(composition)

        let titleBlocks = titleLayout(for: document, width: printableWidth, margin: margin)
        let bodyBottom = pageSize.height - margin - footerSpace
        let runningBodyTop = margin + (document.page.headerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 10 : headerSpace)
        let firstBodyTop = document.page.hasCoverPage ? runningBodyTop : titleBlocks.bodyTop

        let firstHeight = max(80, bodyBottom - firstBodyTop)
        let runningHeight = max(80, bodyBottom - runningBodyTop)

        let pages = paginate(
            attributed,
            width: printableWidth,
            firstHeight: firstHeight,
            height: runningHeight
        )

        let rendererFormat = UIGraphicsPDFRendererFormat()
        rendererFormat.documentInfo = [
            kCGPDFContextTitle as String: document.displayTitle,
            kCGPDFContextAuthor as String: document.author,
            kCGPDFContextSubject as String: document.displaySubtitle,
            kCGPDFContextCreator as String: "TrollDocs"
        ]

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pageSize),
            format: rendererFormat
        )

        return renderer.pdfData { context in
            if document.page.hasCoverPage {
                context.beginPage()
                drawPaper(pageSize, in: context.cgContext)
                drawCover(document, pageSize: pageSize, margin: margin, context: context.cgContext)
            }

            for (index, range) in pages.enumerated() {
                context.beginPage()
                drawPaper(pageSize, in: context.cgContext)

                let isOpening = index == 0 && !document.page.hasCoverPage

                if isOpening {
                    drawTitleBlock(document, layout: titleBlocks)
                } else {
                    drawRunningHead(document, pageSize: pageSize, margin: margin, context: context.cgContext)
                }

                drawFolio(
                    document,
                    pageNumber: index + 1,
                    total: pages.count,
                    pageSize: pageSize,
                    margin: margin,
                    context: context.cgContext
                )

                let rect = CGRect(
                    x: margin,
                    y: isOpening ? titleBlocks.bodyTop : runningBodyTop,
                    width: printableWidth,
                    height: isOpening ? firstHeight : runningHeight
                )

                drawBody(attributed, range: range, rect: rect, pageHeight: pageSize.height, context: context.cgContext)
            }
        }
    }

    // MARK: - Page planning

    private func paginate(
        _ attributed: NSAttributedString,
        width: CGFloat,
        firstHeight: CGFloat,
        height: CGFloat
    ) -> [NSRange] {
        guard attributed.length > 0 else {
            return [NSRange(location: 0, length: 0)]
        }

        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
        var ranges: [NSRange] = []
        var location = 0
        var index = 0

        while location < attributed.length && index < 800 {
            let pageHeight = index == 0 ? firstHeight : height
            let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: pageHeight), transform: nil)
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: location, length: 0),
                path,
                nil
            )
            let visible = CTFrameGetVisibleStringRange(frame)

            if visible.length <= 0 { break }

            ranges.append(NSRange(location: location, length: visible.length))
            location += visible.length
            index += 1
        }

        if ranges.isEmpty {
            ranges = [NSRange(location: 0, length: 0)]
        }

        return ranges
    }

    // MARK: - Title block

    private struct TitleBlockLayout {
        let overlineRect: CGRect
        let titleRect: CGRect
        let subtitleRect: CGRect
        let ruleY: CGFloat
        let bylineRect: CGRect
        let bodyTop: CGFloat
    }

    private func titleLayout(for document: Document, width: CGFloat, margin: CGFloat) -> TitleBlockLayout {
        let overlineRect = CGRect(x: margin, y: margin, width: width, height: 11)
        let titleSize = max(22, document.typography.bodySize * 2.05)
        let titleFont = document.typography.typeface.uiFont(size: titleSize)
        let titleHeight = measure(document.displayTitle, font: titleFont, width: width, lineSpacing: 2)
        let titleRect = CGRect(
            x: margin,
            y: overlineRect.maxY + 12,
            width: width,
            height: titleHeight + 2
        )

        var cursor = titleRect.maxY + 7
        var subtitleRect = CGRect.zero

        let subtitle = document.displaySubtitle
        if !subtitle.isEmpty {
            let subtitleFont = document.typography.typeface.uiFont(
                size: document.typography.bodySize * 1.08,
                italic: true
            )
            let subtitleHeight = measure(subtitle, font: subtitleFont, width: width, lineSpacing: 1)
            subtitleRect = CGRect(x: margin, y: cursor, width: width, height: subtitleHeight + 2)
            cursor = subtitleRect.maxY + 6
        }

        let ruleY = cursor + 6
        cursor = ruleY + 16

        var bylineRect = CGRect.zero
        let author = document.author.trimmingCharacters(in: .whitespacesAndNewlines)
        if !author.isEmpty {
            bylineRect = CGRect(x: margin, y: cursor, width: width, height: 12)
            cursor = bylineRect.maxY
        }

        return TitleBlockLayout(
            overlineRect: overlineRect,
            titleRect: titleRect,
            subtitleRect: subtitleRect,
            ruleY: ruleY,
            bylineRect: bylineRect,
            bodyTop: cursor + 26
        )
    }

    private func drawTitleBlock(_ document: Document, layout: TitleBlockLayout) {
        let overlineFont = UIFont.systemFont(ofSize: 7.5, weight: .semibold)
        drawText(
            longDate(document.updatedAt).uppercased(),
            in: layout.overlineRect,
            font: overlineFont,
            color: faintColor,
            tracking: 1.9,
            singleLine: true
        )

        let titleFont = document.typography.typeface.uiFont(
            size: max(22, document.typography.bodySize * 2.05)
        )
        drawText(
            document.displayTitle,
            in: layout.titleRect,
            font: titleFont,
            color: inkColor,
            lineSpacing: 2
        )

        if layout.subtitleRect.height > 0 {
            let subtitleFont = document.typography.typeface.uiFont(
                size: document.typography.bodySize * 1.08,
                italic: true
            )
            drawText(
                document.displaySubtitle,
                in: layout.subtitleRect,
                font: subtitleFont,
                color: secondaryColor,
                lineSpacing: 1
            )
        }

        if document.page.showsRules {
            drawRule(from: layout.overlineRect.minX, to: layout.overlineRect.maxX, y: layout.ruleY, color: ruleColor, weight: 0.5)
            drawRule(from: layout.overlineRect.minX, to: layout.overlineRect.minX + 44, y: layout.ruleY, color: accentColor, weight: 1.5)
        }

        if layout.bylineRect.height > 0 {
            let bylineFont = UIFont.systemFont(ofSize: 8.5, weight: .medium)
            drawText(
                "Prepared by \(document.author)".uppercased(),
                in: layout.bylineRect,
                font: bylineFont,
                color: secondaryColor,
                tracking: 1.5,
                singleLine: true
            )
        }
    }

    // MARK: - Cover

    private func drawCover(_ document: Document, pageSize: CGSize, margin: CGFloat, context: CGContext) {
        let width = pageSize.width - margin * 2

        if document.page.showsRules {
            let frame = CGRect(origin: .zero, size: pageSize).insetBy(dx: 26, dy: 26)
            context.saveGState()
            context.setStrokeColor(ruleColor.cgColor)
            context.setLineWidth(0.5)
            context.stroke(frame)
            context.restoreGState()
        }

        let overlineFont = UIFont.systemFont(ofSize: 7.5, weight: .semibold)
        drawText(
            document.format.title.uppercased(),
            in: CGRect(x: margin, y: 64, width: width / 2, height: 12),
            font: overlineFont,
            color: faintColor,
            tracking: 1.9,
            singleLine: true
        )
        drawText(
            longDate(document.updatedAt).uppercased(),
            in: CGRect(x: margin + width / 2, y: 64, width: width / 2, height: 12),
            font: overlineFont,
            color: faintColor,
            alignment: .right,
            tracking: 1.9,
            singleLine: true
        )

        let titleFont = document.typography.typeface.uiFont(
            size: max(30, document.typography.bodySize * 2.7)
        )
        let titleHeight = measure(document.displayTitle, font: titleFont, width: width, lineSpacing: 3)
        var cursor = pageSize.height * 0.33

        drawText(
            document.displayTitle,
            in: CGRect(x: margin, y: cursor, width: width, height: titleHeight + 6),
            font: titleFont,
            color: inkColor,
            lineSpacing: 3
        )
        cursor += titleHeight + 20

        if document.page.showsRules {
            drawRule(from: margin, to: margin + 46, y: cursor, color: accentColor, weight: 1.5)
        }
        cursor += 24

        let subtitle = document.displaySubtitle
        if !subtitle.isEmpty {
            let subtitleFont = document.typography.typeface.uiFont(
                size: max(11.5, document.typography.bodySize * 1.05),
                italic: true
            )
            let subtitleHeight = measure(subtitle, font: subtitleFont, width: width, lineSpacing: 1)
            drawText(
                subtitle,
                in: CGRect(x: margin, y: cursor, width: width, height: subtitleHeight + 2),
                font: subtitleFont,
                color: secondaryColor,
                lineSpacing: 1
            )
        }

        let author = document.author.trimmingCharacters(in: .whitespacesAndNewlines)
        if !author.isEmpty {
            let bylineFont = UIFont.systemFont(ofSize: 8.5, weight: .medium)
            drawText(
                author.uppercased(),
                in: CGRect(x: margin, y: pageSize.height - 104, width: width, height: 12),
                font: bylineFont,
                color: secondaryColor,
                tracking: 1.8,
                singleLine: true
            )
        }
    }

    // MARK: - Running head & folio

    private func drawRunningHead(_ document: Document, pageSize: CGSize, margin: CGFloat, context: CGContext) {
        let header = document.page.headerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !header.isEmpty else { return }

        let width = pageSize.width - margin * 2
        let font = UIFont.systemFont(ofSize: 7.5, weight: .semibold)

        drawText(
            header.uppercased(),
            in: CGRect(x: margin, y: margin, width: width * 0.62, height: 11),
            font: font,
            color: faintColor,
            tracking: 1.7,
            singleLine: true
        )
        drawText(
            document.displayTitle,
            in: CGRect(x: margin + width * 0.62, y: margin, width: width * 0.38, height: 11),
            font: document.typography.typeface.uiFont(size: 8, italic: true),
            color: faintColor,
            alignment: .right,
            singleLine: true
        )

        if document.page.showsRules {
            drawRule(from: margin, to: margin + width, y: margin + 16, color: ruleColor, weight: 0.5)
        }
    }

    private func drawFolio(
        _ document: Document,
        pageNumber: Int,
        total: Int,
        pageSize: CGSize,
        margin: CGFloat,
        context: CGContext
    ) {
        let footer = document.page.footerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasFolio = document.page.showsPageNumbers
        guard hasFolio || !footer.isEmpty else { return }

        let width = pageSize.width - margin * 2
        let ruleY = pageSize.height - margin - 20

        if document.page.showsRules {
            drawRule(from: margin, to: margin + width, y: ruleY, color: ruleColor, weight: 0.5)
        }

        if !footer.isEmpty {
            drawText(
                footer.uppercased(),
                in: CGRect(x: margin, y: ruleY + 5, width: width * 0.62, height: 12),
                font: UIFont.systemFont(ofSize: 7.5, weight: .semibold),
                color: faintColor,
                tracking: 1.5,
                singleLine: true
            )
        }

        if hasFolio {
            let label = document.page.pageNumberStyle.label(page: pageNumber, total: total)
            drawText(
                label,
                in: CGRect(x: margin + width * 0.62, y: ruleY + 3, width: width * 0.38, height: 13),
                font: document.typography.typeface.uiFont(size: 9),
                color: secondaryColor,
                alignment: .right,
                singleLine: true
            )
        }
    }

    // MARK: - Body

    private func drawBody(
        _ attributed: NSAttributedString,
        range: NSRange,
        rect: CGRect,
        pageHeight: CGFloat,
        context: CGContext
    ) {
        guard range.length > 0 else { return }

        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)

        context.saveGState()
        context.translateBy(x: 0, y: pageHeight)
        context.scaleBy(x: 1, y: -1)

        let flipped = CGRect(
            x: rect.origin.x,
            y: pageHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        let path = CGPath(rect: flipped, transform: nil)
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: range.location, length: 0),
            path,
            nil
        )
        CTFrameDraw(frame, context)
        context.restoreGState()
    }

    // MARK: - Text primitives

    private func drawPaper(_ size: CGSize, in context: CGContext) {
        context.saveGState()
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.restoreGState()
    }

    private func measure(_ text: String, font: UIFont, width: CGFloat, lineSpacing: CGFloat = 0) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.lineSpacing = lineSpacing
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: style],
            context: nil
        )
        return ceil(rect.height)
    }

    private func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left,
        tracking: CGFloat = 0,
        lineSpacing: CGFloat = 0,
        singleLine: Bool = false
    ) {
        guard !text.isEmpty else { return }
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = singleLine ? .byTruncatingTail : .byWordWrapping
        style.lineSpacing = lineSpacing

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        if tracking != 0 {
            attributes[.kern] = tracking
        }

        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
    }

    private func drawRule(from x1: CGFloat, to x2: CGFloat, y: CGFloat, color: UIColor, weight: CGFloat) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(max(0.4, weight))
        context.move(to: CGPoint(x: x1, y: y))
        context.addLine(to: CGPoint(x: x2, y: y))
        context.strokePath()
        context.restoreGState()
    }

    private func longDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Plain text & CSV

    private func textData(for document: Document) throws -> Data {
        var lines: [String] = []
        let title = document.displayTitle
        lines.append(title.uppercased())
        lines.append(String(repeating: "=", count: min(72, max(12, title.count))))
        if !document.displaySubtitle.isEmpty {
            lines.append(document.displaySubtitle)
        }
        let author = document.author.trimmingCharacters(in: .whitespacesAndNewlines)
        if !author.isEmpty {
            lines.append("By \(author)")
        }
        lines.append(longDate(document.updatedAt))
        lines.append("")
        lines.append(document.content.plainText)

        let output = lines.joined(separator: "\n") + "\n"
        guard let data = output.data(using: .utf8) else {
            throw DocumentRendererError.encodingFailed
        }
        return data
    }

    private func csvData(for document: Document) throws -> Data {
        if document.format.isSpreadsheet {
            let csvStr = document.spreadsheetData.toCSV()
            guard let data = csvStr.data(using: .utf8) else {
                throw DocumentRendererError.encodingFailed
            }
            return data
        }

        let rawLines = document.content.plainText.components(separatedBy: .newlines)
        var rows: [String] = []

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let delimiter: Character
            if trimmed.contains("\t") {
                delimiter = "\t"
            } else if trimmed.contains(";") && !trimmed.contains(",") {
                delimiter = ";"
            } else {
                delimiter = ","
            }

            let cells = trimmed.split(separator: delimiter, omittingEmptySubsequences: false).map(String.init)
            let escaped = cells.map { cell -> String in
                let clean = cell.trimmingCharacters(in: .whitespaces)
                if clean.contains(",") || clean.contains("\"") || clean.contains("\n") {
                    let doubled = clean.replacingOccurrences(of: "\"", with: "\"\"")
                    return "\"" + doubled + "\""
                }
                return clean
            }
            rows.append(escaped.joined(separator: ","))
        }

        let output = rows.isEmpty ? "" : rows.joined(separator: "\r\n") + "\r\n"
        guard let data = output.data(using: .utf8) else {
            throw DocumentRendererError.encodingFailed
        }
        return data
    }

    // MARK: - Spreadsheet PDF Rendering

    private func pdfSpreadsheetData(for document: Document) throws -> Data {
        let sheet = document.spreadsheetData
        let pageSize = CGSize(width: 792, height: 612) // US Letter Landscape
        let margin: CGFloat = 36.0
        let printableWidth = pageSize.width - (margin * 2)

        let rendererFormat = UIGraphicsPDFRendererFormat()
        rendererFormat.documentInfo = [
            kCGPDFContextTitle as String: document.displayTitle,
            kCGPDFContextCreator as String: "TrollDocs Sheets"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: rendererFormat)
        let colCount = max(1, sheet.columnCount)
        let colWidth = printableWidth / CGFloat(colCount)
        let headerRowHeight: CGFloat = 24.0
        let dataRowHeight: CGFloat = 20.0

        let rowsPerPage = Int((pageSize.height - margin * 2 - 80) / dataRowHeight)
        let totalPages = max(1, Int(ceil(Double(sheet.rowCount) / Double(max(1, rowsPerPage)))))

        return renderer.pdfData { context in
            var currentRow = 0
            var pageIndex = 1

            while currentRow < sheet.rowCount || pageIndex == 1 {
                context.beginPage()
                let cg = context.cgContext

                // Document Title Header
                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                    .foregroundColor: inkColor
                ]
                (document.displayTitle as NSString).draw(at: CGPoint(x: margin, y: margin), withAttributes: titleAttrs)

                let metaStr = "Generated on \(longDate(document.updatedAt)) • \(sheet.rowCount) rows × \(sheet.columnCount) cols"
                let metaAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                    .foregroundColor: secondaryColor
                ]
                (metaStr as NSString).draw(at: CGPoint(x: margin, y: margin + 22), withAttributes: metaAttrs)

                var yPos = margin + 44.0

                // Draw Table Header
                let headerRect = CGRect(x: margin, y: yPos, width: printableWidth, height: headerRowHeight)
                cg.setFillColor(UIColor(hex: 0x1B1712).cgColor)
                cg.fill(headerRect)

                for c in 0..<colCount {
                    let cellX = margin + CGFloat(c) * colWidth
                    let colName = sheet.headers[c]
                    let headerCellAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9.5, weight: .bold),
                        .foregroundColor: UIColor.white
                    ]
                    let textRect = CGRect(x: cellX + 4, y: yPos + 5, width: colWidth - 8, height: headerRowHeight - 10)
                    (colName as NSString).draw(in: textRect, withAttributes: headerCellAttrs)
                }
                yPos += headerRowHeight

                // Draw Table Data Rows
                let rowsToDraw = min(rowsPerPage, sheet.rowCount - currentRow)
                for _ in 0..<rowsToDraw {
                    guard currentRow < sheet.rowCount else { break }
                    let isEven = (currentRow % 2 == 0)
                    let rowRect = CGRect(x: margin, y: yPos, width: printableWidth, height: dataRowHeight)

                    if !isEven {
                        cg.setFillColor(UIColor(hex: 0xF5F2EB).cgColor)
                        cg.fill(rowRect)
                    }

                    cg.setStrokeColor(ruleColor.cgColor)
                    cg.setLineWidth(0.5)
                    cg.stroke(rowRect)

                    for c in 0..<colCount {
                        let cellX = margin + CGFloat(c) * colWidth
                        let val = sheet.evaluatedCell(row: currentRow, col: c)
                        let cellAttrs: [NSAttributedString.Key: Any] = [
                            .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .regular),
                            .foregroundColor: inkColor
                        ]
                        let textRect = CGRect(x: cellX + 4, y: yPos + 3, width: colWidth - 8, height: dataRowHeight - 6)
                        (val as NSString).draw(in: textRect, withAttributes: cellAttrs)
                    }

                    yPos += dataRowHeight
                    currentRow += 1
                }

                // Page Footer
                let footerStr = "TrollDocs Sheets • Page \(pageIndex) of \(totalPages)"
                let footerAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 8, weight: .regular),
                    .foregroundColor: faintColor
                ]
                let footRect = CGRect(x: margin, y: pageSize.height - margin + 6, width: printableWidth, height: 14)
                (footerStr as NSString).draw(in: footRect, withAttributes: footerAttrs)

                pageIndex += 1
            }
        }
    }

    // MARK: - Presentation PDF Rendering

    private func pdfPresentationData(for document: Document) throws -> Data {
        let deck = document.presentationDeck
        let pageSize = CGSize(width: 960, height: 540) // 16:9 Widescreen Presentation

        let rendererFormat = UIGraphicsPDFRendererFormat()
        rendererFormat.documentInfo = [
            kCGPDFContextTitle as String: document.displayTitle,
            kCGPDFContextCreator as String: "TrollDocs Slides"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: rendererFormat)

        return renderer.pdfData { context in
            for (idx, slide) in deck.slides.enumerated() {
                context.beginPage()
                let cg = context.cgContext

                // Background
                let bgUIColor = UIColor(slide.theme.backgroundColor)
                cg.setFillColor(bgUIColor.cgColor)
                cg.fill(CGRect(origin: .zero, size: pageSize))

                let titleUIColor = UIColor(slide.theme.titleColor)
                let bodyUIColor = UIColor(slide.theme.bodyColor)
                let accentUIColor = UIColor(slide.theme.accentColor)

                let marginX: CGFloat = 60.0

                switch slide.layout {
                case .titleSlide:
                    let titleAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 42, weight: .bold),
                        .foregroundColor: titleUIColor
                    ]
                    let titleRect = CGRect(x: marginX, y: 180, width: pageSize.width - (marginX * 2), height: 60)
                    (slide.title as NSString).draw(in: titleRect, withAttributes: titleAttrs)

                    // Accent rule
                    cg.setFillColor(accentUIColor.cgColor)
                    cg.fill(CGRect(x: marginX, y: 250, width: 90, height: 4))

                    let subAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 20, weight: .medium),
                        .foregroundColor: bodyUIColor
                    ]
                    let subRect = CGRect(x: marginX, y: 270, width: pageSize.width - (marginX * 2), height: 40)
                    (slide.subtitle as NSString).draw(in: subRect, withAttributes: subAttrs)

                case .bulletPoints, .blank:
                    let titleAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 32, weight: .bold),
                        .foregroundColor: titleUIColor
                    ]
                    (slide.title as NSString).draw(at: CGPoint(x: marginX, y: 50), withAttributes: titleAttrs)

                    cg.setFillColor(accentUIColor.cgColor)
                    cg.fill(CGRect(x: marginX, y: 94, width: pageSize.width - (marginX * 2), height: 3))

                    var yPos: CGFloat = 120
                    for point in slide.bulletPoints {
                        // Bullet dot
                        cg.setFillColor(accentUIColor.cgColor)
                        cg.fillEllipse(in: CGRect(x: marginX, y: yPos + 6, width: 8, height: 8))

                        let pointAttrs: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 18, weight: .regular),
                            .foregroundColor: bodyUIColor
                        ]
                        let pointRect = CGRect(x: marginX + 20, y: yPos, width: pageSize.width - marginX * 2 - 20, height: 36)
                        (point as NSString).draw(in: pointRect, withAttributes: pointAttrs)
                        yPos += 42
                    }

                case .twoColumn:
                    let titleAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 30, weight: .bold),
                        .foregroundColor: titleUIColor
                    ]
                    (slide.title as NSString).draw(at: CGPoint(x: marginX, y: 50), withAttributes: titleAttrs)

                    cg.setFillColor(accentUIColor.cgColor)
                    cg.fill(CGRect(x: marginX, y: 92, width: pageSize.width - (marginX * 2), height: 3))

                    let colW = (pageSize.width - marginX * 2 - 40) / 2
                    let colAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                        .foregroundColor: bodyUIColor
                    ]

                    (slide.leftColumnText as NSString).draw(in: CGRect(x: marginX, y: 120, width: colW, height: 340), withAttributes: colAttrs)
                    (slide.rightColumnText as NSString).draw(in: CGRect(x: marginX + colW + 40, y: 120, width: colW, height: 340), withAttributes: colAttrs)

                case .sectionHeader:
                    let secAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                        .foregroundColor: accentUIColor
                    ]
                    ("SECTION" as NSString).draw(at: CGPoint(x: marginX, y: 210), withAttributes: secAttrs)

                    let titleAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 44, weight: .bold),
                        .foregroundColor: titleUIColor
                    ]
                    (slide.title as NSString).draw(at: CGPoint(x: marginX, y: 236), withAttributes: titleAttrs)
                }

                // Slide Footer
                let footStr = "\(document.displayTitle) • Slide \(idx + 1) of \(deck.slideCount)"
                let footAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: bodyUIColor.withAlphaComponent(0.5)
                ]
                (footStr as NSString).draw(at: CGPoint(x: marginX, y: pageSize.height - 35), withAttributes: footAttrs)
            }
        }
    }

    // MARK: - OpenXML DOCX / XLSX / PPTX Generators

    private func docxData(for document: Document) throws -> Data {
        let escapedTitle = document.displayTitle.replacingOccurrences(of: "&", with: "&amp;")
                                               .replacingOccurrences(of: "<", with: "&lt;")
                                               .replacingOccurrences(of: ">", with: "&gt;")
        let paragraphs = document.content.paragraphs.map { p -> String in
            let text = p.text.replacingOccurrences(of: "&", with: "&amp;")
                             .replacingOccurrences(of: "<", with: "&lt;")
                             .replacingOccurrences(of: ">", with: "&gt;")
            return "<w:p><w:r><w:t>\(text)</w:t></w:r></w:p>"
        }.joined(separator: "\n")

        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            <w:p>
              <w:pPr><w:pStyle w:val="Title"/></w:pPr>
              <w:r><w:t>\(escapedTitle)</w:t></w:r>
            </w:p>
            \(paragraphs)
          </w:body>
        </w:document>
        """
        guard let data = xml.data(using: .utf8) else {
            throw DocumentRendererError.encodingFailed
        }
        return data
    }

    private func xlsxData(for document: Document) throws -> Data {
        let sheet = document.spreadsheetData
        var rowsXml = ""

        // Header Row
        rowsXml += "<Row ss:StyleID=\"Header\">\n"
        for header in sheet.headers {
            let clean = header.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            rowsXml += "  <Cell><Data ss:Type=\"String\">\(clean)</Data></Cell>\n"
        }
        rowsXml += "</Row>\n"

        // Data Rows
        for r in 0..<sheet.rowCount {
            rowsXml += "<Row>\n"
            for c in 0..<sheet.columnCount {
                let cellVal = sheet.evaluatedCell(row: r, col: c)
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                let isNum = Double(cellVal) != nil
                let type = isNum ? "Number" : "String"
                rowsXml += "  <Cell><Data ss:Type=\"\(type)\">\(cellVal)</Data></Cell>\n"
            }
            rowsXml += "</Row>\n"
        }

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <?mso-application progid="Excel.Sheet"?>
        <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
         xmlns:o="urn:schemas-microsoft-com:office:office"
         xmlns:x="urn:schemas-microsoft-com:office:excel"
         xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
          <Styles>
            <Style ss:ID="Header">
              <Font ss:Bold="1" ss:Color="#FFFFFF"/>
              <Interior ss:Color="#1B1712" ss:Pattern="Solid"/>
            </Style>
          </Styles>
          <Worksheet ss:Name="Sheet1">
            <Table>
              \(rowsXml)
            </Table>
          </Worksheet>
        </Workbook>
        """
        guard let data = xml.data(using: .utf8) else {
            throw DocumentRendererError.encodingFailed
        }
        return data
    }

    private func pptxData(for document: Document) throws -> Data {
        let deck = document.presentationDeck
        var slidesXml = ""

        for slide in deck.slides {
            let escapedTitle = slide.title.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            let bullets = slide.bulletPoints.map { b in
                let clean = b.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
                return "<a:p><a:r><a:t>\(clean)</a:t></a:r></a:p>"
            }.joined(separator: "\n")

            slidesXml += """
            <p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
              <p:cSld>
                <p:spTree>
                  <p:sp>
                    <p:txBody>
                      <a:p><a:r><a:t>\(escapedTitle)</a:t></a:r></a:p>
                      \(bullets)
                    </p:txBody>
                  </p:sp>
                </p:spTree>
              </p:cSld>
            </p:sld>
            """
        }

        guard let data = slidesXml.data(using: .utf8) else {
            throw DocumentRendererError.encodingFailed
        }
        return data
    }
}
