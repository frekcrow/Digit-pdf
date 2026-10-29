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

/// 44pt square hit target for the editor's tool row.
struct ToolButton<Label: View>: View {
    let action: () -> Void
    let isEnabled: Bool
    let label: () -> Label

    init(action: @escaping () -> Void, isEnabled: Bool = true, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.isEnabled = isEnabled
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
                .frame(width: 42, height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
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
        }
        .buttonStyle(QuietButtonStyle())
    }
}

struct IconChoice: View {
    let systemName: String
    var selected: Bool
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
        }
        .buttonStyle(QuietButtonStyle())
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
            Spacer()
            Button(action: onClose) {
                Text(trailingTitle.uppercased())
                    .font(Theme.sans(10, weight: .semibold))
                    .kerning(1.6)
                    .foregroundColor(trailingIsAccent ? Theme.accent : Theme.ink)
            }
            .buttonStyle(QuietButtonStyle())
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }
}

struct BarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.rule)
            .frame(width: Theme.hairline, height: 18)
    }
}


extension View {
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
