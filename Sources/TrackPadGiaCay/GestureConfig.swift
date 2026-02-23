import Foundation
import SwiftUI

// MARK: - Actions
enum GestureAction: String, CaseIterable, Codable, Identifiable {
    case none              = "Không làm gì"
    case switchPrevApp     = "← App trước (MRU)"
    case switchNextApp     = "→ App tiếp (MRU)"
    case missionControl    = "Mission Control"
    case appExpose         = "App Exposé"
    case showDesktop       = "Show Desktop"
    case launchpad         = "Launchpad"
    case switchSpaceLeft   = "Chuyển Space ←"
    case switchSpaceRight  = "Chuyển Space →"

    var id: String { rawValue }

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

    var label: String {
        switch self {
        case .middle:  return "Chuột giữa (Button 3)"
        case .side1:   return "Nút hông trái / Back (Button 4)"
        case .side2:   return "Nút hông phải / Forward (Button 5)"
        case .button5: return "Button 6"
        case .button6: return "Button 7"
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
