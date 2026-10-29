import Foundation
import SwiftUI
import UIKit

// MARK: - Slide Layouts

public enum SlideLayout: String, CaseIterable, Codable, Identifiable {
    case titleSlide = "Title Slide"
    case bulletPoints = "Bullet Points"
    case twoColumn = "Two Columns"
    case sectionHeader = "Section Header"
    case blank = "Blank"

    public var id: String { rawValue }

    public var systemIcon: String {
        switch self {
        case .titleSlide: return "rectangle.fill.on.rectangle.fill"
        case .bulletPoints: return "list.bullet.rectangle.portrait"
        case .twoColumn: return "square.split.2x1"
        case .sectionHeader: return "text.quote"
        case .blank: return "rectangle"
        }
    }
}

// MARK: - Slide Themes

public enum SlideTheme: String, CaseIterable, Codable, Identifiable {
    case navyExecutive = "Navy Executive"
    case darkModern = "Dark Modern"
    case cleanPaper = "Editorial Paper"
    case forest = "Pine Forest"
    case sunset = "Crimson Sunset"

    public var id: String { rawValue }

    public var backgroundColor: Color {
        switch self {
        case .navyExecutive: return Color(red: 0.08, green: 0.12, blue: 0.22)
        case .darkModern: return Color(red: 0.10, green: 0.10, blue: 0.12)
        case .cleanPaper: return Color(red: 0.98, green: 0.96, blue: 0.92)
        case .forest: return Color(red: 0.08, green: 0.18, blue: 0.12)
        case .sunset: return Color(red: 0.24, green: 0.08, blue: 0.10)
        }
    }

    public var titleColor: Color {
        switch self {
        case .cleanPaper: return Color(red: 0.11, green: 0.09, blue: 0.07)
        default: return .white
        }
    }

    public var bodyColor: Color {
        switch self {
        case .cleanPaper: return Color(red: 0.35, green: 0.32, blue: 0.28)
        default: return Color(white: 0.85)
        }
    }

    public var accentColor: Color {
        switch self {
        case .navyExecutive: return Color(red: 0.95, green: 0.77, blue: 0.35) // Gold
        case .darkModern: return Color(red: 0.35, green: 0.85, blue: 0.75) // Cyan/Mint
        case .cleanPaper: return Color(red: 0.48, green: 0.18, blue: 0.16) // Oxblood
        case .forest: return Color(red: 0.72, green: 0.88, blue: 0.62) // Champagne Green
        case .sunset: return Color(red: 0.98, green: 0.62, blue: 0.35) // Warm Orange
        }
    }
}

// MARK: - Presentation Slide

public struct PresentationSlide: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var subtitle: String
    public var bulletPoints: [String]
    public var leftColumnText: String
    public var rightColumnText: String
    public var notes: String
    public var layout: SlideLayout
    public var theme: SlideTheme

    public init(
        id: UUID = UUID(),
        title: String = "Slide Title",
        subtitle: String = "Subtitle or presenter name",
        bulletPoints: [String] = ["Key takeaway point one", "Supporting metric or strategic initiative", "Planned action item"],
        leftColumnText: String = "Column 1 Details\n• Supporting point\n• Data metrics",
        rightColumnText: String = "Column 2 Details\n• Projected impact\n• Conclusion",
        notes: String = "",
        layout: SlideLayout = .bulletPoints,
        theme: SlideTheme = .navyExecutive
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.bulletPoints = bulletPoints
        self.leftColumnText = leftColumnText
        self.rightColumnText = rightColumnText
        self.notes = notes
        self.layout = layout
        self.theme = theme
    }
}

// MARK: - Presentation Deck

public struct PresentationDeck: Codable, Equatable {
    public var slides: [PresentationSlide]
    public var currentSlideIndex: Int

    public init(slides: [PresentationSlide] = [], currentSlideIndex: Int = 0) {
        self.slides = slides.isEmpty ? PresentationDeck.defaultDeck().slides : slides
        self.currentSlideIndex = max(0, min(currentSlideIndex, self.slides.count - 1))
    }

    public var slideCount: Int { slides.count }

    public var currentSlide: PresentationSlide {
        get {
            guard !slides.isEmpty else { return PresentationSlide() }
            let index = max(0, min(currentSlideIndex, slides.count - 1))
            return slides[index]
        }
        set {
            guard !slides.isEmpty else { return }
            let index = max(0, min(currentSlideIndex, slides.count - 1))
            slides[index] = newValue
        }
    }

    public mutating func addSlide(layout: SlideLayout = .bulletPoints) {
        let theme = slides.first?.theme ?? .navyExecutive
        let slide = PresentationSlide(
            title: "New Slide",
            subtitle: "",
            bulletPoints: ["First key point", "Second key point"],
            layout: layout,
            theme: theme
        )
        slides.append(slide)
        currentSlideIndex = slides.count - 1
    }

    public mutating func duplicateSlide(at index: Int) {
        guard index >= 0, index < slides.count else { return }
        var copy = slides[index]
        copy.id = UUID()
        copy.title = "\(copy.title) (Copy)"
        slides.insert(copy, at: index + 1)
        currentSlideIndex = index + 1
    }

    public mutating func deleteSlide(at index: Int) {
        guard slides.count > 1, index >= 0, index < slides.count else { return }
        slides.remove(at: index)
        currentSlideIndex = max(0, min(currentSlideIndex, slides.count - 1))
    }

    public mutating func moveSlide(from: Int, to: Int) {
        guard from >= 0, from < slides.count, to >= 0, to < slides.count else { return }
        let slide = slides.remove(at: from)
        slides.insert(slide, at: to)
        currentSlideIndex = to
    }

    public static func defaultDeck() -> PresentationDeck {
        let titleSlide = PresentationSlide(
            title: "TrollDocs Presentation",
            subtitle: "Native Desktop-Class Presentation Studio for iOS",
            bulletPoints: [],
            layout: .titleSlide,
            theme: .navyExecutive
        )
        let bulletSlide = PresentationSlide(
            title: "Core Capabilities",
            subtitle: "Full control over your documents",
            bulletPoints: [
                "Interactive 2D spreadsheet grid with live formula calculations",
                "Desktop-grade rich document typography and CoreText pagination",
                "Native presentation slide deck builder with fullscreen slideshow",
                "Full file import & export via TrollStore and iOS Files app"
            ],
            layout: .bulletPoints,
            theme: .navyExecutive
        )
        let twoColSlide = PresentationSlide(
            title: "Comparison & Roadmap",
            subtitle: "Phase 1 Foundation vs Phase 2 Office Studio",
            leftColumnText: "Previous Generation:\n• Basic file creation\n• Limited format editing\n• Static exports",
            rightColumnText: "Desktop Office Studio:\n• Real cell formulas (SUM, AVG)\n• Multi-slide deck creation\n• Direct in-place editing",
            layout: .twoColumn,
            theme: .navyExecutive
        )
        let summarySlide = PresentationSlide(
            title: "Summary & Action Items",
            subtitle: "Unrestricted execution on iOS 15.0+",
            bulletPoints: [
                "Deploy with TrollStore privileges",
                "Export directly to PDF presentation decks",
                "Share seamlessly via AirDrop and Files"
            ],
            layout: .bulletPoints,
            theme: .navyExecutive
        )

        return PresentationDeck(slides: [titleSlide, bulletSlide, twoColSlide, summarySlide])
    }
}
