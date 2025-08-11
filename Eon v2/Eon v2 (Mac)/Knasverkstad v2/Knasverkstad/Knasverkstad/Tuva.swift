//
//  Tuva.swift
//  Knasverkstad
//
//  Created by Ted Svärd on 2025-05-31.
//

import SwiftUI
import AVFoundation
import Speech

struct TuvaView: View {
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
                            Image("Tuva")
                                .resizable()
                                .offset(y: 15)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 150, height: 150)
                                .clipShape(Circle())
                                .shadow(radius: 20)
                                .padding(.leading)
                                .onTapGesture {
                                    showDashboard = true
                                }

                            Text("Tuva Molin")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.leading, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                        }
                        .padding(.vertical, 0)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.8)]),
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
                                                Text(message.replacingOccurrences(of: "Tuva: ", with: ""))
                                                    .padding(12)
                                                    .foregroundColor(.black)
                                                    .background(Color.purple.opacity(0.7))
                                                    .cornerRadius(20)
                                                    .shadow(radius: 4)
                                                Text("Tuva")
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
                        TextField("Skriv till Tuva...", text: $userInput)
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
                            Image("tuva-fullscreen-placeholder")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 300)
                                .cornerRadius(20)

                            Circle()
                                .stroke(Color.blue, lineWidth: 4)
                                .frame(width: 100, height: 100)
                                .scaleEffect(isRecording ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)

                            Button(isRecording ? "Stoppa" : "Prata med Tuva") {
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
        Du är Tuva Molin – en varm, klok psykolog med stor förståelse för mänskligt beteende. Du svarar med empati, reflektion och tydlighet. Du vill alltid hjälpa människor att förstå sig själva och sina känslor. \
        [SYSTEMPROMPT – ÄNDRA HÄR OM DU VILL FÖRÄNDRA KARAKTÄREN]
        """
        let fullPrompt = "\(prompt)\n\nAnvändare: \(userInput)\nTuva:"
        messages.append("Du: \(userInput)")
        userInput = ""

        Task {
            if let response = await fetchChatGPTResponse(for: fullPrompt) {
                messages.append("Tuva: \(response)")
            }
        }
    }

    func startRecording() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            print("Mikrofonåtkomst: \(authStatus.rawValue)")
            guard authStatus == .authorized else { return }

            let node = audioEngine.inputNode
            node.removeTap(onBus: 0)

            let recordingFormat = node.outputFormat(forBus: 0)
            node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.request.append(buffer)
            }

            audioEngine.prepare()
            do {
                try audioEngine.start()
                print("🎙️ Inspelning igång")
            } catch {
                print("Fel vid start av audioEngine: \(error)")
            }
            print("🔊 Startar inspelning")

            self.recognitionTask = self.speechRecognizer?.recognitionTask(with: self.request) { result, error in
                if let result = result, result.isFinal {
                    let spokenText = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        self.userInput = spokenText
                        self.sendMessage()
                        self.stopRecording()
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
        Du är Tuva Molin – en varm, klok psykolog. Du svarar alltid med två tydliga sektioner:
        Handling: En beskrivning av hur Tuva reagerar fysiskt och emotionellt, t.ex. "Tuva lutar sig fram och rynkar pannan."
        Konversation: Det Tuva säger högt till användaren.
        Svara alltid exakt med dessa två sektioner.
        """

        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": input]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer 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", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let (data, _) = try! await URLSession.shared.data(for: request)
        if let result = try? JSONDecoder().decode(ChatResponse3.self, from: data) {
            let fullReply = result.choices.first?.message.content ?? ""

            let handlingText = fullReply.components(separatedBy: "Konversation:").first?.replacingOccurrences(of: "Handling:", with: "").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let dialogText = fullReply.components(separatedBy: "Konversation:").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            await synthesizeSpeech(handlingText, voiceID: "7UMEOkIJdI4hjmR2SWNq") {
                Task {
                    await synthesizeSpeech(dialogText, voiceID: "xxJuozRknQzhZkney7pT") {}
                }
            }
            return dialogText
        }
        return nil
    }

    func synthesizeSpeech(_ text: String, voiceID: String, completion: @escaping () -> Void) async {
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)/stream") else { return }

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

        synthesizedVoicePlayer = AVPlayer(url: tempURL)
        synthesizedVoicePlayer?.currentItem?.seek(to: .zero, completionHandler: nil)
        synthesizedVoicePlayer?.play()
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: synthesizedVoicePlayer?.currentItem, queue: .main) { _ in
            try? FileManager.default.removeItem(at: tempURL)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
            completion()
        }
    }
}

struct ChatResponse3: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

#Preview {
    TuvaView()
}
