import Foundation
import SwiftUI

struct DayRecord: Codable, Identifiable, Equatable {
    var id: String { day }
    let day: String          // "yyyy-MM-dd"
    var solved: Int
    var correct: Int
    var endLevel: Int
}

struct ReminderSettings: Codable, Equatable {
    /// Ab wann genervt wird (Minuten seit Mitternacht).
    var startMinute: Int = 9 * 60
    /// Bis wann genervt wird (Minuten seit Mitternacht).
    var endMinute: Int = 22 * 60
    /// Abstand zwischen zwei Erinnerungen in Minuten.
    var intervalMinutes: Int = 30
    /// Dauer der Tagesübung in Minuten.
    var sessionMinutes: Int = 5
}

/// Hält Fortschritt, Serie und Einstellungen und speichert alles in UserDefaults.
@MainActor
final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    @Published private(set) var history: [DayRecord] = []
    @Published private(set) var level: Int = 1
    /// Länge der Zahlenreihe beim "Zahlen merken".
    @Published private(set) var memorySpan: Int = 4
    @Published var settings = ReminderSettings() {
        didSet { save(); ReminderScheduler.reschedule(store: self) }
    }
    /// Wird gesetzt, wenn der Nutzer auf eine Erinnerung tippt: dann startet die Übung sofort.
    @Published var startRequested = false

    private let defaults = UserDefaults.standard
    private let key = "kopffit.state.v1"

    private struct Persisted: Codable {
        var history: [DayRecord]
        var level: Int
        var settings: ReminderSettings
        var memorySpan: Int?
    }

    private init() {
        if let data = defaults.data(forKey: key),
           let state = try? JSONDecoder().decode(Persisted.self, from: data) {
            history = state.history
            level = state.level
            settings = state.settings
            memorySpan = state.memorySpan ?? 4
        }
    }

    private func save() {
        let state = Persisted(history: history, level: level, settings: settings, memorySpan: memorySpan)
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: key)
        }
    }

    // MARK: - Tage & Serie

    static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    var completedDays: Set<String> { Set(history.map(\.day)) }

    var doneToday: Bool { completedDays.contains(Self.dayKey()) }

    var todayRecord: DayRecord? { history.first { $0.day == Self.dayKey() } }

    /// Aktuelle Serie. Ist heute noch offen, zählt die Serie bis gestern (sie ist noch nicht verloren).
    var currentStreak: Int {
        let days = completedDays
        let cal = Calendar.current
        var date = Date()
        if !days.contains(Self.dayKey(date)) {
            date = cal.date(byAdding: .day, value: -1, to: date)!
        }
        var count = 0
        while days.contains(Self.dayKey(date)) {
            count += 1
            date = cal.date(byAdding: .day, value: -1, to: date)!
        }
        return count
    }

    var bestStreak: Int {
        let cal = Calendar.current
        let dates = completedDays.compactMap { key -> Date? in
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            return cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        }.sorted()
        var best = 0, run = 0
        var previous: Date?
        for d in dates {
            if let p = previous, cal.dateComponents([.day], from: p, to: d).day == 1 {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = d
        }
        return best
    }

    /// Die letzten 7 Tage (älteste zuerst) mit Erledigt-Status.
    var lastSevenDays: [(date: Date, done: Bool)] {
        let cal = Calendar.current
        let days = completedDays
        return (0..<7).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: Date())!
            return (d, days.contains(Self.dayKey(d)))
        }
    }

    // MARK: - Übung abschließen

    /// Startlevel für die nächste Übung: ein Level unter dem letzten Ende als Aufwärmen.
    var startLevel: Int { max(1, level - 1) }

    var startSpan: Int { max(SessionModel.minSpan, memorySpan - 1) }

    /// Macht den heutigen Tag wieder "offen" und plant die Erinnerungen neu.
    func resetToday() {
        history.removeAll { $0.day == Self.dayKey() }
        save()
        ReminderScheduler.reschedule(store: self)
    }

    func recordSession(day: String, solved: Int, correct: Int, endLevel: Int, endSpan: Int) {
        memorySpan = endSpan
        if let i = history.firstIndex(where: { $0.day == day }) {
            history[i].solved += solved
            history[i].correct += correct
            history[i].endLevel = endLevel
        } else {
            history.append(DayRecord(day: day, solved: solved, correct: correct, endLevel: endLevel))
        }
        level = endLevel
        save()
        ReminderScheduler.markTodayDone(store: self)
    }
}
