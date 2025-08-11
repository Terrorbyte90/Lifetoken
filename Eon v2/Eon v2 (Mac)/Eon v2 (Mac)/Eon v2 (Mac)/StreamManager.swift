//
//  StreamManager.swift
//  Eon v2 (Mac)
//
//  Created by Ted Svärd on 2025-05-22.
//


import Foundation
import Combine

public final class StreamManager: ObservableObject {

    public struct LogEntry: Identifiable, Codable {
        public let id: UUID
        public let timestamp: Date
        public let source: String
        public let message: String
        public let level: LogLevel
    }

    public enum LogLevel: String, Codable, CaseIterable {
        case debug, info, warning, critical
    }

    @Published public private(set) var logs: [LogEntry] = []
    @Published public private(set) var filteredLogs: [LogEntry] = []
    @Published public private(set) var latestLogSummary: String = ""
    @Published public var filterLevel: LogLevel? = nil {
        didSet {
            applyFilter()
        }
    }

    private let maxLogEntries = 1000

    public init() {}

    public func log(source: String, message: String, level: LogLevel = .info) {
        let entry = LogEntry(id: UUID(), timestamp: Date(), source: source, message: message, level: level)
        
        self.logs.append(entry)
        if self.logs.count > self.maxLogEntries {
            self.logs.removeFirst()
        }
        self.updateLatestLog(with: entry)
        self.applyFilter()

        if level == .critical {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .streamCriticalLog, object: self, userInfo: ["entry": entry])
            }
        }

        writeLogEntryToFile(entry)
    }

    private func updateLatestLog(with entry: LogEntry) {
        latestLogSummary = "[\(entry.level.rawValue.uppercased())] \(entry.source): \(entry.message)"
    }
    public func trimOldLogs(olderThan seconds: TimeInterval = 172800) {
        let now = Date()
        logs = logs.filter { now.timeIntervalSince($0.timestamp) < seconds }
        applyFilter()
    }

    public func logStats() -> [LogLevel: Int] {
        Dictionary(grouping: logs, by: { $0.level }).mapValues { $0.count }
    }

    public func saveLogToFile(named filename: String) {
        let summary = exportLogSummary()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? summary.write(to: url, atomically: true, encoding: .utf8)
    }

    private func applyFilter() {
        if let level = filterLevel {
            filteredLogs = logs.filter { $0.level == level }
        } else {
            filteredLogs = logs
        }
    }

    public func clearLogs() {
        logs.removeAll()
        filteredLogs.removeAll()
    }

    public func exportLogSummary() -> String {
        let summary = logs.map { "[\($0.timestamp)] \($0.level.rawValue.uppercased()) \($0.source): \($0.message)" }
        return summary.joined(separator: "\n")
    }

    public func recentCritical() -> [LogEntry] {
        return logs.filter { $0.level == .critical }.suffix(5)
    }
}

public extension Notification.Name {
    static let streamCriticalLog = Notification.Name("streamCriticalLog")
}


extension StreamManager {
    private func writeLogEntryToFile(_ entry: LogEntry) {
        let logLine = "[\(entry.timestamp)] \(entry.level.rawValue.uppercased()) \(entry.source): \(entry.message)\n"
        let fileManager = FileManager.default
        let logsDirectory = fileManager.temporaryDirectory
        let fileURL = logsDirectory.appendingPathComponent("EonLog_\(formattedDate()).txt")
        print("📁 Loggfilens sökväg: \(fileURL.path)")

        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            fileHandle.seekToEndOfFile()
            if let data = logLine.data(using: String.Encoding.utf8) {
                fileHandle.write(data)
            }
            try? fileHandle.close()
        } else {
            try? logLine.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
