import Foundation
import LastysCore

/// Text made in code rather than shown by a SwiftUI view, such as notifications and Face ID prompts.
/// A view reads the app's language from its environment; code can't, and `String(localized:)` follows the
/// phone's language instead. This follows the language chosen in the app, so both agree.
enum AppText {
    private static let lock = NSLock()
    private static var current = Language.khmer

    /// The app's language. Set when the app opens and whenever the person changes it.
    static var language: Language {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }

    /// A translated text, with any values filled in. Falls back to the phone's language if the app has no
    /// translation folder for this one.
    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: bundle(for: language), locale: Locale(identifier: language.rawValue))
    }

    /// A translated text for a key only known at run time, such as a Face ID reason from LastysCore.
    /// Returns the key itself when there is no translation.
    static func lookup(_ key: String) -> String {
        bundle(for: language).localizedString(forKey: key, value: key, table: nil)
    }

    private static func bundle(for language: Language) -> Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }
}
