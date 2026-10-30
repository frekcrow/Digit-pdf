import UIKit
import PDFKit

/// Custom PDFAnnotation that paints a transparent UIImage onto a PDFPage.
final class PDFImageAnnotation: PDFAnnotation {
    private let image: UIImage

    init(bounds: CGRect, image: UIImage) {
        self.image = image
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let cgImage = image.cgImage else { return }
        context.saveGState()
        context.draw(cgImage, in: bounds)
        context.restoreGState()
    }
}

enum PDFAnnotationHelper {

    /// Adds a free-text annotation at the specified location on a page.
    @discardableResult
    static func addFreeText(
        to page: PDFPage,
        text: String,
        bounds: CGRect? = nil,
        fontSize: CGFloat = 14,
        color: UIColor = .black
    ) -> PDFAnnotation {
        let pageBounds = page.bounds(for: .mediaBox)
        let rect = bounds ?? CGRect(
            x: 40,
            y: max(20, pageBounds.height - 100),
            width: min(300, pageBounds.width - 80),
            height: 45
        )

        let annotation = PDFAnnotation(bounds: rect, forType: .freeText, withProperties: nil)
        annotation.contents = text
        annotation.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        annotation.fontColor = color
        annotation.color = UIColor.clear

        page.addAnnotation(annotation)
        return annotation
    }

    /// Adds a stamped signature image onto a page.
    @discardableResult
    static func addSignature(
        to page: PDFPage,
        image: UIImage,
        at point: CGPoint? = nil
    ) -> PDFAnnotation {
        let pageBounds = page.bounds(for: .mediaBox)
        let targetWidth: CGFloat = min(180, pageBounds.width * 0.4)
        let aspect = image.size.height / max(1, image.size.width)
        let targetHeight = targetWidth * aspect

        let originX = point?.x ?? ((pageBounds.width - targetWidth) / 2)
        let originY = point?.y ?? max(50, pageBounds.height * 0.15)
        let rect = CGRect(x: originX, y: originY, width: targetWidth, height: targetHeight)

        let annotation = PDFImageAnnotation(bounds: rect, image: image)
        page.addAnnotation(annotation)
        return annotation
    }

    /// Adds a highlight annotation over the current text selection.
    @discardableResult
    static func addHighlight(
        selection: PDFSelection,
        color: UIColor = UIColor.systemYellow.withAlphaComponent(0.4)
    ) -> [PDFAnnotation] {
        var added: [PDFAnnotation] = []
        for page in selection.pages {
            let bounds = selection.bounds(for: page)
            guard !bounds.isEmpty else { continue }

            let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annotation.color = color
            page.addAnnotation(annotation)
            added.append(annotation)
        }
        return added
    }

    /// Adds a strikethrough annotation over the current text selection.
    @discardableResult
    static func addStrikeout(selection: PDFSelection) -> [PDFAnnotation] {
        var added: [PDFAnnotation] = []
        for page in selection.pages {
            let bounds = selection.bounds(for: page)
            guard !bounds.isEmpty else { continue }

            let annotation = PDFAnnotation(bounds: bounds, forType: .strikeOut, withProperties: nil)
            annotation.color = UIColor.systemRed
            page.addAnnotation(annotation)
            added.append(annotation)
        }
        return added
    }

    /// Adds an underline annotation over the current text selection.
    @discardableResult
    static func addUnderline(selection: PDFSelection) -> [PDFAnnotation] {
        var added: [PDFAnnotation] = []
        for page in selection.pages {
            let bounds = selection.bounds(for: page)
            guard !bounds.isEmpty else { continue }

            let annotation = PDFAnnotation(bounds: bounds, forType: .underline, withProperties: nil)
            annotation.color = UIColor.systemBlue
            page.addAnnotation(annotation)
            added.append(annotation)
        }
        return added
    }

    /// Flattens all annotations, signatures, and drawings into pure vector/raster PDF data.
    static func flatten(document: PDFDocument) -> Data {
        let renderer = UIGraphicsPDFRenderer()
        return renderer.pdfData { context in
            for i in 0..<document.pageCount {
                guard let page = document.page(at: i) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                context.beginPage(withBounds: bounds, pageInfo: [:])

                guard let cgContext = UIGraphicsGetCurrentContext() else { continue }
                cgContext.saveGState()
                // PDF coordinates have origin at bottom-left; UIKit at top-left
                cgContext.translateBy(x: 0, y: bounds.height)
                cgContext.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: cgContext)
                cgContext.restoreGState()
            }
        }
    }
}
