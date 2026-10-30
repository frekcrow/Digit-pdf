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

// MARK: - Buttons & Cupertino Cards

struct CupertinoCard<Content: View>: View {
    var cornerRadius: CGFloat = Theme.cardCornerRadius
    var padding: CGFloat = 16
    let content: () -> Content

    init(cornerRadius: CGFloat = Theme.cardCornerRadius, padding: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(Theme.sheet)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.rule, lineWidth: Theme.hairline)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

struct CupertinoBadge: View {
    let text: String
    var color: Color = Theme.accent

    var body: some View {
        Text(text.uppercased())
            .font(Theme.sans(10, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct InkButtonStyle: ButtonStyle {
    var filled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.sans(12, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(filled ? Theme.accent : Color.clear)
            .foregroundColor(filled ? .white : Theme.accent)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Theme.accent, lineWidth: filled ? 0 : 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1)
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
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Theme.accentWash : Color.clear)
                )
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

/// An Apple-style segmented choice chip.
struct ChoiceChip: View {
    let title: String
    var selected: Bool
    var alignment: HorizontalAlignment = .center
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.sans(12.5, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? (Theme.accent) : Theme.inkSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(selected ? Theme.accentWash : Color(uiColor: .tertiarySystemFill))
                )
                .overlay(
                    Capsule()
                        .stroke(selected ? Theme.accent.opacity(0.4) : Color.clear, lineWidth: 1)
                )
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
                .font(.system(size: 15, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? Theme.accent : Theme.inkSecondary)
                .frame(width: 38, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? Theme.accentWash : Color(uiColor: .tertiarySystemFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(selected ? Theme.accent.opacity(0.4) : Color.clear, lineWidth: 1)
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
        TextField(placeholder, text: $text)
            .font(Theme.sans(15))
            .foregroundColor(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .textInputAutocapitalization(.sentences)
            .disableAutocorrection(true)
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
            Text(title)
                .font(Theme.sans(16, weight: .semibold))
                .foregroundColor(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: onClose) {
                Text(trailingTitle)
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundColor(trailingIsAccent ? Theme.accent : Theme.ink)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityLabel(trailingTitle)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 14)
        .padding(.bottom, 12)
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
