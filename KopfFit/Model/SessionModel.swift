import Foundation
import SwiftUI
import UIKit

/// Steuert eine laufende Übung: Timer, aktuelle Aufgabe, Eingabe und adaptive Schwierigkeit.
@MainActor
final class SessionModel: ObservableObject {
    enum Feedback: Equatable {
        case correct
        case wrong(correctAnswer: Int)
    }

    @Published private(set) var problem: Problem
    @Published private(set) var input = ""
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var feedback: Feedback?
    @Published private(set) var solved = 0
    @Published private(set) var correct = 0
    @Published private(set) var level: Int
    @Published private(set) var finished = false
    @Published var isPaused = false

    let totalSeconds: Int
    let startLevel: Int

    // Adaptivität: nach 4 schnellen richtigen Antworten in Folge eine Stufe hoch,
    // nach 2 Fehlern in Folge eine Stufe runter.
    private var fastCorrectInRow = 0
    private var wrongInRow = 0
    private var problemShownAt = Date()
    private var timerTask: Task<Void, Never>?

    init(minutes: Int, startLevel: Int) {
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
        problemShownAt = Date()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if self.isPaused || self.finished { continue }
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
    }

    // MARK: - Eingabe

    func type(_ digit: Int) {
        guard feedback == nil, !finished, !isPaused, input.count < 6 else { return }
        input.append(String(digit))
        // Automatisch prüfen, sobald so viele Ziffern wie im Ergebnis eingegeben sind.
        if input.count >= problem.answerDigits {
            submit()
        }
    }

    func deleteLast() {
        guard feedback == nil, !input.isEmpty else { return }
        input.removeLast()
    }

    func skip() {
        guard feedback == nil, !finished else { return }
        evaluate(isCorrect: false)
    }

    private func submit() {
        evaluate(isCorrect: Int(input) == problem.answer)
    }

    private func evaluate(isCorrect: Bool) {
        solved += 1
        let elapsed = Date().timeIntervalSince(problemShownAt)

        if isCorrect {
            correct += 1
            wrongInRow = 0
            // "Schnell" heißt: unter 4 Sekunden plus 2 Sekunden pro Stufe.
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
            feedback = .wrong(correctAnswer: problem.answer)
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
        var next = ProblemGenerator.make(level: level)
        // Nicht zweimal hintereinander dieselbe Aufgabe.
        while next == problem { next = ProblemGenerator.make(level: level) }
        problem = next
        input = ""
        feedback = nil
        problemShownAt = Date()
    }

    private func finish() {
        finished = true
        stop()
        Haptics.success()
        ProgressStore.shared.recordSession(solved: solved, correct: correct, endLevel: level)
    }
}

enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
