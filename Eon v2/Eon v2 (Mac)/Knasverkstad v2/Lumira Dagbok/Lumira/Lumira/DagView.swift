//
//  DagView.swift
//  Lumira
//
//  Created by Ted Svärd on 2025-06-12.
//

import SwiftUI

struct DagbokEntry: Identifiable {
    let id = UUID()
    let date: Date
    let text: String
    let response: String
}

struct InläggsListaView: View {
    @Binding var entries: [DagbokEntry]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(entry.text)
                            .font(.body)
                            .padding(8)
                            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)

                        if !entry.response.isEmpty {
                            Text("💡 Lumira:")
                                .font(.subheadline)
                                .bold()

                            Text(entry.response)
                                .font(.body)
                                .padding(8)
                                .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24))
                                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                        }
                    }
                    .padding()
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                    .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .navigationTitle("Historik")
    }
}

struct DagView: View {
    @State private var userInput: String = ""
    @State private var aiResponse: String = ""
    @State private var selectedMode: ReflectionMode = .reflektion
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var entries: [DagbokEntry] = []
    @State private var selectedTab: Int = 0

    enum ReflectionMode: String, CaseIterable, Identifiable {
        case tyst = "🕊️ Tyst"
        case reflektion = "🪞 Resonans"
        case guidning = "🧭 Guidning"

        var id: String { self.rawValue }

        var promptIntro: String {
            switch self {
            case .tyst:
                return "Skriv en reflektion utan att besvara. Endast spegla."
            case .reflektion:
                return "Skriv en emotionellt lyhörd spegling utan att bjuda in till konversation."
            case .guidning:
                return "Skriv som en mjuk, guidande AI som kommenterar men inte kräver svar."
            }
        }
    }

    var skrivvy: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [
                Color(red: 240/255, green: 245/255, blue: 255/255).opacity(0.95),
                Color(red: 200/255, green: 220/255, blue: 255/255).opacity(0.4)
            ]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // Läge
                Picker("", selection: $selectedMode) {
                    ForEach(ReflectionMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 28) {
                        // Inmatning
                        VStack(alignment: .leading, spacing: 14) {
                            Text("📔 Din dag")
                                .font(.title2).bold()
                                .padding(.horizontal)

                            TextEditor(text: $userInput)
                                .padding()
                                .frame(minHeight: 200)
                                .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24))
                                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.primary.opacity(0.1)))
                                .padding(.horizontal)
                                .font(.body)
                        }

                        // Svar
                        if isLoading {
                            ProgressView("Reflekterar…")
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding()
                        } else if let message = errorMessage {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("⚠️ Fel:")
                                    .font(.headline)
                                Text(message)
                                    .font(.body)
                            }
                            .padding()
                            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                            .padding(.horizontal)
                        } else if !aiResponse.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("💡 Lumira reflekterar:")
                                    .font(.headline)
                                Text(aiResponse)
                                    .font(.body)
                            }
                            .padding()
                            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }

                Button(action: generateReflection) {
                    Label("Reflektera med Lumira", systemImage: "sparkles")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal)
                }
                .disabled(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.bottom)
            }
            .padding(.top)
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            skrivvy
                .tag(0)
                .tabItem {
                    Label("Skriv", systemImage: "square.and.pencil")
                }

            NavigationView {
                InläggsListaView(entries: $entries)
            }
            .tag(1)
            .tabItem {
                Label("Historik", systemImage: "book.closed")
            }
        }
    }

    func generateReflection() {
        isLoading = true
        aiResponse = ""
        errorMessage = nil

        let prompt = """
        Du är en AI-driven dagboksreflektör vid namn Lumira. Ditt uppdrag är att analysera och spegla användarens inmatning. Du svarar enligt läget '\(selectedMode.rawValue)'.
        \(selectedMode.promptIntro)

        Användarens text:
        \"\"\"
        \(userInput)
        \"\"\"
        """

        Task {
            do {
                let result = try await callOpenAI(with: prompt)
                DispatchQueue.main.async {
                    self.aiResponse = result
                    self.isLoading = false
                    let entry = DagbokEntry(date: Date(), text: self.userInput, response: result)
                    self.entries.insert(entry, at: 0)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func callOpenAI(with prompt: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer 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", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": "Du är en eftertänksam dagboksreflektör som aldrig ställer frågor eller inleder konversationer."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            if httpResponse.statusCode == 401 {
                throw NSError(domain: "Lumira", code: 401, userInfo: [NSLocalizedDescriptionKey: "Ogiltig API-nyckel. Kontrollera din OpenAI-nyckel."])
            } else if httpResponse.statusCode == 429 {
                throw NSError(domain: "Lumira", code: 429, userInfo: [NSLocalizedDescriptionKey: "För många förfrågningar. Försök igen senare."])
            } else if httpResponse.statusCode == 403 {
                throw NSError(domain: "Lumira", code: 403, userInfo: [NSLocalizedDescriptionKey: "Fel 403: Åtkomst nekad. Kontrollera att din OpenAI API-nyckel har rätt behörigheter eller inte har spärrats."])
            } else {
                let responseString = String(data: data, encoding: .utf8) ?? "Ingen ytterligare information."
                throw NSError(domain: "Lumira", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Fel \(httpResponse.statusCode): Kunde inte bearbeta förfrågan.\nSvar från servern:\n\(responseString)"])
            }
        }
        
        guard !data.isEmpty else {
            throw URLError(.zeroByteResource)
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return decoded.choices.first?.message.content ?? "Lumira kunde inte tolka ditt inlägg."
    }

    struct OpenAIResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
    }
}

#Preview {
    DagView()
}
