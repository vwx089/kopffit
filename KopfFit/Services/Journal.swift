import Foundation

/// Eine einzelne beantwortete Aufgabe, so ausführlich wie möglich,
/// damit spätere Statistiken auch rückwirkend berechnet werden können.
struct AttemptLog: Codable {
    let time: Date
    let day: String          // Tag, an dem die Runde gestartet wurde
    let mode: String         // "arithmetic" oder "memory"
    let level: Int           // Rechen-Level beim Stellen der Aufgabe
    let span: Int?           // Länge der Zahlenreihe (nur "memory")
    let task: String         // z. B. "38 × 7" oder die Zahlenreihe
    let expected: String
    let given: String
    let correct: Bool
    let skipped: Bool
    let seconds: Double      // Zeit vom Erscheinen bis zur Antwort (ohne Tipp-Lesezeit)
    var hint: Bool? = nil    // Tipp angesehen (nur "arithmetic", fehlt bei alten Einträgen)
}

/// Zusammenfassung einer kompletten Runde.
struct SessionLog: Codable {
    let day: String
    let started: Date
    let ended: Date
    let plannedMinutes: Int
    let idleSeconds: Int     // Sekunden, in denen die Uhr wegen Untätigkeit stand
    let pausedSeconds: Int   // Sekunden, in denen die App im Hintergrund war
    let solved: Int
    let correct: Int
    let startLevel: Int
    let endLevel: Int
    let startSpan: Int
    let endSpan: Int
    var hintsUsed: Int? = nil   // Aufgaben, bei denen ein Tipp angesehen wurde
    var hintSeconds: Int? = nil // Sekunden mit offenem Tipp (Uhr stand)
}

/// Hängt Einträge zeilenweise (JSON Lines) an Dateien in "Application Support" an.
enum Journal {
    static let attemptsFile = "attempts.jsonl"
    static let sessionsFile = "sessions.jsonl"

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static func append<T: Encodable>(_ entry: T, to file: String) {
        guard var data = try? encoder.encode(entry) else { return }
        data.append(0x0A)
        let url = directory.appendingPathComponent(file)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func read<T: Decodable>(_ type: T.Type, from file: String) -> [T] {
        guard let text = try? String(contentsOf: directory.appendingPathComponent(file), encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return text.split(separator: "\n").compactMap { try? decoder.decode(T.self, from: Data($0.utf8)) }
    }

    private static var directory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Journal", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
