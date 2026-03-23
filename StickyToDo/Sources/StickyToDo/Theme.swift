import SwiftUI
import AppKit

enum Theme {
    static let rowHover = Color(nsColor: NSColor(calibratedRed: 0.118, green: 0.118, blue: 0.118, alpha: 0.05)) // rgba(30,30,30,0.05)
    static let textPrimary = Color(nsColor: NSColor(calibratedRed: 0.118, green: 0.118, blue: 0.118, alpha: 1.0)) // #1E1E1E
    static let placeholder = Color(nsColor: NSColor(calibratedRed: 0.118, green: 0.118, blue: 0.118, alpha: 0.4)) // #1E1E1E @ 40%
    static let iconLight = Color(nsColor: NSColor(calibratedRed: 0.118, green: 0.118, blue: 0.118, alpha: 0.2)) // #1E1E1E @ 20%
    static let iconDark = Color(nsColor: NSColor(calibratedRed: 0.145, green: 0.145, blue: 0.149, alpha: 1.0)) // #252526
    static let accentOrange = Color(nsColor: NSColor(calibratedRed: 0.851, green: 0.463, blue: 0.271, alpha: 1.0)) // #D97645
    static let accentYellow = Color(nsColor: NSColor(calibratedRed: 0.976, green: 0.694, blue: 0.275, alpha: 1.0)) // #F9B146
    static let doneGreen = Color(nsColor: NSColor(calibratedRed: 0.118, green: 0.118, blue: 0.118, alpha: 1.0)) // #1E1E1E
    static let glassBorderLight = Color.black.opacity(0.10)
    static let glassBorderDark = Color.white.opacity(0.14)

    static let categoryPalette: [String] = [
        "4E79A7",
        "59A14F",
        "E15759",
        "F28E2B",
        "76B7B2",
        "B07AA1",
        "EDC948",
        "9C755F"
    ]

    static func color(fromHex hex: String) -> Color {
        Color(nsColor: nsColor(fromHex: hex) ?? .systemBlue)
    }

    private static func nsColor(fromHex hex: String) -> NSColor? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1.0)
    }
}
