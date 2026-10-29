import SwiftUI
import UIKit

/// The single source of truth for TrollDocs' visual language.
///
/// The palette is borrowed from a printed page: warm ivory stock, dense ink,
/// a single oxblood accent. Nothing else is allowed in.
enum Theme {

    // MARK: - Colours

    static let paperUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x12100C) : UIColor(hex: 0xFAF6EC)
    }

    static let sheetUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x1B1813) : UIColor(hex: 0xFFFFFF)
    }

    static let deskUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x0A0906) : UIColor(hex: 0xE7E1D3)
    }

    static let inkUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xF2EBDB) : UIColor(hex: 0x1B1712)
    }

    static let inkSecondaryUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xA9A08E) : UIColor(hex: 0x6C6455)
    }

    static let inkTertiaryUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x6E6556) : UIColor(hex: 0xA09683)
    }

    static let ruleUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x322C22) : UIColor(hex: 0xE1D8C5)
    }

    static let ruleStrongUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x4B4334) : UIColor(hex: 0xC7BCA5)
    }

    static let accentUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xCE8E80) : UIColor(hex: 0x7B2E29)
    }

    static let accentWashUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x2B1D19) : UIColor(hex: 0xF1E4DB)
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

    // MARK: - Type

    /// New York, the serif companion to San Francisco. Used for titles,
    /// document names and anything that should read like print.
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// San Francisco for labels, controls and running text in the chrome.
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Reserved for folios, measurements and catalogue numbers.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: - Measure

    static var hairline: CGFloat { 1.0 / max(UIScreen.main.scale, 1) }

    static let gutter: CGFloat = 22
    static let rowVerticalPadding: CGFloat = 14
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
