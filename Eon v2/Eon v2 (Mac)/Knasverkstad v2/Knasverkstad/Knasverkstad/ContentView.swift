//
//  ContentView.swift
//  Knasverkstad
//
//  Created by Ted Svärd on 2025-05-30.
//

import SwiftUI
import AVFoundation
import Speech

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Image("Start2")
                    .resizable()
                    .scaleEffect(0.99999)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Knasverkstad")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(radius: 4)
                        .padding(.top, 40)
                        .offset(x: 0, y: -170)

                    Text("Följ med Professor Krumelur in i hans Knasverkstad och träffa de olika karaktärer som finns där!")
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                        .padding(.top, 10)
                        .offset(x: 0, y: 360)

                    NavigationLink(destination: Dashboard().navigationBarBackButtonHidden(true)) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.purple.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.purple.opacity(0.4), radius: 10, x: 0, y: 5)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                                )
                                .scaleEffect(1.05)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: UUID())

                            Image(systemName: "arrow.right")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 60)
                    .offset(x: 0, y: -140)

                    VStack(spacing: 2) {
                        Text("En app av Ted Svärd")
                            .font(.system(size: 25.5))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                            .offset(x: 0, y: 200)
                        Text("Svärd Teknik")
                            .font(.system(size: 22.1))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(radius: 1)
                            .offset(x: 0, y: 200)
                    }
                    .padding(.top, 10)
                }
                .padding()
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
            SFSpeechRecognizer.requestAuthorization { _ in }
        }
    }
}

#Preview {
    ContentView()
}
