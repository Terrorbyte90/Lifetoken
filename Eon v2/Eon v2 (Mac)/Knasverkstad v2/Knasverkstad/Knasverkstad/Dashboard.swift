//
//  Dashboard.swift
//  Knasverkstad
//
//  Created by Ted Svärd on 2025-05-28.
//

import SwiftUI

struct Dashboard: View {
    struct CharacterCardView<Destination: View>: View {
        let name: String
        let description: String
        let imageName: String
        let destination: Destination

        var body: some View {
            NavigationLink(destination: destination.navigationBarBackButtonHidden(true)) {
                ZStack(alignment: .bottomLeading) {
                    Image(imageName)
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
                        Text(name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(radius: 2)

                        Text(description)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.85))
                            .shadow(radius: 1)
                    }
                    .padding()
                }
                .padding(.horizontal)
            }
        }
    }

    func yOffset(for name: String) -> CGFloat {
        switch name {
        case "Kapten Rävskägg": return 40
        case "Tuva Molin": return 90
        case "Grevinna Cornelia Gyllenfjäder": return 100
        default: return 0
        }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 30) {
                        Text("🎭 Välj en karaktär att prata med")
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                            .padding(.top, 20)
                            .multilineTextAlignment(.center)

                        CharacterCardView(name: "Professor Krumelur", description: "Vetenskaplig, humoristisk och allvetande. Guidar dig från matte till kärnfysik.", imageName: "Krumelur", destination: KrumelurView())

                        CharacterCardView(name: "Kapten Rävskägg", description: "Rymdpirat med skägg av eld, rom i blodet och ett hjärta av stjärnstoft.", imageName: "Rav", destination: RavskaggView())

                        CharacterCardView(name: "Tuva Molin", description: "Varm, förstående och inkännande psykolog. Lyssnar alltid utan att döma.", imageName: "Tuva", destination: TuvaView())

                        CharacterCardView(name: "Grevinna Cornelia Gyllenfjäder", description: "Adlig, dramatisk och excentrisk. Förfinat språk och förälskad i kungligheter.", imageName: "Cornelia", destination: CorneliaView())
                    }

                    Spacer(minLength: 50)
                }
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.indigo.opacity(0.4)]),
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                )
            }
        }
    }
}

#Preview {
    Dashboard()
}
