import SwiftUI

struct ZoneUpgradeFlash: ViewModifier {
    @EnvironmentObject var theme: ThemeEngine
    @State private var isFlashing = false
    @StateObject private var zoneManager = ZoneManager.shared

    func body(content: Content) -> some View {
        content
            .overlay {
                if isFlashing {
                    theme.current.accent
                        .opacity(0.35)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .onChange(of: zoneManager.currentZone) { oldVal, newVal in
                withAnimation(.easeIn(duration: 0.1)) { isFlashing = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.5)) { isFlashing = false }
                }
            }
    }
}
