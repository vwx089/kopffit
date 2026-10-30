import Foundation

/// Eine einzelne Kopfrechenaufgabe. Alle Ergebnisse sind ganze Zahlen >= 0,
/// damit die Eingabe über ein reines Ziffern-Keypad funktioniert.
struct Problem: Equatable {
    let text: String
    let answer: Int

    var answerDigits: Int { String(answer).count }
}

/// Erzeugt Aufgaben passend zum Schwierigkeitslevel (1...maxLevel).
enum ProblemGenerator {
    static let maxLevel = 10

    static let levelNames: [Int: String] = [
        1: "Plus & Minus bis 20",
        2: "Plus & Minus bis 100",
        3: "Kleines Einmaleins",
        4: "Zweistellig ± zweistellig",
        5: "Geteilt durch",
        6: "Zweistellig × einstellig",
        7: "Dreistellig ± zweistellig",
        8: "Gemischte Ketten",
        9: "Zweistellig × zweistellig",
        10: "Prozent & Quadratzahlen",
    ]

    /// 70 % aktuelles Level, 30 % ein Level darunter, damit es abwechslungsreich bleibt.
    static func make(level: Int) -> Problem {
        let clamped = min(max(level, 1), maxLevel)
        let chosen = (clamped > 1 && Int.random(in: 0..<10) < 3) ? clamped - 1 : clamped
        return make(exactLevel: chosen)
    }

    static func make(exactLevel level: Int) -> Problem {
        switch level {
        case 1:
            if Bool.random() {
                let a = Int.random(in: 2...12), b = Int.random(in: 2...9)
                return Problem(text: "\(a) + \(b)", answer: a + b)
            } else {
                let a = Int.random(in: 6...20), b = Int.random(in: 1...min(9, a))
                return Problem(text: "\(a) − \(b)", answer: a - b)
            }
        case 2:
            if Bool.random() {
                let a = Int.random(in: 12...89), b = Int.random(in: 3...9)
                return Problem(text: "\(a) + \(b)", answer: a + b)
            } else {
                let a = Int.random(in: 21...99), b = Int.random(in: 3...9)
                return Problem(text: "\(a) − \(b)", answer: a - b)
            }
        case 3:
            let a = Int.random(in: 2...10), b = Int.random(in: 3...10)
            return Problem(text: "\(a) × \(b)", answer: a * b)
        case 4:
            if Bool.random() {
                let a = Int.random(in: 13...89), b = Int.random(in: 11...(99 - a + 11))
                return Problem(text: "\(a) + \(b)", answer: a + b)
            } else {
                let a = Int.random(in: 31...99), b = Int.random(in: 11...(a - 5))
                return Problem(text: "\(a) − \(b)", answer: a - b)
            }
        case 5:
            let b = Int.random(in: 3...10), q = Int.random(in: 3...10)
            return Problem(text: "\(b * q) ÷ \(b)", answer: q)
        case 6:
            let a = Int.random(in: 12...49), b = Int.random(in: 3...9)
            return Problem(text: "\(a) × \(b)", answer: a * b)
        case 7:
            if Bool.random() {
                let a = Int.random(in: 120...899), b = Int.random(in: 13...99)
                return Problem(text: "\(a) + \(b)", answer: a + b)
            } else {
                let a = Int.random(in: 120...999), b = Int.random(in: 13...99)
                return Problem(text: "\(a) − \(b)", answer: a - b)
            }
        case 8:
            let a = Int.random(in: 3...9), b = Int.random(in: 3...9), c = Int.random(in: 5...40)
            if Bool.random() {
                return Problem(text: "\(a) × \(b) + \(c)", answer: a * b + c)
            } else {
                let c2 = Int.random(in: 1...(a * b))
                return Problem(text: "\(a) × \(b) − \(c2)", answer: a * b - c2)
            }
        case 9:
            let a = Int.random(in: 11...29), b = Int.random(in: 11...19)
            return Problem(text: "\(a) × \(b)", answer: a * b)
        default:
            if Bool.random() {
                let n = Int.random(in: 11...25)
                return Problem(text: "\(n)²", answer: n * n)
            } else {
                // Prozentsatz und Grundwert so wählen, dass ein ganzzahliges Ergebnis herauskommt.
                let options: [(p: Int, step: Int)] = [(10, 10), (20, 5), (25, 4), (50, 2), (75, 4), (5, 20), (15, 20)]
                let o = options.randomElement()!
                let n = o.step * Int.random(in: 2...(400 / o.step))
                return Problem(text: "\(o.p) % von \(n)", answer: n * o.p / 100)
            }
        }
    }
}
