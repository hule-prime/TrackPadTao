import Foundation
import SwiftUI

// MARK: - Language
enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case vietnamese = "vi"
    case english    = "en"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .vietnamese: return "🇻🇳  Tiếng Việt"
        case .english:    return "🇺🇸  English"
        }
    }
}

// MARK: - Actions
enum GestureAction: String, CaseIterable, Codable, Identifiable {
    case none              = "none"
    case switchPrevApp     = "switchPrevApp"
    case switchNextApp     = "switchNextApp"
    case missionControl    = "missionControl"
    case appExpose         = "appExpose"
    case showDesktop       = "showDesktop"
    case launchpad         = "launchpad"
    case switchSpaceLeft   = "switchSpaceLeft"
    case switchSpaceRight  = "switchSpaceRight"

    var id: String { rawValue }

    func displayName(lang: AppLanguage) -> String {
        switch lang {
        case .english:
            switch self {
            case .none:             return "Do Nothing"
            case .switchPrevApp:    return "← Previous App (MRU)"
            case .switchNextApp:    return "→ Next App (MRU)"
            case .missionControl:   return "Mission Control"
            case .appExpose:        return "App Exposé"
            case .showDesktop:      return "Show Desktop"
            case .launchpad:        return "Launchpad"
            case .switchSpaceLeft:  return "Switch Space ←"
            case .switchSpaceRight: return "Switch Space →"
            }
        case .vietnamese:
            switch self {
            case .none:             return "Không làm gì"
            case .switchPrevApp:    return "← App trước (MRU)"
            case .switchNextApp:    return "→ App tiếp (MRU)"
            case .missionControl:   return "Mission Control"
            case .appExpose:        return "App Exposé"
            case .showDesktop:      return "Show Desktop"
            case .launchpad:        return "Launchpad"
            case .switchSpaceLeft:  return "Chuyển Space ←"
            case .switchSpaceRight: return "Chuyển Space →"
            }
        }
    }

    var icon: String {
        switch self {
        case .none:             return "nosign"
        case .switchPrevApp:    return "arrow.left.circle.fill"
        case .switchNextApp:    return "arrow.right.circle.fill"
        case .missionControl:   return "rectangle.3.group.fill"
        case .appExpose:        return "square.3.layers.3d"
        case .showDesktop:      return "desktopcomputer"
        case .launchpad:        return "circle.grid.3x3.fill"
        case .switchSpaceLeft:  return "arrow.left.square.fill"
        case .switchSpaceRight: return "arrow.right.square.fill"
        }
    }
}

// MARK: - Trigger button
enum TriggerButton: Int, CaseIterable, Codable, Identifiable {
    case middle   = 2
    case side1    = 3   // nút hông trái / back
    case side2    = 4   // nút hông phải / forward
    case button5  = 5
    case button6  = 6

    var id: Int { rawValue }

    func label(lang: AppLanguage) -> String {
        switch lang {
        case .english:
            switch self {
            case .middle:  return "Middle Mouse (Button 3)"
            case .side1:   return "Left Side / Back (Button 4)"
            case .side2:   return "Right Side / Forward (Button 5)"
            case .button5: return "Button 6"
            case .button6: return "Button 7"
            }
        case .vietnamese:
            switch self {
            case .middle:  return "Chuột giữa (Button 3)"
            case .side1:   return "Nút hông trái / Back (Button 4)"
            case .side2:   return "Nút hông phải / Forward (Button 5)"
            case .button5: return "Button 6"
            case .button6: return "Button 7"
            }
        }
    }

    var icon: String {
        switch self {
        case .middle:  return "computermouse.fill"
        case .side1:   return "arrow.backward.circle.fill"
        case .side2:   return "arrow.forward.circle.fill"
        default:       return "button.programmable"
        }
    }
}

// MARK: - Config model
struct GestureConfig: Codable, Equatable {
    var dragLeft:     GestureAction = .switchPrevApp
    var dragRight:    GestureAction = .switchNextApp
    var dragUp:       GestureAction = .missionControl
    var dragDown:     GestureAction = .showDesktop
    /// Nút chuột dùng để kích hoạt gesture
    var triggerButton: TriggerButton = .middle
    /// Khoảng cách tối thiểu (pixel) để trigger gesture
    var threshold:    Double = 80.0
    var launchAtLogin: Bool = false
    var language: AppLanguage = .vietnamese
}

// MARK: - Persistence
final class GestureConfigStore: ObservableObject {
    static let shared = GestureConfigStore()

    private let key = "TrackPadGiaCay.config"

    @Published var config: GestureConfig {
        didSet { save() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(GestureConfig.self, from: data) {
            config = decoded
        } else {
            config = GestureConfig()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
