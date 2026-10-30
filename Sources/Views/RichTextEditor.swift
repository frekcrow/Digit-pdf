import SwiftUI
import UIKit
import Combine

/// Commands from the SwiftUI tool row into the live text view.
final class RichTextController: ObservableObject {
    weak var textView: UITextView?
    var composition = TextComposition()
    var onChange: ((RichText) -> Void)?

    // MARK: Inline emphasis

    func toggleBold() {
        toggleTrait(.traitBold)
    }

    func toggleItalic() {
        toggleTrait(.traitItalic)
    }

    func toggleUnderline() {
        guard let textView = textView else { return }
        let selection = textView.selectedRange

        if selection.length == 0 {
            var attributes = textView.typingAttributes
            let current = attributes[.underlineStyle] as? Int ?? 0
            if current == 0 {
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            } else {
                attributes.removeValue(forKey: .underlineStyle)
            }
            textView.typingAttributes = attributes
            return
        }

        let storage = textView.textStorage
        let existing = storage.attribute(.underlineStyle, at: selection.location, effectiveRange: nil) as? Int ?? 0
        let shouldUnderline = existing == 0

        storage.beginEditing()
        storage.enumerateAttribute(.underlineStyle, in: selection, options: []) { value, range, _ in
            if shouldUnderline {
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            } else {
                storage.removeAttribute(.underlineStyle, range: range)
            }
        }
        storage.endEditing()

        textView.selectedRange = selection
        emitChange()
    }

    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let textView = textView else { return }
        let selection = textView.selectedRange

        if selection.length == 0 {
            var attributes = textView.typingAttributes
            let font = attributes[.font] as? UIFont
                ?? composition.font.uiFont(size: composition.baseSize)
            var traits = font.fontDescriptor.symbolicTraits
            if traits.contains(trait) {
                traits.remove(trait)
            } else {
                traits.insert(trait)
            }
            if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                attributes[.font] = UIFont(descriptor: descriptor, size: font.pointSize)
                textView.typingAttributes = attributes
            }
            return
        }

        let storage = textView.textStorage
        var everyRunHasTrait = true

        storage.enumerateAttribute(.font, in: selection, options: []) { value, _, stop in
            guard let font = value as? UIFont else { return }
            if !font.fontDescriptor.symbolicTraits.contains(trait) {
                everyRunHasTrait = false
                stop.pointee = true
            }
        }

        let shouldAdd = !everyRunHasTrait

        storage.beginEditing()
        storage.enumerateAttribute(.font, in: selection, options: []) { value, range, _ in
            guard let font = value as? UIFont else { return }
            var traits = font.fontDescriptor.symbolicTraits
            if shouldAdd {
                traits.insert(trait)
            } else {
                traits.remove(trait)
            }
            if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                storage.addAttribute(
                    .font,
                    value: UIFont(descriptor: descriptor, size: font.pointSize),
                    range: range
                )
            }
        }
        storage.endEditing()

        textView.selectedRange = selection
        emitChange()
    }

    // MARK: History

    func undo() {
        textView?.undoManager?.undo()
        emitChange()
    }

    func redo() {
        textView?.undoManager?.redo()
        emitChange()
    }

    // MARK: Paragraphs

    func apply(kind: ParagraphKind) {
        guard let textView = textView else { return }
        let selection = textView.selectedRange
        let text = textView.text as NSString
        let paragraphRange = text.paragraphRange(for: selection)

        guard paragraphRange.length > 0 else {
            textView.typingAttributes = composition.attributes(for: kind)
            return
        }

        let storage = textView.textStorage
        let targetFont = composition.font.uiFont(
            size: composition.baseSize * kind.sizeMultiple,
            bold: kind.isBoldByDefault,
            italic: kind == .quote
        )

        storage.beginEditing()
        storage.addAttribute(.paragraphKind, value: kind.rawValue, range: paragraphRange)
        storage.addAttribute(.paragraphStyle, value: composition.paragraphStyle(for: kind), range: paragraphRange)
        storage.addAttribute(.font, value: targetFont, range: paragraphRange)
        storage.endEditing()

        textView.selectedRange = selection
        textView.typingAttributes = composition.attributes(for: kind)
        emitChange()
    }

    /// Removes any formatting, returning the document to body text.
    func clearInlineFormatting() {
        guard let textView = textView else { return }
        let selection = textView.selectedRange
        guard selection.length > 0 else {
            textView.typingAttributes = composition.attributes(for: .body)
            return
        }

        let storage = textView.textStorage
        storage.beginEditing()
        storage.removeAttribute(.underlineStyle, range: selection)
        storage.addAttribute(
            .font,
            value: composition.font.uiFont(size: composition.baseSize),
            range: selection
        )
        storage.addAttribute(.paragraphKind, value: ParagraphKind.body.rawValue, range: selection)
        storage.addAttribute(.paragraphStyle, value: composition.paragraphStyle(for: .body), range: selection)
        storage.endEditing()

        textView.selectedRange = selection
        emitChange()
    }

    // MARK: - Structural Inserts

    func insertText(_ text: String, kind: ParagraphKind = .body) {
        guard let textView = textView else { return }
        let selection = textView.selectedRange
        let storage = textView.textStorage

        let attrs = composition.attributes(for: kind)
        let insertion = NSAttributedString(string: text, attributes: attrs)

        storage.beginEditing()
        storage.replaceCharacters(in: selection, with: insertion)
        storage.endEditing()

        textView.selectedRange = NSRange(location: selection.location + insertion.length, length: 0)
        emitChange()
    }

    func insertDivider() {
        insertText("\n─── ─── ───\n", kind: .divider)
    }

    func insertPageBreak() {
        insertText("\n\u{000C}─── [PAGE BREAK] ───\n", kind: .pageBreak)
    }

    func insertTable(rows: Int = 3, cols: Int = 3) {
        var tableText = "\n"
        var headers: [String] = []
        var dividers: [String] = []
        for c in 1...cols {
            headers.append("Column \(c)")
            dividers.append("----------")
        }
        tableText += "| " + headers.joined(separator: " | ") + " |\n"
        tableText += "| " + dividers.joined(separator: " | ") + " |\n"

        for r in 1...max(1, rows - 1) {
            var rowItems: [String] = []
            for c in 1...cols {
                rowItems.append("Item \(r).\(c)")
            }
            tableText += "| " + rowItems.joined(separator: " | ") + " |\n"
        }
        tableText += "\n"

        insertText(tableText, kind: .body)
    }

    private func emitChange() {
        guard let textView = textView else { return }
        onChange?(RichText.extract(from: textView.attributedText))
    }
}

// MARK: - View

struct RichTextEditor: UIViewRepresentable {
    let documentID: UUID
    let content: RichText
    let typography: TypographySettings
    let baseSize: CGFloat
    let color: UIColor
    let controller: RichTextController
    let onChange: (RichText) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isEditable = true
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 2, left: 0, bottom: 28, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.tintColor = Theme.accentUIColor
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .yes
        textView.smartQuotesType = .yes
        textView.smartDashesType = .yes

        controller.textView = textView
        controller.onChange = onChange
        controller.composition = typography.composition(baseSize: baseSize, color: color)

        context.coordinator.documentID = documentID
        context.coordinator.typography = typography

        load(into: textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        controller.textView = textView
        controller.onChange = onChange
        context.coordinator.onChange = onChange
        controller.composition = typography.composition(baseSize: baseSize, color: color)

        let currentStyle = textView.traitCollection.userInterfaceStyle
        if context.coordinator.userInterfaceStyle != currentStyle {
            context.coordinator.userInterfaceStyle = currentStyle
            reloadPreservingSelection(in: textView)
            return
        }

        if context.coordinator.documentID != documentID {
            context.coordinator.documentID = documentID
            context.coordinator.typography = typography
            load(into: textView)
        } else if context.coordinator.typography != typography {
            context.coordinator.typography = typography
            reloadPreservingSelection(in: textView)
        }
    }

    // MARK: Helpers

    private func composition() -> TextComposition {
        typography.composition(baseSize: baseSize, color: color)
    }

    private func load(into textView: UITextView) {
        textView.attributedText = content.compose(composition())
        textView.typingAttributes = composition().attributes(for: .body)
    }

    private func reloadPreservingSelection(in textView: UITextView) {
        let selection = textView.selectedRange
        textView.attributedText = content.compose(composition())

        let length = textView.textStorage.length
        let location = min(selection.location, length)
        let available = max(0, length - location)
        textView.selectedRange = NSRange(location: location, length: min(selection.length, available))

        var attributes = composition().attributes(for: .body)
        if location > 0, location <= length,
           let raw = textView.textStorage.attribute(.paragraphKind, at: location - 1, effectiveRange: nil) as? String,
           let kind = ParagraphKind(rawValue: raw) {
            attributes = composition().attributes(for: kind)
        }
        textView.typingAttributes = attributes
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onChange: (RichText) -> Void
        var documentID = UUID()
        var typography: TypographySettings?
        var userInterfaceStyle: UIUserInterfaceStyle = .unspecified

        init(onChange: @escaping (RichText) -> Void) {
            self.onChange = onChange
        }

        func textViewDidChange(_ textView: UITextView) {
            onChange(RichText.extract(from: textView.attributedText))
        }
    }
}
