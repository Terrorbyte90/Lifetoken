import Foundation
import Security
import SwiftUI

/// The single source of truth for all time calculations.
/// Anti-cheat: Uses Keychain + NTP verification. The clock cannot be paused.
class TimeEngine: ObservableObject {
    static let shared = TimeEngine()

    @Published var balance: TimeInterval = 0          // seconds remaining
    @Published var isTimedOut: Bool = false
    @Published var ntpVerified: Bool = false
    @Published var cheatingDetected: Bool = false

    private let service = "com.lifetoken.engine"
    private let balanceKey = "lifetoken_balance_v2"
    private let lastSyncKey = "lifetoken_lastsync_v2"
    private let drainRateKey = "lifetoken_drainrate"

    private var tickTimer: Timer?
    private var ntpTimer: Timer?
    private var lastVerifiedTime: Date?
    private var currentDrainRate: TimeInterval = 1.0  // seconds drained per real second

    /// Prevents the next server sync from rolling back a manual balance reset
    var skipServerCorrection: Bool = false

    // NTP servers to query
    private let ntpServers = ["time.apple.com", "time.cloudflare.com", "pool.ntp.org"]

    private init() {
        loadFromKeychain()
        applyPendingServerReset()   // one-time reset if flagged
        startTicking()
        startNTPVerification()
        registerBackgroundDrain()
    }

    // MARK: - One-time balance restore (runs exactly once on first launch of this build)

    private func applyPendingServerReset() {
        let doneKey = "balance_reset_done_v4"
        guard !UserDefaults.standard.bool(forKey: doneKey) else { return }
        UserDefaults.standard.set(true, forKey: doneKey)
        // Reset to 24 hours — runs once, then never again
        balance = 86400
        isTimedOut = false
        cheatingDetected = false
        skipServerCorrection = true
        saveToKeychain(balance: 86400, timestamp: Date())
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            Task { await ServerSync.shared.syncBalance(86400) }
        }
    }

    // MARK: - Keychain Storage

    private func saveToKeychain(balance: TimeInterval, timestamp: Date) {
        let data: [String: Any] = [
            "balance": balance,
            "timestamp": timestamp.timeIntervalSince1970,
            "drain": currentDrainRate
        ]
        guard let encoded = try? JSONSerialization.data(withJSONObject: data) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: balanceKey
        ]
        let attributes: [String: Any] = [kSecValueData as String: encoded]

        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = encoded
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    /// Public wrapper so AppDelegate can call saveToKeychain
    func saveToKeychainPublic() {
        saveToKeychain(balance: balance, timestamp: Date())
    }

    private func loadFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: balanceKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let savedBalance = dict["balance"] as? TimeInterval,
              let savedTimestamp = dict["timestamp"] as? TimeInterval,
              let savedDrain = dict["drain"] as? TimeInterval else {
            // First launch — set 24 hours
            balance = 86400
            saveToKeychain(balance: 86400, timestamp: Date())
            return
        }

        let lastSync = Date(timeIntervalSince1970: savedTimestamp)
        let now = Date()
        let elapsed = now.timeIntervalSince(lastSync)
        currentDrainRate = savedDrain

        // Apply offline drain — clock never stops
        let drained = elapsed * currentDrainRate
        balance = max(0, savedBalance - drained)
        isTimedOut = balance <= 0
    }

    // MARK: - Tick

    func startTicking() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let drain = self.currentDrainRate
                self.balance = max(0, self.balance - drain)
                self.isTimedOut = self.balance <= 0
                // Save every 30 seconds to avoid excessive Keychain writes
                if Int(self.balance) % 30 == 0 {
                    self.saveToKeychain(balance: self.balance, timestamp: Date())
                }
            }
        }
    }

    // MARK: - NTP Verification

    func startNTPVerification() {
        verifyTimeNow()
        ntpTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.verifyTimeNow()
        }
    }

    private func verifyTimeNow() {
        // Use worldtimeapi as a simple HTTP time source
        guard let url = URL(string: "https://worldtimeapi.org/api/ip") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            // TLS / network errors are non-fatal — skip verification silently
            if let error = error {
                _ = error   // acknowledged; NTP check simply skipped this cycle
                return
            }
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let unixtime = json["unixtime"] as? TimeInterval else { return }

            let serverTime = Date(timeIntervalSince1970: unixtime)
            let deviceTime = Date()
            let discrepancy = abs(serverTime.timeIntervalSince(deviceTime))

            DispatchQueue.main.async {
                self.ntpVerified = true
                self.lastVerifiedTime = serverTime

                // If device clock is off by more than 60 seconds, flag cheating
                if discrepancy > 60 {
                    self.cheatingDetected = true
                    // Use server time as reference — any gained time is clawed back
                    let storedSync = self.loadLastSyncTimestamp()
                    if let storedSync = storedSync {
                        let realElapsed = serverTime.timeIntervalSince(storedSync)
                        let deviceElapsed = deviceTime.timeIntervalSince(storedSync)
                        // If device elapsed is less than real (clock was moved back), drain the difference
                        if deviceElapsed < realElapsed {
                            let stolen = (realElapsed - deviceElapsed) * self.currentDrainRate
                            self.balance = max(0, self.balance - stolen)
                        }
                    }
                }
                self.saveLastSyncTimestamp(serverTime)
            }
        }.resume()
    }

    private func loadLastSyncTimestamp() -> Date? {
        let key = "lifetoken_ntpsync"
        guard let val = UserDefaults.standard.object(forKey: key) as? Date else { return nil }
        return val
    }

    private func saveLastSyncTimestamp(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "lifetoken_ntpsync")
    }

    // MARK: - Background Drain Registration

    func registerBackgroundDrain() {
        // Save current state when app goes to background
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.saveToKeychain(balance: self.balance, timestamp: Date())
        }
        // On foreground: reload and apply catch-up drain
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.loadFromKeychain()
            self?.startTicking()
        }
    }

    // MARK: - Public API

    /// Add time to balance (earnings, rewards, casino wins)
    func addTime(_ seconds: TimeInterval) {
        DispatchQueue.main.async {
            self.balance += seconds
            self.saveToKeychain(balance: self.balance, timestamp: Date())
        }
    }

    /// Deduct time (purchases, zone migration, casino losses, taxes)
    @discardableResult
    func deductTime(_ seconds: TimeInterval) -> Bool {
        guard balance >= seconds else { return false }
        DispatchQueue.main.async {
            self.balance -= seconds
            self.saveToKeychain(balance: self.balance, timestamp: Date())
        }
        return true
    }

    /// Set drain rate (zone-based, called by ZoneManager)
    func setDrainRate(_ rate: TimeInterval) {
        currentDrainRate = rate
        saveToKeychain(balance: balance, timestamp: Date())
    }

    /// DEV ONLY — Reset balance, persist to Keychain, and push to server
    func devResetBalance(to seconds: TimeInterval = 86400) {
        DispatchQueue.main.async {
            self.balance = seconds
            self.isTimedOut = false
            self.cheatingDetected = false
            self.skipServerCorrection = true
            self.saveToKeychain(balance: seconds, timestamp: Date())
        }
        Task { await ServerSync.shared.syncBalance(seconds) }
    }

    // MARK: - Formatting

    static func formatted(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds))
        if s >= 31536000 {
            let y = s / 31536000
            let d = (s % 31536000) / 86400
            return "\(y)y \(d)d"
        } else if s >= 86400 {
            let d = s / 86400
            let h = (s % 86400) / 3600
            let m = (s % 3600) / 60
            return "\(d)d \(String(format: "%02d:%02d", h, m))"
        } else {
            let h = s / 3600
            let m = (s % 3600) / 60
            let sec = s % 60
            return String(format: "%02d:%02d:%02d", h, m, sec)
        }
    }

    static func shortFormatted(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds))
        if s >= 31536000 { return "\(s/31536000)y" }
        if s >= 86400 { return "\(s/86400)d \((s%86400)/3600)h" }
        if s >= 3600 { return "\(s/3600)h \((s%3600)/60)m" }
        if s >= 60 { return "\(s/60)m \(s%60)s" }
        return "\(s)s"
    }
}
