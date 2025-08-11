//
//  ContentView.swift
//  Knasverkstad
//
//  Created by Ted Svärd on 2025-05-28.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Image("Start")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                VStack(spacing: 30) {
                    VStack(spacing: 12) {
                        Text("🎩 Välkommen till")
                            .font(.system(size: 22, weight: .light, design: .rounded))
                            .foregroundColor(.white)

                        Text("Knasverkstad")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                    }

                    Text("Professor Krumelurs verkstad. Här hittar du en samling underliga, charmiga och pratglada karaktärer – redo att snacka med dig!")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)

                    NavigationLink(destination: CharacterSelectionView()) {
                        Text("🚀 In i verkstaden")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)
                    }
                    .padding(.top, 30)
                }
                .padding(.horizontal)
            }
            .navigationBarHidden(true)
        }
    }
}

struct CharacterSelectionView: View {
    var body: some View {
        Text("Character Selection View Placeholder")
            .font(.title)
            .foregroundColor(.gray)
    }
}

#Preview {
    ContentView()
}
