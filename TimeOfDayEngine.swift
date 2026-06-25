import Foundation
import SwiftUI

// MARK: - TimeOfDayEngine
//
// Dygnsfaser i Stockholmstid driver gameplay-bonusar:
//
//   Gryningsljus  05:00–08:59   ×1.20 steg, ×1.10 hälsolön   ("Morgonenergi")
//   Dagsljus      09:00–16:59   ×1.15 jobb, ×1.05 hälsolön     ("Produktivt dagsljus")
//   Skymning      17:00–21:59   ×1.20 kasino-vinst, +5% kasino-risk ("Risktimme")
//   Djupnatt      22:00–04:59   ×1.10 jobb, −10% drain, ×0.85 hälsolön ("Tystnadens timme")
//
// Faserna visas i dashboard, i Work, Kasino och Missions.
// Detta ger spelaren en anledning att planera sin dag — det är "prime time"-mekaniken.

enum DayPhase: String, CaseIterable, Identifiable {
    case dawn        // Gryningsljus
    case day         // Dagsljus
    case dusk        // Skymning
    case night       // Djupnatt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dawn:  return "GRYNINGSLJUS"
        case .day:   return "DAGSLJUS"
        case .dusk:  return "SKYMNING"
        case .night: return "DJUPNATT"
        }
    }

    var subtitle: String {
        switch self {
        case .dawn:  return "Morgonenergi — steglön ×1.20"
        case .day:   return "Produktivt — jobb ×1.15"
        case .dusk:  return "Risktimme — kasino ×1.20 / risk +5%"
        case .night: return "Tystnad — drain −10%, jobb ×1.10"
        }
    }

    var icon: String {
        switch self {
        case .dawn:  return "sun.haze.fill"
        case .day:   return "sun.max.fill"
        case .dusk:  return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .dawn:  return Color(red: 1.00, green: 0.62, blue: 0.30)   // orange-guld
        case .day:   return Color(red: 0.30, green: 0.75, blue: 1.00)   // klarblå
        case .dusk:  return Color(red: 0.85, green: 0.30, blue: 0.55)   // magenta
        case .night: return Color(red: 0.40, green: 0.42, blue: 0.78)   // djup indigo
        }
    }

    var rangeText: String {
        switch self {
        case .dawn:  return "05:00–08:59"
        case .day:   return "09:00–16:59"
        case .dusk:  return "17:00–21:59"
        case .night: return "22:00–04:59"
        }
    }

    /// Kompositmultiplikatorer — spelas in av IncomeManager, WorkManager, CasinoHub m.fl.
    var stepBonusMultiplier: Double {
        self == .dawn ? 1.20 : 1.00
    }
    var healthIncomeMultiplier: Double {
        switch self {
        case .dawn:  return 1.10
        case .day:   return 1.05
        case .night: return 0.85
        default:     return 1.00
        }
    }
    var workMultiplier: Double {
        switch self {
        case .day:   return 1.15
        case .night: return 1.10
        default:     return 1.00
        }
    }
    var casinoRewardMultiplier: Double { self == .dusk ? 1.20 : 1.00 }
    var casinoRiskAddition: Double      { self == .dusk ? 0.05 : 0.00 }
    var drainRateMultiplier: Double     { self == .night ? 0.90 : 1.00 }
}

@MainActor
final class TimeOfDayEngine: ObservableObject {
    static let shared = TimeOfDayEngine()

    @Published private(set) var currentPhase: DayPhase = .day
    @Published private(set) var stockholmHour: Int = 12
    @Published private(set) var stockholmDate: Date = Date()
    @Published private(set) var nextPhaseChangeIn: TimeInterval = 0

    static let stockholmTZ = TimeZone(identifier: "Europe/Stockholm")!

    private var tickTimer: Timer?
    private var phaseTimer: Timer?

    private init() {
        refresh()
        // Uppdatera fas varje minut — tillräckligt för UI + mek
        tickTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // Tick varje sekund för countdown till nästa fas
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateCountdown() }
        }
    }

    private func refresh() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.stockholmTZ
        let now = Date()
        let hour = cal.component(.hour, from: now)
        stockholmHour = hour
        stockholmDate = now
        let newPhase = Self.phase(forHour: hour)
        if newPhase != currentPhase {
            withAnimation(LTAnimation.springSmooth) {
                currentPhase = newPhase
            }
        }
        updateCountdown()
    }

    private func updateCountdown() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.stockholmTZ
        let now = Date()
        let hour = cal.component(.hour, from: now)
        // Beräkna sekunder kvar tills nästa fas-gräns
        let phaseBoundaries: [Int] = [5, 9, 17, 22]   // Stockholm-timmar där fas byter
        let nextBoundary = phaseBoundaries.first { $0 > hour } ?? (5 + 24)
        let comps = cal.dateComponents([.year, .month, .day], from: now)
        var nextComps = comps
        nextComps.hour = nextBoundary % 24
        nextComps.minute = 0
        nextComps.second = 0
        if let next = cal.date(from: nextComps) {
            nextPhaseChangeIn = max(0, next.timeIntervalSince(now))
        } else {
            nextPhaseChangeIn = 0
        }
    }

    static func phase(forHour hour: Int) -> DayPhase {
        switch hour {
        case 5...8:   return .dawn
        case 9...16:  return .day
        case 17...21: return .dusk
        default:      return .night
        }
    }

    /// Visuell text för countdown: "3h 12m kvar till DJUPNATT"
    var nextPhaseLabel: String {
        let s = Int(nextPhaseChangeIn)
        let h = s / 3600
        let m = (s % 3600) / 60
        let upcoming = upcomingPhase
        if h > 0 { return "\(h)t \(m)m → \(upcoming.displayName)" }
        if m > 0 { return "\(m)m → \(upcoming.displayName)" }
        return "Strax → \(upcoming.displayName)"
    }

    private var upcomingPhase: DayPhase {
        let nextHour = (stockholmHour + 1) % 24
        // Hitta nästa avvikande fas
        var h = nextHour
        var candidate = Self.phase(forHour: h)
        var guard_ = 0
        while candidate == currentPhase && guard_ < 24 {
            h = (h + 1) % 24
            candidate = Self.phase(forHour: h)
            guard_ += 1
        }
        return candidate
    }

    /// Formaterad Stockholm-tid HH:mm
    var clockText: String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.stockholmTZ
        let comps = cal.dateComponents([.hour, .minute], from: stockholmDate)
        return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }
}

// MARK: - DayPhaseBadge (delad vy-komponent)

struct DayPhaseBadge: View {
    let phase: DayPhase
    var compact: Bool = false
    @State private var pulse: Bool = false

    var body: some View {
        HStack(spacing: compact ? 4 : 7) {
            Image(systemName: phase.icon)
                .font(.system(size: compact ? 10 : 12, weight: .bold))
                .foregroundColor(phase.accentColor)
                .shadow(color: phase.accentColor.opacity(0.6), radius: 4)
                .scaleEffect(pulse ? 1.08 : 1.0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(phase.displayName)
                    .font(.system(size: compact ? 8 : 10, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(1.5)
                if !compact {
                    Text(TimeOfDayEngine.shared.clockText + " STO")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(1)
                }
            }
        }
        .padding(.horizontal, compact ? 8 : 11)
        .padding(.vertical, compact ? 4 : 6)
        .background(phase.accentColor.opacity(0.12))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(phase.accentColor.opacity(0.40), lineWidth: 1)
        )
        .shadow(color: phase.accentColor.opacity(0.20), radius: 6, x: 0, y: 2)
        .accessibilityLabel("Dygnsfas: \(phase.displayName). \(phase.subtitle)")
    }
}