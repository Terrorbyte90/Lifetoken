//
//  Intro.swift
//  LifeToken
//
//  Created by Ted Svärd on 2025-05-17.
//


import SwiftUI

struct IntroView: View {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @State private var fakeSeconds = 0
    @State private var timer: Timer? = nil
    @State private var navigateToDashboard = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                Text("LIFETOKEN")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text("\(fakeSeconds) sekunder")
                    .font(.system(size: 48, weight: .medium, design: .monospaced))
                    .foregroundColor(.green)
                    .onAppear {
                        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                            fakeSeconds += 1
                        }
                    }
                    .onDisappear {
                        timer?.invalidate()
                        timer = nil
                    }
                Text("Du lever – så länge din tid inte tar slut.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 16) {
                    Text("• Steg är tid. Varje 7 steg ger dig 1 sekund att leva vidare.")
                    Text("• Zoner påverkar din inkomst och överlevnad.")
                    Text("• Var aktiv – tiden tickar. Appen belönar rörelse.")
                    Text("• Du kan alltid se hur mycket tid du har kvar.")
                    Text("• Du tjänar in tid som utbetalas kl 12.00 varje dag.")
                }
                .foregroundColor(.white)
                .padding(.horizontal)

                Spacer()

                NavigationLink(value: "dashboard") {
                    EmptyView()
                }
                .navigationDestination(for: String.self) { value in
                    if value == "dashboard" {
                        DashboardView().navigationBarBackButtonHidden(true)
                    }
                }

                Button(action: {
                    hasLaunchedBefore = true
                    navigateToDashboard = true
                }) {
                    Text("Starta tiden")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .background(Color.black.ignoresSafeArea())
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

#Preview {
    IntroView()
        .preferredColorScheme(.dark)
}
