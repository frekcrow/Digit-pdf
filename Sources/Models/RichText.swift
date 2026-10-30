import Foundation
import UIKit

extension NSAttributedString.Key {
    static let paragraphKind = NSAttributedString.Key("TrollDocsParagraphKind")
}

// MARK: - Structure

enum ParagraphKind: String, CaseIterable, Codable, Identifiable {
    case body
    case heading
    case subheading
    case quote
    case bulletList
    case numberedList
    case divider
    case pageBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .body: return "Body"
        case .heading: return "Heading 1"
        case .subheading: return "Heading 2"
        case .quote: return "Quotation"
        case .bulletList: return "Bulleted List"
        case .numberedList: return "Numbered List"
        case .divider: return "Section Divider"
        case .pageBreak: return "Hard Page Break"
        }
    }

    var shortTitle: String {
        switch self {
        case .body: return "BODY"
        case .heading: return "H1"
        case .subheading: return "H2"
        case .quote: return "QUOTE"
        case .bulletList: return "• LIST"
        case .numberedList: return "1. LIST"
        case .divider: return "LINE"
        case .pageBreak: return "PAGE BREAK"
        }
    }

    var sizeMultiple: CGFloat {
        switch self {
        case .body: return 1
        case .heading: return 1.55
        case .subheading: return 1.2
        case .quote: return 1
        case .bulletList: return 1
        case .numberedList: return 1
        case .divider: return 0.7
        case .pageBreak: return 0.6
        }
    }

    var isBoldByDefault: Bool {
        self == .heading || self == .subheading
    }

    var isList: Bool {
        self == .bulletList || self == .numberedList
    }
}

/// A run of text sharing the same inline emphasis. Sizes are intentionally not
/// stored: they are derived from the paragraph kind and the page typography, so
/// changing the document's type never leaves orphaned point sizes behind.
struct RichRun: Codable, Equatable {
    var text: String
    var bold: Bool
    var italic: Bool
    var underline: Bool

    init(_ text: String = "", bold: Bool = false, italic: Bool = false, underline: Bool = false) {
        self.text = text
        self.bold = bold
        self.italic = italic
        self.underline = underline
    }
}

struct RichParagraph: Codable, Equatable {
    var kind: ParagraphKind
    var runs: [RichRun]

    init(kind: ParagraphKind = .body, runs: [RichRun] = [RichRun()]) {
        self.kind = kind
        self.runs = runs
    }

    init(kind: ParagraphKind = .body, text: String) {
        self.kind = kind
        self.runs = [RichRun(text)]
    }

    var text: String {
        runs.map { $0.text }.joined()
    }
}

struct RichText: Codable, Equatable {
    var paragraphs: [RichParagraph]

    init(paragraphs: [RichParagraph] = [RichParagraph()]) {
        self.paragraphs = paragraphs.isEmpty ? [RichParagraph()] : paragraphs
    }

    static let empty = RichText()

    var plainText: String {
        paragraphs.map { $0.text }.joined(separator: "\n")
    }

    var isEmpty: Bool {
        plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var wordCount: Int {
        plainText.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var characterCount: Int {
        plainText.count
    }
}

// MARK: - Attributed string bridge

extension RichText {

    /// Builds the attributed string used by both the writing view and the
    /// PDF engine, so the screen and the page share one typographic truth.
    func compose(_ composition: TextComposition) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let count = paragraphs.count
        var listCounter = 1

        for (index, paragraph) in paragraphs.enumerated() {
            let baseAttributes = composition.attributes(for: paragraph.kind)

            if paragraph.kind == .divider {
                var divAttrs = baseAttributes
                divAttrs[.font] = UIFont.systemFont(ofSize: 9, weight: .light)
                divAttrs[.foregroundColor] = Theme.ruleStrongUIColor
                result.append(NSAttributedString(string: "─── ─── ───", attributes: divAttrs))
            } else if paragraph.kind == .pageBreak {
                var breakAttrs = baseAttributes
                breakAttrs[.font] = UIFont.monospacedSystemFont(ofSize: 8, weight: .bold)
                breakAttrs[.foregroundColor] = Theme.accentUIColor
                result.append(NSAttributedString(string: "\u{000C}─── [PAGE BREAK] ───", attributes: breakAttrs))
            } else {
                if paragraph.kind == .bulletList {
                    var bulletAttrs = baseAttributes
                    bulletAttrs[.foregroundColor] = Theme.accentUIColor
                    result.append(NSAttributedString(string: "•  ", attributes: bulletAttrs))
                } else if paragraph.kind == .numberedList {
                    var numAttrs = baseAttributes
                    numAttrs[.foregroundColor] = Theme.accentUIColor
                    numAttrs[.font] = UIFont.monospacedDigitSystemFont(ofSize: composition.size(for: .numberedList), weight: .semibold)
                    result.append(NSAttributedString(string: "\(listCounter).  ", attributes: numAttrs))
                    listCounter += 1
                } else {
                    listCounter = 1
                }

                for run in paragraph.runs where !run.text.isEmpty {
                    var attributes = baseAttributes
                    attributes[.font] = composition.font.uiFont(
                        size: composition.size(for: paragraph.kind),
                        bold: run.bold || paragraph.kind.isBoldByDefault,
                        italic: run.italic || paragraph.kind == .quote
                    )
                    if run.underline {
                        attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                    }
                    result.append(NSAttributedString(string: run.text, attributes: attributes))
                }
            }

            if index < count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: baseAttributes))
            }
        }

        return result
    }

    /// Reads the model back out of an editable text view.
    static func extract(from attributed: NSAttributedString) -> RichText {
        let string = attributed.string as NSString
        if string.length == 0 { return RichText() }

        var paragraphs: [RichParagraph] = []
        var location = 0

        while location < string.length {
            let searchRange = NSRange(location: location, length: string.length - location)
            let newline = string.range(of: "\n", options: [], range: searchRange)
            let end = newline.location == NSNotFound ? string.length : newline.location
            let paragraphRange = NSRange(location: location, length: max(0, end - location))

            paragraphs.append(paragraph(at: location, range: paragraphRange, attributed: attributed))

            if newline.location == NSNotFound { break }

            location = end + 1
            if location >= string.length {
                paragraphs.append(
                    RichParagraph(kind: paragraphs.last?.kind ?? .body, runs: [RichRun("")])
                )
                break
            }
        }

        return RichText(paragraphs: paragraphs)
    }

    private static func paragraph(
        at location: Int,
        range: NSRange,
        attributed: NSAttributedString
    ) -> RichParagraph {
        let probe = range.length > 0 ? range.location : location
        var kind: ParagraphKind = .body

        if probe >= 0, probe < attributed.length,
           let raw = attributed.attribute(.paragraphKind, at: probe, effectiveRange: nil) as? String,
           let parsed = ParagraphKind(rawValue: raw) {
            kind = parsed
        }

        var runs: [RichRun] = []
        let string = attributed.string as NSString

        if range.length > 0 {
            attributed.enumerateAttributes(in: range, options: []) { attributes, runRange, _ in
                let font = attributes[.font] as? UIFont
                let traits = font?.fontDescriptor.symbolicTraits ?? []
                let underline = (attributes[.underlineStyle] as? Int ?? 0) != 0
                let text = string.substring(with: runRange)
                runs.append(
                    RichRun(
                        text,
                        bold: traits.contains(.traitBold) && !kind.isBoldByDefault,
                        italic: traits.contains(.traitItalic) && kind != .quote,
                        underline: underline
                    )
                )
            }
        }

        if runs.isEmpty {
            runs = [RichRun("")]
        }

        return RichParagraph(kind: kind, runs: runs)
    }
}
