import SwiftUI

// MARK: - Account Settings View
// Provides account management including data deletion (App Store guideline 5.1.1(v))

struct AccountSettingsView: View {
    @ObservedObject private var gameState = GameState.shared
    @ObservedObject private var server = ServerSync.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String? = nil
    @State private var showDeleteError = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        // Profile info
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader("KONTO")

                            infoRow(icon: "person.fill", label: "Spelarnamn", value: gameState.username)
                            infoRow(icon: "wifi", label: "Serverstatus", value: server.isOnline ? "Ansluten" : "Offline")
                            if let lastSync = server.lastSyncDate {
                                infoRow(icon: "arrow.triangle.2.circlepath", label: "Senaste sync",
                                        value: lastSync.formatted(.relative(presentation: .named)))
                            }
                        }

                        Divider().background(Color.white.opacity(0.08))

                        // Privacy & data
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader("INTEGRITET & DATA")

                            Text("LifeToken lagrar ditt spelarnamn, din tidssaldo och zon på en privat server. Hälsodata bearbetas lokalt på din enhet och delas aldrig med tredje part.")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                                .lineSpacing(4)

                            Text("Hälsodata: steg, sömn, träning, kalorier, stående, mindfulness och HRV används enbart för att beräkna din dagliga tidsinkomst i spelet.")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                                .lineSpacing(4)
                        }

                        Divider().background(Color.white.opacity(0.08))

                        // Delete account
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("RADERA KONTO")

                            Text("Permanent radering av ditt konto och all tillhörande data från servern. Denna åtgärd kan inte ångras.")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                                .lineSpacing(4)

                            Button {
                                showDeleteConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                    Text("RADERA MITT KONTO")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.3), lineWidth: 1))
                            }
                            .disabled(isDeleting)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Inställningar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") { dismiss() }
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
        }
        .preferredColorScheme(.dark)
        .confirmationDialog(
            "Radera konto permanent?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Radera konto", role: .destructive) {
                Task { await performDeletion() }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("All din data — tidssaldo, zon, historik — raderas permanent från servern. Lokal hälsodata påverkas inte.")
        }
        .alert("Fel vid radering", isPresented: $showDeleteError) {
            Button("OK") {}
        } message: {
            Text(deleteError ?? "Okänt fel.")
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundColor(.white.opacity(0.3))
            .tracking(2)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.3))
                .frame(width: 16)
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func performDeletion() async {
        isDeleting = true
        do {
            try await ServerSync.shared.deleteAccount()
            // Clear all local data
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: "username")
            defaults.removeObject(forKey: "hasLaunched")
            defaults.removeObject(forKey: "loginStreak")
            defaults.removeObject(forKey: "lastLoginDate")
            defaults.removeObject(forKey: "hk_last_awarded_date")
            defaults.set(false, forKey: "hasLaunched")
            // Reset game state
            GameState.shared.username = ""
            dismiss()
        } catch {
            deleteError = error.localizedDescription
            showDeleteError = true
        }
        isDeleting = false
    }
}
