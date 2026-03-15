import Foundation

class BoostManager {
    static let shared = BoostManager()

    private let boostsKey = "activeBoosts"

    func getActiveBoosts() -> [String] {
        return UserDefaults.standard.stringArray(forKey: boostsKey) ?? []
    }

    func clearBoosts() {
        UserDefaults.standard.removeObject(forKey: boostsKey)
    }

    func boosterMultiplier() -> Double {
        let boosts = getActiveBoosts()
        if boosts.contains(where: { $0.contains("50%") }) {
            return 1.5
        } else if boosts.contains(where: { $0.contains("30%") }) {
            return 1.3
        } else if boosts.contains(where: { $0.contains("20%") }) {
            return 1.2
        } else if boosts.contains(where: { $0.contains("10%") }) {
            return 1.1
        } else if boosts.contains(where: { $0.contains("DNA-Boost") }) {
            return 2.0
        }
        return 1.0
    }

    func activeBoosterLabel() -> String? {
        let boosts = getActiveBoosts()
        if boosts.contains(where: { $0.contains("50%") }) { return "Booster 50%" }
        if boosts.contains(where: { $0.contains("30%") }) { return "Booster 30%" }
        if boosts.contains(where: { $0.contains("20%") }) { return "Booster 20%" }
        if boosts.contains(where: { $0.contains("10%") }) { return "Booster 10%" }
        if boosts.contains(where: { $0.contains("DNA-Boost") }) { return "DNA-Boost x2" }
        return nil
    }

    func calculatedEarnings(baseSeconds: TimeInterval) -> TimeInterval {
        return baseSeconds * boosterMultiplier()
    }

    /// Check if tidsstopp (time drain pause) is active
    var tidsstoppIsActive: Bool {
        let expiry = UserDefaults.standard.double(forKey: "tidsstopp_expiry")
        guard expiry > 0 else { return false }
        return Date().timeIntervalSince1970 < expiry
    }
}
