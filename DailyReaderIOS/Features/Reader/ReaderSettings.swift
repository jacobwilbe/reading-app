import Foundation
import SwiftUI
import UIKit

enum ReaderFontFamily: String, CaseIterable, Identifiable {
    case systemSerif
    case systemSans
    case systemRounded
    case georgia

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .systemSerif:
            return "System Serif"
        case .systemSans:
            return "System Sans"
        case .systemRounded:
            return "System Rounded"
        case .georgia:
            return "Georgia"
        }
    }

    func uiFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        switch self {
        case .systemSerif:
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            let descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
            return UIFont(descriptor: descriptor, size: size)
        case .systemSans:
            return UIFont.systemFont(ofSize: size, weight: weight)
        case .systemRounded:
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
            return UIFont(descriptor: descriptor, size: size)
        case .georgia:
            let name = weight >= .semibold ? "Georgia-Bold" : "Georgia"
            return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
        }
    }
}

enum ReaderTheme: String, CaseIterable, Identifiable {
    case light
    case sepia
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .sepia:
            return "Sepia"
        case .dark:
            return "Dark"
        }
    }

    var pageBackgroundColor: UIColor {
        switch self {
        case .light:
            return UIColor(red: 0.98, green: 0.98, blue: 0.96, alpha: 1.0)
        case .sepia:
            return UIColor(red: 0.95, green: 0.90, blue: 0.80, alpha: 1.0)
        case .dark:
            return UIColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1.0)
        }
    }

    var textColor: UIColor {
        switch self {
        case .light, .sepia:
            return UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        case .dark:
            return UIColor(red: 0.91, green: 0.92, blue: 0.94, alpha: 1.0)
        }
    }

    var secondaryTextColor: UIColor {
        switch self {
        case .light:
            return UIColor(red: 0.38, green: 0.40, blue: 0.44, alpha: 1.0)
        case .sepia:
            return UIColor(red: 0.41, green: 0.35, blue: 0.28, alpha: 1.0)
        case .dark:
            return UIColor(red: 0.66, green: 0.70, blue: 0.76, alpha: 1.0)
        }
    }

    var overlayBackground: Color {
        switch self {
        case .light:
            return Color.white.opacity(0.62)
        case .sepia:
            return Color(red: 0.94, green: 0.88, blue: 0.77).opacity(0.66)
        case .dark:
            return Color.black.opacity(0.48)
        }
    }

    var overlayText: Color {
        switch self {
        case .dark:
            return Color.white.opacity(0.9)
        case .light, .sepia:
            return Color.black.opacity(0.72)
        }
    }
}

struct ReaderSettings: Equatable {
    var fontSize: Double
    var fontFamily: ReaderFontFamily
    var theme: ReaderTheme
    var zoomScalePreference: Double

    static let `default` = ReaderSettings(
        fontSize: 17,
        fontFamily: .systemSerif,
        theme: .sepia,
        zoomScalePreference: 1.0
    )

    var cacheKey: String {
        let sizePart = String(format: "%.2f", fontSize)
        let zoomPart = String(format: "%.2f", zoomScalePreference)
        return "font=\(fontFamily.rawValue)|theme=\(theme.rawValue)|size=\(sizePart)|zoom=\(zoomPart)"
    }
}

@MainActor
final class ReaderSettingsStore: ObservableObject {
    static let shared = ReaderSettingsStore()

    @Published var fontSize: Double {
        didSet {
            defaults.set(min(max(fontSize, 14), 24), forKey: Keys.fontSize)
        }
    }

    @Published var fontFamily: ReaderFontFamily {
        didSet {
            defaults.set(fontFamily.rawValue, forKey: Keys.fontFamily)
        }
    }

    @Published var theme: ReaderTheme {
        didSet {
            defaults.set(theme.rawValue, forKey: Keys.theme)
        }
    }

    @Published var zoomScalePreference: Double {
        didSet {
            defaults.set(min(max(zoomScalePreference, 0.8), 2.5), forKey: Keys.zoomScale)
        }
    }

    var currentSettings: ReaderSettings {
        ReaderSettings(
            fontSize: fontSize,
            fontFamily: fontFamily,
            theme: theme,
            zoomScalePreference: zoomScalePreference
        )
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let fontSize = "reader.settings.fontSize"
        static let fontFamily = "reader.settings.fontFamily"
        static let theme = "reader.settings.theme"
        static let zoomScale = "reader.settings.zoomScale"
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedFontSize = defaults.object(forKey: Keys.fontSize) as? Double ?? ReaderSettings.default.fontSize
        let storedZoom = defaults.object(forKey: Keys.zoomScale) as? Double ?? ReaderSettings.default.zoomScalePreference

        let storedFontFamilyRaw = defaults.string(forKey: Keys.fontFamily) ?? ReaderSettings.default.fontFamily.rawValue
        let storedThemeRaw = defaults.string(forKey: Keys.theme) ?? ReaderSettings.default.theme.rawValue

        self.fontSize = min(max(storedFontSize, 14), 24)
        self.zoomScalePreference = min(max(storedZoom, 0.8), 2.5)
        self.fontFamily = ReaderFontFamily(rawValue: storedFontFamilyRaw) ?? ReaderSettings.default.fontFamily
        self.theme = ReaderTheme(rawValue: storedThemeRaw) ?? ReaderSettings.default.theme
    }
}
