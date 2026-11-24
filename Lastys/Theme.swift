import SwiftUI
import UIKit

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
    /// The app's text font: Plus Jakarta Sans for Latin, with Nokora taking over for Khmer, so a line that
    /// mixes both reads in each script's own face. Both are bundled variable fonts; the system font is the
    /// last fallback. (The name is historical: it covers Khmer too.)
    static func jakarta(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font(AppFont.make(size: size, weight: weight))
    }
}

private enum AppFont {
    static func make(size: CGFloat, weight: Font.Weight) -> UIFont {
        let uiWeight = weight.uiWeight
        let nokora = UIFontDescriptor(fontAttributes: [
            .family: "Nokora",
            .traits: [UIFontDescriptor.TraitKey.weight: uiWeight],
        ])
        let latin = UIFontDescriptor(fontAttributes: [
            .family: "Plus Jakarta Sans",
            .traits: [UIFontDescriptor.TraitKey.weight: uiWeight],
            .cascadeList: [nokora],
        ])
        let font = UIFont(descriptor: latin, size: size)
        // Keep Dynamic Type scaling, as `Font.custom` did.
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: font)
    }
}

private extension Font.Weight {
    var uiWeight: UIFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
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

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.jakarta(16, .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isEnabled ? Theme.rose : Theme.muted.opacity(0.4)))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// A tappable checkbox with a label, at least 44pt tall.
struct CheckboxRow: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn ? Theme.rose : Theme.muted)
                Text(title)
                    .font(.jakarta(15))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
