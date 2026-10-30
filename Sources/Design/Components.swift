import SwiftUI

// MARK: - Rules & labels

/// A true hairline. Thin enough to feel printed, never a border.
struct Hairline: View {
    var color: Color = Theme.rule
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.hairline)
    }
}

struct SmallCaps: View {
    let text: String
    var color: Color = Theme.inkSecondary
    var size: CGFloat = 9.5
    var weight: Font.Weight = .semibold
    var tracking: CGFloat = 1.5

    var body: some View {
        Text(text.uppercased())
            .font(Theme.sans(size, weight: weight))
            .kerning(tracking)
            .foregroundColor(color)
    }
}

struct SectionLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            SmallCaps(text: title, color: Theme.inkTertiary, size: 8.5, tracking: 1.9)
                .fixedSize()
            Hairline()
        }
    }
}

// MARK: - Buttons

struct InkButtonStyle: ButtonStyle {
    var filled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Rectangle().fill(filled ? Theme.ink : Color.clear))
            .overlay(
                Rectangle()
                    .stroke(Theme.ink, lineWidth: filled ? 0 : Theme.hairline * 1.3)
            )
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.45 : 1)
    }
}

/// 44pt square hit target for the editor's tool row matching Apple HIG.
struct ToolButton<Label: View>: View {
    let action: () -> Void
    let isEnabled: Bool
    var accessibilityLabel: String?
    var isSelected: Bool
    let label: () -> Label

    init(
        action: @escaping () -> Void,
        isEnabled: Bool = true,
        accessibilityLabel: String? = nil,
        isSelected: Bool = false,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.isEnabled = isEnabled
        self.accessibilityLabel = accessibilityLabel
        self.isSelected = isSelected
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
        .accessibilityLabel(accessibilityLabel ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Choices

/// A word with a rule beneath it. The only selected-state language in the app.
struct ChoiceChip: View {
    let title: String
    var selected: Bool
    var alignment: HorizontalAlignment = .center
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: alignment, spacing: 6) {
                Text(title)
                    .font(Theme.sans(12, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? Theme.ink : Theme.inkSecondary)
                    .fixedSize()
                Rectangle()
                    .fill(selected ? Theme.accent : Color.clear)
                    .frame(height: 1.5)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct IconChoice: View {
    let systemName: String
    var selected: Bool
    var accessibilityLabel: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(selected ? Theme.ink : Theme.inkTertiary)
                .frame(width: 34, height: 30)
                .background(Rectangle().fill(selected ? Theme.accentWash : Color.clear))
                .overlay(
                    Rectangle()
                        .stroke(selected ? Theme.accent.opacity(0.5) : Color.clear,
                                lineWidth: Theme.hairline * 1.2)
                )
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityLabel(accessibilityLabel ?? systemName)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Fields

struct InspectorRow<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(label)
                .font(Theme.sans(13))
                .foregroundColor(Theme.ink)
            Spacer(minLength: 12)
            content
        }
        .padding(.vertical, 11)
    }
}

struct UnderlineField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(spacing: 7) {
            TextField(placeholder, text: $text)
                .font(Theme.serif(15))
                .foregroundColor(Theme.ink)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(true)
            Hairline(color: Theme.ruleStrong)
        }
    }
}

// MARK: - Sheet chrome

struct SheetBar: View {
    let title: String
    var trailingTitle: String = "Done"
    var trailingIsAccent: Bool = true
    var onClose: () -> Void

    var body: some View {
        HStack {
            SmallCaps(text: title, color: Theme.inkTertiary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: onClose) {
                Text(trailingTitle.uppercased())
                    .font(Theme.sans(10.5, weight: .semibold))
                    .kerning(1.6)
                    .foregroundColor(trailingIsAccent ? Theme.accent : Theme.ink)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityLabel(trailingTitle)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
}

struct BarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.rule)
            .frame(width: Theme.hairline, height: 18)
    }
}

// MARK: - Haptic Feedback & Touch Target Helpers

enum Haptics {
    static func destructive() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}

extension View {
    /// Enforces Apple HIG minimum 44×44 pt touch hit target with invisible padding.
    func minimumTouchTarget(width: CGFloat = 44, height: CGFloat = 44) -> some View {
        self.frame(minWidth: width, minHeight: height)
            .contentShape(Rectangle())
    }

    /// iOS 16 gives lists their own opaque background. Keep the paper showing.
    @ViewBuilder
    func paperBackedList() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
