import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Design tokens taken from the Lastys prototype.
enum Theme {
    static let background = Color(hex: 0xFBF8F6)
    static let surface = Color.white
    static let ink = Color(hex: 0x1C1917)
    static let muted = Color(hex: 0x6B6461)

    static let rose = Color(hex: 0xC2255C)
    static let roseDark = Color(hex: 0x9F1D4C)
    static let roseDeep = Color(hex: 0x7A1239)
    static let roseTint = Color(hex: 0xFCE7EE)
    static let roseLine = Color(hex: 0xF3C9D7)

    static let green = Color(hex: 0x15803D)
    static let greenTint = Color(hex: 0xDCFCE7)

    static let cardBorder = Color(hex: 0xEEE8E4)
    static let fieldBorder = Color(hex: 0xE7E1DD)
    static let divider = Color(hex: 0xF1ECE8)
}

extension Font {
    /// Plus Jakarta Sans (bundled variable font), falls back to the system font.
    static func jakarta(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Plus Jakarta Sans", size: size).weight(weight)
    }
}

// MARK: - Shared components

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    var fill: Color = Theme.surface
    var border: Color = Theme.cardBorder

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(fill))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 16, fill: Color = Theme.surface, border: Color = Theme.cardBorder) -> some View {
        modifier(CardModifier(padding: padding, fill: fill, border: border))
    }
}

struct VersionTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.jakarta(11, .bold))
            .tracking(0.2)
            .foregroundStyle(Theme.roseDark)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.roseTint))
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.jakarta(14, .semibold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.fieldBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct Wordmark: View {
    var size: CGFloat = 24
    var body: some View {
        (Text("Lastys").foregroundColor(Theme.ink) + Text(".").foregroundColor(Theme.rose))
            .font(.jakarta(size, .heavy))
            .tracking(-0.6)
    }
}
