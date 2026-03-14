import SwiftUI

// MARK: - Timed Out Overlay
// Visas när spelarens tid når 0 — inspirerad av filmens dramatiska dödsögonblick

struct TimedOutOverlay: View {
    @ObservedObject private var engine = TimeEngine.shared
    @State private var animateIn = false
    @State private var textOpacity = 0.0
    @State private var showRestart = false

    var body: some View {
        ZStack {
            // Dramatisk röd bakgrund
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Glödande 00:00:00
                VStack(spacing: 16) {
                    Text("00:00:00")
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                        .shadow(color: .red.opacity(0.8), radius: 20, x: 0, y: 0)
                        .shadow(color: .red.opacity(0.4), radius: 40, x: 0, y: 0)
                        .opacity(animateIn ? 1 : 0)
                        .scaleEffect(animateIn ? 1 : 0.7)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: animateIn)

                    // Arm-linje som slocknar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.red.opacity(0.05), Color.red.opacity(0.3), Color.red.opacity(0.05)]),
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(height: 4)
                        .padding(.horizontal, 60)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeIn.delay(0.8), value: animateIn)
                }

                VStack(spacing: 12) {
                    Text("TIMED OUT")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .opacity(textOpacity)
                        .animation(.easeIn(duration: 0.5).delay(0.7), value: textOpacity)

                    Text("Din tid tog slut.")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .opacity(textOpacity)
                        .animation(.easeIn(duration: 0.5).delay(0.9), value: textOpacity)
                }

                // Filmcitat
                VStack(spacing: 8) {
                    Text("\"Ingen slösar med sin tid")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .italic()
                    Text("som inte har tillräckligt av den.\"")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .italic()
                    Text("— In Time, 2011")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.15))
                        .padding(.top, 4)
                }
                .opacity(textOpacity)
                .animation(.easeIn(duration: 0.5).delay(1.2), value: textOpacity)
                .padding(.horizontal)

                Spacer()

                // Starta om
                if showRestart {
                    VStack(spacing: 16) {
                        Divider().background(Color.white.opacity(0.1)).padding(.horizontal)

                        Text("Börja om med 24 timmar")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))

                        Button {
                            engine.addTime(86400) // Ge 24h och starta om
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("STARTA OM LIVET")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(14)
                        }
                        .padding(.horizontal)

                        Text("Du börjar i Duskline med 24 timmar.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 40)
            }
        }
        .onAppear {
            animateIn = true
            textOpacity = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeIn(duration: 0.4)) {
                    showRestart = true
                }
            }
        }
    }
}

// MARK: - Timekeeper Event System
// Slumpmässiga händelser där "Tidsvakter" kontrollerar din tid — inspirerat av filmens Timekeepers

class TimekeeperEventManager: ObservableObject {
    static let shared = TimekeeperEventManager()

    @Published var showEvent = false
    @Published var currentEvent: TimekeeperEvent? = nil

    private var eventTimer: Timer?

    private init() {
        scheduleNextEvent()
    }

    private func scheduleNextEvent() {
        // Slumpmässig tid mellan 30 min och 3 timmar (demo: 5-15 min)
        let interval = Double.random(in: 300...900)
        eventTimer?.invalidate()
        eventTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.triggerRandomEvent()
        }
    }

    private func triggerRandomEvent() {
        let roll = Double.random(in: 0...1)
        let event: TimekeeperEvent

        if roll < 0.40 {
            event = .timekeeperStop
        } else if roll < 0.65 {
            event = .minuteManRaid
        } else if roll < 0.80 {
            event = .strangerGift
        } else if roll < 0.92 {
            event = .marketBonus
        } else {
            event = .zoneAlert
        }

        DispatchQueue.main.async {
            self.currentEvent = event
            self.showEvent = true
        }

        scheduleNextEvent()
    }

    func resolveEvent(accepted: Bool) {
        guard let event = currentEvent else {
            showEvent = false
            return
        }

        switch event {
        case .timekeeperStop:
            if accepted {
                let fine = TimeInterval.random(in: 600...3600)
                TimeEngine.shared.deductTime(fine)
            } else {
                if Double.random(in: 0...1) < 0.3 {
                    // Lyckades fly
                } else {
                    let fine = TimeInterval.random(in: 1800...7200)
                    TimeEngine.shared.deductTime(fine)
                }
            }
        case .minuteManRaid:
            // Kolla om spelaren har Minutman-sköld
            if ShopManager.shared.hasMinutemanShield() {
                ShopManager.shared.consumeMinutemanShield()
                // Skölden blockerar — ingen tid stjäls
            } else if accepted {
                let stolen = TimeInterval.random(in: 300...1800)
                TimeEngine.shared.deductTime(stolen)
            } else {
                // Kämpa emot — 40% chans att undkomma utan förlust
                if Double.random(in: 0...1) > 0.4 {
                    let stolen = TimeInterval.random(in: 600...2400)
                    TimeEngine.shared.deductTime(stolen)
                }
            }
        case .strangerGift:
            if accepted {
                // Ta emot gåvan
                let gift = TimeInterval.random(in: 1800...14400)
                TimeEngine.shared.addTime(gift)
                GameState.shared.recordEarning(gift)
            }
        case .marketBonus:
            // Alltid positiv händelse
            let bonus = TimeInterval.random(in: 900...3600)
            TimeEngine.shared.addTime(bonus)
            GameState.shared.recordEarning(bonus)
        case .zoneAlert:
            // Varning om att din zon ökar skatten tillfälligt
            break
        }

        showEvent = false
        currentEvent = nil
    }
}

enum TimekeeperEvent {
    case timekeeperStop      // Tidsvakt stannar dig — betala böter eller fly
    case minuteManRaid       // Minutman rånar dig — ge tid eller kämpa
    case strangerGift        // En okänd ger dig tid (Henry Hamilton-moment)
    case marketBonus         // Tidsbörsen rasar upp — bonussekunder
    case zoneAlert           // Din zon höjer skatten tillfälligt

    var title: String {
        switch self {
        case .timekeeperStop: return "TIDSVAKT STOPPAR DIG"
        case .minuteManRaid: return "MINUTMAN ATTACK"
        case .strangerGift: return "EN OKÄND MÖTER DIG"
        case .marketBonus: return "TIDSMARKNAD: UPPGÅNG"
        case .zoneAlert: return "ZON SKATTEÖKNING"
        }
    }

    var description: String {
        switch self {
        case .timekeeperStop:
            return "En Tidsvakt kräver att se din klocka. Du misstänks för tidsmanipulation. Acceptera kontroll (betala böter) eller försök fly."
        case .minuteManRaid:
            return "En Minutman pekar ut sin arm mot dig. \"Din tid eller ditt liv.\" Ge tid — eller ta risken att fly."
        case .strangerGift:
            return "En okänd person i zonen ser din klocka. \"Du behöver det mer än jag\", säger hen. Vill du acceptera gåvan?"
        case .marketBonus:
            return "Tidsbörsen exploderar uppåt. Alla aktiva investerare tjänar bonussekunder. Du får dela av vinsten."
        case .zoneAlert:
            return "Din zon aviserar en tillfällig skatteökning. Myndigheterna kontrollerar tidsflödet."
        }
    }

    var icon: String {
        switch self {
        case .timekeeperStop: return "shield.lefthalf.filled"
        case .minuteManRaid: return "person.fill.xmark"
        case .strangerGift: return "gift.fill"
        case .marketBonus: return "chart.line.uptrend.xyaxis"
        case .zoneAlert: return "exclamationmark.triangle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .timekeeperStop: return .red
        case .minuteManRaid: return .orange
        case .strangerGift: return .green
        case .marketBonus: return .cyan
        case .zoneAlert: return .yellow
        }
    }

    var acceptLabel: String {
        switch self {
        case .timekeeperStop: return "Acceptera kontroll"
        case .minuteManRaid: return "Ge tid"
        case .strangerGift: return "Ta emot"
        case .marketBonus: return "Hämta bonus"
        case .zoneAlert: return "Förstått"
        }
    }

    var declineLabel: String? {
        switch self {
        case .timekeeperStop: return "Försök fly"
        case .minuteManRaid: return "Kämpa emot"
        case .strangerGift: return "Avvisa"
        case .marketBonus: return nil
        case .zoneAlert: return nil
        }
    }
}

// MARK: - Timekeeper Event Sheet

struct TimekeeperEventSheet: View {
    let event: TimekeeperEvent
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Ikon
                ZStack {
                    Circle()
                        .fill(event.iconColor.opacity(0.1))
                        .frame(width: 90, height: 90)
                    Circle()
                        .stroke(event.iconColor.opacity(0.4), lineWidth: 1)
                        .frame(width: 90, height: 90)
                    Image(systemName: event.icon)
                        .font(.system(size: 36))
                        .foregroundColor(event.iconColor)
                }

                VStack(spacing: 10) {
                    Text(event.title)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(event.description)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Knappar
                VStack(spacing: 12) {
                    Button(action: onAccept) {
                        Text(event.acceptLabel)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(event.iconColor)
                            .cornerRadius(12)
                    }

                    if let declineLabel = event.declineLabel {
                        Button(action: onDecline) {
                            Text(declineLabel)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.07))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal)

                Text("Händelser sker slumpmässigt i systemet.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))

                Spacer()
            }
        }
    }
}
