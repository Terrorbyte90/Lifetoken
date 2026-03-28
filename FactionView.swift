import SwiftUI

struct FactionView: View {
    @StateObject private var manager = FactionManager.shared
    @ObservedObject private var server = ServerSync.shared
    @ObservedObject private var engine = TimeEngine.shared

    @State private var newFactionName = ""
    @State private var distributeTarget = ""
    @State private var contributeAmount: Double = 1800
    @State private var distributeAmount: Double = 1800

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerSection

                if let faction = manager.currentFaction {
                    factionOverviewCard(faction)
                    factionBankCard(faction)
                    memberManagementCard(faction)
                    joinRequestsCard(faction)
                    factionLedgerCard(faction)
                } else {
                    createFactionCard
                    discoverFactionsCard
                }
            }
            .padding(.horizontal, LTSpacing.horizontal)
            .padding(.top, 16)
            .padding(.bottom, LTSpacing.scrollBottom)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.03, blue: 0.08), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("FRAKTIONER")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            manager.claimPendingPayoutsIfAny()
            contributeAmount = min(contributeAmount, max(600, min(21600, engine.balance)))
            if let faction = manager.currentFaction {
                distributeAmount = min(distributeAmount, max(600, min(21600, Double(faction.treasurySeconds))))
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Hierarki: Leader / Officer / Member")
                .font(LTFont.body(10))
                .foregroundColor(.white.opacity(0.55))
            Text("Leader + Officer kan godkänna ansökningar och dela ut från fraktionsbanken.")
                .font(LTFont.body(10))
                .foregroundColor(.white.opacity(0.45))
            Text(server.isOnline ? "Server: ansluten" : "Server: offline (lokal fallback aktiv)")
                .font(LTFont.caption(9))
                .foregroundColor(server.isOnline ? .green : .orange)
            if !manager.feedbackMessage.isEmpty {
                Text(manager.feedbackMessage)
                    .font(LTFont.caption(9))
                    .foregroundColor(.orange)
            }
            LTInfoCallout(
                title: "Rollöversikt",
                message: "Alla kan sätta in tid i fraktionsbanken. Leader och Officer kan dessutom godkänna ansökningar och dela ut tid.",
                icon: "person.3.sequence.fill",
                tint: .purple
            )
        }
        .padding(12)
        .ltCard(radius: LTRadius.sm)
    }

    private var createFactionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SKAPA FRAKTION")
                .font(LTFont.label(10))
                .foregroundColor(.white.opacity(0.35))
                .tracking(2)
            Text("Namn: 3-28 tecken.")
                .font(LTFont.caption(9))
                .foregroundColor(.white.opacity(0.5))
            TextField("Namn", text: $newFactionName)
                .textInputAutocapitalization(.words)
                .padding(10)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button("Skapa") {
                manager.createFaction(name: newFactionName)
                newFactionName = ""
            }
            .font(LTFont.heading(11))
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(LTPalette.neonGreen)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .ltCard(radius: LTRadius.md)
    }

    private var discoverFactionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GÅ MED I FRAKTION")
                .font(LTFont.label(10))
                .foregroundColor(.white.opacity(0.35))
                .tracking(2)
            if manager.factions.isEmpty {
                LTEmptyStateCard(
                    icon: "person.3.sequence",
                    title: "Inga fraktioner ännu",
                    message: "Skapa den första fraktionen och bygg upp ett gemensamt konto tillsammans.",
                    tint: .purple
                )
            } else {
                ForEach(manager.factions) { faction in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(faction.name)
                                .font(LTFont.heading(11))
                                .foregroundColor(.white)
                            Text("\(faction.members.count)/\(Faction.maxMembers) medlemmar")
                                .font(LTFont.caption(9))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        Spacer()
                        Button("Ansök") {
                            manager.requestJoin(factionID: faction.id, username: GameState.shared.username)
                        }
                        .font(LTFont.body(10))
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(12)
        .ltCard(radius: LTRadius.md)
    }

    private func factionOverviewCard(_ faction: Faction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(faction.name)
                    .font(LTFont.heading(18))
                    .foregroundColor(.white)
                Spacer()
                if let role = manager.currentMember?.role {
                    Text(role.label.uppercased())
                        .font(LTFont.caption(9))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.13))
                        .clipShape(Capsule())
                }
            }
            Text("\(faction.members.count)/\(Faction.maxMembers) medlemmar")
                .font(LTFont.body(10))
                .foregroundColor(.white.opacity(0.55))
            Button("Lämna fraktion") {
                manager.leaveCurrentFaction()
            }
            .font(LTFont.body(10))
            .foregroundColor(.red)
        }
        .padding(12)
        .ltAccentCard(color: .purple)
    }

    private func factionBankCard(_ faction: Faction) -> some View {
        let contributeMax = max(600, min(21600, engine.balance))
        let distributeMax = max(600, min(21600, Double(faction.treasurySeconds)))
        let canContribute = engine.balance >= 600
        let canDistribute = manager.canDistributeFunds && faction.treasurySeconds >= 600

        return VStack(alignment: .leading, spacing: 9) {
            Text("FRAKTIONSBANK")
                .font(LTFont.label(10))
                .foregroundColor(.white.opacity(0.35))
                .tracking(2)
            Text("Saldo: \(TimeEngine.shortFormatted(Double(faction.treasurySeconds)))")
                .font(LTFont.value(20))
                .foregroundColor(.yellow)
            Text("Alla medlemmar kan sätta in tid. Endast Leader/Officer kan dela ut tid till medlemmar.")
                .font(LTFont.body(10))
                .foregroundColor(.white.opacity(0.52))
            LTInfoCallout(
                title: "Fraktionsbank",
                message: "Alla överföringar loggas i bankhistoriken. Dela ut tid först när fraktionen har buffert för drift.",
                icon: "building.columns.fill",
                tint: .yellow
            )

            HStack {
                Text("Insättning: \(TimeEngine.shortFormatted(contributeAmount))")
                    .font(LTFont.body(10))
                Spacer()
            }
            Slider(value: $contributeAmount, in: 600...contributeMax, step: 600)
                .tint(.green)
            Button("Sätt in tid i fraktionsbanken") {
                manager.contribute(seconds: Int(min(contributeAmount, engine.balance)), to: faction.id)
            }
            .font(LTFont.body(10))
            .foregroundColor(canContribute ? .black : .white.opacity(0.4))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(canContribute ? .green : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(!canContribute)

            if manager.canDistributeFunds {
                Divider().background(Color.white.opacity(0.1))
                Text("Utdelning (Leader/Officer)")
                    .font(LTFont.caption(9))
                    .foregroundColor(.white.opacity(0.5))
                TextField("Mottagare (användarnamn)", text: $distributeTarget)
                    .textInputAutocapitalization(.never)
                    .padding(9)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                HStack {
                    Text("Belopp: \(TimeEngine.shortFormatted(distributeAmount))")
                        .font(LTFont.body(10))
                    Spacer()
                }
                Slider(value: $distributeAmount, in: 600...distributeMax, step: 600)
                    .tint(.orange)
                Button("Dela ut tid") {
                    manager.distribute(seconds: Int(min(distributeAmount, Double(faction.treasurySeconds))), to: distributeTarget)
                    distributeTarget = ""
                }
                .font(LTFont.body(10))
                .foregroundColor(canDistribute ? .black : .white.opacity(0.4))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(canDistribute ? .orange : Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(!canDistribute)
            }
        }
        .padding(12)
        .ltCard(radius: LTRadius.md)
    }

    private func memberManagementCard(_ faction: Faction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MEDLEMMAR")
                .font(LTFont.label(10))
                .foregroundColor(.white.opacity(0.35))
                .tracking(2)
            ForEach(faction.members) { member in
                HStack {
                    Text(member.username)
                        .font(LTFont.body(11))
                        .foregroundColor(.white)
                    Spacer()
                    Text(member.role.label)
                        .font(LTFont.caption(9))
                        .foregroundColor(.white.opacity(0.6))
                    if manager.currentMember?.role == .leader && member.username != GameState.shared.username {
                        Menu("Roll") {
                            ForEach(FactionRole.allCases) { role in
                                Button(role.label) {
                                    manager.setRole(username: member.username, role: role)
                                }
                            }
                        }
                        .font(.caption)
                    }
                }
                .padding(9)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .ltCard(radius: LTRadius.md)
    }

    private func joinRequestsCard(_ faction: Faction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ANSÖKNINGAR")
                .font(LTFont.label(10))
                .foregroundColor(.white.opacity(0.35))
                .tracking(2)
            if faction.joinRequests.isEmpty {
                LTEmptyStateCard(
                    icon: "person.crop.circle.badge.questionmark",
                    title: "Inga väntande ansökningar",
                    message: "När spelare ansöker om medlemskap dyker de upp här.",
                    tint: .cyan
                )
            } else {
                ForEach(faction.joinRequests, id: \.self) { username in
                    HStack {
                        Text(username)
                            .font(LTFont.body(11))
                            .foregroundColor(.white)
                        Spacer()
                        if manager.canManageMembers {
                            Button("Godkänn") { manager.approveJoin(username: username) }
                                .font(.caption)
                                .foregroundColor(.green)
                            Button("Avslå") { manager.rejectJoin(username: username) }
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(12)
        .ltCard(radius: LTRadius.md)
    }

    private func factionLedgerCard(_ faction: Faction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BANKHISTORIK")
                .font(LTFont.label(10))
                .foregroundColor(.white.opacity(0.35))
                .tracking(2)
            if faction.ledger.isEmpty {
                LTEmptyStateCard(
                    icon: "list.clipboard",
                    title: "Ingen aktivitet ännu",
                    message: "Insättningar och utdelningar i fraktionsbanken visas här.",
                    tint: .white
                )
            } else {
                ForEach(faction.ledger.prefix(10)) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.label)
                                .font(LTFont.body(10))
                                .foregroundColor(.white)
                            Text(item.actor)
                                .font(LTFont.caption(9))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        Spacer()
                        Text((item.amount >= 0 ? "+" : "") + TimeEngine.shortFormatted(Double(abs(item.amount))))
                            .font(LTFont.body(10))
                            .foregroundColor(item.amount >= 0 ? .green : .orange)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(12)
        .ltCard(radius: LTRadius.md)
    }
}

#Preview {
    NavigationStack {
        FactionView()
            .preferredColorScheme(.dark)
    }
}
