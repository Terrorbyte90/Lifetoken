import SwiftUI

struct FactionView: View {
    @StateObject private var manager = FactionManager.shared
    @State private var showContributeSheet = false
    @State private var contributeAmount: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LTSpacing.xl) {
                // Header
                headerSection

                if let faction = manager.currentFaction {
                    factionDetailSection(faction)
                } else {
                    noFactionSection
                }

                if let war = manager.activeWar {
                    warSection(war)
                }
            }
            .padding(LTSpacing.lg)
        }
        .navigationTitle("Fraktion")
        .sheet(isPresented: $showContributeSheet) {
            contributeSheet
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: LTSpacing.xs) {
                Text("FRAKTION")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(LTPalette.neonGreen)
                    .tracking(3)
                if !manager.isOnline {
                    Label("Hämtad från cache", systemImage: "wifi.slash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private func factionDetailSection(_ faction: Faction) -> some View {
        VStack(alignment: .leading, spacing: LTSpacing.lg) {
            Text(faction.name)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white)

            HStack(spacing: LTSpacing.xl) {
                statColumn(label: "MEDLEMMAR", value: "\(faction.memberIDs.count)/\(Faction.maxMembers)")
                statColumn(label: "SKATTKAMMARE", value: "\(faction.treasurySeconds)s")
            }

            Button {
                showContributeSheet = true
            } label: {
                Text("Bidra till skattkammaren")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(LTSpacing.md)
                    .background(LTPalette.neonGreen)
                    .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
            }
        }
    }

    private var noFactionSection: some View {
        VStack(alignment: .leading, spacing: LTSpacing.md) {
            Text("Du är inte med i någon fraktion.")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            Button {
                // Requires backend
            } label: {
                Text(manager.isOnline ? "Skapa fraktion" : "Kräver anslutning")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(manager.isOnline ? .black : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(LTSpacing.md)
                    .background(manager.isOnline ? LTPalette.neonGreen : Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
            }
            .disabled(!manager.isOnline)
        }
    }

    private func warSection(_ war: FactionWar) -> some View {
        VStack(alignment: .leading, spacing: LTSpacing.md) {
            Text("AKTIVT KRIG")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(LTPalette.danger)
                .tracking(3)

            HStack {
                let f1Score = war.scores[war.faction1ID] ?? 0
                let f2Score = war.scores[war.faction2ID] ?? 0
                Text("\(war.faction1ID): \(f1Score)")
                Spacer()
                Text("vs")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(war.faction2ID): \(f2Score)")
            }
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(.white)
        }
        .padding(LTSpacing.md)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
    }

    private var contributeSheet: some View {
        VStack(spacing: LTSpacing.xl) {
            Text("Bidra till skattkammaren")
                .font(.system(size: 18, weight: .bold))

            TextField("Antal sekunder", text: $contributeAmount)
                .keyboardType(.numberPad)
                .font(.system(size: 22, design: .monospaced))
                .multilineTextAlignment(.center)

            Button("Bidra") {
                if let seconds = Int(contributeAmount), seconds > 0 {
                    manager.contribute(seconds: seconds, to: manager.currentFaction?.id ?? "")
                    showContributeSheet = false
                    contributeAmount = ""
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(LTPalette.neonGreen)
        }
        .padding(LTSpacing.xl)
        .presentationDetents([.medium])
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: LTSpacing.xs) {
            Text(label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)
            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)
        }
    }
}
