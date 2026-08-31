import Foundation
import Security
import UIKit  // needed for UIDevice
import CryptoKit

struct AuthResponse: Decodable {
    let token: String
    let userId: String
    let timeBalance: Double?
    let zone: String?

    enum CodingKeys: String, CodingKey {
        case token, userId, zone
        case user_id
        case timeBalance, time_balance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = try container.decode(String.self, forKey: .token)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
            ?? container.decode(String.self, forKey: .user_id)
        timeBalance = try container.decodeIfPresent(Double.self, forKey: .timeBalance)
            ?? container.decodeIfPresent(Double.self, forKey: .time_balance)
        zone = try container.decodeIfPresent(String.self, forKey: .zone)
    }
}

struct ServerUser: Decodable, Identifiable {
    let id: String
    let username: String
    let avatar: String
    let zone: String
    var timeBalance: Double?
    var hasSharedTime: Bool

    init(
        id: String,
        username: String,
        avatar: String = "⏱",
        zone: String,
        timeBalance: Double? = nil,
        hasSharedTime: Bool = false
    ) {
        self.id = id
        self.username = username
        self.avatar = avatar
        self.zone = zone
        self.timeBalance = timeBalance
        self.hasSharedTime = hasSharedTime
    }

    enum CodingKeys: String, CodingKey {
        case id, username, avatar, zone
        case timeBalance, time_balance
        case hasSharedTime, has_shared_time
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar) ?? "⏱"
        zone = try container.decode(String.self, forKey: .zone)
        timeBalance = try container.decodeIfPresent(Double.self, forKey: .timeBalance)
            ?? container.decodeIfPresent(Double.self, forKey: .time_balance)
        hasSharedTime = try container.decodeIfPresent(Bool.self, forKey: .hasSharedTime)
            ?? container.decodeIfPresent(Bool.self, forKey: .has_shared_time)
            ?? false
    }
}

struct AdminUser: Codable, Identifiable {
    let id: String
    let username: String
    let avatar: String?
    let timeBalance: Double?
    let zone: String
    let totalEarned: Double?
    let loginStreak: Int?
    let lastLogin: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, username, avatar, zone
        case timeBalance = "time_balance"
        case totalEarned = "total_earned"
        case loginStreak = "login_streak"
        case lastLogin = "last_login"
        case createdAt = "created_at"
    }
}

struct SyncResponse: Decodable {
    let serverTime: Double
    let adjustedBalance: Double?
    let antiCheatFlag: Bool?
    let adminOverride: Bool?  // Endast true när admin manuellt har satt balansen

    enum CodingKeys: String, CodingKey {
        case serverTime, server_time
        case adjustedBalance, adjusted_balance
        case antiCheatFlag, anti_cheat_flag
        case adminOverride, admin_override
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        serverTime = try container.decodeIfPresent(Double.self, forKey: .serverTime)
            ?? container.decodeIfPresent(Double.self, forKey: .server_time)
            ?? Date().timeIntervalSince1970
        adjustedBalance = try container.decodeIfPresent(Double.self, forKey: .adjustedBalance)
            ?? container.decodeIfPresent(Double.self, forKey: .adjusted_balance)
        antiCheatFlag = try container.decodeIfPresent(Bool.self, forKey: .antiCheatFlag)
            ?? container.decodeIfPresent(Bool.self, forKey: .anti_cheat_flag)
        adminOverride = try container.decodeIfPresent(Bool.self, forKey: .adminOverride)
            ?? container.decodeIfPresent(Bool.self, forKey: .admin_override)
    }
}

class ServerSync: ObservableObject, @unchecked Sendable {
    static let shared = ServerSync()
    private let serverOrigins = [
        "https://209-38-98-107.sslip.io"
    ]
    private var preferredOriginIndex = 0
    private var syncTimer: Timer?
    private var reconnectTimer: Timer?
    private var websocketTask: URLSessionWebSocketTask?
    private var websocketPingTimer: Timer?
    private var hasLiveChannel = false
    private let maxAttemptsPerOrigin = 3
    private let balanceDriftCorrectionThreshold: TimeInterval = 5
    private var periodicSyncInFlight = false

    private struct DeferredRequest: Codable, Identifiable {
        let id: String
        let path: String
        let bodyJSON: String
        let requireAuth: Bool
        let createdAt: Date
    }
    private let deferredStorageKey = "lt_deferred_requests_v1"
    private var deferredRequests: [DeferredRequest] = []

    private lazy var serverSession: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.waitsForConnectivity = true
        cfg.timeoutIntervalForRequest = 12
        cfg.timeoutIntervalForResource = 30
        if #available(iOS 13.0, *) {
            cfg.tlsMinimumSupportedProtocolVersion = .TLSv12
        }
        return URLSession(configuration: cfg)
    }()

    private struct ServerHTTPError: LocalizedError {
        let statusCode: Int
        let message: String?

        var errorDescription: String? {
            if let message, !message.isEmpty {
                return message
            }
            return "HTTP \(statusCode)"
        }
    }

    private struct ServerUserWire: Decodable {
        let id: String
        let username: String
        let avatar: String?
        let zone: String?
        let timeBalance: Double?
        let hasSharedTime: Bool?

        enum CodingKeys: String, CodingKey {
            case id, username, avatar, zone
            case timeBalance, time_balance
            case hasSharedTime, has_shared_time
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            username = try container.decode(String.self, forKey: .username)
            avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
            zone = try container.decodeIfPresent(String.self, forKey: .zone)
            timeBalance = try container.decodeIfPresent(Double.self, forKey: .timeBalance)
                ?? container.decodeIfPresent(Double.self, forKey: .time_balance)
            hasSharedTime = try container.decodeIfPresent(Bool.self, forKey: .hasSharedTime)
                ?? container.decodeIfPresent(Bool.self, forKey: .has_shared_time)
        }

        func toServerUser(fallbackZone: String?) -> ServerUser {
            ServerUser(
                id: id,
                username: username,
                avatar: avatar ?? "⏱",
                zone: zone ?? fallbackZone ?? "",
                timeBalance: timeBalance,
                hasSharedTime: hasSharedTime ?? false
            )
        }
    }

    private struct ServerUserEnvelope: Decodable {
        let zone: String?
        let members: [ServerUserWire]?
        let leaderboard: [ServerUserWire]?
    }

    private func currentLocalBalance() async -> TimeInterval {
        await MainActor.run { TimeEngine.shared.balance }
    }

    private func currentZoneName() async -> String {
        await MainActor.run { GameState.shared.currentZone.name }
    }

    private func decodeServerUsers(from data: Data, fallbackZone: String? = nil) throws -> [ServerUser] {
        let decoder = JSONDecoder()
        if let direct = try? decoder.decode([ServerUser].self, from: data) {
            return direct
        }
        if let envelope = try? decoder.decode(ServerUserEnvelope.self, from: data) {
            let zone = envelope.zone ?? fallbackZone
            if let members = envelope.members {
                return members.map { $0.toServerUser(fallbackZone: zone) }
            }
            if let leaderboard = envelope.leaderboard {
                return leaderboard.map { $0.toServerUser(fallbackZone: zone) }
            }
        }
        throw ServerHTTPError(statusCode: 422, message: "Unexpected user list payload")
    }

    private func orderedOrigins() -> [String] {
        guard preferredOriginIndex < serverOrigins.count else { return serverOrigins }
        var ordered = [serverOrigins[preferredOriginIndex]]
        ordered.append(contentsOf: serverOrigins.enumerated().compactMap { idx, origin in
            idx == preferredOriginIndex ? nil : origin
        })
        return ordered
    }

    private func markPreferredOrigin(_ origin: String) {
        if let idx = serverOrigins.firstIndex(of: origin) {
            preferredOriginIndex = idx
        }
    }

    // MARK: - Password hash helper (deterministic per device+user)
    private func passwordHash(username: String, deviceId: String) -> String {
        let combined = "\(username):\(deviceId):lifetoken"
        let hash = SHA256.hash(data: Data(combined.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func stableDeviceId() -> String {
        if let existing = keychainLoad(key: deviceIdKey), !existing.isEmpty {
            return existing
        }
        let generated = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        keychainSave(key: deviceIdKey, value: generated)
        return generated
    }

    private func isValidServerUsername(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (3...30).contains(trimmed.count) else { return false }
        return trimmed.range(of: "^[A-Za-z0-9]{3,30}$", options: .regularExpression) != nil
    }

    private func sanitizedUsername(from raw: String, deviceId: String) -> String {
        let filtered = raw.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        var candidate = String(String.UnicodeScalarView(filtered))
        if candidate.count < 3 {
            let suffix = String(deviceId.filter { $0.isLetter || $0.isNumber }.prefix(6))
            candidate += suffix
        }
        if candidate.count < 3 {
            candidate += "999"
        }
        if candidate.count > 30 {
            candidate = String(candidate.prefix(30))
        }
        return candidate
    }

    private func resolvedServerUsername() async -> String? {
        let raw = UserDefaults.standard.string(forKey: "username")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }

        if isValidServerUsername(raw) {
            UserDefaults.standard.set(raw, forKey: serverUsernameKey)
            return raw
        }

        if let cached = UserDefaults.standard.string(forKey: serverUsernameKey),
           isValidServerUsername(cached) {
            await MainActor.run {
                if GameState.shared.username != cached {
                    GameState.shared.username = cached
                }
                UserDefaults.standard.set(cached, forKey: "username")
            }
            return cached
        }

        let deviceId = await MainActor.run { self.stableDeviceId() }
        let sanitized = sanitizedUsername(from: raw, deviceId: deviceId)
        UserDefaults.standard.set(sanitized, forKey: serverUsernameKey)
        await MainActor.run {
            if GameState.shared.username != sanitized {
                GameState.shared.username = sanitized
            }
            UserDefaults.standard.set(sanitized, forKey: "username")
        }
        return sanitized
    }

    private func shouldApplyServerCorrection(
        serverBalance: TimeInterval,
        localBalance: TimeInterval,
        isAdminOverride: Bool
    ) -> Bool {
        if isAdminOverride { return true }
        if TimeEngine.shared.skipServerCorrection { return false }
        return abs(serverBalance - localBalance) >= balanceDriftCorrectionThreshold
    }

    @Published var isOnline: Bool = false
    @Published var lastSyncDate: Date? = nil
    @Published var zoneMembers: [ServerUser] = []
    @Published var onlineCount: Int = 0
    @Published var isAdmin: Bool = false
    @Published var connectionMode: String = "polling"
    @Published var deferredRequestCount: Int = 0

    private init() {
        loadDeferredRequests()
        startPeriodicSync()
    }

    // MARK: - Keychain token storage
    private let tokenKey = "lt_server_token"
    private let userIdKey = "lt_server_userid"
    private let deviceIdKey = "lt_server_deviceid"
    private let serverUsernameKey = "lt_server_username"

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
        if let authUsername = await resolvedServerUsername() {
            // Always try to auth on startup (handles stale tokens and first launch)
            await loginOrRegister(username: authUsername)
            // Pull server's stored balance so admin changes propagate immediately
            await fetchServerBalance()
            await refreshAdminStatus()
            await startRealtimeUpdates()
            await flushDeferredRequests()
        } else {
            await checkHealth()
        }
    }

    // MARK: - Health check (uses root /health, NOT /api/health)

    func checkHealth() async {
        for origin in orderedOrigins() {
            guard let url = secureURL(from: origin + "/health") else { continue }
            do {
                let req = URLRequest(url: url, timeoutInterval: 10)
                let (data, resp) = try await serverSession.data(for: req)
                let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["status"] as? String == "ok" {
                    markPreferredOrigin(origin)
                    DispatchQueue.main.async {
                        self.isOnline = true
                        self.connectionMode = self.hasLiveChannel ? "live" : "polling"
                    }
                    // Re-auth if we somehow have no token
                    if self.token == nil, let authUsername = await self.resolvedServerUsername() {
                        await self.loginOrRegister(username: authUsername)
                    }
                    await self.refreshAdminStatus()
                    await self.startRealtimeUpdates()
                    return
                }
            } catch {
                continue
            }
        }
        DispatchQueue.main.async { self.isOnline = false }
        disconnectRealtimeUpdates()
        scheduleReconnect()
    }

    // MARK: - Periodic sync

    func startPeriodicSync() {
        DispatchQueue.main.async {
            self.syncTimer?.invalidate()
            self.syncTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                guard !self.periodicSyncInFlight else { return }
                self.periodicSyncInFlight = true
                Task {
                    defer {
                        DispatchQueue.main.async {
                            self.periodicSyncInFlight = false
                        }
                    }
                    await self.fetchServerBalance()
                    let balance = await self.currentLocalBalance()
                    await self.syncBalance(balance)
                    await self.fetchZoneMembers()
                    await self.flushDeferredRequests()
                }
            }
        }
    }

    private func scheduleReconnect() {
        DispatchQueue.main.async {
            self.reconnectTimer?.invalidate()
            self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
                Task { await self?.checkHealth() }
            }
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
        let data = try await post(path: "/auth/register", body: body, requireAuth: false, allowHTTPErrorResponseData: true)
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
        let data = try await post(path: "/auth/login", body: body, requireAuth: false, allowHTTPErrorResponseData: true)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errMsg = json["error"] as? String {
            throw NSError(domain: "ServerSync", code: 401, userInfo: [NSLocalizedDescriptionKey: errMsg])
        }
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    func loginOrRegister(username: String) async {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else { return }
        let deviceId = await MainActor.run { self.stableDeviceId() }
        do {
                let resp = try await register(username: trimmedUsername, deviceId: deviceId)
                token = resp.token
                userId = resp.userId
                DispatchQueue.main.async {
                    self.isOnline = true
                    self.onlineCount = 1
                }
                await refreshAdminStatus()
            } catch {
            // Register failed (user may already exist) — try login as fallback
            do {
                let resp = try await login(username: trimmedUsername, deviceId: deviceId)
                token = resp.token
                userId = resp.userId
                DispatchQueue.main.async {
                    self.isOnline = true
                    self.onlineCount = 1
                }
                await refreshAdminStatus()
            } catch {
                DispatchQueue.main.async { self.isOnline = false }
                scheduleReconnect()
            }
        }
    }

    // MARK: - Time sync

    func syncBalance(_ balance: TimeInterval) async {
        guard token != nil else { return }
        let localZoneName = await currentZoneName()
        let body: [String: Any] = [
            "timeBalance": max(0, balance),
            "zone": localZoneName,
            "lastSyncTimestamp": Date().timeIntervalSince1970
        ]
        do {
            let data = try await post(path: "/user/sync", body: body, requireAuth: true)
            let resp = try JSONDecoder().decode(SyncResponse.self, from: data)
            await MainActor.run {
                self.isOnline = true
                self.lastSyncDate = Date()
                if let adj = resp.adjustedBalance {
                    let localBalance = TimeEngine.shared.balance
                    let isAdminOverride = resp.adminOverride == true
                    if self.shouldApplyServerCorrection(
                        serverBalance: adj,
                        localBalance: localBalance,
                        isAdminOverride: isAdminOverride
                    ) {
                        TimeEngine.shared.applyServerBalance(adj)
                    }
                }
                if TimeEngine.shared.skipServerCorrection {
                    TimeEngine.shared.clearServerCorrectionSkip()
                }
                // Anti-cheat handled server-side silently
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
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let balanceValue = json["timeBalance"] ?? json["time_balance"]
                let serverBalance: Double? = {
                    if let d = balanceValue as? Double { return d }
                    if let n = balanceValue as? NSNumber { return n.doubleValue }
                    if let s = balanceValue as? String { return Double(s) }
                    return nil
                }()
                guard let serverBalance = serverBalance else { return }
                let isAdminOverride = (json["adminOverride"] as? Bool) ?? (json["admin_override"] as? Bool) ?? false
                await MainActor.run {
                    let localBalance = TimeEngine.shared.balance
                    if self.shouldApplyServerCorrection(
                        serverBalance: serverBalance,
                        localBalance: localBalance,
                        isAdminOverride: isAdminOverride
                    ) {
                        TimeEngine.shared.applyServerBalance(serverBalance)
                    }
                    self.isOnline = true
                    self.lastSyncDate = Date()
                }
            }
        } catch {
            DispatchQueue.main.async { self.isOnline = false }
        }
    }

    func fetchServerTime() async -> TimeInterval? {
        do {
            let data = try await get(path: "/user/servertime", requireAuth: false)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return (json?["serverTime"] as? TimeInterval) ?? (json?["server_time"] as? TimeInterval)
        } catch { return nil }
    }

    // MARK: - Social

    func fetchZoneMembers() async {
        guard token != nil else { return }
        let localZone = await currentZoneName()
        do {
            let data = try await get(path: "/social/zone-members", requireAuth: true)
            let members = try decodeServerUsers(from: data, fallbackZone: localZone)
            DispatchQueue.main.async {
                self.zoneMembers = members
                self.onlineCount = members.count
            }
        } catch {}
    }

    func fetchLeaderboard() async {
        guard token != nil else { return }
        let localZone = await currentZoneName()
        do {
            let data = try await get(path: "/social/zone-leaderboard", requireAuth: true)
            let users = try decodeServerUsers(from: data, fallbackZone: localZone)
            DispatchQueue.main.async {
                self.onlineCount = max(self.onlineCount, users.count)
            }
        } catch {}
    }

    /// Fetches leaderboard entries for a specific zone.
    /// Zone is URL-escaped to support spaces and Swedish characters.
    func fetchZoneLeaderboard(zone: String, limit: Int = 20) async throws -> [ServerUser] {
        guard token != nil else { return [] }
        let encodedZone = zone.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? zone
        let data = try await get(path: "/social/zone-leaderboard?zone=\(encodedZone)&limit=\(limit)", requireAuth: true)
        return try decodeServerUsers(from: data, fallbackZone: zone)
    }

    func transferTime(toUserId: String, amount: TimeInterval) async throws {
        guard !toUserId.isEmpty, amount.isFinite, amount > 0 else {
            throw URLError(.badURL)
        }
        let body: [String: Any] = ["targetUserId": toUserId, "amount": amount]
        _ = try await post(path: "/social/transfer", body: body, requireAuth: true)
    }

    func shareTime(withUserId: String) async throws {
        let body: [String: Any] = ["targetUserId": withUserId, "shareTime": true]
        _ = try await post(path: "/social/share-time", body: body, requireAuth: true)
    }

    func sendMessage(toUserId: String, message: String) async throws {
        let body: [String: Any] = ["targetUserId": toUserId, "message": message]
        do {
            _ = try await post(path: "/social/message", body: body, requireAuth: true)
        } catch {
            enqueueDeferredRequest(path: "/social/message", body: body, requireAuth: true)
            throw error
        }
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
        do {
            _ = try await post(path: "/bets/sync-steps", body: body, requireAuth: true)
        } catch {
            enqueueDeferredRequest(path: "/bets/sync-steps", body: body, requireAuth: true)
        }
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
        do {
            _ = try await post(path: "/board/sync", body: body, requireAuth: true)
        } catch {
            enqueueDeferredRequest(path: "/board/sync", body: body, requireAuth: true)
        }
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

    // MARK: - Account Management

    /// Permanently deletes the user's account and all data from the server.
    /// Called from settings/profile for App Store GDPR compliance.
    func deleteAccount() async throws {
        _ = try await requestData(method: "DELETE", path: "/user/account", body: nil, requireAuth: true)
        token = nil
        userId = nil
        disconnectRealtimeUpdates()
        await MainActor.run {
            self.isAdmin = false
        }
    }

    // MARK: - Admin

    func adminFetchUsers() async throws -> [AdminUser] {
        let data = try await get(path: "/admin/users", requireAuth: true)
        struct UsersResponse: Codable { let users: [AdminUser] }
        let resp = try JSONDecoder().decode(UsersResponse.self, from: data)
        return resp.users
    }

    func adminSetBalance(userId: String, timeBalance: Double) async throws {
        let body: [String: Any] = ["timeBalance": timeBalance]
        _ = try await post(path: "/admin/user/\(userId)/balance", body: body, requireAuth: true)
        if userId == self.userId {
            await MainActor.run {
                TimeEngine.shared.applyServerBalance(timeBalance)
            }
        }
    }

    func adminSetZone(userId: String, zone: String) async throws {
        let body: [String: Any] = ["zone": zone]
        _ = try await post(path: "/admin/user/\(userId)/zone", body: body, requireAuth: true)
    }

    func adminGiveTime(userId: String, amount: Double) async throws {
        let body: [String: Any] = ["amount": amount]
        _ = try await post(path: "/admin/user/\(userId)/give-time", body: body, requireAuth: true)
        if userId == self.userId {
            await fetchServerBalance()
        }
    }

    // MARK: - HTTP helpers

    private func get(path: String, requireAuth: Bool) async throws -> Data {
        try await requestData(method: "GET", path: path, body: nil, requireAuth: requireAuth)
    }

    private func post(
        path: String,
        body: [String: Any],
        requireAuth: Bool,
        allowHTTPErrorResponseData: Bool = false
    ) async throws -> Data {
        try await requestData(
            method: "POST",
            path: path,
            body: body,
            requireAuth: requireAuth,
            allowHTTPErrorResponseData: allowHTTPErrorResponseData
        )
    }

    private func secureURL(from rawURL: String) -> URL? {
        guard let url = URL(string: rawURL),
              url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    private func shouldRetry(statusCode: Int) -> Bool {
        statusCode == 408 || statusCode == 429 || (500...599).contains(statusCode)
    }

    private func isTransientNetworkError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .networkConnectionLost,
             .dnsLookupFailed,
             .notConnectedToInternet,
             .resourceUnavailable:
            return true
        default:
            return false
        }
    }

    private func retryAfterDelay(from response: HTTPURLResponse, attempt: Int) -> TimeInterval {
        if let retryAfter = response.value(forHTTPHeaderField: "Retry-After"),
           let secs = TimeInterval(retryAfter), secs > 0 {
            return min(secs, 30)
        }
        // Exponential backoff with cap (0.5, 1, 2, ...)
        return min(pow(2.0, Double(attempt - 1)) * 0.5, 5.0)
    }

    private func backoffDelay(attempt: Int) -> TimeInterval {
        min(pow(2.0, Double(attempt - 1)) * 0.5, 5.0)
    }

    private func errorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let message = json["error"] as? String, !message.isEmpty {
            return message
        }
        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }
        return nil
    }

    private func refreshAuthIfPossible() async -> Bool {
        guard let authUsername = await resolvedServerUsername() else { return false }
        await loginOrRegister(username: authUsername)
        return token != nil
    }

    private func requestData(
        method: String,
        path: String,
        body: [String: Any]?,
        requireAuth: Bool,
        allowHTTPErrorResponseData: Bool = false
    ) async throws -> Data {
        if requireAuth, token == nil {
            _ = await refreshAuthIfPossible()
        }
        var lastError: Error = URLError(.cannotConnectToHost)
        var didReauthenticate = false

        for origin in orderedOrigins() {
            guard let url = secureURL(from: origin + "/api" + path) else { continue }

            for attempt in 1...maxAttemptsPerOrigin {
                do {
                    var req = URLRequest(url: url, timeoutInterval: 12)
                    req.httpMethod = method
                    req.setValue("application/json", forHTTPHeaderField: "Accept")
                    if method != "GET" {
                        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    }
                    if requireAuth, let t = token {
                        req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
                    }
                    if let body {
                        req.httpBody = try JSONSerialization.data(withJSONObject: body)
                    }

                    let (data, response) = try await serverSession.data(for: req)
                    guard let http = response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }

                    if http.statusCode == 401, requireAuth, !didReauthenticate {
                        let refreshed = await refreshAuthIfPossible()
                        if refreshed {
                            didReauthenticate = true
                            continue
                        }
                    }

                    if shouldRetry(statusCode: http.statusCode), attempt < maxAttemptsPerOrigin {
                        let delay = retryAfterDelay(from: http, attempt: attempt)
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }

                    if shouldRetry(statusCode: http.statusCode) {
                        lastError = ServerHTTPError(statusCode: http.statusCode, message: errorMessage(from: data))
                        break
                    }

                    if !(200...299).contains(http.statusCode), !allowHTTPErrorResponseData {
                        lastError = ServerHTTPError(statusCode: http.statusCode, message: errorMessage(from: data))
                        break
                    }

                    markPreferredOrigin(origin)
                    return data
                } catch {
                    lastError = error
                    if isTransientNetworkError(error), attempt < maxAttemptsPerOrigin {
                        let delay = backoffDelay(attempt: attempt)
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    break
                }
            }
        }

        throw lastError
    }

    // MARK: - Realtime channel (WebSocket with polling fallback)

    private func websocketURL(for origin: String) -> URL? {
        guard var comps = URLComponents(string: origin) else { return nil }
        comps.scheme = "wss"
        comps.path = "/ws"
        return comps.url
    }

    func startRealtimeUpdates() async {
        guard websocketTask == nil else { return }
        guard let origin = orderedOrigins().first,
              let url = websocketURL(for: origin) else { return }

        var req = URLRequest(url: url)
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let task = serverSession.webSocketTask(with: req)
        websocketTask = task
        task.resume()
        hasLiveChannel = true
        DispatchQueue.main.async {
            self.connectionMode = "live"
        }
        startWebSocketPing()
        receiveNextWebSocketMessage()
    }

    private func disconnectRealtimeUpdates() {
        websocketPingTimer?.invalidate()
        websocketPingTimer = nil
        websocketTask?.cancel(with: .goingAway, reason: nil)
        websocketTask = nil
        hasLiveChannel = false
        DispatchQueue.main.async {
            self.connectionMode = "polling"
        }
    }

    private func startWebSocketPing() {
        DispatchQueue.main.async {
            self.websocketPingTimer?.invalidate()
            self.websocketPingTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
                guard let self, let task = self.websocketTask else { return }
                task.sendPing { error in
                    if error != nil {
                        self.disconnectRealtimeUpdates()
                    }
                }
            }
        }
    }

    private func receiveNextWebSocketMessage() {
        websocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                self.disconnectRealtimeUpdates()
            case .success(let message):
                self.handleWebSocketMessage(message)
                self.receiveNextWebSocketMessage()
            }
        }
    }

    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data?
        switch message {
        case .string(let text): data = text.data(using: .utf8)
        case .data(let payload): data = payload
        @unknown default: data = nil
        }
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        Task {
            switch type {
            case "balance_updated", "admin_override":
                await fetchServerBalance()
            case "zone_members_updated":
                await fetchZoneMembers()
            case "news_updated":
                await fetchServerNews()
            case "admin_role_changed":
                await refreshAdminStatus()
            default:
                break
            }
        }
    }

    // MARK: - Admin role

    func refreshAdminStatus() async {
        guard token != nil else {
            await MainActor.run { self.isAdmin = false }
            return
        }
        do {
            _ = try await get(path: "/admin/users", requireAuth: true)
            await MainActor.run { self.isAdmin = true }
        } catch {
            await MainActor.run { self.isAdmin = false }
        }
    }

    // MARK: - Deferred outbox

    private func enqueueDeferredRequest(path: String, body: [String: Any], requireAuth: Bool) {
        guard deferredRequests.count < 120,
              JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        let item = DeferredRequest(
            id: UUID().uuidString,
            path: path,
            bodyJSON: json,
            requireAuth: requireAuth,
            createdAt: Date()
        )
        deferredRequests.append(item)
        persistDeferredRequests()
    }

    private func loadDeferredRequests() {
        guard let data = UserDefaults.standard.data(forKey: deferredStorageKey),
              let decoded = try? JSONDecoder().decode([DeferredRequest].self, from: data) else {
            deferredRequests = []
            deferredRequestCount = 0
            return
        }
        deferredRequests = decoded
        deferredRequestCount = decoded.count
    }

    private func persistDeferredRequests() {
        if let data = try? JSONEncoder().encode(deferredRequests) {
            UserDefaults.standard.set(data, forKey: deferredStorageKey)
        }
        DispatchQueue.main.async {
            self.deferredRequestCount = self.deferredRequests.count
        }
    }

    func flushDeferredRequests() async {
        guard !deferredRequests.isEmpty else { return }
        var remaining: [DeferredRequest] = []
        for item in deferredRequests {
            do {
                guard let data = item.bodyJSON.data(using: .utf8),
                      let body = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    remaining.append(item)
                    continue
                }
                _ = try await post(
                    path: item.path,
                    body: body,
                    requireAuth: item.requireAuth
                )
            } catch {
                remaining.append(item)
            }
        }
        deferredRequests = remaining
        persistDeferredRequests()
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
