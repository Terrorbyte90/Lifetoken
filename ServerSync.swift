import Foundation
import Security
import UIKit
import CryptoKit

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

class ServerSync: ObservableObject, @unchecked Sendable {
    static let shared = ServerSync()
    private let baseURL    = "http://209.38.98.107:4000/api"
    private let healthURL  = "http://209.38.98.107:4000/health"
    private var syncTimer: Timer?
    private var reconnectTimer: Timer?

    // MARK: - Password hash helper (deterministic per device+user)
    private func passwordHash(username: String, deviceId: String) -> String {
        let combined = "\(username):\(deviceId):lifetoken"
        let hash = SHA256.hash(data: Data(combined.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

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

    /// Called on app launch — always authenticates and checks connectivity
    func startup() async {
        let storedUsername = UserDefaults.standard.string(forKey: "username") ?? ""
        if !storedUsername.isEmpty {
            // Always try to auth on startup (handles stale tokens and first launch)
            await loginOrRegister(username: storedUsername)
            // Pull server's stored balance so admin changes propagate immediately
            await fetchServerBalance()
        } else {
            await checkHealth()
        }
    }

    // MARK: - Health check (uses root /health, NOT /api/health)

    func checkHealth() async {
        guard let url = URL(string: healthURL) else { return }
        do {
            let req = URLRequest(url: url, timeoutInterval: 10)
            let (data, resp) = try await URLSession.shared.data(for: req)
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["status"] as? String == "ok" {
                DispatchQueue.main.async { self.isOnline = true }
                // Re-auth if we somehow have no token
                let storedUsername = UserDefaults.standard.string(forKey: "username") ?? ""
                if self.token == nil && !storedUsername.isEmpty {
                    await self.loginOrRegister(username: storedUsername)
                }
            } else {
                DispatchQueue.main.async { self.isOnline = false }
                scheduleReconnect()
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
        let hash = passwordHash(username: username, deviceId: deviceId)
        let body: [String: Any] = [
            "username": username,
            "deviceId": deviceId,
            "passwordHash": hash
        ]
        let data = try await post(path: "/auth/register", body: body, requireAuth: false)
        // Decode or throw if server returns error
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errMsg = json["error"] as? String {
            throw NSError(domain: "ServerSync", code: 409, userInfo: [NSLocalizedDescriptionKey: errMsg])
        }
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    func login(username: String, deviceId: String) async throws -> AuthResponse {
        let hash = passwordHash(username: username, deviceId: deviceId)
        let body: [String: Any] = [
            "username": username,
            "deviceId": deviceId,
            "passwordHash": hash
        ]
        let data = try await post(path: "/auth/login", body: body, requireAuth: false)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errMsg = json["error"] as? String {
            throw NSError(domain: "ServerSync", code: 401, userInfo: [NSLocalizedDescriptionKey: errMsg])
        }
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    func loginOrRegister(username: String) async {
        let deviceId = await MainActor.run { UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString }
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
                // Server is authoritative: always apply adjustedBalance if present
                if let adj = resp.adjustedBalance,
                   !TimeEngine.shared.skipServerCorrection {
                    TimeEngine.shared.balance = adj
                }
                TimeEngine.shared.skipServerCorrection = false
            }
        } catch {
            DispatchQueue.main.async { self.isOnline = false }
            scheduleReconnect()
        }
    }

    /// Pull the server's stored balance for this user and apply it locally.
    /// Call this on app startup or foreground to pick up admin-set balances.
    func fetchServerBalance() async {
        guard token != nil else { return }
        do {
            let data = try await get(path: "/user/balance", requireAuth: true)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let serverBalance = json["timeBalance"] as? Double {
                DispatchQueue.main.async {
                    if !TimeEngine.shared.skipServerCorrection {
                        TimeEngine.shared.balance = serverBalance
                    }
                }
            }
        } catch { /* endpoint may not exist on all server versions */ }
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

    // MARK: - StepBet

    func createStepBet(bet: StepBet) async {
        guard token != nil else { return }
        let body: [String: Any] = [
            "betId":         bet.id,
            "challengerName": bet.challengerName,
            "opponentName":  bet.opponentName,
            "stake":         bet.stake,
            "deadline":      bet.deadline.timeIntervalSince1970
        ]
        _ = try? await post(path: "/bets/create", body: body, requireAuth: true)
    }

    func acceptStepBet(betId: String) async {
        guard token != nil else { return }
        let body: [String: Any] = ["betId": betId]
        _ = try? await post(path: "/bets/accept", body: body, requireAuth: true)
    }

    func syncStepBet(betId: String, steps: Int) async {
        guard token != nil else { return }
        let body: [String: Any] = ["betId": betId, "steps": steps, "timestamp": Date().timeIntervalSince1970]
        _ = try? await post(path: "/bets/sync-steps", body: body, requireAuth: true)
    }

    func settleBet(betId: String, winnerName: String) async {
        guard token != nil else { return }
        let body: [String: Any] = ["betId": betId, "winner": winnerName]
        _ = try? await post(path: "/bets/settle", body: body, requireAuth: true)
    }

    // MARK: - Board / Styrelsen

    func syncBoardBalances(members: [BoardMember]) async {
        guard token != nil else { return }
        let payload = members.map { ["id": $0.id, "balance": $0.balance, "displayName": $0.displayName] }
        let body: [String: Any] = ["members": payload]
        _ = try? await post(path: "/board/sync", body: body, requireAuth: true)
    }

    func fetchBoardState() async {
        guard token != nil else { return }
        _ = try? await get(path: "/board/state", requireAuth: true)
    }

    // MARK: - News feed

    func fetchServerNews() async {
        guard token != nil else { return }
        guard let data = try? await get(path: "/news/feed", requireAuth: true),
              let items = try? JSONDecoder().decode([NewsItem].self, from: data) else { return }
        DispatchQueue.main.async {
            for item in items.reversed() {
                if !NewsManager.shared.items.contains(where: { $0.id == item.id }) {
                    NewsManager.shared.items.insert(item, at: 0)
                }
            }
        }
    }

    // MARK: - Faction

    func fetchFaction() async throws -> Faction? {
        // Stub — implement with real API when backend is ready
        throw URLError(.notConnectedToInternet)
    }

    func pushFactionContribution(factionID: String, seconds: Int) async throws {
        // Stub — implement with real API when backend is ready
        throw URLError(.notConnectedToInternet)
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
