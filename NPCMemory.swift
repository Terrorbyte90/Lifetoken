import Foundation

enum NPCInteractionType: String, Codable {
    case loanDefaulted
    case pvpDefeat
    case loanRepaid
}

enum NPCDialogTone: Equatable {
    case neutral, positive, negative
}

struct NPCMemoryRecord: Codable {
    let npcID: String
    let interactionType: NPCInteractionType
    let occurredAt: Date
    var avoidUntil: Date?
}

@MainActor
final class NPCMemoryStore: ObservableObject {
    static let shared = NPCMemoryStore()

    private var records: [String: [NPCMemoryRecord]] = [:]
    private let filename = "npc_memory.json"

    init() { load() }

    func record(npcID: String, type: NPCInteractionType) {
        var avoidUntil: Date? = nil
        if type == .pvpDefeat {
            avoidUntil = Date.now.addingTimeInterval(48 * 3600)
        }
        let record = NPCMemoryRecord(npcID: npcID, interactionType: type, occurredAt: .now, avoidUntil: avoidUntil)
        records[npcID, default: []].append(record)
        save()
    }

    // Testing helper — allows injecting past dates
    func recordForTesting(npcID: String, type: NPCInteractionType, avoidUntil: Date?) {
        let r = NPCMemoryRecord(npcID: npcID, interactionType: type, occurredAt: .now, avoidUntil: avoidUntil)
        records[npcID, default: []].append(r)
    }

    func isAvoiding(npcID: String) -> Bool {
        records[npcID]?.last(where: { $0.avoidUntil != nil })
            .map { $0.avoidUntil! > Date.now } ?? false
    }

    func dialogTone(for npcID: String) -> NPCDialogTone {
        guard let last = records[npcID]?.last else { return .neutral }
        switch last.interactionType {
        case .loanDefaulted: return .negative
        case .pvpDefeat: return .negative
        case .loanRepaid: return .positive
        }
    }

    private func save() {
        guard let url = documentsURL else { return }
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: url)
        }
    }

    private func load() {
        guard let url = documentsURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [NPCMemoryRecord]].self, from: data)
        else { return }
        records = decoded
    }

    private var documentsURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(filename)
    }
}
