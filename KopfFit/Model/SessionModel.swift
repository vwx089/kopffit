import Foundation
import SwiftUI
import UIKit

/// Steuert eine laufende Übung: Timer, aktuelle Aufgabe, Eingabe und adaptive Schwierigkeit.
/// Die ersten 70 % der Zeit wird gerechnet, danach folgt der Block "Zahlen merken".
@MainActor
final class SessionModel: ObservableObject {
    enum Feedback: Equatable {
        case correct
        case wrong(correctAnswer: String)
    }

    enum Mode { case arithmetic, memory }

    @Published private(set) var problem: Problem
    @Published private(set) var input = ""
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var feedback: Feedback?
    @Published private(set) var solved = 0
    @Published private(set) var correct = 0
    @Published private(set) var level: Int
    @Published private(set) var finished = false
    @Published var isPaused = false
    /// Wird nach einigen Sekunden ohne Eingabe gesetzt: Dann läuft die Uhr nicht weiter.
    @Published private(set) var isIdle = false
    /// Tipp-Fenster ist offen: Die Uhr steht so lange.
    @Published private(set) var isShowingHint = false
    /// Für die aktuelle Aufgabe wurde ein Tipp angesehen.
    private var usedHint = false
    private var hintOpenedAt: Date?
    private var hintsUsed = 0
    private var hintSeconds = 0

    // Zahlen merken
    @Published private(set) var mode: Mode = .arithmetic
    /// Ziffer, die gerade eingeblendet wird ("" = kurze Lücke). nil: Eingabephase.
    @Published private(set) var memoryVisibleDigit: String?
    @Published private(set) var span: Int
    @Published private(set) var bestSpan = 0
    private var memoryDigits = ""
    private var memoryCorrectInRow = 0
    private var memoryWrongInRow = 0
    private var showTask: Task<Void, Never>?
    static let minSpan = 3
    static let maxSpan = 12

    /// Ab dieser Restzeit (Sekunden) wird von Rechnen auf Zahlen merken umgeschaltet.
    private var memoryStartsAt: Int { totalSeconds * 3 / 10 }

    /// Nach so vielen Sekunden ohne Eingabe hält der Timer an.
    static let idleLimit: TimeInterval = 15

    let totalSeconds: Int
    /// Der Tag, an dem die Übung gestartet wurde. Für ihn zählt die Runde, auch wenn sie nach Mitternacht endet.
    private(set) var startedDay = ProgressStore.dayKey()
    let startLevel: Int

    // Adaptivität: nach 4 schnellen richtigen Antworten in Folge eine Stufe hoch,
    // nach 2 Fehlern in Folge eine Stufe runter.
    private var fastCorrectInRow = 0
    private var wrongInRow = 0
    private var problemShownAt = Date()
    private var lastActivityAt = Date()
    // Für die Statistik: gelöste Rechenaufgaben und die dafür gebrauchte Zeit.
    private var arithmeticSolved = 0
    private var arithmeticSeconds: Double = 0
    // Für das Journal
    private var startedAt = Date()
    private var idleSeconds = 0
    private var pausedSeconds = 0
    private let startSpan: Int
    private var timerTask: Task<Void, Never>?

    init(minutes: Int, startLevel: Int, startSpan: Int) {
        span = startSpan
        self.startSpan = startSpan
        totalSeconds = minutes * 60
        remainingSeconds = minutes * 60
        self.startLevel = startLevel
        level = startLevel
        problem = ProblemGenerator.make(level: startLevel)
    }

    var progress: Double { 1 - Double(remainingSeconds) / Double(max(totalSeconds, 1)) }

    var accuracy: Int { solved == 0 ? 0 : Int((Double(correct) / Double(solved) * 100).rounded()) }

    func start() {
        guard timerTask == nil else { return }
        startedDay = ProgressStore.dayKey()
        startedAt = Date()
        problemShownAt = Date()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if self.finished { continue }
                if self.isPaused { self.pausedSeconds += 1; continue }
                if self.isShowingHint { self.hintSeconds += 1; continue }
                self.isIdle = self.feedback == nil && !self.isShowingSequence
                    && Date().timeIntervalSince(self.lastActivityAt) > Self.idleLimit
                if self.isIdle { self.idleSeconds += 1; continue }
                self.remainingSeconds -= 1
                if self.remainingSeconds <= 0 {
                    self.finish()
                    return
                }
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        showTask?.cancel()
    }

    var isShowingSequence: Bool { memoryVisibleDigit != nil }

    /// Wie viele Ziffern die erwartete Antwort hat.
    private var expectedLength: Int { mode == .memory ? memoryDigits.count : problem.answerDigits }

    // MARK: - Eingabe

    func type(_ digit: Int) {
        guard feedback == nil, !finished, !isPaused, !isShowingSequence, input.count < 12 else { return }
        markActivity()
        input.append(String(digit))
        // Automatisch prüfen, sobald so viele Ziffern wie im Ergebnis eingegeben sind.
        if input.count >= expectedLength {
            submit()
        }
    }

    func deleteLast() {
        markActivity()
        guard feedback == nil, !input.isEmpty else { return }
        input.removeLast()
    }

    func skip() {
        markActivity()
        guard feedback == nil, !finished, !isShowingSequence else { return }
        evaluate(isCorrect: false, skipped: true)
    }

    // MARK: - Tipps

    var canShowHint: Bool { mode == .arithmetic && feedback == nil && !finished }

    func showHint() {
        guard canShowHint, !isShowingHint else { return }
        if !usedHint { hintsUsed += 1 }
        usedHint = true
        hintOpenedAt = Date()
        isShowingHint = true
    }

    func hideHint() {
        guard isShowingHint else { return }
        // Lesezeit nicht als Rechenzeit werten.
        if let opened = hintOpenedAt {
            problemShownAt = problemShownAt.addingTimeInterval(Date().timeIntervalSince(opened))
        }
        hintOpenedAt = nil
        isShowingHint = false
        markActivity()
    }

    private func markActivity() {
        lastActivityAt = Date()
        isIdle = false
    }

    private func submit() {
        if mode == .memory {
            evaluate(isCorrect: input == memoryDigits)
        } else {
            evaluate(isCorrect: Int(input) == problem.answer)
        }
    }

    private func evaluate(isCorrect: Bool, skipped: Bool = false) {
        let isMemory = mode == .memory
        Journal.append(AttemptLog(
            time: Date(), day: startedDay,
            mode: isMemory ? "memory" : "arithmetic",
            level: level, span: isMemory ? span : nil,
            task: isMemory ? memoryDigits : problem.text,
            expected: isMemory ? memoryDigits : String(problem.answer),
            given: input, correct: isCorrect, skipped: skipped,
            seconds: Date().timeIntervalSince(problemShownAt),
            hint: isMemory ? nil : usedHint
        ), to: Journal.attemptsFile)

        if isMemory {
            evaluateMemory(isCorrect: isCorrect)
            return
        }
        solved += 1
        let elapsed = Date().timeIntervalSince(problemShownAt)
        arithmeticSolved += 1
        // Lange Pausen nicht mitzählen, sonst verfälscht eine Unterbrechung das Tempo.
        arithmeticSeconds += min(elapsed, Self.idleLimit)

        if isCorrect {
            correct += 1
            wrongInRow = 0
            // "Schnell" heißt: unter 4 Sekunden plus 2 Sekunden pro Stufe.
            // Ein Tipp ist ungestraft: Die Lesezeit ist schon aus elapsed herausgerechnet.
            if elapsed < 4 + Double(level) * 2 {
                fastCorrectInRow += 1
            } else {
                fastCorrectInRow = 0
            }
            feedback = .correct
            Haptics.success()
        } else {
            fastCorrectInRow = 0
            wrongInRow += 1
            feedback = .wrong(correctAnswer: String(problem.answer))
            Haptics.error()
        }

        if fastCorrectInRow >= 4 && level < ProblemGenerator.maxLevel {
            level += 1
            fastCorrectInRow = 0
        } else if wrongInRow >= 2 && level > 1 {
            level -= 1
            wrongInRow = 0
        }

        let delay: Duration = isCorrect ? .milliseconds(350) : .milliseconds(1500)
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            self?.nextProblem()
        }
    }

    private func nextProblem() {
        guard !finished else { return }
        if mode == .memory || remainingSeconds <= memoryStartsAt {
            startMemoryRound()
            return
        }
        var next = ProblemGenerator.make(level: level)
        // Nicht zweimal hintereinander dieselbe Aufgabe.
        while next == problem { next = ProblemGenerator.make(level: level) }
        problem = next
        usedHint = false
        input = ""
        feedback = nil
        problemShownAt = Date()
        lastActivityAt = Date()
    }

    // MARK: - Zahlen merken

    /// Zeigt eine Zahlenreihe Ziffer für Ziffer, danach wird sie eingetippt.
    private func startMemoryRound() {
        mode = .memory
        input = ""
        feedback = nil
        var digits = ""
        while digits.count < span {
            let d = String(Int.random(in: 0...9))
            if digits.last.map({ String($0) }) != d { digits += d }
        }
        memoryDigits = digits
        memoryVisibleDigit = ""
        markActivity()

        showTask?.cancel()
        showTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            for d in digits {
                guard let self, !Task.isCancelled else { return }
                self.memoryVisibleDigit = String(d)
                self.markActivity()
                try? await Task.sleep(for: .milliseconds(800))
                self.memoryVisibleDigit = ""
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard let self, !Task.isCancelled else { return }
            self.memoryVisibleDigit = nil
            self.problemShownAt = Date()
            self.markActivity()
        }
    }

    // Nach 2 richtigen Reihen in Folge eine Ziffer mehr, nach 2 falschen eine weniger.
    private func evaluateMemory(isCorrect: Bool) {
        solved += 1
        if isCorrect {
            correct += 1
            bestSpan = max(bestSpan, span)
            memoryWrongInRow = 0
            memoryCorrectInRow += 1
            feedback = .correct
            Haptics.success()
        } else {
            memoryCorrectInRow = 0
            memoryWrongInRow += 1
            feedback = .wrong(correctAnswer: memoryDigits)
            Haptics.error()
        }

        if memoryCorrectInRow >= 2 && span < Self.maxSpan {
            span += 1
            memoryCorrectInRow = 0
        } else if memoryWrongInRow >= 2 && span > Self.minSpan {
            span -= 1
            memoryWrongInRow = 0
        }

        let delay: Duration = isCorrect ? .milliseconds(600) : .milliseconds(2000)
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            self?.nextProblem()
        }
    }

    private func finish() {
        finished = true
        stop()
        Haptics.success()
        Journal.append(SessionLog(
            day: startedDay, started: startedAt, ended: Date(),
            plannedMinutes: totalSeconds / 60, idleSeconds: idleSeconds, pausedSeconds: pausedSeconds,
            solved: solved, correct: correct,
            startLevel: startLevel, endLevel: level, startSpan: startSpan, endSpan: span,
            hintsUsed: hintsUsed, hintSeconds: hintSeconds
        ), to: Journal.sessionsFile)
        ProgressStore.shared.recordSession(day: startedDay, solved: solved, correct: correct, endLevel: level, endSpan: span,
            arithmeticSolved: arithmeticSolved, arithmeticSeconds: arithmeticSeconds, bestSpan: bestSpan)
    }
}

enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
