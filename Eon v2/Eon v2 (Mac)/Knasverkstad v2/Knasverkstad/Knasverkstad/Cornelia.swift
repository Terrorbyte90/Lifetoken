//
//  Cornelia.swift
//  Knasverkstad
//
//  Created by Ted Svärd on 2025-05-29.
//

import SwiftUI
import AVFoundation
import Speech

struct CorneliaView: View {
    @State private var messages: [String] = []
    @State private var userInput: String = ""
    @State private var isVoiceMode = false
    @State private var isRecording = false
    @State private var isPopupPresented = false
    @State private var synthesizedVoicePlayer: AVPlayer?
    @State private var showDashboard = false
    
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "sv-SE"))
    let audioEngine = AVAudioEngine()
    @State private var request = SFSpeechAudioBufferRecognitionRequest()
    @State private var recognitionTask: SFSpeechRecognitionTask?

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    VStack(spacing: 0) {
                        HStack {
                            Image("Cornelia")
                                .resizable()
                                .offset(y: 20)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 150, height: 150)
                                .clipShape(Circle())
                                .shadow(radius: 20)
                                .padding(.leading)
                                .onTapGesture {
                                    showDashboard = true
                                }

                            Text("Cornelia")
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
                            .fill(LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.6), Color.pink.opacity(0.8)]),
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
                                                Text(message.replacingOccurrences(of: "Cornelia: ", with: ""))
                                                    .padding(12)
                                                    .foregroundColor(.black)
                                                    .background(Color.pink.opacity(0.8))
                                                    .cornerRadius(20)
                                                    .shadow(radius: 4)
                                                Text("Cornelia")
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
                        .onChange(of: messages.count) {
                            withAnimation {
                                proxy.scrollTo(messages.indices.last, anchor: .bottom)
                            }
                        }
                    }

                    HStack {
                        TextField("Skriv till Cornelia...", text: $userInput)
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
                            .foregroundColor(.purple)
                    }
                    .padding(.bottom, 20)
                }
                .background(Color(.systemGroupedBackground))

                if isPopupPresented {
                    ZStack {
                        Color.black.opacity(0.8).edgesIgnoringSafeArea(.all)

                        VStack {
                            Text("Röstläge aktivt – logg")
                                .font(.headline)
                                .foregroundColor(.white)

                            ScrollView {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(messages, id: \.self) { msg in
                                        Text(msg)
                                            .foregroundColor(.white)
                                            .font(.caption)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(4)
                                            .background(Color.black.opacity(0.3))
                                            .cornerRadius(6)
                                    }
                                }
                                .padding()
                            }
                            .frame(maxHeight: 300)

                            Circle()
                                .stroke(Color.purple, lineWidth: 4)
                                .frame(width: 100, height: 100)
                                .scaleEffect(isRecording ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)
                        }
                        .padding()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                startRecording()
                                isRecording = true
                            }
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
        let input = userInput
        messages.append("Du: \(input)")
        messages.append("📤 Skickar till ElevenLabs agent: \(input)")
        userInput = ""
        Task {
            await sendToElevenLabsAgent(text: input)
            isPopupPresented = false
        }
    }

    func startRecording() {
        messages.append("🎤 startRecording() called")
        // Kontrollera mikrofontillstånd och logga detta före allt annat
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                messages.append("❌ Mikrofontillgång nekad.")
                return
            } else {
                messages.append("✅ Mikrofontillgång beviljad.")
            }
        }
        SFSpeechRecognizer.requestAuthorization { authStatus in
            guard authStatus == .authorized else { return }
            DispatchQueue.main.async {
                // Reset any previous recognition task before starting a new one
                self.recognitionTask?.cancel()
                self.recognitionTask = nil

                // Configure audio session
                let audioSession = AVAudioSession.sharedInstance()
                do {
                    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    messages.append("✅ Ljudsession aktiverad")
                } catch {
                    messages.append("❌ Fel vid aktivering av ljudsession: \(error.localizedDescription)")
                }

                // Create a fresh local recognition request before any buffer is appended
                let localRequest = SFSpeechAudioBufferRecognitionRequest()
                self.request = localRequest

                // Ersätt installTap med säkrare och loggad version
                let inputNode = audioEngine.inputNode
                inputNode.removeTap(onBus: 0)
                let recordingFormat = inputNode.outputFormat(forBus: 0)
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                    localRequest.append(buffer)
                    messages.append("🎙️ Buffert tillagd")
                }
                messages.append("🎤 installTap utförd")

                audioEngine.prepare()
                // Starta audioEngine med loggning
                do {
                    try audioEngine.start()
                    messages.append("▶️ audioEngine startad")
                    messages.append("🎧 audioEngine.isRunning: \(audioEngine.isRunning)")
                } catch {
                    messages.append("❌ Fel vid start av audioEngine: \(error.localizedDescription)")
                }

                // Logga att recognitionTask skapas
                messages.append("🧠 Startar recognitionTask")
                self.recognitionTask = self.speechRecognizer?.recognitionTask(with: localRequest) { result, error in
                    if let result = result {
                        let spokenText = result.bestTranscription.formattedString
                        // Logga det upptäckta talet
                        messages.append("🗣️ Upptäckt tal: \(spokenText)")
                        DispatchQueue.main.async {
                            self.userInput = spokenText
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                self.sendMessage()
                                self.stopRecording()
                            }
                        }
                    }
                    // Om result == nil men error != nil, logga felet på slutet
                    if let error = error {
                        messages.append("❌ Fel vid taligenkänning: \(error.localizedDescription)")
                    }
                }
                self.isRecording = true
            }
        }
    }

    func stopRecording() {
        // Always remove tap, even if audioEngine is stopped
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        messages.append("⛔️ audioEngine stoppad")
        recognitionTask?.cancel()
        recognitionTask = nil
    }


    // Skicka till ElevenLabs agent och spela upp svaret (uppdaterad för streaming AI och fallback)
    func sendToElevenLabsAgent(text: String) async {
        guard let url = URL(string: "https://api.elevenlabs.io/v1/agents/agent_01jwpkfez7fqbrparp7t94ycxk/invoke") else {
            messages.append("❌ Ogiltig ElevenLabs-agent-URL.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer sk_64b296789f8b47a7daf5e26bbf42e2c7dd7ee553663f7e99", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "text": text,
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                messages.append("❌ Kunde inte tolka ElevenLabs-agentens svar.")
                return
            }
            if let errorMsg = json["error"] as? String {
                messages.append("❌ Svar från ElevenLabs-agent: \(errorMsg)")
                return
            }

            let responseText = (json["response"] as? String) ?? ""
            messages.append("📥 Mottaget från ElevenLabs agent: \(responseText)")
            messages.append("Cornelia: \(responseText)")

            if let audioURLString = json["audio_url"] as? String, let audioURL = URL(string: audioURLString) {
                messages.append("🔊 Spelar upp ljud från audio_url.")
                await playAudio(from: audioURL)
            } else {
                messages.append("❌ Ingen ljudfil inkluderad. Kontrollera om agenten har korrekt voice-anslutning.")
            }
        } catch {
            messages.append("❌ Fel vid ElevenLabs-agent-anrop: \(error.localizedDescription)")
        }
    }

    // Spela upp ljud från angiven URL (lokal eller remote)
    func playAudio(from url: URL) async {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            messages.append("🎚️ AVAudioSession satt till playback")
        } catch {
            messages.append("❌ Fel vid inställning av AVAudioSession till playback: \(error.localizedDescription)")
        }
        DispatchQueue.main.async {
            synthesizedVoicePlayer = AVPlayer(url: url)
            synthesizedVoicePlayer?.play()
        }
    }
}

struct ChatResponse4: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

// struct ChatCorneliaResponse: Codable {
//     let handling: String
//     let konversation: String
// }

#Preview {
    CorneliaView()
}
