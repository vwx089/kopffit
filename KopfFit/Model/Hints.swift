import Foundation

/// Ein Tipp zu einer Aufgabe: allgemeine Vorgehensweise, optional eine Eselsbrücke,
/// und ein Lösungsweg mit den konkreten Zahlen (ohne das Endergebnis zu verraten).
struct Hint {
    let title: String
    let tips: [String]
    var mnemonic: String? = nil
    let walkthrough: [String]
}

extension Problem {
    var hint: Hint { Hints.make(for: self) }
}

enum Hints {
    static func make(for p: Problem) -> Hint {
        let o = p.operands
        switch p.kind {
        case .addition: return addition(o[0], o[1])
        case .subtraction: return subtraction(o[0], o[1])
        case .multiplication:
            if o[0] <= 10 && o[1] <= 10 { return smallTimes(o[0], o[1]) }
            if o[1] <= 9 { return bigTimesSmall(o[0], o[1]) }
            return bigTimesBig(o[0], o[1])
        case .division: return division(o[0], o[1])
        case .chainPlus: return chain(o[0], o[1], o[2], plus: true)
        case .chainMinus: return chain(o[0], o[1], o[2], plus: false)
        case .square: return square(o[0])
        case .percent: return percent(o[0], o[1])
        }
    }

    // MARK: - Plus

    private static func addition(_ a: Int, _ b: Int) -> Hint {
        if b < 10 {
            let toTen = (10 - a % 10) % 10
            if toTen > 0 && b > toTen {
                return Hint(
                    title: "Plus über den Zehner",
                    tips: [
                        "Springe zuerst bis zum nächsten vollen Zehner.",
                        "Dann zählst du den Rest dazu. Volle Zehner sind für den Kopf viel leichter.",
                    ],
                    mnemonic: "Zehnerfreunde: 1+9, 2+8, 3+7, 4+6, 5+5. Die Ergänzung zum Zehner sofort sehen.",
                    walkthrough: [
                        "\(b) zerlegen in \(toTen) + \(b - toTen)",
                        "\(a) + \(toTen) = \(a + toTen)",
                        "Jetzt noch \(a + toTen) + \(b - toTen)",
                    ])
            }
            return Hint(
                title: "Plus ohne Zehnerübergang",
                tips: [
                    "Die Zehner bleiben gleich, nur die Einer ändern sich.",
                    "Rechne nur Einer + Einer und setze die Zehner davor.",
                ],
                walkthrough: [
                    "Einer: \(a % 10) + \(b) = \(a % 10 + b)",
                    a >= 10 ? "Die \(a / 10 * 10) bleiben, Einer dahinter setzen" : "Fertig, die Einer sind schon das Ergebnis",
                ])
        }
        // Mehrstellig plus zweistellig
        let tens = b / 10 * 10, ones = b % 10
        var tips = [
            "Erst die Zehner dazu, dann die Einer. Die erste Zahl bleibt dabei ganz.",
            "Schreib nichts im Kopf untereinander, sondern rechne von links nach rechts.",
        ]
        var walk = [
            "\(b) zerlegen in \(tens) + \(ones)",
            "\(a) + \(tens) = \(a + tens)",
            "Jetzt noch \(a + tens) + \(ones)",
        ]
        if ones >= 8 {
            let up = tens + 10
            tips.append("Endet eine Zahl auf 8 oder 9, ist Runden und Ausgleichen oft schneller.")
            walk.append("Oder: \(a) + \(up) = \(a + up), dann \(up - b) wieder weg")
        }
        return Hint(title: "Plus mit Zehnern", tips: tips, walkthrough: walk)
    }

    // MARK: - Minus

    private static func subtraction(_ a: Int, _ b: Int) -> Hint {
        if b < 10 {
            let aOnes = a % 10
            if b > aOnes && a >= 10 {
                return Hint(
                    title: "Minus über den Zehner",
                    tips: [
                        "Zieh zuerst so viel ab, dass du genau auf dem vollen Zehner landest.",
                        "Dann ziehst du den Rest vom Zehner ab.",
                    ],
                    mnemonic: "Vom Zehner aus rückwärts denken: 10 − 4 ist die Zehnerfreundin von 4, also 6.",
                    walkthrough: [
                        "\(b) zerlegen in \(aOnes) + \(b - aOnes)",
                        "\(a) − \(aOnes) = \(a - aOnes)",
                        "Jetzt noch \(a - aOnes) − \(b - aOnes)",
                    ])
            }
            return Hint(
                title: "Minus ohne Zehnerübergang",
                tips: [
                    "Die Zehner bleiben gleich, nur die Einer werden kleiner.",
                ],
                walkthrough: [
                    "Einer: \(aOnes) − \(b) = \(aOnes - b)",
                    a >= 10 ? "Die \(a / 10 * 10) bleiben, Einer dahinter setzen" : "Fertig, das ist schon das Ergebnis",
                ])
        }
        let tens = b / 10 * 10, ones = b % 10
        var tips = [
            "Erst die Zehner abziehen, dann die Einer.",
            "Liegen beide Zahlen nah beieinander, ist Ergänzen leichter: Von der kleinen Zahl zur großen hochzählen.",
        ]
        var walk = [
            "\(b) zerlegen in \(tens) + \(ones)",
            "\(a) − \(tens) = \(a - tens)",
            "Jetzt noch \(a - tens) − \(ones)",
        ]
        if ones >= 8 {
            let up = tens + 10
            tips.append("Endet die abgezogene Zahl auf 8 oder 9: großzügig abziehen und zurückgeben.")
            walk.append("Oder: \(a) − \(up) = \(a - up), dann \(up - b) wieder dazu")
        } else if a - b < 20 {
            walk.append("Oder ergänzen: Von \(b) bis \(a) hochzählen, wie viel fehlt?")
        }
        return Hint(title: "Minus mit Zehnern", tips: tips, walkthrough: walk)
    }

    // MARK: - Mal

    /// Kleines Einmaleins: über eine leichte Reihe gehen.
    private static func smallTimes(_ a: Int, _ b: Int) -> Hint {
        let general = [
            "Tauschen ist erlaubt: 3 × 8 ist dasselbe wie 8 × 3. Nimm die Reihe, die dir leichter fällt.",
            "Leichte Anker: × 2 verdoppeln, × 5 ist die Hälfte von × 10, × 10 eine Null anhängen.",
        ]
        // Der leichteste Faktor bestimmt den Trick.
        let order = [10, 5, 2, 9, 4, 3, 6, 8, 7]
        let f = order.first(where: { $0 == a || $0 == b }) ?? b
        let other = f == a ? b : a

        if a == b {
            return Hint(title: "Quadratzahl", tips: general + ["Quadratzahlen bis 10 × 10 lohnen sich zum Auswendiglernen, sie tauchen ständig auf."],
                        mnemonic: mnemonic(a, b),
                        walkthrough: trick(f, other))
        }
        return Hint(title: "Kleines Einmaleins", tips: general, mnemonic: mnemonic(a, b), walkthrough: trick(f, other))
    }

    private static func trick(_ f: Int, _ n: Int) -> [String] {
        switch f {
        case 10: return ["Mal 10: einfach eine Null an \(n) anhängen"]
        case 5: return ["Mal 5 ist die Hälfte von mal 10", "\(n) × 10 = \(n * 10)", "Jetzt noch \(n * 10) halbieren"]
        case 2: return ["Mal 2 heißt verdoppeln", "\(n) + \(n) rechnen"]
        case 9: return ["Mal 9 ist mal 10 minus einmal", "\(n) × 10 = \(n * 10)", "Jetzt noch \(n * 10) − \(n)"]
        case 4: return ["Mal 4 heißt zweimal verdoppeln", "\(n) verdoppelt = \(n * 2)", "Jetzt \(n * 2) noch einmal verdoppeln"]
        case 3: return ["Mal 3 ist verdoppeln plus einmal", "\(n) × 2 = \(n * 2)", "Jetzt noch \(n * 2) + \(n)"]
        case 6: return ["Mal 6 ist mal 5 plus einmal", "\(n) × 5 = \(n * 5)", "Jetzt noch \(n * 5) + \(n)"]
        case 8: return ["Mal 8 heißt dreimal verdoppeln", "\(n) → \(n * 2) → \(n * 4)", "Jetzt \(n * 4) noch einmal verdoppeln"]
        default: return ["Mal 7 ist mal 5 plus mal 2", "\(n) × 5 = \(n * 5) und \(n) × 2 = \(n * 2)", "Jetzt \(n * 5) + \(n * 2)"]
        }
    }

    /// Bekannte Eselsbrücken für die kniffligen Aufgaben.
    private static func mnemonic(_ a: Int, _ b: Int) -> String? {
        let pair = Set([a, b])
        if pair == [7, 8] { return "5, 6, 7, 8: 56 = 7 × 8. Die Ziffern stehen der Reihe nach." }
        if pair == [3, 4] { return "1, 2, 3, 4: 12 = 3 × 4. Auch hier der Reihe nach." }
        if pair == [6, 7] { return "Merksatz: „Sechs mal sieben ist 42, die Antwort auf alles.“" }
        if pair == [8] { return "Ein Schachbrett hat 8 × 8 Felder, also 64." }
        if pair.contains(9) {
            let n = a == 9 ? b : a
            if n <= 10 {
                return "Fingertrick für die 9er-Reihe: Alle 10 Finger hoch, den \(n). Finger einknicken. Finger links davon sind die Zehner, rechts davon die Einer. Und die Quersumme ist immer 9."
            }
        }
        return nil
    }

    private static func bigTimesSmall(_ a: Int, _ b: Int) -> Hint {
        let tens = a / 10 * 10, ones = a % 10
        if ones == 0 {
            return Hint(title: "Zehnerzahl mal einstellig", tips: ["Rechne ohne die Null und häng sie am Ende wieder an."],
                        walkthrough: ["\(a / 10) × \(b) = \(a / 10 * b)", "Jetzt die Null wieder anhängen"])
        }
        var walk = [
            "\(a) zerlegen in \(tens) + \(ones)",
            "\(tens) × \(b) = \(tens * b)",
            "\(ones) × \(b) = \(ones * b)",
            "Jetzt \(tens * b) + \(ones * b)",
        ]
        var tips = [
            "Zerlege die große Zahl in Zehner und Einer und nimm beide einzeln mal.",
            "Zuerst die Zehner rechnen und merken, dann die Einer dazu.",
        ]
        if ones >= 8 {
            let up = tens + 10
            tips.append("Endet die Zahl auf 8 oder 9, geht es oft schneller mit Aufrunden und Abziehen.")
            walk.append("Oder: \(up) × \(b) = \(up * b), dann \(up - a) × \(b) = \((up - a) * b) wieder weg")
        }
        if b == 5 {
            tips.append("Mal 5: mal 10 rechnen und halbieren.")
        }
        return Hint(title: "Zweistellig mal einstellig", tips: tips, walkthrough: walk)
    }

    private static func bigTimesBig(_ a: Int, _ b: Int) -> Hint {
        if a == 11 || b == 11 {
            let n = a == 11 ? b : a
            if n < 100 && n >= 10 {
                let d1 = n / 10, d2 = n % 10
                return Hint(
                    title: "Mal 11",
                    tips: ["Mal 11 heißt: mal 10 plus einmal.",
                           "Bei zweistelligen Zahlen geht's noch schneller mit dem Ziffern-Trick."],
                    mnemonic: "Ziffern auseinanderziehen, ihre Summe in die Mitte. Ist die Summe 10 oder mehr, den Zehner nach vorne übertragen.",
                    walkthrough: [
                        "Ziffern \(d1) und \(d2) auseinanderziehen: \(d1) _ \(d2)",
                        "In die Mitte kommt \(d1) + \(d2) = \(d1 + d2)",
                        d1 + d2 >= 10 ? "Die 1 vom Zehner wandert nach vorne zur \(d1)" : "Zahl zusammensetzen",
                    ])
            }
        }
        if (11...19).contains(a) && (11...19).contains(b) {
            let aOnes = a % 10, bOnes = b % 10
            return Hint(
                title: "Zehnerzahl mal Zehnerzahl",
                tips: [
                    "Zerlege eine Zahl und rechne zwei leichte Teilaufgaben.",
                    "Bei zwei Zahlen zwischen 11 und 19 gibt es einen schnellen Trick.",
                ],
                mnemonic: "Trick für 11–19: Erste Zahl plus Einer der zweiten, mal 10. Dann Einer mal Einer dazu.",
                walkthrough: [
                    "\(a) + \(bOnes) = \(a + bOnes), mal 10 = \((a + bOnes) * 10)",
                    "Einer mal Einer: \(aOnes) × \(bOnes) = \(aOnes * bOnes)",
                    "Jetzt \((a + bOnes) * 10) + \(aOnes * bOnes)",
                ])
        }
        // a 11...29, b 11...19: b in 10 + Einer zerlegen
        let bTens = b / 10 * 10, bOnes = b % 10
        return Hint(
            title: "Zweistellig mal zweistellig",
            tips: [
                "Zerlege die kleinere Zahl in Zehner und Einer.",
                "Mal 10 ist leicht (Null anhängen), den Rest rechnest du extra und zählst zusammen.",
            ],
            walkthrough: [
                "\(b) zerlegen in \(bTens) + \(bOnes)",
                "\(a) × \(bTens) = \(a * bTens)",
                "\(a) × \(bOnes) = \(a * bOnes)",
                "Jetzt \(a * bTens) + \(a * bOnes)",
            ])
    }

    // MARK: - Geteilt

    private static func division(_ n: Int, _ d: Int) -> Hint {
        var tips = [
            "Dreh die Aufgabe um: Welche Zahl mal \(d) ergibt \(n)?",
            "Taste dich mit einem leichten Anker heran, zum Beispiel 5 × \(d) oder 10 × \(d).",
        ]
        var mnemonic: String?
        switch d {
        case 2: tips.append("Geteilt durch 2 heißt halbieren.")
        case 4: tips.append("Geteilt durch 4 heißt zweimal halbieren.")
        case 5: mnemonic = "Durch 5 teilen: Zahl verdoppeln und dann durch 10 teilen."
        case 10: tips.append("Durch 10 teilen: die Null hinten wegstreichen.")
        default: break
        }
        let five = 5 * d
        let walk: [String]
        if d == 10 {
            walk = ["Bei \(n) die Null hinten wegnehmen"]
        } else if n == five {
            walk = ["Anker: 5 × \(d) = \(five). Passt genau!"]
        } else if n > five {
            walk = ["Anker: 5 × \(d) = \(five)",
                    "Es fehlen noch \(n) − \(five) = \(n - five)",
                    "Wie oft passt \(d) in \(n - five)? Das zu 5 dazuzählen"]
        } else {
            walk = ["Anker: 5 × \(d) = \(five), das ist zu viel",
                    "Es ist \(five - n) zu viel",
                    "Wie oft passt \(d) in \(five - n)? Das von 5 abziehen"]
        }
        return Hint(title: "Geteilt durch", tips: tips, mnemonic: mnemonic, walkthrough: walk)
    }

    // MARK: - Ketten

    private static func chain(_ a: Int, _ b: Int, _ c: Int, plus: Bool) -> Hint {
        let product = a * b
        let sign = plus ? "+" : "−"
        let rest: String
        if plus {
            let toTen = (10 - product % 10) % 10
            rest = c % 10 > toTen && toTen > 0
                ? "Tipp für \(product) + \(c): Erst die Zehner dazu, dann über den nächsten Zehner springen"
                : "Jetzt \(product) + \(c): Zehner zuerst, dann die Einer"
        } else {
            rest = "Jetzt \(product) − \(c): Zehner zuerst abziehen, dann die Einer"
        }
        return Hint(
            title: "Punkt vor Strich",
            tips: [
                "Erst das Malnehmen, dann Plus oder Minus.",
                "Das Zwischenergebnis einmal leise vorsagen, dann bleibt es besser im Kopf.",
            ],
            mnemonic: "Punkt vor Strich: Die Punkte (× und ÷) sind stärker als die Striche (+ und −).",
            walkthrough: [
                "Zuerst \(a) × \(b) = \(product)",
                "Dann \(sign) \(c)",
                rest,
            ])
    }

    // MARK: - Quadrat & Prozent

    private static func square(_ n: Int) -> Hint {
        var tips = [
            "Runde auf den nächsten Zehner und gleich die andere Seite genauso weit aus. Das ergibt eine leichte Malaufgabe.",
            "Danach den Abstand zum Zehner ins Quadrat nehmen und dazuzählen.",
        ]
        if n % 10 == 5 {
            let t = n / 10
            return Hint(
                title: "Quadrat einer Zahl mit 5 am Ende",
                tips: tips + ["Für Zahlen mit 5 am Ende gibt es einen Turbo-Trick."],
                mnemonic: "Endet die Zahl auf 5: Zehnerziffer mal (Zehnerziffer + 1), dann 25 dahinter schreiben.",
                walkthrough: [
                    "Zehnerziffer \(t) mal \(t + 1) = \(t * (t + 1))",
                    "Jetzt 25 hinten anhängen",
                ])
        }
        if n % 10 == 0 {
            return Hint(title: "Quadrat einer Zehnerzahl", tips: ["Zehnerzahl hoch zwei: Zehnerziffer ins Quadrat und zwei Nullen anhängen."],
                        walkthrough: ["\(n / 10) × \(n / 10) = \(n / 10 * (n / 10))", "Jetzt zwei Nullen anhängen"])
        }
        let lower = n / 10 * 10
        let up = n % 10 > 5
        let k = up ? lower + 10 - n : n - lower
        let round = up ? lower + 10 : lower
        let other = up ? n - k : n + k
        tips.append("Die Quadratzahlen bis 20 auswendig zu können, hilft oft.")
        return Hint(
            title: "Quadratzahl",
            tips: tips,
            mnemonic: "Formel dahinter: n² = (n − k) × (n + k) + k²",
            walkthrough: [
                "\(n) liegt \(k) von \(round) entfernt",
                "\(round) × \(other) = \(round * other)",
                "Abstand ins Quadrat: \(k) × \(k) = \(k * k)",
                "Jetzt \(round * other) + \(k * k)",
            ])
    }

    private static func percent(_ p: Int, _ n: Int) -> Hint {
        let tips = [
            "Prozent heißt „von Hundert“. 10 % ist ein Zehntel, also durch 10 teilen.",
            "Baue alles aus leichten Bausteinen: 50 % halbieren, 25 % zweimal halbieren, 10 % durch 10.",
        ]
        let walk: [String]
        switch p {
        case 10: walk = ["10 % = durch 10", "\(n) ÷ 10: die letzte Null weg (oder Komma eins nach links)"]
        case 20: walk = ["20 % = verdoppeln und durch 10 teilen", "\(n) verdoppelt = \(n * 2)", "Jetzt \(n * 2) durch 10 teilen"]
        case 25: walk = ["25 % = ein Viertel = zweimal halbieren", "\(n) halbiert = \(n / 2)", "Jetzt \(n / 2) noch einmal halbieren"]
        case 50: walk = ["50 % = die Hälfte", "\(n) halbieren"]
        case 75: walk = ["75 % = 50 % + 25 %", "50 % von \(n) = \(n / 2)", "25 % ist die Hälfte davon: \(n / 4)", "Jetzt \(n / 2) + \(n / 4)"]
        case 5: walk = ["5 % = die Hälfte von 10 %", "10 % von \(n) = \(n / 10)", "Jetzt \(n / 10) halbieren"]
        case 15: walk = ["15 % = 10 % + 5 %", "10 % von \(n) = \(n / 10)", "5 % ist die Hälfte davon: \(n / 20)", "Jetzt \(n / 10) + \(n / 20)"]
        default: walk = ["\(n) ÷ 100 × \(p)"]
        }
        return Hint(
            title: "Prozent",
            tips: tips,
            mnemonic: "Tauschtrick: 8 % von 50 ist dasselbe wie 50 % von 8. Manchmal ist die getauschte Aufgabe viel leichter.",
            walkthrough: walk)
    }
}
