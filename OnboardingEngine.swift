import Foundation

/// Manages the onboarding state machine. Separates logic from Intro.swift UI.
@MainActor
final class OnboardingEngine: ObservableObject {
    static let shared = OnboardingEngine()

    // Steps: 0, 0.5 (HealthKit), 1, 2, 3, 4, 5, 6
    @Published private(set) var currentStep: Double = 0
    @Published private(set) var drainRateMultiplier: Double = 0.1
    @Published private(set) var healthKitAccessGranted: Bool = false
    @Published private(set) var isComplete: Bool = false

    private let stepSequence: [Double] = [0, 0.5, 1, 2, 3, 4, 5, 6]
    private var stepIndex: Int = 0

    func advance() {
        guard stepIndex < stepSequence.count - 1 else {
            completeOnboarding()
            return
        }
        stepIndex += 1
        currentStep = stepSequence[stepIndex]
    }

    /// Called after HealthKit authorization dialog completes
    func setHealthKitAccess(_ granted: Bool) {
        healthKitAccessGranted = granted
        advance()
    }

    func healthKitDenied() {
        healthKitAccessGranted = false
        advance()
    }

    func completeOnboarding() {
        drainRateMultiplier = 1.0
        isComplete = true
        // NOTE: TimeEngine.setDrainRate(_:) exists but is zone-based (absolute rate, not a multiplier).
        // When zone-aware drain multiplier support is added to TimeEngine, call it here.
        UserDefaults.standard.set(true, forKey: "hasLaunched")
    }
}
