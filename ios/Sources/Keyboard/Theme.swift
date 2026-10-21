import UIKit

/// The board's colours, resolved per trait collection so the keyboard follows the
/// system's light and dark appearance like the stock one does.
enum Theme {
    static let background = dynamic(light: 0xE8E9ED, dark: 0x15171A)
    static let key = dynamic(light: 0xFFFFFF, dark: 0x2A2E34)
    static let keySpecial = dynamic(light: 0xC9CDD6, dark: 0x1F2328)
    static let keyPressed = dynamic(light: 0xAFB6C4, dark: 0x3C424A)
    static let keyAccent = dynamic(light: 0x2F6FD0, dark: 0x3B7DDD)
    static let text = dynamic(light: 0x1A1C1E, dark: 0xF2F3F5)
    static let hint = dynamic(light: 0x8A8F99, dark: 0x7B828C)
    static let popup = dynamic(light: 0xFFFFFF, dark: 0x2A2E34)

    private static func dynamic(light: Int, dark: Int) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? colour(dark) : colour(light)
        }
    }

    private static func colour(_ rgb: Int) -> UIColor {
        UIColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
