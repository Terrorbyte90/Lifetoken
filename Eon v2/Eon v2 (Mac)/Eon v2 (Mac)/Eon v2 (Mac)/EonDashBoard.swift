import SwiftUI

public struct EonDashboard: View {
    @ObservedObject var dialogueCore: DialogueCore
    @StateObject var memoryStream: MemoryStream
    @StateObject var streamManager: StreamManager
    @ObservedObject var selfNarrative: SelfNarrative
    @ObservedObject var identityManifest: IdentityManifest
    @ObservedObject var securityCore: SecurityCore
    @ObservedObject var evolutionLoop: EvolutionLoop

    @State private var userInput: String = ""

    public init(dialogueCore: DialogueCore,
                memoryStream: MemoryStream,
                streamManager: StreamManager,
                selfNarrative: SelfNarrative,
                identityManifest: IdentityManifest,
                securityCore: SecurityCore,
                evolutionLoop: EvolutionLoop) {
        self.dialogueCore = dialogueCore
        self._memoryStream = StateObject(wrappedValue: memoryStream)
        self._streamManager = StateObject(wrappedValue: streamManager)
        self.selfNarrative = selfNarrative
        self.identityManifest = identityManifest
        self.securityCore = securityCore
        self.evolutionLoop = evolutionLoop
    }

    public var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("🧠 Eon Dashboard")
                    .font(.largeTitle).bold()

                GroupBox(label: Text("📌 Identitet & Syfte")) {
                    Text(identityManifest.fullIdentity())
                        .font(.callout)
                        .padding(4)
                }

                GroupBox(label: Text("🔐 Sandboxmedvetenhet")) {
                    VStack(alignment: .leading, spacing: 4) {
                        let reflection = securityCore.currentReflection()
                        Text("Status: \(securityCore.sandboxStatus)")
                        Text("Reflektion: \(reflection)")
                    }
                    .font(.caption)
                }

                GroupBox(label: Text("📈 Utveckling")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Versioner: \(evolutionLoop.versionCount)")
                        Text("Senaste förbättring: \(evolutionLoop.lastImprovement ?? "Inget ännu")")
                    }
                    .font(.caption)
                }

                GroupBox(label: Text("🧩 Senaste insikt")) {
                    Text(memoryStream.lastInsight ?? "Ingen insikt ännu.")
                        .italic()
                        .font(.caption)
                }

                Spacer()
            }
            .frame(minWidth: 300, maxWidth: 350)
            .padding()

            VStack(spacing: 10) {
                GroupBox(label: Text("💬 Dialog med Eon")) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(dialogueCore.dialogueHistory.reversed()) { entry in
                                VStack(alignment: .leading) {
                                    Text("🗣 \(entry.sender.rawValue.capitalized): \(entry.message)")
                                        .font(.body)
                                    if let emotion = entry.emotionDetected {
                                        Text("Emotion: \(emotion.rawValue.capitalized)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                        }
                    }
                    .frame(minHeight: 200)
                }

                HStack {
                    TextField("Skriv till Eon...", text: $userInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Skicka") {
                        let message = userInput
                        userInput = ""
                        DispatchQueue.global(qos: .userInitiated).async {
                            dialogueCore.receiveUserMessage(message)
                        }
                    }
                }

                GroupBox(label: Text("📚 Minneslogg (senaste)")) {
                    ScrollView {
                        ForEach(memoryStream.memoryEntries.suffix(5).reversed()) { entry in
                            VStack(alignment: .leading) {
                                Text(entry.content)
                                Text("🔸 \(entry.category.rawValue.capitalized), \(entry.emotionalTag.rawValue), \(String(format: "%.2f", entry.relevance))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Divider()
                        }
                    }
                    .frame(maxHeight: 160)
                }

                GroupBox(label: Text("📄 Systemlogg")) {
                    ScrollView {
                        ForEach(streamManager.filteredLogs.suffix(5)) { log in
                            Text("[\(log.level.rawValue.uppercased())] \(log.source): \(log.message)")
                                .font(.caption)
                        }
                    }
                    .frame(maxHeight: 120)
                }

                GroupBox(label: Text("📖 Självberättelse")) {
                    Text(selfNarrative.narrativeSummary)
                        .font(.footnote)
                        .padding(4)
                }

                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
}
#if DEBUG
struct EonDashboard_Previews: PreviewProvider {
    static var previews: some View {
        EonDashboard(
            dialogueCore: DialogueCore(),
            memoryStream: MemoryStream(),
            streamManager: StreamManager(),
            selfNarrative: SelfNarrative(),
            identityManifest: IdentityManifest(),
            securityCore: SecurityCore(),
            evolutionLoop: EvolutionLoop()
        )
    }
}
#endif
