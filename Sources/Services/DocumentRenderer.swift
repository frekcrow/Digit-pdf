import Foundation
import UIKit
import CoreText

enum DocumentRendererError: LocalizedError {
    case pageTooNarrow

    var errorDescription: String? {
        switch self {
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
        try pdfData(for: document)
    }

    // MARK: - PDF

    func pdfData(for document: Document) throws -> Data {
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
                drawWatermark(document.page.watermark, in: context.cgContext, pageSize: pageSize)
                drawCover(document, pageSize: pageSize, margin: margin, context: context.cgContext)
            }

            for (index, range) in pages.enumerated() {
                context.beginPage()
                drawPaper(pageSize, in: context.cgContext)
                drawWatermark(document.page.watermark, in: context.cgContext, pageSize: pageSize)

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

    private func drawWatermark(_ watermark: WatermarkSettings, in context: CGContext, pageSize: CGSize) {
        guard watermark.isEnabled && !watermark.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        context.saveGState()

        let center = CGPoint(x: pageSize.width / 2.0, y: pageSize.height / 2.0)
        context.translateBy(x: center.x, y: center.y)
        let radians = watermark.angle * (.pi / 180.0)
        context.rotate(by: CGFloat(radians))

        let font = UIFont.systemFont(ofSize: watermark.fontSize, weight: .black)
        let color = inkColor.withAlphaComponent(CGFloat(watermark.opacity))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let str = NSAttributedString(string: watermark.text, attributes: attributes)
        let textSize = str.size()
        let textRect = CGRect(x: -textSize.width / 2.0, y: -textSize.height / 2.0, width: textSize.width, height: textSize.height)

        str.draw(in: textRect)

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
}
