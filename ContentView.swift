import SwiftUI


struct DashboardView: View {
    @ObservedObject private var incomeManager = IncomeManager.shared
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasLaunched")
    @State private var selectedTimeZone = TimeZone.current.identifier
    @State private var username = ""
    @State private var timeRemaining: TimeInterval = 82800
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var currentZone: ZoneProfile? = nil
    @State private var currentQuoteIndex: Int = 0
    @State private var quoteTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var showTimeMarket = false
    @State private var earnedToday: TimeInterval = 0
    @State private var payoutTime: String = ""
    @State private var showZoneMap = false
    let quotes = [
        "⏳ Du förlorar 1 sekund varje sekund. Tjäna tillbaka dem genom att röra på dig.",
        "👟 Varje 7 steg ger dig 1 sekund livstid. Gå för att fortsätta leva.",
        "💡 Din tid är din valuta. Använd den klokt.",
        "🔥 Zoner låser upp fördelar – ju längre du överlever, desto starkare blir du.",
        "🛒 Boosts kan dubbla din inkomst. Använd dem rätt.",
        "📅 Dagens intjänade sekunder räknas varje natt klockan 00:00.",
        "🏃‍♂️ 7000 steg? Det är 1000 extra sekunder – varje dag räknas."
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                Text("LIFETOKEN")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.top, 80)

                Text(timeFormatted(seconds: timeRemaining))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .onReceive(timer) { _ in
                        updateTimeRemaining()
                    }

                Text("Användare: \(UserDefaults.standard.string(forKey: "username") ?? "–")")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Zon: \(currentZone?.name ?? "-")")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))

                if !BoostManager.shared.getActiveBoosts().isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aktiva boosts:")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.green)

                        ForEach(BoostManager.shared.getActiveBoosts(), id: \.self) { boost in
                            Text("• \(boost)")
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                }


                Spacer()
                Spacer()

                // Earnings & payout section
                let boostedEarnings = BoostManager.shared.calculatedEarnings(baseSeconds: earnedToday)
                Text("💰 Lön hittills: \(timeFormatted(seconds: boostedEarnings))")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)

                Text("⏳ Tid till lön: \(payoutTime)")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 16) {
                    Button(action: {
                        showTimeMarket = true
                    }) {
                        Text("🛒 Butik")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }

                    Button(action: {
                        showZoneMap = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "map.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)

                            Text("Zoner")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    }

                    // Återställning av tiden
                    Button(action: {
                        UserDefaults.standard.set(Date(), forKey: "absoluteStartTimeUTC")
                    }) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.green)
                    }
                }

                Text(quotes[currentQuoteIndex])
                    .font(.footnote)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                    .multilineTextAlignment(.center)
                    .onReceive(quoteTimer) { _ in
                        currentQuoteIndex = (currentQuoteIndex + 1) % quotes.count
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .ignoresSafeArea()
        }
        .alert("Dagens Lön", isPresented: $incomeManager.showDailySummary) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(incomeManager.summaryMessage)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(showOnboarding: $showOnboarding)
        }
        .sheet(isPresented: $showTimeMarket) {
            TimeMarketView(timeRemaining: $timeRemaining, currentZone: currentZone)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showZoneMap) {
            ZoneVisual()
                .presentationDetents([.large])
        }
    }

    private func updateTimeRemaining() {
        guard let startTime = UserDefaults.standard.object(forKey: "absoluteStartTimeUTC") as? Date else { return }
        let secondsElapsed = Date().timeIntervalSince(startTime)
        let startLife: TimeInterval = 82800
        timeRemaining = max(0, startLife - secondsElapsed)
        ZoneManager.shared.evaluateZoneChange(currentTime: timeRemaining)
        currentZone = ZoneManager.shared.currentZone(forTime: timeRemaining)

        // Update earnedToday with real-time incomeManager value
        earnedToday = incomeManager.earnedSeconds

        // Calculate time until next payout (12:00 noon)
        let now = Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.hour = 12
        components.minute = 0
        components.second = 0
        let noonToday = Calendar.current.date(from: components)!
        let targetTime = now < noonToday ? noonToday : Calendar.current.date(byAdding: .day, value: 1, to: noonToday)!
        let remaining = Int(targetTime.timeIntervalSince(now))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        payoutTime = "\(hours)h \(minutes)m"
    }

    private func timeFormatted(seconds: TimeInterval) -> String {
        let hrs = Int(seconds) / 3600
        let min = (Int(seconds) % 3600) / 60
        let sec = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", hrs, min, sec)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var username: String = ""
    @State private var selectedZone: String = TimeZone.current.identifier

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Användarnamn")) {
                    TextField("Ange namn", text: $username)
                }

                Section(header: Text("Välj tidszon")) {
                    Picker("Tidszon", selection: $selectedZone) {
                        ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { zone in
                            Text(zone).tag(zone)
                        }
                    }
                }

                Section {
                    Button("Starta Livet") {
                        UserDefaults.standard.set(true, forKey: "hasLaunched")
                        UserDefaults.standard.set(username, forKey: "username")
                        UserDefaults.standard.set(selectedZone, forKey: "userTimeZone")
                        UserDefaults.standard.set(Date(), forKey: "absoluteStartTimeUTC")
                        showOnboarding = false
                    }
                    .disabled(username.isEmpty)
                }
            }
            .navigationTitle("Välj start")
        }
    }
}
