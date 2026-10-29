import SwiftUI

/// Presentation Slide Deck Studio for TrollDocs ("TrollSlides").
struct PresentationEditorView: View {
    @Binding var document: Document
    var onSave: () -> Void

    @State private var showingSlideshow: Bool = false
    @State private var newBulletText: String = ""
    @State private var isShowingNotes: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Deck Toolbar
            deckToolbar
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.sheet)

            Divider()
                .background(Theme.rule)

            // Main Editor Canvas
            ScrollView {
                VStack(spacing: 16) {
                    // 16:9 Slide Canvas
                    slideCanvas
                        .padding(.top, 16)

                    // Slide Inspector & Properties Panel
                    slideControlsPanel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
            }
            .background(Theme.desk)

            Divider()
                .background(Theme.rule)

            // Bottom Slide Filmstrip / Thumbnail Carousel
            filmstripDrawer
                .padding(.vertical, 8)
                .background(Theme.sheet)
        }
        .fullScreenCover(isPresented: $showingSlideshow) {
            SlideshowPlayerView(deck: document.presentationDeck)
        }
    }

    // MARK: - Deck Toolbar

    private var deckToolbar: some View {
        HStack(spacing: 12) {
            // Play Slideshow Button
            Button(action: { showingSlideshow = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                    Text("Play Show")
                        .font(Theme.sans(11.5, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.accent)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }

            // Slide Layout Menu
            Menu {
                ForEach(SlideLayout.allCases) { layout in
                    Button {
                        document.presentationDeck.currentSlide.layout = layout
                        onSave()
                    } label: {
                        Label(layout.rawValue, systemImage: layout.systemIcon)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: document.presentationDeck.currentSlide.layout.systemIcon)
                        .font(.system(size: 11))
                    Text(document.presentationDeck.currentSlide.layout.rawValue)
                        .font(Theme.sans(11))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Theme.desk)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundColor(Theme.ink)
            }

            // Theme Picker Menu
            Menu {
                ForEach(SlideTheme.allCases) { theme in
                    Button {
                        document.presentationDeck.currentSlide.theme = theme
                        onSave()
                    } label: {
                        Text(theme.rawValue)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(document.presentationDeck.currentSlide.theme.accentColor)
                        .frame(width: 8, height: 8)
                    Text("Theme")
                        .font(Theme.sans(11))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Theme.desk)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundColor(Theme.ink)
            }

            Spacer()

            // Speaker Notes Toggle
            Button(action: { withAnimation { isShowingNotes.toggle() } }) {
                Image(systemName: isShowingNotes ? "note.text" : "note")
                    .font(.system(size: 14))
                    .foregroundColor(isShowingNotes ? Theme.accent : Theme.inkSecondary)
            }
        }
    }

    // MARK: - Slide Canvas (16:9)

    private var slideCanvas: some View {
        let slide = document.presentationDeck.currentSlide
        let theme = slide.theme

        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.backgroundColor)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 10) {
                switch slide.layout {
                case .titleSlide:
                    Spacer()
                    VStack(alignment: .center, spacing: 12) {
                        TextField("Presentation Title", text: $document.presentationDeck.currentSlide.title)
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundColor(theme.titleColor)
                            .multilineTextAlignment(.center)
                            .onChange(of: document.presentationDeck.currentSlide.title) { _ in onSave() }

                        Rectangle()
                            .fill(theme.accentColor)
                            .frame(width: 60, height: 2)

                        TextField("Subtitle or presenter", text: $document.presentationDeck.currentSlide.subtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.bodyColor)
                            .multilineTextAlignment(.center)
                            .onChange(of: document.presentationDeck.currentSlide.subtitle) { _ in onSave() }
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()

                case .bulletPoints:
                    TextField("Slide Heading", text: $document.presentationDeck.currentSlide.title)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(theme.titleColor)
                        .padding(.top, 16)
                        .onChange(of: document.presentationDeck.currentSlide.title) { _ in onSave() }

                    Rectangle()
                        .fill(theme.accentColor)
                        .frame(height: 2)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(0..<slide.bulletPoints.count, id: \.self) { idx in
                            HStack(alignment: .top, spacing: 6) {
                                Circle()
                                    .fill(theme.accentColor)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 5)

                                Text(slide.bulletPoints[idx])
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(theme.bodyColor)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .padding(.top, 4)
                    Spacer()

                case .twoColumn:
                    TextField("Slide Heading", text: $document.presentationDeck.currentSlide.title)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(theme.titleColor)
                        .padding(.top, 14)
                        .onChange(of: document.presentationDeck.currentSlide.title) { _ in onSave() }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Column 1")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(theme.accentColor)
                            Text(slide.leftColumnText)
                                .font(.system(size: 11))
                                .foregroundColor(theme.bodyColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                        Divider().background(theme.accentColor.opacity(0.3))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Column 2")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(theme.accentColor)
                            Text(slide.rightColumnText)
                                .font(.system(size: 11))
                                .foregroundColor(theme.bodyColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding(.top, 4)
                    Spacer()

                case .sectionHeader:
                    Spacer()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SECTION")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundColor(theme.accentColor)

                        TextField("Section Title", text: $document.presentationDeck.currentSlide.title)
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundColor(theme.titleColor)
                            .onChange(of: document.presentationDeck.currentSlide.title) { _ in onSave() }
                    }
                    Spacer()

                case .blank:
                    Spacer()
                    Text("Blank Canvas")
                        .font(.system(size: 12))
                        .foregroundColor(theme.bodyColor.opacity(0.5))
                        .frame(maxWidth: .infinity)
                    Spacer()
                }

                // Slide Footer
                HStack {
                    Text(document.displayTitle)
                        .font(.system(size: 8))
                        .foregroundColor(theme.bodyColor.opacity(0.5))
                    Spacer()
                    Text("\(document.presentationDeck.currentSlideIndex + 1)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(theme.accentColor)
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Slide Controls & Bullet Point Editor

    private var slideControlsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Bullet Points Manager (if bullet layout)
            if document.presentationDeck.currentSlide.layout == .bulletPoints {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BULLET POINTS")
                        .font(Theme.mono(9, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(Theme.inkSecondary)

                    ForEach(0..<document.presentationDeck.currentSlide.bulletPoints.count, id: \.self) { idx in
                        HStack(spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundColor(Theme.accent)

                            TextField("Point", text: $document.presentationDeck.currentSlide.bulletPoints[idx])
                                .font(Theme.sans(13))
                                .foregroundColor(Theme.ink)
                                .onChange(of: document.presentationDeck.currentSlide.bulletPoints[idx]) { _ in onSave() }

                            Button(action: {
                                document.presentationDeck.currentSlide.bulletPoints.remove(at: idx)
                                onSave()
                            }) {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.inkTertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    // Add new bullet field
                    HStack {
                        TextField("Add new bullet point...", text: $newBulletText)
                            .font(Theme.sans(12))
                            .onSubmit {
                                addBulletPoint()
                            }

                        Button(action: addBulletPoint) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Theme.accent)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(12)
                .background(Theme.sheet)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Two Column Text Editor (if twoColumn layout)
            if document.presentationDeck.currentSlide.layout == .twoColumn {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Left Column")
                            .font(Theme.mono(9, weight: .bold))
                            .foregroundColor(Theme.inkSecondary)
                        TextEditor(text: $document.presentationDeck.currentSlide.leftColumnText)
                            .font(Theme.sans(12))
                            .frame(height: 90)
                            .background(Theme.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onChange(of: document.presentationDeck.currentSlide.leftColumnText) { _ in onSave() }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Right Column")
                            .font(Theme.mono(9, weight: .bold))
                            .foregroundColor(Theme.inkSecondary)
                        TextEditor(text: $document.presentationDeck.currentSlide.rightColumnText)
                            .font(Theme.sans(12))
                            .frame(height: 90)
                            .background(Theme.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onChange(of: document.presentationDeck.currentSlide.rightColumnText) { _ in onSave() }
                    }
                }
                .padding(12)
                .background(Theme.sheet)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Speaker Notes Drawer
            if isShowingNotes {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SPEAKER NOTES")
                        .font(Theme.mono(9, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(Theme.inkSecondary)

                    TextEditor(text: $document.presentationDeck.currentSlide.notes)
                        .font(Theme.sans(12))
                        .frame(height: 70)
                        .background(Theme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .onChange(of: document.presentationDeck.currentSlide.notes) { _ in onSave() }
                }
                .padding(12)
                .background(Theme.sheet)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Filmstrip Drawer

    private var filmstripDrawer: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<document.presentationDeck.slideCount, id: \.self) { idx in
                    let isSelected = (document.presentationDeck.currentSlideIndex == idx)
                    let slide = document.presentationDeck.slides[idx]

                    VStack(spacing: 4) {
                        // Thumbnail Preview Card
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(slide.theme.backgroundColor)
                                .frame(width: 80, height: 45)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isSelected ? Theme.accent : Theme.rule, lineWidth: isSelected ? 2 : 0.5)
                                )

                            Text(slide.title.isEmpty ? "Slide \(idx + 1)" : slide.title)
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(slide.theme.titleColor)
                                .lineLimit(2)
                                .padding(4)
                        }

                        Text("\(idx + 1)")
                            .font(Theme.mono(9, weight: isSelected ? .bold : .regular))
                            .foregroundColor(isSelected ? Theme.accent : Theme.inkTertiary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        document.presentationDeck.currentSlideIndex = idx
                    }
                    .contextMenu {
                        Button {
                            document.presentationDeck.duplicateSlide(at: idx)
                            onSave()
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }

                        if document.presentationDeck.slideCount > 1 {
                            Button(role: .destructive) {
                                document.presentationDeck.deleteSlide(at: idx)
                                onSave()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                // Add Slide Button
                Button(action: {
                    document.presentationDeck.addSlide()
                    onSave()
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4]))
                                .frame(width: 80, height: 45)
                            Image(systemName: "plus")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.inkSecondary)
                        }
                        Text("Add")
                            .font(Theme.mono(9))
                            .foregroundColor(Theme.inkTertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func addBulletPoint() {
        let trimmed = newBulletText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        document.presentationDeck.currentSlide.bulletPoints.append(trimmed)
        newBulletText = ""
        onSave()
    }
}

// MARK: - Fullscreen Slideshow Player

struct SlideshowPlayerView: View {
    let deck: PresentationDeck
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0

    var body: some View {
        ZStack {
            let slide = currentSlide
            slide.theme.backgroundColor.ignoresSafeArea()

            // Tap navigation areas: left half = back, right half = next
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if currentIndex > 0 { currentIndex -= 1 }
                    }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if currentIndex < deck.slideCount - 1 { currentIndex += 1 }
                    }
            }

            // Slide Content
            VStack(alignment: .leading, spacing: 20) {
                Spacer()

                switch slide.layout {
                case .titleSlide:
                    VStack(spacing: 16) {
                        Text(slide.title)
                            .font(.system(size: 38, weight: .bold, design: .serif))
                            .foregroundColor(slide.theme.titleColor)
                            .multilineTextAlignment(.center)

                        Rectangle()
                            .fill(slide.theme.accentColor)
                            .frame(width: 80, height: 3)

                        Text(slide.subtitle)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(slide.theme.bodyColor)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                case .bulletPoints, .blank:
                    Text(slide.title)
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundColor(slide.theme.titleColor)

                    Rectangle()
                        .fill(slide.theme.accentColor)
                        .frame(height: 3)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(slide.bulletPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(slide.theme.accentColor)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 8)
                                Text(point)
                                    .font(.system(size: 20, weight: .regular))
                                    .foregroundColor(slide.theme.bodyColor)
                            }
                        }
                    }

                case .twoColumn:
                    Text(slide.title)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(slide.theme.titleColor)

                    HStack(alignment: .top, spacing: 30) {
                        Text(slide.leftColumnText)
                            .font(.system(size: 16))
                            .foregroundColor(slide.theme.bodyColor)
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                        Text(slide.rightColumnText)
                            .font(.system(size: 16))
                            .foregroundColor(slide.theme.bodyColor)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }

                case .sectionHeader:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SECTION")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(3)
                            .foregroundColor(slide.theme.accentColor)

                        Text(slide.title)
                            .font(.system(size: 40, weight: .bold, design: .serif))
                            .foregroundColor(slide.theme.titleColor)
                    }
                }

                Spacer()

                // Bottom Presenter Bar
                HStack {
                    Text("Slide \(currentIndex + 1) of \(deck.slideCount)")
                        .font(Theme.mono(11, weight: .bold))
                        .foregroundColor(slide.theme.accentColor)
                    Spacer()
                    Text("Tap right to advance, left to rewind")
                        .font(.system(size: 10))
                        .foregroundColor(slide.theme.bodyColor.opacity(0.4))
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 30)

            // Floating Close Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(slide.theme.bodyColor.opacity(0.6))
                    }
                    .padding(20)
                }
                Spacer()
            }
        }
    }

    private var currentSlide: PresentationSlide {
        let idx = max(0, min(currentIndex, deck.slideCount - 1))
        return deck.slides[idx]
    }
}
