import SwiftUI
import Foundation

// MARK: - NPC Player

struct NPCPlayer: Identifiable {
    let id: UUID
    let name: String
    let zone: String
    let avatar: String
    let bio: String
    var balance: TimeInterval
    var loanInterestRate: Double    // monthly interest rate
    var reliability: Double         // 0-1, chance they repay on time
    var lastSeen: String

    static let all: [NPCPlayer] = [
        NPCPlayer(id: UUID(), name: "Viktor R.",   zone: "Askan",         avatar: "😐",
                  bio: "Skrotsamlare. Alltid lite knapp på tid. Pålitlig nog.",
                  balance: 3600 * 6,    loanInterestRate: 0.18, reliability: 0.75, lastSeen: "4h sedan"),
        NPCPlayer(id: UUID(), name: "Lena S.",     zone: "Spillrorna",    avatar: "😶",
                  bio: "Budlöpare. Tyst och metodisk. Betalar alltid i tid.",
                  balance: 3600 * 10,   loanInterestRate: 0.16, reliability: 0.80, lastSeen: "2h sedan"),
        NPCPlayer(id: UUID(), name: "Marco D.",    zone: "Betongen",      avatar: "🧑",
                  bio: "Fabriksarbetare. Springer fort men lever knappast.",
                  balance: 3600 * 18,   loanInterestRate: 0.15, reliability: 0.78, lastSeen: "1h sedan"),
        NPCPlayer(id: UUID(), name: "Aisha B.",    zone: "Dimman",        avatar: "🧕",
                  bio: "Fabriksarbetare med extra skift. Noggrant bokförd.",
                  balance: 86400 * 2,   loanInterestRate: 0.12, reliability: 0.85, lastSeen: "30m sedan"),
        NPCPlayer(id: UUID(), name: "Pjotr V.",    zone: "Halvmörkret",   avatar: "🧔",
                  bio: "Säkerhetsvakt. Håller sin tid noga. Låg ränta.",
                  balance: 86400 * 4,   loanInterestRate: 0.10, reliability: 0.88, lastSeen: "45m sedan"),
        NPCPlayer(id: UUID(), name: "Mara D.",     zone: "Gränslandet",   avatar: "🧐",
                  bio: "Revisor. Noggrant bokförd. Betalar alltid tillbaka.",
                  balance: 86400 * 8,   loanInterestRate: 0.08, reliability: 0.95, lastSeen: "1h sedan"),
        NPCPlayer(id: UUID(), name: "Sven K.",     zone: "Stigarnas Dal", avatar: "👨‍💼",
                  bio: "Tekniker. Stabil och förutsägbar.",
                  balance: 86400 * 15,  loanInterestRate: 0.09, reliability: 0.90, lastSeen: "20m sedan"),
        NPCPlayer(id: UUID(), name: "Yuki T.",     zone: "Uppgången",     avatar: "👩‍🔬",
                  bio: "Laboratorieassistent. Precis och pålitlig.",
                  balance: 86400 * 30,  loanInterestRate: 0.07, reliability: 0.93, lastSeen: "10m sedan"),
        NPCPlayer(id: UUID(), name: "ARIA-7",      zone: "Tröskeln",      avatar: "🤖",
                  bio: "AI-analytiker. Aldrig sen med betalning. Låg ränta.",
                  balance: 86400 * 60,  loanInterestRate: 0.05, reliability: 0.99, lastSeen: "15m sedan"),
        NPCPlayer(id: UUID(), name: "Kai Dusk",    zone: "Klarljuset",    avatar: "😎",
                  bio: "Tidshandlare. Hög risk, hög belöning. Lite otillförlitlig.",
                  balance: 86400 * 400, loanInterestRate: 0.25, reliability: 0.60, lastSeen: "3h sedan"),
        NPCPlayer(id: UUID(), name: "Echo",        zone: "Vakttornet",    avatar: "🎭",
                  bio: "Mystisk spelare. Ingen vet var hen kommer ifrån. Hög ränta.",
                  balance: 86400 * 300, loanInterestRate: 0.30, reliability: 0.55, lastSeen: "Just nu"),
        NPCPlayer(id: UUID(), name: "Director Y.", zone: "Valvet",        avatar: "🧑‍⚖️",
                  bio: "Tidsdirektör. Enormt kapital. Kräver stor insats.",
                  balance: 86400 * 365 * 2, loanInterestRate: 0.40, reliability: 0.70, lastSeen: "Just nu"),
        NPCPlayer(id: UUID(), name: "Syndra Wei",  zone: "Kronan",        avatar: "👑",
                  bio: "Tidsmiljonär. Erbjuder lån till högt pris. Alltid pålitlig.",
                  balance: 86400 * 365 * 5, loanInterestRate: 0.50, reliability: 1.0, lastSeen: "5m sedan"),
        NPCPlayer(id: UUID(), name: "Solarex",     zone: "Evigheten",     avatar: "☀️",
                  bio: "Evighetskärna. Oöverskådligt kapital. Aldrig förhandlingsbar.",
                  balance: 86400 * 365 * 100, loanInterestRate: 0.75, reliability: 1.0, lastSeen: "Alltid"),
    ]
}

// MARK: - Loan Record

struct LoanRecord: Codable, Identifiable {
    let id: UUID
    let npcName: String
    let principal: TimeInterval
    let dailyRate: Double
    let startDate: Date
    let dueDays: Int
    let lentToNPC: Bool   // true = you lent to NPC, false = you borrowed from NPC

    var daysElapsed: Double { Date().timeIntervalSince(startDate) / 86400 }
    var interest: TimeInterval { principal * dailyRate * daysElapsed }
    var totalDue: TimeInterval { principal + interest }
    var isPastDue: Bool { daysElapsed > Double(dueDays) }
}

// MARK: - Chat Message

struct ZoneMessage: Identifiable {
    let id: UUID
    let senderName: String
    let text: String
    let date: Date
    var isFromSelf: Bool
}

// MARK: - Social Manager

class SocialManager: ObservableObject, @unchecked Sendable {
    static let shared = SocialManager()

    @Published var activeLoans: [LoanRecord] = []
    @Published var transferHistory: [(String, TimeInterval, Date)] = []
    @Published var chatMessages: [ZoneMessage] = []
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""

    private let loansKey = "social_loans"

    private init() {
        loadLoans()
        loadMockMessages()
    }

    func npcsInZone(_ zone: ZoneProfile) -> [NPCPlayer] {
        NPCPlayer.all.filter { npc in
            guard let npcZone = ZoneProfile.allZones.first(where: { $0.name == npc.zone }) else { return false }
            return npcZone.index == zone.index
        }
    }

    func npcsNearby(_ zone: ZoneProfile) -> [NPCPlayer] {
        NPCPlayer.all.filter { npc in
            guard let npcZone = ZoneProfile.allZones.first(where: { $0.name == npc.zone }) else { return false }
            return abs(npcZone.index - zone.index) <= 1
        }
    }

    func lendToNPC(_ npc: NPCPlayer, amount: TimeInterval, days: Int) -> Bool {
        guard TimeEngine.shared.deductTime(amount) else {
            alertMessage = "Otillräcklig tid för överföring."
            showAlert = true
            return false
        }
        let loan = LoanRecord(
            id: UUID(), npcName: npc.name, principal: amount,
            dailyRate: npc.loanInterestRate / 30,
            startDate: Date(), dueDays: days, lentToNPC: true
        )
        activeLoans.append(loan)
        saveLoans()
        transferHistory.append((npc.name, -amount, Date()))
        return true
    }

    func collectFromNPC(_ loan: LoanRecord, npc: NPCPlayer) {
        guard let idx = activeLoans.firstIndex(where: { $0.id == loan.id }) else { return }
        let repays = Double.random(in: 0...1) < npc.reliability
        if repays {
            let repayment = loan.totalDue
            let taxed = repayment * (1 - GameState.shared.currentZone.taxRate)
            TimeEngine.shared.addTime(taxed)
            GameState.shared.recordEarning(taxed - loan.principal)
            alertMessage = "\(npc.name) betalade tillbaka!\n+\(TimeEngine.shortFormatted(taxed)) (efter skatt)\nRänta: +\(TimeEngine.shortFormatted(loan.interest))"
            transferHistory.append((npc.name, taxed, Date()))
        } else {
            alertMessage = "\(npc.name) betalade INTE tillbaka.\nDu förlorade \(TimeEngine.shortFormatted(loan.principal))."
        }
        activeLoans.remove(at: idx)
        saveLoans()
        showAlert = true
    }

    func sendMessage(_ text: String) {
        let msg = ZoneMessage(id: UUID(), senderName: GameState.shared.username, text: text, date: Date(), isFromSelf: true)
        chatMessages.append(msg)
        // Mirror via server
        Task {
            try? await ServerSync.shared.sendMessage(toUserId: "zone_broadcast", message: text)
        }
        // Simulate NPC reply occasionally
        if Double.random(in: 0...1) < 0.4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2...6)) {
                let npcs = NPCPlayer.all.filter { $0.zone == GameState.shared.currentZone.name }
                if let npc = npcs.randomElement() {
                    let replies = ["Noterat.", "Intressant.", "Hmm...", "Håller med.", "Tveksam.", "OK."]
                    let reply = ZoneMessage(id: UUID(), senderName: npc.name, text: replies.randomElement() ?? "...", date: Date(), isFromSelf: false)
                    self.chatMessages.append(reply)
                }
            }
        }
    }

    func transferToServerUser(_ user: ServerUser, amount: TimeInterval) {
        guard TimeEngine.shared.deductTime(amount) else {
            alertMessage = "Otillräcklig tid för överföring."
            showAlert = true
            return
        }
        Task {
            do {
                try await ServerSync.shared.transferTime(toUserId: user.id, amount: amount)
                DispatchQueue.main.async {
                    self.alertMessage = "Överfört \(TimeEngine.shortFormatted(amount)) till \(user.username)."
                    self.showAlert = true
                    self.transferHistory.append((user.username, -amount, Date()))
                }
            } catch {
                DispatchQueue.main.async {
                    TimeEngine.shared.addTime(amount) // refund
                    self.alertMessage = "Överföringen misslyckades. Tid återbetalad."
                    self.showAlert = true
                }
            }
        }
    }

    private func loadMockMessages() {
        let zone = GameState.shared.currentZone.name
        let mocks: [(String, String)] = [
            ("System", "Välkommen till \(zone)-chatten."),
            ("ARIA-7", "Zonmätare stabila."),
            ("System", "Vänta på andra spelare..."),
        ]
        chatMessages = mocks.enumerated().map { (i, m) in
            ZoneMessage(id: UUID(), senderName: m.0, text: m.1, date: Date().addingTimeInterval(Double(-mocks.count + i) * 60), isFromSelf: false)
        }
    }

    private func saveLoans() {
        if let data = try? JSONEncoder().encode(activeLoans) {
            UserDefaults.standard.set(data, forKey: loansKey)
        }
    }

    private func loadLoans() {
        guard let data = UserDefaults.standard.data(forKey: loansKey),
              let loaded = try? JSONDecoder().decode([LoanRecord].self, from: data) else { return }
        activeLoans = loaded
    }
}

// MARK: - Social View

struct SocialView: View {
    @ObservedObject private var social = SocialManager.shared
    @ObservedObject private var engine = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @ObservedObject private var serverSync = ServerSync.shared

    @State private var selectedTab: SocialTab = .spelare
    @State private var selectedNPC: NPCPlayer? = nil
    @State private var showLendSheet: Bool = false
    @State private var lendAmount: TimeInterval = 3600
    @State private var lendDays: Int = 7
    @State private var selectedServerUser: ServerUser? = nil
    @State private var showTransferSheet: Bool = false
    @State private var transferAmount: TimeInterval = 3600
    @State private var chatInput: String = ""
    @State private var showYatzy: Bool = false

    private let hapticLight = UIImpactFeedbackGenerator(style: .light)

    enum SocialTab: String, CaseIterable {
        case spelare  = "Spelare"
        case yatzy    = "Yatzy"
        case chat     = "Zon-chatt"
        case lan      = "Lån"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.05), Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                tabBar
                Divider().background(Color.white.opacity(0.08))

                switch selectedTab {
                case .spelare: playerSection
                case .yatzy:   yatzySection
                case .chat:    chatSection
                case .lan:     loanSection
                }
            }
        }
        .sheet(isPresented: $showLendSheet) {
            if let npc = selectedNPC {
                LendSheetView(npc: npc, lendAmount: $lendAmount, lendDays: $lendDays) {
                    _ = social.lendToNPC(npc, amount: lendAmount, days: lendDays)
                    showLendSheet = false
                }
            }
        }
        .sheet(isPresented: $showTransferSheet) {
            if let user = selectedServerUser {
                TransferSheetView(user: user, amount: $transferAmount) {
                    social.transferToServerUser(user, amount: transferAmount)
                    showTransferSheet = false
                }
            }
        }
        .alert("Transaktion", isPresented: $social.showAlert) {
            Button("OK") {}
        } message: { Text(social.alertMessage) }
        .task { await serverSync.fetchZoneMembers() }
        .fullScreenCover(isPresented: $showYatzy) {
            MultiplayerYatzyView()
        }
        .onChange(of: selectedTab) { _, _ in hapticLight.impactOccurred() }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: LTSpacing.xs) {
            Text("SOCIAL EKONOMI")
                .font(LTFont.displayTitle(22))
                .foregroundColor(.white)
                .padding(.top, 60)
            HStack(spacing: LTSpacing.xs + 2) {
                Circle()
                    .fill(serverSync.isOnline ? LTPalette.neonGreen : LTPalette.danger)
                    .frame(width: 7, height: 7)
                    .neonGlow(serverSync.isOnline ? LTPalette.neonGreen : LTPalette.danger, intensity: 0.4)
                Text(serverSync.isOnline ? "Server online" : "Offline")
                    .font(LTFont.body(11))
                    .foregroundColor(.white.opacity(0.4))
                Text("·  Zon: \(gameState.currentZone.name)")
                    .font(LTFont.body(11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(serverSync.isOnline ? "Server online" : "Offline"). Zon: \(gameState.currentZone.name)")
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, LTSpacing.md)
    }

    // MARK: Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(SocialTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(LTAnimation.springFast) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(LTFont.label(12))
                        .foregroundColor(selectedTab == tab ? .green : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LTSpacing.sm + 2)
                        .background(selectedTab == tab ? Color.green.opacity(0.1) : Color.clear)
                        .overlay(alignment: .bottom) {
                            if selectedTab == tab {
                                Rectangle()
                                    .fill(LTPalette.neonGreen)
                                    .frame(height: 2)
                                    .neonGlow(LTPalette.neonGreen, intensity: 0.5)
                                    .transition(.opacity)
                            }
                        }
                }
                .buttonStyle(LTPressEffect(scale: 0.97))
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .background(Color.black.opacity(0.3))
        .animation(LTAnimation.springFast, value: selectedTab)
    }

    // MARK: - Player Section

    private var playerSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Online players from server (same zone)
                let onlineInZone = serverSync.zoneMembers.filter { $0.zone == gameState.currentZone.name }
                if !onlineInZone.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "ONLINE I ZONEN (\(onlineInZone.count))", color: .green)
                        ForEach(onlineInZone) { user in
                            OnlineUserCard(user: user) {
                                selectedServerUser = user
                                showTransferSheet = true
                            }
                        }
                    }
                }

                // NPC players in current zone
                let zoneNPCs = social.npcsInZone(gameState.currentZone)
                if !zoneNPCs.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "NPC I \(gameState.currentZone.name.uppercased())", color: .cyan)
                        ForEach(zoneNPCs) { npc in
                            NPCCard(npc: npc) {
                                selectedNPC = npc
                                lendAmount = min(3600, engine.balance * 0.1)
                                showLendSheet = true
                            }
                        }
                    }
                }

                // Cross-zone players (locked)
                let otherPlayers = serverSync.zoneMembers.filter { $0.zone != gameState.currentZone.name }
                if !otherPlayers.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "ANDRA ZONER (LÅST)", color: .gray)
                        ForEach(otherPlayers) { user in
                            CrossZoneUserCard(user: user)
                        }
                    }
                }

                if onlineInZone.isEmpty && zoneNPCs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.2))
                        Text("Ingen i denna zon just nu.")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }

                Spacer(minLength: 80)
            }
            .padding()
        }
    }

    // MARK: - Yatzy Section

    private var yatzySection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 10) {
                    Text("🎲")
                        .font(.system(size: 60))
                    Text("YATZY DUELL")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Satsa din tid — vinnaren tar allt.")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 20)

                // Info box
                VStack(alignment: .leading, spacing: 12) {
                    yatzyInfoRow(icon: "timer", text: "Välj en insats i sekunder innan spelet startar")
                    yatzyInfoRow(icon: "trophy.fill", text: "Vinnaren får sin insats + motståndarens insats")
                    yatzyInfoRow(icon: "arrow.left.arrow.right", text: "Spela mot AI eller lokal Spelare 2 (passa telefonen)")
                    yatzyInfoRow(icon: "dice.fill", text: "Standard Yatzy — 15 kategorier, 3 kast per runda")
                    yatzyInfoRow(icon: "exclamationmark.triangle", text: "Förlustar dras direkt från ditt saldo")
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                .padding(.horizontal)

                // Balance info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DITT SALDO")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                        Text(TimeEngine.shortFormatted(engine.balance))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("MIN INSATS")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                        Text("100s – 7 200s")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Play button
                Button {
                    hapticLight.impactOccurred()
                    showYatzy = true
                } label: {
                    HStack(spacing: LTSpacing.sm) {
                        Image(systemName: "dice.fill")
                            .font(.system(size: 20))
                            .accessibilityHidden(true)
                        Text("SPELA YATZY DUELL")
                            .font(LTFont.heading(18))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LTSpacing.lg + 2)
                    .background(
                        LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: LTRadius.md))
                    .shadow(color: .orange.opacity(0.4), radius: 12)
                }
                .buttonStyle(LTPressEffect())
                .padding(.horizontal, LTSpacing.horizontal)
                .accessibilityLabel("Spela Yatzy Duell")

                Spacer(minLength: 80)
            }
            .padding(.top, 10)
        }
    }

    private func yatzyInfoRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.orange)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
        }
    }

    // MARK: - Chat Section

    private var chatSection: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(social.chatMessages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: social.chatMessages.count) { _, _ in
                    if let last = social.chatMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // Input field
            HStack(spacing: 10) {
                TextField("Skriv ett meddelande...", text: $chatInput)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button(action: sendChat) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                        .foregroundColor(chatInput.isEmpty ? .gray : LTPalette.neonGreen)
                        .padding(LTSpacing.sm + 2)
                }
                .disabled(chatInput.isEmpty)
                .buttonStyle(LTPressEffect())
                .accessibilityLabel("Skicka meddelande")
                .accessibilityHint(chatInput.isEmpty ? "Skriv ett meddelande först" : "")
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.4))
        }
    }

    private func sendChat() {
        let trimmed = chatInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        social.sendMessage(trimmed)
        chatInput = ""
    }

    // MARK: - Loan Section

    private var loanSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Info banner
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.cyan)
                    Text("Alla överföringar kostar 10% nätverksskatt utöver zonens skatt.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding()
                .background(Color.cyan.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Active loans
                if !social.activeLoans.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "AKTIVA LÅN", color: .yellow)
                        ForEach(social.activeLoans) { loan in
                            let npc = NPCPlayer.all.first(where: { $0.name == loan.npcName })
                            LoanCard(loan: loan) {
                                if let n = npc { social.collectFromNPC(loan, npc: n) }
                            }
                        }
                    }
                }

                // NPC lenders (nearby zones only)
                let nearbyNPCs = social.npcsNearby(gameState.currentZone)
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "UTLÅNING TILL NPC", color: .white)
                    ForEach(nearbyNPCs) { npc in
                        NPCCard(npc: npc) {
                            selectedNPC = npc
                            lendAmount = min(3600, engine.balance * 0.1)
                            showLendSheet = true
                        }
                    }
                }

                Spacer(minLength: 80)
            }
            .padding()
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(color.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Online User Card

struct OnlineUserCard: View {
    let user: ServerUser
    let onTransfer: () -> Void

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        HStack(spacing: LTSpacing.md) {
            Text(user.avatar.isEmpty ? "👤" : user.avatar)
                .font(.system(size: 26))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(user.username)
                    .font(LTFont.heading(14))
                    .foregroundColor(.white)
                HStack(spacing: LTSpacing.xs + 2) {
                    Circle()
                        .fill(LTPalette.neonGreen)
                        .frame(width: 6, height: 6)
                        .neonGlow(LTPalette.neonGreen, intensity: 0.4)
                    Text("Online · \(user.zone)")
                        .font(LTFont.body(10))
                        .foregroundColor(.green.opacity(0.8))
                }
                if let balance = user.timeBalance {
                    Text("~\(TimeEngine.shortFormatted(balance))")
                        .font(LTFont.body(10))
                        .foregroundColor(.white.opacity(0.4))
                        .contentTransition(.numericText())
                }
            }

            Spacer()

            Button {
                haptic.impactOccurred()
                onTransfer()
            } label: {
                HStack(spacing: LTSpacing.xs) {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 12))
                        .accessibilityHidden(true)
                    Text("DELA TID")
                        .font(LTFont.label(10))
                }
                .foregroundColor(.black)
                .padding(.horizontal, LTSpacing.sm + 2)
                .padding(.vertical, 7)
                .background(LTPalette.neonGreen)
                .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
            }
            .buttonStyle(LTPressEffect())
            .accessibilityLabel("Dela tid med \(user.username)")
        }
        .padding(LTSpacing.md)
        .ltAccentCard(color: .green, radius: LTRadius.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.username), online i \(user.zone)\(user.timeBalance != nil ? ", saldo ~\(TimeEngine.shortFormatted(user.timeBalance!))" : "")")
    }
}

// MARK: - Cross Zone User Card (locked)

struct CrossZoneUserCard: View {
    let user: ServerUser

    var body: some View {
        HStack(spacing: 12) {
            Text(user.avatar.isEmpty ? "👤" : user.avatar)
                .font(.system(size: 24))
                .opacity(0.4)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.username)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.5))
                }
                Text("Annan zon: \(user.zone)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
                Text("Zonrestriktioner gäller för överföringar.")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.4))
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(0.6)
    }
}

// MARK: - NPC Card

struct NPCCard: View {
    let npc: NPCPlayer
    let onLend: () -> Void

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        HStack(spacing: LTSpacing.md) {
            Text(npc.avatar)
                .font(.system(size: 28))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: LTSpacing.xs) {
                HStack {
                    Text(npc.name)
                        .font(LTFont.heading(14))
                        .foregroundColor(.white)
                    Spacer()
                    Text(npc.zone)
                        .font(LTFont.body(10))
                        .foregroundColor(.cyan.opacity(0.8))
                }
                Text(npc.bio)
                    .font(LTFont.body(11))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)
                HStack(spacing: LTSpacing.lg) {
                    Label(String(format: "%.0f%%/mån", npc.loanInterestRate * 100), systemImage: "percent")
                        .font(LTFont.body(10))
                        .foregroundColor(.yellow)
                    Label(String(format: "%.0f%% pålitlig", npc.reliability * 100), systemImage: "checkmark.shield")
                        .font(LTFont.body(10))
                        .foregroundColor(npc.reliability > 0.8 ? .green : .orange)
                }
                Text("Senast sedd: \(npc.lastSeen)")
                    .font(LTFont.caption(9))
                    .foregroundColor(.white.opacity(0.25))
            }

            Button("LÅN") {
                haptic.impactOccurred()
                onLend()
            }
            .font(LTFont.label(11))
            .foregroundColor(.black)
            .padding(.horizontal, LTSpacing.sm + 2)
            .padding(.vertical, LTSpacing.sm)
            .background(Color.green)
            .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
            .buttonStyle(LTPressEffect())
            .accessibilityLabel("Ge lån till \(npc.name)")
            .accessibilityHint("Ränta \(Int(npc.loanInterestRate * 100))% per månad")
        }
        .padding(LTSpacing.md)
        .ltCard(radius: LTRadius.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(npc.name) i \(npc.zone). \(npc.bio). Ränta \(Int(npc.loanInterestRate * 100))% per månad, pålitlighet \(Int(npc.reliability * 100))%")
    }
}

// MARK: - Loan Card

struct LoanCard: View {
    let loan: LoanRecord
    let onCollect: () -> Void

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: LTSpacing.xs) {
                Text(loan.npcName)
                    .font(LTFont.heading(13))
                    .foregroundColor(.white)
                Text("Utlånat: \(TimeEngine.shortFormatted(loan.principal))")
                    .font(LTFont.body(11))
                    .foregroundColor(.white.opacity(0.6))
                Text("Förfaller om \(max(0, loan.dueDays - Int(loan.daysElapsed)))d  |  Total: \(TimeEngine.shortFormatted(loan.totalDue))")
                    .font(LTFont.body(11))
                    .foregroundColor(.yellow)
                    .contentTransition(.numericText())
            }
            Spacer()
            if loan.isPastDue {
                Button("KRAV") {
                    haptic.impactOccurred()
                    onCollect()
                }
                .font(LTFont.heading(12))
                .foregroundColor(.black)
                .padding(.horizontal, LTSpacing.sm + 2)
                .padding(.vertical, LTSpacing.sm)
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
                .buttonStyle(LTPressEffect())
                .accessibilityLabel("Kräv återbetalning från \(loan.npcName)")
            }
        }
        .padding(LTSpacing.md)
        .background(loan.isPastDue ? Color.orange.opacity(0.1) : Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
        .overlay(RoundedRectangle(cornerRadius: LTRadius.sm)
            .stroke(loan.isPastDue ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(loan.npcName): utlånat \(TimeEngine.shortFormatted(loan.principal)), totalt \(TimeEngine.shortFormatted(loan.totalDue)). \(loan.isPastDue ? "Förfallet." : "Förfaller om \(max(0, loan.dueDays - Int(loan.daysElapsed))) dagar.")")
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ZoneMessage

    var body: some View {
        HStack {
            if message.isFromSelf { Spacer(minLength: 40) }

            VStack(alignment: message.isFromSelf ? .trailing : .leading, spacing: 2) {
                if !message.isFromSelf {
                    Text(message.senderName)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.7))
                }
                Text(message.text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(message.isFromSelf ? Color.green.opacity(0.25) : Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(shortTime(message.date))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
            }

            if !message.isFromSelf { Spacer(minLength: 40) }
        }
    }

    func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

#Preview {
    SocialView()
        .preferredColorScheme(.dark)
}
