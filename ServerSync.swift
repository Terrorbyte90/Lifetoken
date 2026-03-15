import Foundation
import Security
import UIKit

struct AuthResponse: Codable {
    let token: String
    let userId: String
    let timeBalance: Double?
    let zone: String?
}

struct ServerUser: Codable, Identifiable {
    let id: String
    let username: String
    let avatar: String
    let zone: String
    var timeBalance: Double?
    var hasSharedTime: Bool
}

struct SyncResponse: Codable {
    let serverTime: Double
    let adjustedBalance: Double?
    let antiCheatFlag: Bool?
}

class ServerSync: ObservableObject {
    static let shared = ServerSync()
    private let baseURL = "http://209.38.98.107:4000/api"
    private var syncTimer: Timer?
    private var reconnectTimer: Timer?

    @Published var isOnline: Bool = false
    @Published var lastSyncDate: Date? = nil
    @Published var zoneMembers: [ServerUser] = []
    @Published var onlineCount: Int = 0

    private init() {
        startPeriodicSync()
    }

    // MARK: - Keychain token storage
    private let tokenKey = "lt_server_token"
    private let userIdKey = "lt_server_userid"

    var token: String? {
        get { keychainLoad(key: tokenKey) }
        set {
            if let v = newValue { keychainSave(key: tokenKey, value: v) }
            else { keychainDelete(key: tokenKey) }
        }
    }

    var userId: String? {
        get { keychainLoad(key: userIdKey) }
        set {
            if let v = newValue { keychainSave(key: userIdKey, value: v) }
            else { keychainDelete(key: userIdKey) }
        }
    }

    // MARK: - Startup

    /// Called on app launch — auto-logins if we have stored credentials
    func startup() async {
        let storedUsername = UserDefaults.standard.string(forKey: "username") ?? ""
        if token == nil && !storedUsername.isEmpty {
            await loginOrRegister(username: storedUsername)
        } else if token != nil {
            await checkHealth()
        }
    }

    // MARK: - Health check

    func checkHealth() async {
        do {
            let data = try await get(path: "/health", requireAuth: false)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["status"] as? String == "ok" {
                DispatchQueue.main.async { self.isOnline = true }
            }
        } catch {
            DispatchQueue.main.async { self.isOnline = false }
            scheduleReconnect()
        }
    }

    // MARK: - Periodic sync

    func startPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task {
                await self?.syncBalance(TimeEngine.shared.balance)
                await self?.fetchZoneMembers()
            }
        }
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            Task { await self?.checkHealth() }
        }
    }

    // MARK: - Auth

    func register(username: String, deviceId: String) async throws -> AuthResponse {
        let body: [String: Any] = ["username": username, "deviceId": deviceId]
        let data = try await post(path: "/auth/register", body: body, requireAuth: false)
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    func login(username: String, deviceId: String) async throws -> AuthResponse {
        let body: [String: Any] = ["username": username, "deviceId": deviceId]
        let data = try await post(path: "/auth/login", body: body, requireAuth: false)
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    func loginOrRegister(username: String) async {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        do {
            let resp = try await register(username: username, deviceId: deviceId)
            token = resp.token
            userId = resp.userId
            DispatchQueue.main.async {
                self.isOnline = true
                self.onlineCount = 1
            }
        } catch {
            // Register failed (user may already exist) — try login as fallback
            do {
                let resp = try await login(username: username, deviceId: deviceId)
                token = resp.token
                userId = resp.userId
                DispatchQueue.main.async {
                    self.isOnline = true
                    self.onlineCount = 1
                }
            } catch {
                DispatchQueue.main.async { self.isOnline = false }
                scheduleReconnect()
            }
        }
    }

    // MARK: - Time sync

    func syncBalance(_ balance: TimeInterval) async {
        guard token != nil else { return }
        let body: [String: Any] = [
            "timeBalance": balance,
            "zone": GameState.shared.currentZone.name,
            "lastSyncTimestamp": Date().timeIntervalSince1970
        ]
        do {
            let data = try await post(path: "/user/sync", body: body, requireAuth: true)
            let resp = try JSONDecoder().decode(SyncResponse.self, from: data)
            DispatchQueue.main.async {
                self.isOnline = true
                self.lastSyncDate = Date()
                if let adj = resp.adjustedBalance, adj < TimeEngine.shared.balance * 0.95 {
                    // Only apply server correction if it's significantly lower (anti-cheat)
                    TimeEngine.shared.balance = adj
                }
            }
        } catch {
            DispatchQueue.main.async { self.isOnline = false }
            scheduleReconnect()
        }
    }

    func fetchServerTime() async -> TimeInterval? {
        do {
            let data = try await get(path: "/user/servertime", requireAuth: false)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["serverTime"] as? TimeInterval
        } catch { return nil }
    }

    // MARK: - Social

    func fetchZoneMembers() async {
        guard token != nil else { return }
        do {
            let data = try await get(path: "/social/zone-members", requireAuth: true)
            let members = try JSONDecoder().decode([ServerUser].self, from: data)
            DispatchQueue.main.async {
                self.zoneMembers = members
                self.onlineCount = members.count
            }
        } catch {}
    }

    func fetchLeaderboard() async {
        guard token != nil else { return }
        do {
            let data = try await get(path: "/social/zone-leaderboard", requireAuth: true)
            let users = try JSONDecoder().decode([ServerUser].self, from: data)
            DispatchQueue.main.async {
                self.onlineCount = max(self.onlineCount, users.count)
            }
        } catch {}
    }

    func transferTime(toUserId: String, amount: TimeInterval) async throws {
        let body: [String: Any] = ["targetUserId": toUserId, "amount": amount]
        _ = try await post(path: "/social/transfer", body: body, requireAuth: true)
    }

    func shareTime(withUserId: String) async throws {
        let body: [String: Any] = ["targetUserId": withUserId, "shareTime": true]
        _ = try await post(path: "/social/share-time", body: body, requireAuth: true)
    }

    func sendMessage(toUserId: String, message: String) async throws {
        let body: [String: Any] = ["targetUserId": toUserId, "message": message]
        _ = try await post(path: "/social/message", body: body, requireAuth: true)
    }

    // MARK: - HTTP helpers

    private func get(path: String, requireAuth: Bool) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url, timeoutInterval: 10)
        if requireAuth, let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    private func post(path: String, body: [String: Any], requireAuth: Bool) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if requireAuth, let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    // MARK: - Keychain

    private func keychainSave(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func keychainLoad(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func keychainDelete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
