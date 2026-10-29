import Foundation
import SwiftUI
import UIKit

// MARK: - Page geometry

enum PageSize: String, CaseIterable, Codable, Identifiable {
    case a4
    case letter
    case legal
    case a5

    var id: String { rawValue }

    var title: String {
        switch self {
        case .a4: return "A4"
        case .letter: return "Letter"
        case .legal: return "Legal"
        case .a5: return "A5"
        }
    }

    var detail: String {
        switch self {
        case .a4: return "210 x 297 mm"
        case .letter: return "8.5 x 11 in"
        case .legal: return "8.5 x 14 in"
        case .a5: return "148 x 210 mm"
        }
    }

    /// Portrait dimensions in PostScript points (1/72 inch).
    var points: CGSize {
        switch self {
        case .a4: return CGSize(width: 595.28, height: 841.89)
        case .letter: return CGSize(width: 612, height: 792)
        case .legal: return CGSize(width: 612, height: 1008)
        case .a5: return CGSize(width: 419.53, height: 595.28)
        }
    }
}

enum PageOrientation: String, CaseIterable, Codable, Identifiable {
    case portrait
    case landscape

    var id: String { rawValue }

    var title: String {
        switch self {
        case .portrait: return "Portrait"
        case .landscape: return "Landscape"
        }
    }

    var systemIcon: String {
        switch self {
        case .portrait: return "rectangle.portrait"
        case .landscape: return "rectangle"
        }
    }
}

enum MarginPreset: String, CaseIterable, Codable, Identifiable {
    case narrow
    case normal
    case wide
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .narrow: return "Narrow"
        case .normal: return "Normal"
        case .wide: return "Wide"
        case .custom: return "Custom"
        }
    }

    var detail: String {
        switch self {
        case .narrow: return "13 mm"
        case .normal: return "20 mm"
        case .wide: return "25 mm"
        case .custom: return "Set by hand"
        }
    }

    /// Uniform margin in points.
    var points: CGFloat {
        switch self {
        case .narrow: return 36
        case .normal: return 57
        case .wide: return 71
        case .custom: return 57
        }
    }
}

enum PageNumberStyle: String, CaseIterable, Codable, Identifiable {
    case numerals
    case pageOfTotal
    case pageWord

    var id: String { rawValue }

    var title: String {
        switch self {
        case .numerals: return "1"
        case .pageOfTotal: return "1 / 4"
        case .pageWord: return "Page 1"
        }
    }

    func label(page: Int, total: Int) -> String {
        switch self {
        case .numerals: return "\(page)"
        case .pageOfTotal: return "\(page) / \(total)"
        case .pageWord: return "Page \(page)"
        }
    }
}

struct PageSettings: Codable, Equatable {
    var size: PageSize = .a4
    var orientation: PageOrientation = .portrait
    var margin: MarginPreset = .normal
    var customMargin: CGFloat = 57
    var showsPageNumbers: Bool = true
    var pageNumberStyle: PageNumberStyle = .pageOfTotal
    var headerText: String = ""
    var footerText: String = ""
    var showsRules: Bool = true
    var hasCoverPage: Bool = false

    var bounds: CGSize {
        let base = size.points
        return orientation == .portrait
            ? base
            : CGSize(width: base.height, height: base.width)
    }

    var marginPoints: CGFloat {
        if margin == .custom {
            return max(24, min(120, customMargin))
        }
        return margin.points
    }

    var marginDetail: String {
        if margin == .custom {
            return "\(Int(customMargin.rounded())) pt"
        }
        return margin.detail
    }
}

// MARK: - Typeface

enum DocumentFont: String, CaseIterable, Codable, Identifiable {
    case newYork
    case palatino
    case georgia
    case baskerville
    case times
    case system
    case menlo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newYork: return "New York"
        case .palatino: return "Palatino"
        case .georgia: return "Georgia"
        case .baskerville: return "Baskerville"
        case .times: return "Times"
        case .system: return "San Francisco"
        case .menlo: return "Menlo"
        }
    }

    private var postScriptNames: [String] {
        switch self {
        case .newYork: return []
        case .palatino: return ["Palatino-Roman", "Palatino"]
        case .georgia: return ["Georgia"]
        case .baskerville: return ["Baskerville"]
        case .times: return ["TimesNewRomanPSMT", "TimesNewRomanPS"]
        case .system: return []
        case .menlo: return ["Menlo-Regular", "Menlo"]
        }
    }

    func uiFont(size: CGFloat, bold: Bool = false, italic: Bool = false) -> UIFont {
        var descriptor: UIFontDescriptor

        if self == .newYork {
            descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            if let serif = descriptor.withDesign(.serif) {
                descriptor = serif
            }
        } else if let name = postScriptNames.first(where: { UIFont(name: $0, size: size) != nil }),
                  let base = UIFont(name: name, size: size) {
            descriptor = base.fontDescriptor
        } else {
            descriptor = UIFont.systemFont(ofSize: size).fontDescriptor
        }

        var traits: UIFontDescriptor.SymbolicTraits = []
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        if let updated = descriptor.withSymbolicTraits(traits) {
            descriptor = updated
        }

        return UIFont(descriptor: descriptor, size: size)
    }
}

// MARK: - Typography

enum TextAlignmentOption: String, CaseIterable, Codable, Identifiable {
    case left
    case justified
    case center
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: return "Left"
        case .justified: return "Justified"
        case .center: return "Centred"
        case .right: return "Right"
        }
    }

    var systemIcon: String {
        switch self {
        case .left: return "text.alignleft"
        case .justified: return "text.justify"
        case .center: return "text.aligncenter"
        case .right: return "text.alignright"
        }
    }

    var nsAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .justified: return .justified
        case .center: return .center
        case .right: return .right
        }
    }
}

struct TypographySettings: Codable, Equatable {
    var typeface: DocumentFont = .newYork
    var bodySize: CGFloat = 11.5
    var leading: CGFloat = 1.45
    var paragraphSpacing: CGFloat = 9
    var alignment: TextAlignmentOption = .justified
    var firstLineIndent: CGFloat = 0

    func composition(baseSize: CGFloat? = nil, color: UIColor) -> TextComposition {
        TextComposition(
            font: typeface,
            baseSize: baseSize ?? bodySize,
            leading: leading,
            paragraphSpacing: paragraphSpacing,
            alignment: alignment,
            firstLineIndent: firstLineIndent,
            color: color
        )
    }
}

/// Everything needed to turn the pure `RichText` model into an attributed
/// string, for either the screen or the printed page.
struct TextComposition {
    var font: DocumentFont = .newYork
    var baseSize: CGFloat = 11.5
    var leading: CGFloat = 1.45
    var paragraphSpacing: CGFloat = 9
    var alignment: TextAlignmentOption = .justified
    var firstLineIndent: CGFloat = 0
    var color: UIColor = .label

    func size(for kind: ParagraphKind) -> CGFloat {
        baseSize * kind.sizeMultiple
    }

    func paragraphStyle(for kind: ParagraphKind) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = kind == .quote ? .left : alignment.nsAlignment
        style.lineBreakMode = .byWordWrapping
        style.lineHeightMultiple = leading
        style.paragraphSpacing = paragraphSpacing
        style.paragraphSpacingBefore = kind == .heading
            ? size(for: kind) * 1.0
            : (kind == .subheading ? size(for: kind) * 0.55 : 0)
        style.firstLineHeadIndent = kind == .body ? firstLineIndent : 0
        style.headIndent = kind == .quote ? size(for: kind) * 1.3 : 0
        return style
    }

    func attributes(for kind: ParagraphKind) -> [NSAttributedString.Key: Any] {
        let runFont = font.uiFont(
            size: size(for: kind),
            bold: kind.isBoldByDefault,
            italic: kind == .quote
        )
        return [
            .font: runFont,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle(for: kind),
            .paragraphKind: kind.rawValue
        ]
    }
}

extension DocumentFont {
    /// The same face, for SwiftUI specimen lines.
    func swiftUIFont(size: CGFloat) -> Font {
        switch self {
        case .newYork:
            return .system(size: size, design: .serif)
        case .system:
            return .system(size: size)
        case .menlo:
            return .system(size: size, design: .monospaced)
        default:
            if let name = postScriptNames.first(where: { UIFont(name: $0, size: size) != nil }) {
                return .custom(name, size: size)
            }
            return .system(size: size, design: .serif)
        }
    }
}
