import SwiftUI
import UIKit

/// The single source of truth for TrollDocs' visual language.
///
/// Redesigned to Modern Cupertino Pro: Apple Human Interface Guidelines,
/// native system materials (.ultraThinMaterial), semantic dynamic colors,
/// and San Francisco typography.
enum Theme {

    // MARK: - Colours (Cupertino System Semantic)

    static let paperUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x000000) : UIColor(hex: 0xF2F2F7)
    }

    static let sheetUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x1C1C1E) : UIColor(hex: 0xFFFFFF)
    }

    static let deskUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x121214) : UIColor(hex: 0xE5E5EA)
    }

    static let inkUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xFFFFFF) : UIColor(hex: 0x1C1C1E)
    }

    static let inkSecondaryUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x8E8E93) : UIColor(hex: 0x6C6C70)
    }

    static let inkTertiaryUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x636366) : UIColor(hex: 0xAEAEB2)
    }

    static let ruleUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x38383A) : UIColor(hex: 0xE5E5EA)
    }

    static let ruleStrongUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x48484A) : UIColor(hex: 0xD1D1D6)
    }

    static let accentUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x0A84FF) : UIColor(hex: 0x007AFF)
    }

    static let accentWashUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: 0x0A84FF).withAlphaComponent(0.18)
            : UIColor(hex: 0x007AFF).withAlphaComponent(0.12)
    }

    static var paper: Color { Color(uiColor: paperUIColor) }
    static var sheet: Color { Color(uiColor: sheetUIColor) }
    static var desk: Color { Color(uiColor: deskUIColor) }
    static var ink: Color { Color(uiColor: inkUIColor) }
    static var inkSecondary: Color { Color(uiColor: inkSecondaryUIColor) }
    static var inkTertiary: Color { Color(uiColor: inkTertiaryUIColor) }
    static var rule: Color { Color(uiColor: ruleUIColor) }
    static var ruleStrong: Color { Color(uiColor: ruleStrongUIColor) }
    static var accent: Color { Color(uiColor: accentUIColor) }
    static var accentWash: Color { Color(uiColor: accentWashUIColor) }

    // MARK: - Type (San Francisco Pro & New York)

    /// San Francisco, the native voice of iOS.
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// New York serif, used for typeset publication reading & editorial body text.
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// SF Monospaced for page numbers, tabular measures, and coordinates.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: - Cupertino Metrics & Shapes

    static var hairline: CGFloat { 1.0 / max(UIScreen.main.scale, 1) }

    static let gutter: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 12
    static let chipCornerRadius: CGFloat = 8
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((hex & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(hex & 0x0000FF) / 255.0,
            alpha: alpha
        )
    }
}

// MARK: - App Appearance

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var iconName: String {
        switch self {
        case .system: return "circle.righthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    static func apply(style: UIUserInterfaceStyle) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
