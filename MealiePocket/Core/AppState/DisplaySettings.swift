import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        default: return nil
        }
    }
    var label: LocalizedStringKey {
        switch self {
        case .system: return "settings.theme.system"
        case .light:  return "settings.theme.light"
        case .dark:   return "settings.theme.dark"
        }
    }
}

enum PlannerDefaultView: String, CaseIterable, Identifiable {
    case day, week, month
    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .day: return "planner.viewMode.day"
        case .week: return "planner.viewMode.week"
        case .month: return "planner.viewMode.month"
        }
    }
}

@Observable class DisplaySettings {
    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme") }
    }
    var languageCode: String {
        didSet { UserDefaults.standard.set(languageCode, forKey: "selectedLanguage") }
    }
    var plannerDefaultView: PlannerDefaultView {
        didSet { UserDefaults.standard.set(plannerDefaultView.rawValue, forKey: "plannerDefaultView") }
    }
    var locale: Locale { languageCode == "system" ? .autoupdatingCurrent : Locale(identifier: languageCode) }

    init() {
        let t = UserDefaults.standard.string(forKey: "selectedTheme") ?? "system"
        theme = AppTheme(rawValue: t) ?? .system
        languageCode = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "system"
        let plannerViewRaw = UserDefaults.standard.string(forKey: "plannerDefaultView") ?? "month"
        plannerDefaultView = PlannerDefaultView(rawValue: plannerViewRaw) ?? .month
    }
}
