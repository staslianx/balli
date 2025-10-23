//
//  FontExtensions.swift
//  balli
//
//  Complete font system including SF Rounded, Passion One, Inter, and Caveat
//  Extracted from AppTheme.swift
//

import SwiftUI
import CoreText

extension Font {
    // MARK: - SF Rounded Weight Enum

    enum SFRoundedWeight {
        case regular
        case medium
        case semiBold
        case bold
        case heavy
        case black

        var systemWeight: Font.Weight {
            switch self {
            case .regular:
                return .regular
            case .medium:
                return .medium
            case .semiBold:
                return .semibold
            case .bold:
                return .bold
            case .heavy:
                return .heavy
            case .black:
                return .black
            }
        }

        var uiFontWeight: UIFont.Weight {
            switch self {
            case .regular:
                return .regular
            case .medium:
                return .medium
            case .semiBold:
                return .semibold
            case .bold:
                return .bold
            case .heavy:
                return .heavy
            case .black:
                return .black
            }
        }
    }

    // MARK: - SF Rounded System Font

    static func sfRounded(_ size: CGFloat, weight: SFRoundedWeight = .regular) -> Font {
        return .system(size: size, weight: weight.systemWeight, design: .rounded)
    }

    /// Helper for system font with SF Rounded (for toolbar buttons etc)
    static func system(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.system(size: size, weight: weight, design: .rounded)
    }

    // SF Rounded semantic names
    static var sfRoundedLargeTitle: Font { sfRounded(34, weight: .semiBold) }
    static var sfRoundedTitle: Font { sfRounded(28, weight: .semiBold) }
    static var sfRoundedTitle2: Font { sfRounded(22, weight: .semiBold) }
    static var sfRoundedTitle3: Font { sfRounded(20, weight: .semiBold) }
    static var sfRoundedHeadline: Font { sfRounded(17, weight: .semiBold) }
    static var sfRoundedBody: Font { sfRounded(17, weight: .regular) }
    static var sfRoundedCallout: Font { sfRounded(16, weight: .regular) }
    static var sfRoundedSubheadline: Font { sfRounded(15, weight: .regular) }
    static var sfRoundedFootnote: Font { sfRounded(13, weight: .regular) }
    static var sfRoundedCaption: Font { sfRounded(12, weight: .regular) }
    static var sfRoundedCaption2: Font { sfRounded(11, weight: .regular) }

    // MARK: - Passion One Font

    enum PassionOneWeight {
        case regular
        case bold
        case black

        var fontName: String {
            switch self {
            case .regular:
                return "PassionOne-Regular"
            case .bold:
                return "PassionOne-Bold"
            case .black:
                return "PassionOne-Black"
            }
        }
    }

    static func passionOne(_ size: CGFloat, weight: PassionOneWeight = .regular) -> Font {
        return .custom(weight.fontName, size: size)
    }

    // MARK: - Inter Font

    enum InterWeight {
        case regular
        case medium
        case semiBold
        case bold

        var weightValue: Font.Weight {
            switch self {
            case .regular:
                return .regular
            case .medium:
                return .medium
            case .semiBold:
                return .semibold
            case .bold:
                return .bold
            }
        }
    }

    static func inter(_ size: CGFloat, weight: InterWeight = .regular) -> Font {
        // Using Inter variable font with SwiftUI weight
        return .custom("Inter", size: size).weight(weight.weightValue)
    }

    // Semantic Inter font styles for AI responses
    static var interLargeTitle: Font { inter(32, weight: .bold) }
    static var interTitle: Font { inter(28, weight: .bold) }
    static var interTitle2: Font { inter(24, weight: .semiBold) }
    static var interTitle3: Font { inter(21, weight: .semiBold) }
    static var interHeadline: Font { inter(19, weight: .semiBold) }
    static var interBody: Font { inter(17, weight: .regular) }
    static var interCallout: Font { inter(16, weight: .regular) }
    static var interSubheadline: Font { inter(15, weight: .medium) }
    static var interFootnote: Font { inter(14, weight: .regular) }
    static var interCaption: Font { inter(13, weight: .regular) }

    // MARK: - Caveat Font (Variable Weight)

    /// Caveat is a variable font with weight axis from 400 (regular) to 700 (bold)
    static func caveat(_ size: CGFloat, weight: CGFloat = 400) -> Font {
        // Weight range: 400 (regular) to 700 (bold)
        // You can use any value in between for fine control
        let clampedWeight = min(max(weight, 400), 700)

        // For SwiftUI, we need to create a UIFont with variation settings first
        let uiFont = UIFont(
            descriptor: UIFontDescriptor(
                fontAttributes: [
                    .name: "Caveat",
                    kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [
                        0x77676874: clampedWeight // 'wght' axis in hex
                    ]
                ]
            ),
            size: size
        )

        return Font(uiFont)
    }

    // Convenience methods for common Caveat weights
    static func caveatRegular(_ size: CGFloat) -> Font {
        return caveat(size, weight: 400)
    }

    static func caveatMedium(_ size: CGFloat) -> Font {
        return caveat(size, weight: 550)
    }

    static func caveatBold(_ size: CGFloat) -> Font {
        return caveat(size, weight: 700)
    }

    // MARK: - Playfair Display Font (Variable Font)

    enum PlayfairDisplayWeight {
        case regular
        case semiBold
        case bold

        var weight: Font.Weight {
            switch self {
            case .regular:
                return .regular
            case .semiBold:
                return .semibold
            case .bold:
                return .bold
            }
        }
    }

    static func playfairDisplay(_ size: CGFloat, weight: PlayfairDisplayWeight = .regular) -> Font {
        return .custom("Playfair Display", size: size).weight(weight.weight)
    }

    // Semantic Playfair Display styles
    static var playfairDisplayLargeTitle: Font { playfairDisplay(34, weight: .bold) }
    static var playfairDisplayTitle: Font { playfairDisplay(28, weight: .bold) }
    static var playfairDisplayTitle2: Font { playfairDisplay(24, weight: .bold) }
    static var playfairDisplayTitle3: Font { playfairDisplay(20, weight: .bold) }
    static var playfairDisplayHeadline: Font { playfairDisplay(17, weight: .bold) }
    static var playfairDisplayBody: Font { playfairDisplay(17, weight: .regular) }
}
