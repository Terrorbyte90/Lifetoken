import SwiftUI
import Combine

// MARK: - ZoneTheme

struct ZoneTheme {
    let primary: Color
    let secondary: Color
    let accent: Color
}

// MARK: - ThemeEngine

@MainActor
final class ThemeEngine: ObservableObject {
    static let shared = ThemeEngine()

    @Published private(set) var current: ZoneTheme = ThemeEngine.theme(for: "askan")

    private var cancellable: AnyCancellable?

    init() {
        // Observe ZoneManager.currentZone (ZoneProfile) and map to its name
        cancellable = ZoneManager.shared.$currentZone
            .receive(on: RunLoop.main)
            .sink { [weak self] zone in
                withAnimation(.easeInOut(duration: 0.5)) {
                    self?.current = ThemeEngine.theme(for: zone.name)
                }
            }
    }

    static func theme(for zoneID: ZoneID) -> ZoneTheme {
        switch zoneID.lowercased() {
        case "askan":
            return ZoneTheme(primary: Color(red: 0.91, green: 0.89, blue: 0.88),
                             secondary: Color(red: 0.10, green: 0.10, blue: 0.10),
                             accent: Color(red: 1.0, green: 0.18, blue: 0.18))
        case "grundskiftet":
            return ZoneTheme(primary: Color(red: 0.77, green: 0.72, blue: 0.66),
                             secondary: Color(red: 0.18, green: 0.15, blue: 0.13),
                             accent: Color(red: 1.0, green: 0.42, blue: 0.21))
        case "krypdalen":
            return ZoneTheme(primary: Color(red: 0.66, green: 0.60, blue: 0.50),
                             secondary: Color(red: 0.18, green: 0.13, blue: 0.06),
                             accent: Color(red: 1.0, green: 0.55, blue: 0.26))
        case "grabotten":
            return ZoneTheme(primary: Color(red: 0.54, green: 0.54, blue: 0.54),
                             secondary: Color(red: 0.13, green: 0.13, blue: 0.13),
                             accent: Color(red: 0.69, green: 0.69, blue: 0.69))
        case "skymring":
            return ZoneTheme(primary: Color(red: 0.42, green: 0.48, blue: 0.55),
                             secondary: Color(red: 0.10, green: 0.13, blue: 0.19),
                             accent: Color(red: 0.61, green: 0.50, blue: 0.83))
        case "halvmorker", "halvmörkret":
            return ZoneTheme(primary: Color(red: 0.24, green: 0.35, blue: 0.42),
                             secondary: Color(red: 0.05, green: 0.12, blue: 0.18),
                             accent: Color(red: 0.0, green: 0.83, blue: 0.67))
        case "stigarnasdal", "stigarnas dal":
            return ZoneTheme(primary: Color(red: 0.29, green: 0.40, blue: 0.25),
                             secondary: Color(red: 0.10, green: 0.17, blue: 0.09),
                             accent: Color(red: 0.48, green: 0.78, blue: 0.48))
        case "troskelzonen", "tröskeln":
            return ZoneTheme(primary: Color(red: 0.36, green: 0.42, blue: 0.48),
                             secondary: Color(red: 0.10, green: 0.13, blue: 0.19),
                             accent: Color(red: 0.39, green: 0.71, blue: 0.96))
        case "duskline", "klarljuset":
            return ZoneTheme(primary: Color(red: 0.17, green: 0.29, blue: 0.43),
                             secondary: Color(red: 0.05, green: 0.10, blue: 0.16),
                             accent: Color(red: 0.31, green: 0.76, blue: 0.97))
        case "midgrey", "uppgången":
            return ZoneTheme(primary: Color(red: 0.38, green: 0.44, blue: 0.50),
                             secondary: Color(red: 0.11, green: 0.15, blue: 0.19),
                             accent: Color(red: 0.56, green: 0.79, blue: 0.98))
        case "risefield", "gränslandet":
            return ZoneTheme(primary: Color(red: 0.42, green: 0.37, blue: 0.26),
                             secondary: Color(red: 0.16, green: 0.13, blue: 0.06),
                             accent: Color(red: 1.0, green: 0.84, blue: 0.0))
        case "aetherpoint", "novalux", "vakttornet":
            return ZoneTheme(primary: Color(red: 0.10, green: 0.14, blue: 0.49),
                             secondary: Color(red: 0.02, green: 0.04, blue: 0.19),
                             accent: Color(red: 0.24, green: 0.35, blue: 1.0))
        case "vaultum", "solara", "valvet", "kronan", "evigheten":
            return ZoneTheme(primary: Color(red: 0.71, green: 0.33, blue: 0.04),
                             secondary: Color(red: 0.49, green: 0.18, blue: 0.07),
                             accent: Color(red: 1.0, green: 0.97, blue: 0.93))
        default:
            return ZoneTheme(primary: Color(red: 0.91, green: 0.89, blue: 0.88),
                             secondary: Color(red: 0.10, green: 0.10, blue: 0.10),
                             accent: Color(red: 0.22, green: 1.0, blue: 0.08))
        }
    }
}
