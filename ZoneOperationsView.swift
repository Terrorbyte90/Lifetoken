import SwiftUI

struct ZoneOperationsView: View {
    @ObservedObject private var gameState = GameState.shared
    @ObservedObject private var reputation = ZoneReputationManager.shared
    @ObservedObject private var governance = GovernanceManager.shared
    @ObservedObject private var garden = GardenManager.shared
    @ObservedObject private var engine = TimeEngine.shared

    @State private var selectedRule: GovernanceRuleType = .marketTaxCut
    @State private var governanceMessage = ""
    @State private var showGovernanceMessage = false
    @State private var showPlantPicker = false
    @State private var selectedPlotID: String?
    @State private var selectedCrop: GardenCropType = GardenCropType.all.first!

    private var zoneName: String { gameState.currentZone.name }
    private var repValue: Int { reputation.reputation(for: zoneName) }
    private var repProgress: Double { Double(repValue) / 50.0 }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.03, green: 0.05, blue: 0.09), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        headerCard
                        zoneActionsCard
                        governanceCard
                        gardenCard
                    }
                    .padding(.horizontal, LTSpacing.horizontal)
                    .padding(.top, 60)
                    .padding(.bottom, LTSpacing.scrollBottom)
                }
            }
            .navigationTitle("ZONCENTRALEN")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Zonstyre", isPresented: $showGovernanceMessage) {
            Button("OK") {}
        } message: {
            Text(governanceMessage)
        }
        .sheet(isPresented: $showPlantPicker) {
            plantPickerSheet
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(zoneName.uppercased())
                        .font(LTFont.heading(16))
                        .foregroundColor(gameState.currentZone.color)
                    Text("Rykte: \(repValue)/50")
                        .font(LTFont.body(11))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Text(reputation.npcTone(for: zoneName))
                    .font(LTFont.caption(10))
                    .foregroundColor(repValue >= 25 ? .green : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }
            ProgressView(value: repProgress)
                .tint(repValue >= 25 ? LTPalette.neonGreen : LTPalette.warning)
            Text("Prisfaktor i zon: x\(String(format: "%.2f", reputation.priceMultiplier(for: zoneName)))")
                .font(LTFont.caption(10))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(14)
        .ltAccentCard(color: gameState.currentZone.color)
    }

    private var zoneActionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AKTIVITETER")
                .font(LTFont.label(10))
                .foregroundColor(.white.opacity(0.35))
                .tracking(2)

            HStack(spacing: 8) {
                NavigationLink {
                    ZoneVisual()
                } label: {
                    actionChip(icon: "map.fill", text: "Zonkarta", color: .cyan)
                }
                NavigationLink {
                    BankView()
                } label: {
                    actionChip(icon: "building.columns.fill", text: "Bank", color: .green)
                }
            }
            HStack(spacing: 8) {
                NavigationLink {
                    FactionView()
                } label: {
                    actionChip(icon: "person.3.fill", text: "Fraktion", color: .purple)
                }
                NavigationLink {
                    NightMarketView()
                } label: {
                    actionChip(icon: "moon.stars.fill", text: "Nattmarknad", color: .orange)
                }
            }
        }
        .padding(14)
        .ltCard(radius: LTRadius.md)
    }

    private func actionChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
            Text(text)
                .font(LTFont.body(11))
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    private var governanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SOCIALT MAKTSPEL")
                    .font(LTFont.label(10))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(2)
                Spacer()
                if let rule = governance.activeRule, Date() < rule.expiresAt {
                    Text("AKTIV REGEL")
                        .font(LTFont.caption(9))
                        .foregroundColor(.yellow)
                }
            }

            if let rule = governance.activeRule, Date() < rule.expiresAt {
                VStack(alignment: .leading, spacing: 5) {
                    Text(rule.type.title)
                        .font(LTFont.heading(12))
                        .foregroundColor(.yellow)
                    Text(rule.type.description)
                        .font(LTFont.body(10))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Gäller till \(rule.expiresAt.formatted(date: .omitted, time: .shortened))")
                        .font(LTFont.caption(9))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(10)
                .background(Color.yellow.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let proposal = governance.activeProposal, Date() < proposal.endsAt {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pågående omröstning: \(proposal.type.title)")
                        .font(LTFont.heading(11))
                        .foregroundColor(.white)
                    Text(proposal.type.description)
                        .font(LTFont.body(10))
                        .foregroundColor(.white.opacity(0.65))
                    HStack {
                        Text("JA \(proposal.yesVotes.count)")
                            .font(LTFont.body(10))
                            .foregroundColor(.green)
                        Text("NEJ \(proposal.noVotes.count)")
                            .font(LTFont.body(10))
                            .foregroundColor(.red)
                        Spacer()
                        Button("Rösta JA") {
                            governance.vote(yes: true, by: gameState.username)
                        }
                        .font(LTFont.body(10))
                        Button("Rösta NEJ") {
                            governance.vote(yes: false, by: gameState.username)
                        }
                        .font(LTFont.body(10))
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if governance.canPropose(from: gameState.currentZone) {
                        Picker("Regel", selection: $selectedRule) {
                            ForEach(GovernanceRuleType.allCases) { rule in
                                Text(rule.title).tag(rule)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                        Button("Lägg förslag") {
                            let success = governance.propose(rule: selectedRule, by: gameState.username)
                            governanceMessage = success ? "Förslag publicerat." : "Det finns redan ett aktivt förslag."
                            showGovernanceMessage = true
                        }
                        .font(LTFont.heading(11))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(LTPalette.neonGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Text("Endast toppspelare i högsta zonerna kan lägga regel-förslag.")
                            .font(LTFont.body(10))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
            }
        }
        .padding(14)
        .ltCard(radius: LTRadius.md)
        .onAppear { governance.cleanupExpired() }
    }

    private var gardenCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TRÄDGÅRD")
                .font(LTFont.label(10))
                .foregroundColor(.white.opacity(0.35))
                .tracking(2)

            if !garden.isUnlocked(for: gameState.currentZone) {
                Text("Låses upp från zon 9. Fortsätt klättra.")
                    .font(LTFont.body(10))
                    .foregroundColor(.white.opacity(0.55))
            } else {
                ForEach(garden.plots) { plot in
                    gardenPlotRow(plot)
                }
            }
        }
        .padding(14)
        .ltCard(radius: LTRadius.md)
    }

    private func gardenPlotRow(_ plot: GardenPlot) -> some View {
        let crop = garden.crop(for: plot)
        let canHarvest = garden.canHarvest(plot: plot)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(plot.id.replacingOccurrences(of: "_", with: " ").uppercased())
                    .font(LTFont.caption(9))
                    .foregroundColor(.white.opacity(0.4))
                if let crop {
                    Text(crop.name)
                        .font(LTFont.heading(11))
                        .foregroundColor(.white)
                } else {
                    Text("Tom jord")
                        .font(LTFont.body(10))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Spacer()
            if crop == nil {
                Button("Plantera") {
                    selectedPlotID = plot.id
                    showPlantPicker = true
                }
                .font(LTFont.body(10))
            } else if canHarvest {
                Button("Skörda") {
                    let reward = garden.harvest(plotID: plot.id)
                    if reward > 0 {
                        TransactionLedger.shared.record(label: "Trädgård — skörd", amount: reward)
                    }
                }
                .font(LTFont.body(10))
                .foregroundColor(.green)
            } else {
                Text("Växer...")
                    .font(LTFont.body(10))
                    .foregroundColor(.orange)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var plantPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(GardenCropType.all.filter { $0.minZoneIndex <= gameState.currentZone.index }) { crop in
                    Button {
                        if let selectedPlotID {
                            _ = garden.plant(crop: crop, plotID: selectedPlotID)
                        }
                        showPlantPicker = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(crop.name)
                                Text("Växer: \(Int(crop.growthSeconds / 3600))h")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("+\(TimeEngine.shortFormatted(crop.rewardSeconds))")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("Plantera")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") { showPlantPicker = false }
                }
            }
        }
    }
}

#Preview {
    ZoneOperationsView()
        .preferredColorScheme(.dark)
}
