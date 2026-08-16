import SwiftUI
import AVKit

// MARK: - DeathView
// Fas 1: Gameover.mp4 spelas fullskärm
// Fas 2: 24-timmars spärrad skärm

struct DeathView: View {
    @ObservedObject private var engine = TimeEngine.shared
    @State private var showLockedScreen = false
    @State private var gameOverPlayer: AVPlayer? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showLockedScreen {
                LockedScreen()
                    .transition(.opacity)
            } else {
                GameOverVideoView(player: gameOverPlayer) {
                    withAnimation(.easeIn(duration: 0.8)) { showLockedScreen = true }
                }
                .ignoresSafeArea()
            }
        }
        .onAppear { setupGameOverVideo() }
        .onDisappear { gameOverPlayer?.pause(); gameOverPlayer = nil }
    }

    private func setupGameOverVideo() {
        guard let url = Bundle.main.url(forResource: "Gameover", withExtension: "mp4", subdirectory: "Media.bundle/Media") else {
            // Ingen video hittad — hoppa direkt till spärrad skärm
            showLockedScreen = true
            return
        }
        let p = AVPlayer(url: url)
        p.actionAtItemEnd = .pause
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem,
            queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeIn(duration: 0.8)) { showLockedScreen = true }
            }
        }
        p.play()
        gameOverPlayer = p
    }
}

// MARK: - Gameover Video (fullskärm)

struct GameOverVideoView: View {
    let player: AVPlayer?
    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .disabled(true)
                    .ignoresSafeArea()
                    .aspectRatio(contentMode: .fill)
            }

            // Knapp för att hoppa över videon
            VStack {
                Spacer()
                Button {
                    onFinished()
                } label: {
                    Text("HOPPA ÖVER")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                }
                .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - Spärrad skärm (24h)

struct LockedScreen: View {
    @ObservedObject private var engine = TimeEngine.shared
    @State private var timeRemaining: TimeInterval = 0
    @State private var countdown = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var glitchOffset: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var glitchTimer: Timer? = nil

    private let deathMessages = [
        "Din tid rann ut.\nSystemet bryr sig inte.",
        "Du förlorade din tid.\nLikt alla andra förr eller senare.",
        "Klockan nådde noll.\nDet gör den alltid till slut.",
        "Ditt saldo är nollat.\nDu är nu ingenting i systemet.",
        "Evigheten väntade.\nNu har den dig."
    ]
    @State private var message = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [Color.red.opacity(0.12), .clear],
                center: .bottom, startRadius: 0, endRadius: 400
            )
            .ignoresSafeArea()

            // Skanningslinjer
            Canvas { ctx, size in
                for y in stride(from: 0.0, to: size.height, by: 3) {
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(p, with: .color(Color.white.opacity(0.012)), lineWidth: 1)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Ikon
                ZStack {
                    Circle()
                        .stroke(Color.red.opacity(0.25), lineWidth: 1)
                        .frame(width: 100, height: 100)
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 52))
                        .foregroundColor(Color.red.opacity(0.7))
                }
                .padding(.bottom, 32)

                Text("DU ÄR BORTA")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(.red.opacity(0.85))
                    .tracking(6)
                    .shadow(color: .red.opacity(0.4), radius: 12)
                    .offset(x: glitchOffset)
                    .padding(.bottom, 16)

                Text(message)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 48)

                Rectangle()
                    .fill(Color.red.opacity(0.15))
                    .frame(height: 1)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)

                // Nedräkning
                VStack(spacing: 8) {
                    Text("KONTOT ÄR SPÄRRAT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.25))
                        .tracking(3)

                    Text(formattedCountdown)
                        .font(.system(size: 44, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .monospacedDigit()

                    Text("Du kan börja om om \(formattedCountdown)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.2))
                        .italic()
                }
                .padding(.bottom, 48)

                if timeRemaining <= 0 {
                    Button {
                        engine.clearDeath()
                        engine.balance = 3600
                    } label: {
                        Text("ÅTERUPPSTÅ")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()
            }
            .opacity(opacity)
        }
        .onAppear {
            message = deathMessages.randomElement()!
            timeRemaining = max(0, engine.timeUntilRebirth)
            withAnimation(.easeIn(duration: 1.5)) { opacity = 1 }
            startGlitch()
        }
        .onReceive(countdown) { _ in
            timeRemaining = max(0, engine.timeUntilRebirth)
        }
        .onDisappear {
            glitchTimer?.invalidate()
            glitchTimer = nil
        }
    }

    private var formattedCountdown: String {
        let remaining = Int(max(0, timeRemaining))
        let h = remaining / 3600
        let m = remaining % 3600 / 60
        let s = remaining % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private func startGlitch() {
        glitchTimer?.invalidate()
        glitchTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.08)) { glitchOffset = CGFloat.random(in: -4...4) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.08)) { glitchOffset = 0 }
            }
        }
    }
}

// MARK: - Preview

#Preview("Death Screen") {
    DeathView()
        .preferredColorScheme(.dark)
}
