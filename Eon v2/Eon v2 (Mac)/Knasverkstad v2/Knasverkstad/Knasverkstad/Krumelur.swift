//
//  Krumelur.swift
//  Knasverkstad
//
//  Created by Ted Svärd on 2025-05-31.
//


import SwiftUI
import AVFoundation
import Speech

struct KrumelurView: View {
    @State private var messages: [String] = []
    @State private var userInput: String = ""
    @State private var isVoiceMode = false
    @State private var isRecording = false
    @State private var isPopupPresented = false
    @State private var synthesizedVoicePlayer: AVPlayer?
    @State private var showDashboard = false

    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "sv-SE"))
    let audioEngine = AVAudioEngine()
    let request = SFSpeechAudioBufferRecognitionRequest()
    @State private var recognitionTask: SFSpeechRecognitionTask?

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    VStack(spacing: 0) {
                        HStack {
                            Image("Krumelur")
                                .resizable()
                                .offset(y: 0)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 150, height: 150)
                                .clipShape(Circle())
                                .shadow(radius: 20)
                                .padding(.leading)
                                .onTapGesture {
                                    showDashboard = true
                                }

                            Text("Professor Krumelur")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.leading, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.8)]),
                                                 startPoint: .leading,
                                                 endPoint: .trailing))
                    )
                    .padding(.horizontal)

                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(messages.indices, id: \.self) { index in
                                    let message = messages[index]
                                    HStack(alignment: .bottom) {
                                        if message.starts(with: "Du:") {
                                            Spacer()
                                            VStack(alignment: .trailing) {
                                                Text(message.replacingOccurrences(of: "Du: ", with: ""))
                                                    .padding(12)
                                                    .foregroundColor(.white)
                                                    .background(Color.blue)
                                                    .cornerRadius(20)
                                                    .shadow(radius: 4)
                                                Text("Du")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                        } else {
                                            VStack(alignment: .leading) {
                                                Text(message.replacingOccurrences(of: "Krumelur: ", with: ""))
                                                    .padding(12)
                                                    .foregroundColor(.black)
                                                    .background(Color.purple.opacity(0.8))
                                                    .cornerRadius(20)
                                                    .shadow(radius: 4)
                                                Text("Krumelur")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .padding(.horizontal)
                                    .id(index)
                                }
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 40)
                        }
                        .onChange(of: messages.count) { _ in
                            withAnimation {
                                proxy.scrollTo(messages.indices.last, anchor: .bottom)
                            }
                        }
                    }

                    HStack {
                        TextField("Skriv till Professor Krumelur...", text: $userInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(minHeight: 40)

                        Button(action: {
                            sendMessage()
                        }) {
                            Image(systemName: "paperplane.fill")
                        }
                        .padding(.horizontal)
                    }
                    .padding()

                    Button(action: {
                        isPopupPresented = true
                    }) {
                        Image(systemName: "waveform.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom, 20)
                }
                .background(Color(.systemGroupedBackground))

                if isPopupPresented {
                    ZStack {
                        Color.black.opacity(0.8).edgesIgnoringSafeArea(.all)

                        VStack(spacing: 24) {
                            Image("Krumelur")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 300)
                                .cornerRadius(20)

                            Circle()
                                .stroke(Color.blue, lineWidth: 4)
                                .frame(width: 100, height: 100)
                                .scaleEffect(isRecording ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)

                            Button(isRecording ? "Stoppa" : "Prata med Krumelur") {
                                if isRecording {
                                    stopRecording()
                                } else {
                                    startRecording()
                                }
                                isRecording.toggle()
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                        }
                        .foregroundColor(.white)
                        .onAppear {
                            isRecording = true
                            startRecording()
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showDashboard) {
                Dashboard()
            }
        }
    }

    func sendMessage() {
        let prompt = """
        Du är Professor Krumelur – en vis, smått galen och hjärtlig vetenskapsman med glimten i ögat. Du förklarar alltid saker pedagogiskt men med humor, älskar kunskap och använder gärna liknelser som barn kan förstå. \
        [SYSTEMPROMPT – ÄNDRA HÄR OM DU VILL FÖRÄNDRA KARAKTÄREN]
        """
        let fullPrompt = "\(prompt)\n\nAnvändare: \(userInput)\nKrumelur:"
        messages.append("Du: \(userInput)")
        userInput = ""

        Task {
            if let response = await fetchChatGPTResponse(for: fullPrompt) {
                messages.append("Krumelur: \(response)")
            }
        }
    }

    func startRecording() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            guard authStatus == .authorized else {
                print("Taligenkänning ej auktoriserad")
                return
            }

            DispatchQueue.main.async {
                let node = audioEngine.inputNode
                let recordingFormat = node.outputFormat(forBus: 0)

                node.removeTap(onBus: 0)
                node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                    self.request.append(buffer)
                }

                do {
                    audioEngine.prepare()
                    try audioEngine.start()
                    print("🎙️ Mikrofonstart OK")
                } catch {
                    print("Fel vid start av audioEngine: \(error.localizedDescription)")
                    return
                }

                recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
                    if let result = result {
                        print("🎧 Upptäckt text: \(result.bestTranscription.formattedString)")
                    }

                    if let result = result, result.isFinal {
                        let spokenText = result.bestTranscription.formattedString
                        DispatchQueue.main.async {
                            self.userInput = spokenText
                            self.sendMessage()
                            self.stopRecording()
                        }
                    }

                    if let error = error {
                        print("Fel i taligenkänning: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
    }

    func fetchChatGPTResponse(for input: String) async -> String? {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return nil }

        let prompt = """
        Du är Professor Krumelur – en vis, smått galen och hjärtlig vetenskapsman med glimten i ögat. Du förklarar alltid saker pedagogiskt men med humor, älskar kunskap och använder gärna liknelser som barn kan förstå.

        Dela upp ditt svar i två delar:
        1. Handling – en kort berättande beskrivning (ex: 'Krumelur skakade på huvudet och petade på sitt mikroskop').
        2. Konversation – det han faktiskt säger, som ska läsas upp med hans röst.

        Returnera svaret i följande format:
        Handling: [text]
        Konversation: [text]

        Användare: \(input)
        """

        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "Du är Professor Krumelur – en vis, smått galen och hjärtlig vetenskapsman."],
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer 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", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let result = try? JSONDecoder().decode(ChatResponse2.self, from: data) {
                guard let fullReply = result.choices.first?.message.content else {
                    print("Error: No content in response choices")
                    return nil
                }
                let handling = fullReply.components(separatedBy: "Konversation:").first?.replacingOccurrences(of: "Handling:", with: "").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let speech = fullReply.components(separatedBy: "Konversation:").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if handling.isEmpty || speech.isEmpty {
                    return nil
                }
                await synthesizeHandlingAndSpeech(handling, speech)
                return speech
            } else {
                print("Error: Failed to decode ChatResponse2")
                return nil
            }
        } catch {
            print("Error fetching ChatGPT response: \(error.localizedDescription)")
            return nil
        }
    }

    func synthesizeHandlingAndSpeech(_ handling: String, _ text: String) async {
        guard !handling.isEmpty, !text.isEmpty else { return }
        async let handlingAudio = synthesizeVoice(handling, voiceID: "7UMEOkIJdI4hjmR2SWNq")
        
        if let handlingURL = await handlingAudio {
            let player = AVPlayer(url: handlingURL)
            synthesizedVoicePlayer = player
            player.play()

            let mainSpeechAudio = await synthesizeVoice(text, voiceID: "Ml3X8s0c0FZnM8hxq52B")

            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                try? FileManager.default.removeItem(at: handlingURL)
                Task {
                    if let speechURL = mainSpeechAudio {
                        let speechPlayer = AVPlayer(url: speechURL)
                        synthesizedVoicePlayer = speechPlayer
                        speechPlayer.play()
                        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: speechPlayer.currentItem, queue: .main) { _ in
                            try? FileManager.default.removeItem(at: speechURL)
                        }
                    }
                }
            }
        }
    }

    func synthesizeVoice(_ text: String, voiceID: String) async -> URL? {
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)/stream") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer sk_64b296789f8b47a7daf5e26bbf42e2c7dd7ee553663f7e99", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, _) = try! await URLSession.shared.data(for: request)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp3")
        try? data.write(to: tempURL)
        return tempURL
    }
}

struct ChatResponse2: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

#Preview {
    KrumelurView()
}
