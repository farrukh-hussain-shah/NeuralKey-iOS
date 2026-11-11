import SwiftUI
import UIKit

// Design tokens sampled from the supplied Neural Key boards (Splash, Onboarding, Home).
// Every screen must use these instead of literal values so the app stays consistent
// and the Light appearance can be added in one place in Phase 2.

// MARK: - Colour

enum NKColor {
    /// Primary brand blue (buttons, toggles, active indicators). Sampled: #0F5AF3.
    static let brand = Color(hex: 0x0F5AF3)
    /// Lighter blue for small text and icons on dark surfaces. The brand blue is only
    /// 3.6:1 on near-black, which fails WCAG AA for body-size text; this one is 6:1.
    static let brandText = Color(hex: 0x4D8DFF)
    /// Accent end of the brand gradient used on the boards' section labels.
    static let brandCyan = Color(hex: 0x06B6D4)

    static let background = Color(hex: 0x050505)
    /// Navy glow at the top of onboarding and home.
    static let backgroundGlow = Color(hex: 0x0A1E4A)
    static let splashBackground = Color(hex: 0x101622)

    /// Bottom sheet surface.
    static let surface = Color(hex: 0x09090B)
    /// Cards, chips and illustration panels.
    static let surfaceRaised = Color(hex: 0x1A2130)
    /// Text inputs and list rows.
    static let surfaceField = Color(hex: 0x1A1A1C)
    static let surfaceHighlight = Color(hex: 0x252A3D)

    static let border = Color(hex: 0x2A303C)
    static let borderSubtle = Color(hex: 0x1C1F26)
    static let track = Color(hex: 0x1E2736)

    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0x9AA3B2)
    static let textTertiary = Color(hex: 0x7E8696)

    static let success = Color(hex: 0x24C55E)
    static let warning = Color(hex: 0xF5A524)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Spacing & shape

enum NKSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum NKRadius {
    static let chip: CGFloat = 10
    static let button: CGFloat = 12
    static let card: CGFloat = 16
    static let sheet: CGFloat = 28
}

enum NKSize {
    /// Minimum tappable size from the Human Interface Guidelines.
    static let minTapTarget: CGFloat = 44
    static let primaryButtonHeight: CGFloat = 52
}

// MARK: - Typography

/// Text styles. Each maps to a Dynamic Type style so text scales with the user's setting.
///
/// The boards are set in Space Grotesk. If the font files are bundled (see README) they are
/// used automatically; otherwise the system font is used with the same sizes and weights.
enum NKTextStyle {
    case display
    case title
    case title2
    case headline
    case body
    case subheadline
    case footnote
    case caption
    case overline

    var size: CGFloat {
        switch self {
        case .display: return 34
        case .title: return 28
        case .title2: return 22
        case .headline: return 17
        case .body: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .overline: return 11
        }
    }

    var weight: Font.Weight {
        switch self {
        case .display, .title: return .bold
        case .title2, .headline, .overline: return .semibold
        case .caption: return .medium
        case .body, .subheadline, .footnote: return .regular
        }
    }

    var relativeTo: Font.TextStyle {
        switch self {
        case .display: return .largeTitle
        case .title: return .title
        case .title2: return .title2
        case .headline: return .headline
        case .body: return .callout
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption
        case .overline: return .caption2
        }
    }

    fileprivate var brandFontName: String {
        switch weight {
        case .bold: return "SpaceGrotesk-Bold"
        case .semibold: return "SpaceGrotesk-SemiBold"
        case .medium: return "SpaceGrotesk-Medium"
        default: return "SpaceGrotesk-Regular"
        }
    }
}

enum NKTypography {
    static let isBrandFontAvailable: Bool = UIFont(name: "SpaceGrotesk-Regular", size: 12) != nil

    static func font(_ style: NKTextStyle) -> Font {
        if isBrandFontAvailable {
            return .custom(style.brandFontName, size: style.size, relativeTo: style.relativeTo)
        }
        return .system(style.relativeTo).weight(style.weight)
    }
}

extension View {
    func nkFont(_ style: NKTextStyle) -> some View {
        font(NKTypography.font(style))
    }
}
