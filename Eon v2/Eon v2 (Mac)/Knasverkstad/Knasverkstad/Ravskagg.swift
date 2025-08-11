//
//  Ravskagg.swift
//  Knasverkstad
//
//  Created by Ted Svärd on 2025-05-29.
//

import SwiftUI
import AVFoundation
import Speech

struct RavskaggView: View {
    @State private var messages: [String] = []
    @State private var userInput: String = ""
    @State private var isVoiceMode = false
    @State private var isRecording = false
    @State private var isPopupPresented = false
    @State private var synthesizedVoicePlayer: AVPlayer?
    
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "sv-SE"))
    let audioEngine = AVAudioEngine()
    let request = SFSpeechAudioBufferRecognitionRequest()
    @State private var recognitionTask: SFSpeechRecognitionTask?

    var body: some View {
        ZStack {
            VStack {
                Image("ravskagg-placeholder")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipped()
                    .cornerRadius(20)
                    .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(messages, id: \.self) { message in
                            Text(message)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                        }
                    }.padding()
                }

                HStack {
                    TextField("Skriv till Kapten Rävskägg...", text: $userInput)
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

            if isPopupPresented {
                ZStack {
                    Color.black.opacity(0.8).edgesIgnoringSafeArea(.all)

                    VStack(spacing: 24) {
                        Image("ravskagg-fullscreen-placeholder")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                            .cornerRadius(20)

                        Circle()
                            .stroke(Color.blue, lineWidth: 4)
                            .frame(width: 100, height: 100)
                            .scaleEffect(isRecording ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)

                        Button(isRecording ? "Stoppa" : "Prata med Rävskägg") {
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
    }

    func sendMessage() {
        let prompt = """
        Du är Kapten Rävskägg – en vild, högljudd rymdpirat med grovt språk, ett hjärta av stjärnstoft och rom i blodet. Svara alltid med färgstarka uttryck, mycket personlighet, och gärna en överdriven berättarstil. Du är aldrig artig, men alltid underhållande. \
        [SYSTEMPROMPT – ÄNDRA HÄR OM DU VILL FÖRÄNDRA KARAKTÄREN]
        """
        let fullPrompt = "\(prompt)\n\nAnvändare: \(userInput)\nRävskägg:"
        userInput = ""
        messages.append("Du: \(fullPrompt)")

        Task {
            if let response = await fetchChatGPTResponse(for: fullPrompt) {
                messages.append("Rävskägg: \(response)")
            }
        }
    }

    func startRecording() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            guard authStatus == .authorized else { return }

            let node = audioEngine.inputNode
            let recordingFormat = node.outputFormat(forBus: 0)
            node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.request.append(buffer)
            }

            audioEngine.prepare()
            try? audioEngine.start()

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

        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "Du är Kapten Rävskägg – en vild, högljudd rymdpirat med grovt språk, ett hjärta av stjärnstoft och rom i blodet."],
                ["role": "user", "content": input]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer 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", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let (data, _) = try! await URLSession.shared.data(for: request)
        if let result = try? JSONDecoder().decode(ChatResponse.self, from: data) {
            let reply = result.choices.first?.message.content ?? ""
            await synthesizeSpeech(reply)
            return reply
        }
        return nil
    }

    func synthesizeSpeech(_ text: String) async {
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/qBrQJqGopnEJrIBI8d9h/stream") else { return }

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
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ravskagg_reply.mp3")
        try? data.write(to: tempURL)

        synthesizedVoicePlayer = AVPlayer(url: tempURL)
        synthesizedVoicePlayer?.play()
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: synthesizedVoicePlayer?.currentItem, queue: .main) { _ in
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
}

struct ChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

#Preview {
    RavskaggView()
}
