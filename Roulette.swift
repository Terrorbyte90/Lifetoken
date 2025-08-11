import Foundation
import SwiftUI

struct SlotMachineView: View {
    @State private var symbols = ["🍒", "💎", "🍋", "🔔", "🍀"]
    @State private var displayedReels = [0, 0, 0]
    @State private var targetReels = [0, 0, 0]
    @State private var isSpinning = false
    @State private var resultMessage = ""
    @State private var betMinutes: Int = 5
    @State private var timeRemaining: TimeInterval = 82800
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @EnvironmentObject var zoneManager: ZoneManager

    private var currentZone: ZoneProfile {
        zoneManager.currentZone(forTime: timeRemaining)
    }

    private var winChancePercentage: Int {
        let zoneNames = ZoneProfile.allZones.map { $0.name }
        if let index = zoneNames.firstIndex(of: currentZone.name) {
            let percentage = 10 - (index * 2)
            return max(1, percentage)
        }
        return 10
    }

    private var zoneMultiplier: Int {
        switch currentZone.name {
        case "Duskline": return 5
        case "Midgrey": return 10
        case "Risefield": return 15
        case "Aetherpoint": return 20
        case "Novalux": return 25
        case "Vaultum": return 30
        case "Solara": return 35
        default: return 5
        }
    }

    var multiplierText: String {
        "Jackpot ger \(zoneMultiplier)x insatsen."
    }

    var zoneInfoText: String {
        "Zonen du är i påverkar både vinst och risk."
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("Slot Machine")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .bold()
                .foregroundColor(.white)
                .shadow(radius: 5)

            HStack(spacing: 20) {
                ForEach(0..<3) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(resultMessage.contains("JACKPOT") ? Color.yellow : .clear, lineWidth: 4)
                                    .shadow(color: resultMessage.contains("JACKPOT") ? .yellow : .clear, radius: 6)
                            )
                            .frame(width: 80, height: 80)
                            .shadow(radius: 4)

                        Text(symbols[displayedReels[index]])
                            .font(.system(size: 40))
                            .transition(.scale)
                            .id(displayedReels[index])
                            .animation(.easeInOut(duration: 0.1), value: displayedReels[index])
                    }
                }
            }

            VStack(spacing: 5) {
                Text("Satsa minuter:")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                
                Picker("", selection: $betMinutes) {
                    ForEach(1..<61) { minute in
                        Text("\(minute) min")
                            .foregroundColor(.white)
                            .tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 100)
                .colorMultiply(.white)
            }

            Button(action: spin) {
                Text(isSpinning ? "Snurrar..." : "Spela")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .padding(.vertical, 12)
                    .frame(maxWidth: 160)
                    .background(isSpinning ? Color.gray.opacity(0.4) : Color.green.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(radius: 5)
            }
            .disabled(isSpinning || TimeInterval(betMinutes * 60) > timeRemaining)

            if !resultMessage.isEmpty {
                Text(resultMessage)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.yellow)
                    .padding(.top, 20)
                
                if resultMessage.contains("JACKPOT") {
                    Text("Du är vid liv en stund till…")
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("Du spelar med ditt liv…")
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            Spacer()

            // Instruktioner och mini-klocka dashboard-stil, längst ner
            VStack(spacing: 8) {
                Text("Vid förlust förlorar du din insats.\nTre lika ger insatsen gånger fem.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                Text("Här kan du leva längre eller avsluta snabbare…")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 6)

            VStack(spacing: 4) {
                Text("Du befinner dig i Zonen:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(zoneManager.currentZone.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.green)

                VStack(spacing: 4) {
                    Text(multiplierText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Text(zoneInfoText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, 6)

            VStack(spacing: 4) {
                Text("LIFETOKEN")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text(timeFormatted(seconds: timeRemaining))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .onReceive(timer) { _ in
                        updateTimeRemaining()
                    }
            }
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
    }

    func spin() {
        let betSeconds = betMinutes * 60
        if TimeInterval(betSeconds) > timeRemaining {
            resultMessage = "❌ Du har inte tillräckligt med tid."
            return
        }
        adjustTime(by: betSeconds)
        isSpinning = true
        resultMessage = ""
        // Custom targetReels logic
        let winChance = Int.random(in: 1...100)
        let isJackpot = winChance <= winChancePercentage
        let isTwoOfAKind = winChance <= 35
        if isJackpot {
            // 10% chans för JACKPOT (3 lika)
            let symbol = Int.random(in: 0..<symbols.count)
            targetReels = [symbol, symbol, symbol]
        } else if isTwoOfAKind {
            // 25% chans för två lika
            let a = Int.random(in: 0..<symbols.count)
            var b = Int.random(in: 0..<symbols.count)
            while b == a { b = Int.random(in: 0..<symbols.count) }
            let positions = [0, 1, 2].shuffled()
            targetReels = [Int](repeating: 0, count: 3)
            targetReels[positions[0]] = a
            targetReels[positions[1]] = a
            targetReels[positions[2]] = b
        } else {
            // 65% chans för ingen vinst
            var newReels: [Int]
            repeat {
                newReels = (0..<3).map { _ in Int.random(in: 0..<symbols.count) }
            } while newReels[0] == newReels[1] || newReels[1] == newReels[2] || newReels[0] == newReels[2]
            targetReels = newReels
        }

        let durations = [
            Double.random(in: 2.0...3.5),
            Double.random(in: 2.5...4.0),
            Double.random(in: 3.0...4.5)
        ]

        for index in 0..<3 {
            let duration = durations[index]
            spinReel(at: index, duration: duration)
        }
    }

    func spinReel(at index: Int, duration: Double) {
        var spinTime: Double = 0.0
        let spinInterval: Double = 0.06

        Timer.scheduledTimer(withTimeInterval: spinInterval, repeats: true) { timer in
            spinTime += spinInterval
            displayedReels[index] = Int.random(in: 0..<symbols.count)

            if spinTime >= duration {
                timer.invalidate()
                displayedReels[index] = targetReels[index]

                if index == 2 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isSpinning = false
                        checkResult()
                    }
                }
            }
        }
    }

    func checkResult() {
        let reelA = targetReels[0]
        let reelB = targetReels[1]
        let reelC = targetReels[2]

        if reelA == reelB && reelB == reelC {
            let betSeconds = betMinutes * 60
            let multiplier = zoneMultiplier
            let winSeconds = betSeconds * multiplier
            let adjustment = -winSeconds
            adjustTime(by: adjustment)
            let winnings = betMinutes * multiplier
            resultMessage = "🎉 JACKPOT! Du vann \(winnings) minuter!"
        } else if reelA == reelB || reelB == reelC || reelA == reelC {
            let lostMinutes = betMinutes
            resultMessage = "🥈 Två lika! Du förlorade \(lostMinutes) minuter."
        } else {
            let lostMinutes = betMinutes
            resultMessage = "❌ Ingen vinst. Du förlorade \(lostMinutes) minuter."
        }
    }

    func adjustTime(by seconds: Int) {
        guard let oldStart = UserDefaults.standard.object(forKey: "absoluteStartTimeUTC") as? Date else { return }
        guard seconds != 0 else { return }

        // POSITIVA värden -> backar starttid = ökar livstid
        // NEGATIVA värden -> skjuter starttid FRAM = minskar livstid
        let adjusted = oldStart.addingTimeInterval(TimeInterval(-seconds))
        UserDefaults.standard.set(adjusted, forKey: "absoluteStartTimeUTC")
        updateTimeRemaining()
    }

    private func updateTimeRemaining() {
        guard let startTime = UserDefaults.standard.object(forKey: "absoluteStartTimeUTC") as? Date else { return }
        let secondsElapsed = Date().timeIntervalSince(startTime)
        let startLife: TimeInterval = 82800
        timeRemaining = max(0, startLife - secondsElapsed)
    }
}

#Preview {
    SlotMachineView()
        .environmentObject(ZoneManager())
}

    // Formatera tid som HH:MM:SS
    func formattedTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

func timeFormatted(seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, secs)
}
