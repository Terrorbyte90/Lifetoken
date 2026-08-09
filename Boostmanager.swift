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
        let boosts = activeNonExpiredBoosts()
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

    /// Returns only boosts that have not yet expired.
    /// Boosts without an exp: tag are treated as permanent (legacy).
    private func activeNonExpiredBoosts() -> [String] {
        let now = Date().timeIntervalSince1970
        return getActiveBoosts().filter { boost in
            if let range = boost.range(of: "exp:") {
                let expStr = String(boost[range.upperBound...]).prefix(while: { $0.isNumber })
                if let expiry = Double(expStr) {
                    return now < expiry
                }
            }
            return true  // no exp: tag — keep (legacy or permanent item)
        }
    }

    func pruneExpiredBoosts() {
        let pruned = activeNonExpiredBoosts()
        UserDefaults.standard.set(pruned, forKey: boostsKey)
    }

    func activeBoosterLabel() -> String? {
        let boosts = activeNonExpiredBoosts()
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

    /// Aktivera en boost med namn och varaktighet (köpt på nattmarknaden etc.)
    func activateBoost(named name: String, duration: TimeInterval) {
        var boosts = getActiveBoosts()
        let entry = "\(name) (exp:\(Int(Date().timeIntervalSince1970 + duration)))"
        boosts.append(entry)
        UserDefaults.standard.set(boosts, forKey: boostsKey)

        // Tidsstopp är speciell — sätt expiry-nyckel
        if name.contains("Tidsstopp") {
            let expiry = Date().timeIntervalSince1970 + duration
            UserDefaults.standard.set(expiry, forKey: "tidsstopp_expiry")
        }
    }
}
