//
//  Dashboard.swift
//  Knasverkstad
//
//  Created by Ted Svärd on 2025-05-28.
//

import SwiftUI

struct Dashboard: View {
    struct Character: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let imageName: String
    }

    let characters = [
        Character(
            name: "Professor Krumelur",
            description: "Vetenskaplig, humoristisk och allvetande. Guidar dig från matte till kärnfysik.",
            imageName: "krumelur"
        ),
        Character(
            name: "Kapten Rävskägg",
            description: "Rymdpirat med skägg av eld, rom i blodet och ett hjärta av stjärnstoft.",
            imageName: "ravskagg"
        ),
        Character(
            name: "Tuva Molin",
            description: "Varm, förstående och inkännande psykolog. Lyssnar alltid utan att döma.",
            imageName: "tuva"
        ),
        Character(
            name: "Grevinna Cornelia Gyllenfjäder von Ädelrot",
            description: "Adlig, dramatisk och excentrisk. Förfinat språk och förälskad i kungligheter.",
            imageName: "cornelia"
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("🎭 Välj en karaktär att prata med")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                    .padding(.top, 40)
                    .multilineTextAlignment(.center)

                ForEach(characters) { character in
                    ZStack(alignment: .bottomLeading) {
                        Image(character.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    gradient: Gradient(colors: [.clear, Color.black.opacity(0.7)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(24)
                            .shadow(radius: 10)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(character.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(radius: 2)

                            Text(character.description)
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.85))
                                .shadow(radius: 1)
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 50)
            }
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.indigo.opacity(0.4)]),
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

#Preview {
    Dashboard()
}
