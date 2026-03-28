import SwiftUI

// MARK: - Admin Panel View
// Only accessible for user "Ted". Shows all players with their time/zone,
// and allows setting balance or zone for any player.

struct AdminPanelView: View {
    @StateObject private var vm = AdminPanelVM()
    @ObservedObject private var zones = ZoneManager.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                    Text("ADMIN PANEL")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                    Spacer()
                    Text("\(vm.users.count) spelare")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Button {
                        Task { await vm.loadUsers() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.08))

                LTInfoCallout(
                    title: "Adminläge",
                    message: "Ändringar här slår direkt på användarens konto. Kontrollera alltid värden innan du skickar.",
                    icon: "shield.lefthalf.filled.badge.checkmark",
                    tint: .red
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Divider().background(Color.red.opacity(0.3))

                if vm.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.green)
                    Spacer()
                } else if let err = vm.errorMessage {
                    Spacer()
                    LTEmptyStateCard(
                        icon: "exclamationmark.triangle.fill",
                        title: "Kunde inte läsa admin-data",
                        message: err,
                        tint: .red
                    )
                    .padding(.horizontal, 12)
                    Spacer()
                } else if vm.users.isEmpty {
                    Spacer()
                    LTEmptyStateCard(
                        icon: "person.3",
                        title: "Inga spelare hittades",
                        message: "Försök ladda om när fler användare har synkats mot servern.",
                        tint: .white
                    )
                    .padding(.horizontal, 12)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(vm.users) { user in
                                AdminUserRow(user: user, vm: vm)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
            }
        }
        .task { await vm.loadUsers() }
        .alert("Fel", isPresented: $vm.showError) {
            Button("OK") {}
        } message: { Text(vm.errorMessage ?? "") }
    }
}

// MARK: - Admin User Row

struct AdminUserRow: View {
    let user: AdminUser
    @ObservedObject var vm: AdminPanelVM

    @State private var expanded = false
    @State private var newBalanceText = ""
    @State private var newZone = ""
    @State private var giveTimeText = ""

    private let allZones: [String] = [
        "Askan", "Spillrorna", "Betongen", "Dimman", "Halvmörkret",
        "Gränslandet", "Stigarnas Dal", "Uppgången", "Tröskeln",
        "Klarljuset", "Vakttornet", "Valvet", "Kronan", "Evigheten"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed row
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    expanded.toggle()
                    if expanded {
                        newBalanceText = String(Int(user.timeBalance ?? 0))
                        newZone = user.zone
                        giveTimeText = ""
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(user.avatar ?? "⏱")
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.username)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text(user.zone)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TimeEngine.shortFormatted(user.timeBalance ?? 0))
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundColor(balanceColor(user.timeBalance ?? 0))
                        if let streak = user.loginStreak, streak > 0 {
                            Text("streak \(streak)d")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.orange.opacity(0.7))
                        }
                    }

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded editor
            if expanded {
                VStack(spacing: 12) {
                    Divider().background(Color.white.opacity(0.1))

                    // Set balance
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SÄTT BALANS (sekunder)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                        HStack(spacing: 8) {
                            TextField("sekunder", text: $newBalanceText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            // Quick presets
                            ForEach([("24h", 86400.0), ("48h", 172800.0), ("7d", 604800.0)], id: \.0) { label, val in
                                Button(label) {
                                    newBalanceText = String(Int(val))
                                }
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            Button("OK") {
                                if let bal = Double(newBalanceText) {
                                    Task { await vm.setBalance(userId: user.id, balance: bal) }
                                    expanded = false
                                }
                            }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    // Give/take time
                    VStack(alignment: .leading, spacing: 6) {
                        Text("GE/TA TID (sekunder, negativ för att ta)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                        HStack(spacing: 8) {
                            TextField("+3600 eller -3600", text: $giveTimeText)
                                .keyboardType(.numbersAndPunctuation)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Button("GE") {
                                if let amt = Double(giveTimeText) {
                                    Task { await vm.giveTime(userId: user.id, amount: amt) }
                                    expanded = false
                                }
                            }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    // Set zone
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SÄTT ZON")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(allZones, id: \.self) { z in
                                    Button(z) {
                                        Task { await vm.setZone(userId: user.id, zone: z) }
                                        expanded = false
                                    }
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(z == user.zone ? .black : .white.opacity(0.7))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(z == user.zone ? Color.green : Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                    }

                    // Stats
                    HStack(spacing: 16) {
                        if let earned = user.totalEarned {
                            statLabel("Totalt tjänat", TimeEngine.shortFormatted(earned))
                        }
                        if let joined = user.createdAt {
                            statLabel("Gick med", String(joined.prefix(10)))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(expanded ? 0.3 : 0.08), lineWidth: 1)
                )
        )
    }

    private func balanceColor(_ balance: Double) -> Color {
        if balance < 3600 { return .red }
        if balance < 86400 { return .orange }
        return .green
    }

    private func statLabel(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Admin Panel ViewModel

@MainActor
class AdminPanelVM: ObservableObject {
    @Published var users: [AdminUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var showError = false

    func loadUsers() async {
        isLoading = true
        errorMessage = nil
        do {
            users = try await ServerSync.shared.adminFetchUsers()
        } catch {
            errorMessage = "Kunde inte ladda spelare: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }

    func setBalance(userId: String, balance: Double) async {
        do {
            try await ServerSync.shared.adminSetBalance(userId: userId, timeBalance: balance)
            await loadUsers()
        } catch {
            errorMessage = "Kunde inte sätta balans: \(error.localizedDescription)"
            showError = true
        }
    }

    func setZone(userId: String, zone: String) async {
        do {
            try await ServerSync.shared.adminSetZone(userId: userId, zone: zone)
            await loadUsers()
        } catch {
            errorMessage = "Kunde inte sätta zon: \(error.localizedDescription)"
            showError = true
        }
    }

    func giveTime(userId: String, amount: Double) async {
        do {
            try await ServerSync.shared.adminGiveTime(userId: userId, amount: amount)
            await loadUsers()
        } catch {
            errorMessage = "Kunde inte ge tid: \(error.localizedDescription)"
            showError = true
        }
    }
}
