import SwiftUI

struct InspectorView: View {
    @Binding var document: Document
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                SheetBar(title: "Document setup") {
                    dismiss()
                }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Page & Type")
                            .font(Theme.serif(30))
                            .foregroundColor(Theme.ink)
                        Text("The measures below decide how the document looks on paper, not on this screen.")
                            .font(Theme.sans(12))
                            .foregroundColor(Theme.inkSecondary)
                            .lineSpacing(3)
                            .padding(.top, 6)

                        pageSection
                            .padding(.top, 28)
                        typeSection
                            .padding(.top, 30)
                        runningSection
                            .padding(.top, 30)
                        watermarkSection
                            .padding(.top, 30)
                        detailsSection
                            .padding(.top, 30)

                        Text("Exported files are written to the TrollDocs folder in the Files app.")
                            .font(Theme.sans(11))
                            .foregroundColor(Theme.inkTertiary)
                            .lineSpacing(3)
                            .padding(.top, 26)
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 6)
                }
            }
        }
    }

    // MARK: - Page

    private var pageSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Page")
                .padding(.bottom, 12)

            InspectorRow("Format") {
                HStack(spacing: 16) {
                    ForEach(PageSize.allCases) { size in
                        ChoiceChip(
                            title: size.title,
                            selected: document.page.size == size
                        ) {
                            document.page.size = size
                        }
                    }
                }
            }
            Hairline()

            InspectorRow("Orientation") {
                HStack(spacing: 16) {
                    ForEach(PageOrientation.allCases) { orientation in
                        ChoiceChip(
                            title: orientation.title,
                            selected: document.page.orientation == orientation
                        ) {
                            document.page.orientation = orientation
                        }
                    }
                }
            }
            Hairline()

            InspectorRow("Margins") {
                HStack(spacing: 16) {
                    ForEach(MarginPreset.allCases) { preset in
                        ChoiceChip(
                            title: preset.title,
                            selected: document.page.margin == preset
                        ) {
                            document.page.margin = preset
                        }
                    }
                }
            }

            if document.page.margin == .custom {
                InspectorRow("Margin width") {
                    HStack(spacing: 12) {
                        Slider(value: $document.page.customMargin, in: 24...110, step: 1)
                            .frame(width: 140)
                            .tint(Theme.accent)
                        Text(document.page.marginDetail)
                            .font(Theme.mono(9))
                            .foregroundColor(Theme.inkSecondary)
                            .frame(width: 46, alignment: .trailing)
                    }
                }
            }
            Hairline()

            toggleRow("Page numbers", isOn: $document.page.showsPageNumbers)
                .padding(.vertical, 2)
            Hairline()

            if document.page.showsPageNumbers {
                InspectorRow("Folio style") {
                    HStack(spacing: 14) {
                        ForEach(PageNumberStyle.allCases) { style in
                            ChoiceChip(
                                title: style.title,
                                selected: document.page.pageNumberStyle == style
                            ) {
                                document.page.pageNumberStyle = style
                            }
                        }
                    }
                }
                Hairline()
            }

            toggleRow("Cover page", isOn: $document.page.hasCoverPage)
                .padding(.vertical, 2)
            Hairline()

            toggleRow("Printed rules", isOn: $document.page.showsRules)
                .padding(.vertical, 2)
        }
    }

    // MARK: - Type

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Typography")
                .padding(.bottom, 12)

            Text("Typeface")
                .font(Theme.sans(13))
                .foregroundColor(Theme.ink)
                .padding(.bottom, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(DocumentFont.allCases) { font in
                        typefaceChip(font)
                    }
                }
                .padding(.bottom, 4)
            }
            Hairline()

            InspectorRow("Size") {
                HStack(spacing: 12) {
                    Slider(value: $document.typography.bodySize, in: 8...16, step: 0.5)
                        .frame(width: 140)
                        .tint(Theme.accent)
                    Text(String(format: "%.1f pt", document.typography.bodySize))
                        .font(Theme.mono(9))
                        .foregroundColor(Theme.inkSecondary)
                        .frame(width: 54, alignment: .trailing)
                }
            }
            Hairline()

            InspectorRow("Leading") {
                HStack(spacing: 12) {
                    Slider(value: $document.typography.leading, in: 1.1...2.0, step: 0.05)
                        .frame(width: 140)
                        .tint(Theme.accent)
                    Text(String(format: "%.2f", document.typography.leading))
                        .font(Theme.mono(9))
                        .foregroundColor(Theme.inkSecondary)
                        .frame(width: 54, alignment: .trailing)
                }
            }
            Hairline()

            InspectorRow("Paragraph gap") {
                HStack(spacing: 12) {
                    Slider(value: $document.typography.paragraphSpacing, in: 0...20, step: 1)
                        .frame(width: 140)
                        .tint(Theme.accent)
                    Text("\(Int(document.typography.paragraphSpacing)) pt")
                        .font(Theme.mono(9))
                        .foregroundColor(Theme.inkSecondary)
                        .frame(width: 54, alignment: .trailing)
                }
            }
            Hairline()

            InspectorRow("Alignment") {
                HStack(spacing: 8) {
                    ForEach(TextAlignmentOption.allCases) { alignment in
                        IconChoice(
                            systemName: alignment.systemIcon,
                            selected: document.typography.alignment == alignment
                        ) {
                            document.typography.alignment = alignment
                        }
                    }
                }
            }
            Hairline()

            toggleRow(
                "Indent first line",
                isOn: Binding<Bool>(
                    get: { document.typography.firstLineIndent > 0 },
                    set: { document.typography.firstLineIndent = $0 ? 18 : 0 }
                )
            )
            .padding(.vertical, 2)

            HStack {
                Text("11.5 pt is a book-page measure. Larger sizes suit letters and notices.")
                    .font(Theme.sans(11))
                    .foregroundColor(Theme.inkTertiary)
                    .lineSpacing(3)
                Spacer(minLength: 12)
                Button {
                    document.typography = TypographySettings()
                } label: {
                    Text("Reset")
                        .font(Theme.sans(9.5, weight: .semibold))
                        .kerning(1.3)
                        .foregroundColor(Theme.accent)
                }
                .buttonStyle(QuietButtonStyle())
            }
            .padding(.top, 14)
        }
    }

    // MARK: - Running head

    private var runningSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Running matter")
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 7) {
                SmallCaps(text: "Running head", color: Theme.inkTertiary, size: 8.5)
                UnderlineField(
                    placeholder: "e.g. Quarterly Report",
                    text: $document.page.headerText
                )
            }

            VStack(alignment: .leading, spacing: 7) {
                SmallCaps(text: "Footer note", color: Theme.inkTertiary, size: 8.5)
                UnderlineField(
                    placeholder: "e.g. Private and confidential",
                    text: $document.page.footerText
                )
            }
            .padding(.top, 20)
        }
    }

    // MARK: - Watermark

    private var watermarkSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Watermark")
                .padding(.bottom, 12)

            toggleRow("Enable Watermark", isOn: $document.page.watermark.isEnabled)
            Hairline()

            if document.page.watermark.isEnabled {
                InspectorRow("Preset") {
                    HStack(spacing: 8) {
                        ForEach(["DRAFT", "CONFIDENTIAL", "FINAL", "SAMPLE"], id: \.self) { preset in
                            ChoiceChip(
                                title: preset,
                                selected: document.page.watermark.text == preset
                            ) {
                                document.page.watermark.text = preset
                            }
                        }
                    }
                }
                Hairline()

                InspectorRow("Text") {
                    TextField("Watermark text", text: $document.page.watermark.text)
                        .font(Theme.sans(13))
                        .foregroundColor(Theme.ink)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                Hairline()

                InspectorRow("Opacity") {
                    HStack(spacing: 12) {
                        Slider(value: $document.page.watermark.opacity, in: 0.05...0.40, step: 0.05)
                            .frame(width: 140)
                            .tint(Theme.accent)
                        Text("\(Int(document.page.watermark.opacity * 100))%")
                            .font(Theme.mono(9))
                            .foregroundColor(Theme.inkSecondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Hairline()

                InspectorRow("Angle") {
                    HStack(spacing: 12) {
                        ChoiceChip(
                            title: "45° Diagonal",
                            selected: document.page.watermark.angle == 45.0
                        ) {
                            document.page.watermark.angle = 45.0
                        }

                        ChoiceChip(
                            title: "0° Horizontal",
                            selected: document.page.watermark.angle == 0.0
                        ) {
                            document.page.watermark.angle = 0.0
                        }
                    }
                }
                Hairline()
            }
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Document")
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 7) {
                SmallCaps(text: "Subtitle", color: Theme.inkTertiary, size: 8.5)
                UnderlineField(
                    placeholder: "A short line beneath the title",
                    text: $document.subtitle
                )
            }

            VStack(alignment: .leading, spacing: 7) {
                SmallCaps(text: "Author", color: Theme.inkTertiary, size: 8.5)
                UnderlineField(
                    placeholder: "Prepared by",
                    text: $document.author
                )
            }
            .padding(.top, 20)

            InspectorRow("File") {
                Text(document.fileName)
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.inkSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Rows

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(Theme.sans(13))
                .foregroundColor(Theme.ink)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
        }
        .padding(.vertical, 7)
    }

    private func typefaceChip(_ font: DocumentFont) -> some View {
        let selected = document.typography.typeface == font
        return Button {
            document.typography.typeface = font
        } label: {
            VStack(spacing: 6) {
                Text(font.title)
                    .font(font.swiftUIFont(size: 15))
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
