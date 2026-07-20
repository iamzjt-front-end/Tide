import Foundation

enum PomodoroExportFormat: String, CaseIterable, Identifiable {
  case csv
  case json

  var id: Self { self }
  var fileExtension: String { rawValue }
  var title: String { rawValue.uppercased() }
}

enum PomodoroExportService {
  private struct JSONExport: Encodable {
    var schemaVersion: Int
    var exportedAt: Date
    var sessions: [FocusSession]
    var rounds: [PomodoroRoundRecord]
  }

  static func data(
    for archive: PomodoroArchive,
    format: PomodoroExportFormat,
    now: Date = .now
  ) throws -> Data {
    switch format {
    case .json:
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      encoder.dateEncodingStrategy = .iso8601
      return try encoder.encode(JSONExport(
        schemaVersion: archive.schemaVersion,
        exportedAt: now,
        sessions: archive.sessions,
        rounds: archive.roundRecords
      ))
    case .csv:
      let formatter = ISO8601DateFormatter()
      var rows = [
        "run_id,started_at,ended_at,duration_seconds,planned_seconds,outcome,category,tag"
      ]
      rows += archive.sessions.map { session in
        [
          session.runID.uuidString,
          formatter.string(from: session.startedAt),
          formatter.string(from: session.endedAt),
          String(session.durationSeconds),
          String(session.plannedSeconds),
          session.outcome.rawValue,
          session.categoryName ?? "",
          session.tagName ?? "",
        ].map(csvEscape).joined(separator: ",")
      }
      return Data(rows.joined(separator: "\n").utf8)
    }
  }

  private static func csvEscape(_ value: String) -> String {
    guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")
    else { return value }
    return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
  }
}
