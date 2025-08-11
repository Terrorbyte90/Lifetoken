//
//  MemoryViewer.swift
//  Eon v2 (Mac)
//
//  Created by Ted Svärd on 2025-05-22.
//

import Foundation
import SwiftUI

public struct MemoryViewer: View {

    @ObservedObject var memoryStream: MemoryStream
    @State private var searchText: String = ""
    @State private var minRelevance: Double = 0.0

    public init(memoryStream: MemoryStream) {
        self.memoryStream = memoryStream
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Text("🧠 Eons Minnen")
                .font(.largeTitle)
                .bold()
                .padding(.bottom, 10)

            if memoryStream.memoryEntries.isEmpty {
                Text("Inga minnen ännu.")
                    .foregroundColor(.gray)
            } else {
                TextField("Sök i minnen...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, 5)

                HStack {
                    Text("Min relevans: \(String(format: "%.1f", minRelevance))")
                    Slider(value: $minRelevance, in: 0...1)
                }
                .padding(.bottom, 5)

                let filteredEntries = memoryStream.memoryEntries.reversed().filter {
                    (searchText.isEmpty || $0.content.localizedCaseInsensitiveContains(searchText)) &&
                    $0.relevance >= minRelevance
                }

                List {
                    ForEach(filteredEntries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("📌 \(entry.timestamp.formatted())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(entry.content)
                                .font(.body)
                            HStack {
                                Text("Källa: \(entry.source)")
                                Spacer()
                                Text("Känsla: \(entry.emotionalTag.rawValue.capitalized)")
                                Text("Relevans: \(String(format: "%.2f", entry.relevance))")
                                Text("Kategori: \(entry.category.rawValue.capitalized)")
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(entry.content, forType: .string)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.blue)
                                        .help("Kopiera minne")
                                }
                            }
                            .font(.caption2)
                            .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Divider().padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 4) {
                Text("Senaste insikt:")
                    .font(.headline)
                Text(memoryStream.lastInsight ?? "Ingen insikt genererad ännu.")
                    .italic()
            }

            Spacer()
        }
        .padding()
    }
}
