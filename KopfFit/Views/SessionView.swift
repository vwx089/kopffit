import SwiftUI

struct SessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: SessionModel
    @State private var confirmAbort = false

    init(minutes: Int, startLevel: Int) {
        _model = StateObject(wrappedValue: SessionModel(
            minutes: minutes, startLevel: startLevel, startSpan: ProgressStore.shared.startSpan))
    }

    var body: some View {
        Group {
            if model.finished {
                ResultView(model: model) { dismiss() }
            } else {
                exercise
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        // Timer läuft nur, solange die App im Vordergrund ist. Wegwischen zählt nicht.
        .onChange(of: scenePhase) { _, phase in
            model.isPaused = phase != .active
        }
    }

    private var exercise: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            problemArea
            Spacer()
            Keypad(
                onDigit: { Haptics.tap(); model.type($0) },
                onDelete: { model.deleteLast() },
                onSkip: { model.skip() }
            )
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .confirmationDialog("Übung abbrechen?", isPresented: $confirmAbort, titleVisibility: .visible) {
            Button("Abbrechen, heute zählt nicht", role: .destructive) { dismiss() }
            Button("Weiterrechnen", role: .cancel) {}
        } message: {
            Text("Nur eine komplette Runde zählt. Die Erinnerungen gehen weiter.")
        }
        .sheet(isPresented: Binding(
            get: { model.isShowingHint },
            set: { if !$0 { model.hideHint() } }
        )) {
            HintSheet(problem: model.problem) { model.hideHint() }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button { confirmAbort = true } label: {
                    Image(systemName: "xmark").font(.headline)
                }
                .accessibilityLabel("Abbrechen")
                Spacer()
                HStack(spacing: 6) {
                    Text(timeString(model.remainingSeconds))
                        .font(.title3.monospacedDigit().bold())
                    if model.isIdle {
                        Label("angehalten", systemImage: "pause.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: model.isIdle)
                Spacer()
                Text("\(model.correct)/\(model.solved)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: model.progress)
                .tint(model.isIdle ? .orange : .accentColor)
            Text(model.mode == .memory
                 ? "Zahlen merken · \(model.span) Ziffern"
                 : "Level \(model.level) · \(ProblemGenerator.levelNames[model.level] ?? "")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var problemArea: some View {
        VStack(spacing: 24) {
            Group {
                if model.mode == .memory {
                    if let digit = model.memoryVisibleDigit {
                        Text(digit.isEmpty ? " " : digit)
                    } else {
                        Text("Eintippen")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(model.problem.text)
                }
            }
            .font(.system(size: 52, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .padding(.horizontal)

            if model.mode == .arithmetic {
                Button { model.showHint() } label: {
                    Label("Tipp", systemImage: "lightbulb.fill")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.2), in: Capsule())
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .disabled(!model.canShowHint)
                .opacity(model.canShowHint ? 1 : 0.4)
                .accessibilityLabel("Tipp zur Aufgabe anzeigen")
            }

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(answerBackground)
                    .frame(minWidth: 200, maxWidth: 320, minHeight: 76, maxHeight: 76)
                Text(answerText)
                    .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(answerForeground)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
            }
            .animation(.easeOut(duration: 0.15), value: model.feedback)

            if case .wrong(let answer) = model.feedback {
                Text("Richtig wäre \(answer)")
                    .font(.headline)
                    .foregroundStyle(.red)
            } else {
                Text(" ").font(.headline)
            }
        }
        .overlay {
            if model.isPaused {
                Text("Pausiert")
                    .font(.title.bold())
                    .padding()
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var answerText: String {
        if model.isShowingSequence { return "Merken…" }
        if model.input.isEmpty && model.feedback == nil { return "?" }
        return model.input.isEmpty ? "–" : model.input
    }

    private var answerBackground: Color {
        switch model.feedback {
        case .correct: return .green.opacity(0.25)
        case .wrong: return .red.opacity(0.25)
        case nil: return Color.secondary.opacity(0.12)
        }
    }

    private var answerForeground: Color {
        switch model.feedback {
        case .correct: return .green
        case .wrong: return .red
        case nil: return model.input.isEmpty ? .secondary : .primary
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", max(seconds, 0) / 60, max(seconds, 0) % 60)
    }
}

/// Ziffernblock wie beim Telefon. Statt Enter: "Weiter" überspringt (zählt als falsch).
struct Keypad: View {
    let onDigit: (Int) -> Void
    let onDelete: () -> Void
    let onSkip: () -> Void

    private let rows: [[Int]] = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { digit in
                        key(action: { onDigit(digit) }) { Text("\(digit)") }
                    }
                }
            }
            HStack(spacing: 10) {
                key(action: onSkip) { Text("Weiter").font(.headline) }
                key(action: { onDigit(0) }) { Text("0") }
                key(action: onDelete) { Image(systemName: "delete.left") }
            }
        }
    }

    private func key<Label: View>(action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View {
        Button(action: action) {
            label()
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

/// Zeigt Tipps zur aktuellen Rechenaufgabe. Der Rechenweg mit den eigenen Zahlen
/// wird erst auf Wunsch aufgedeckt, damit man es zuerst selbst versuchen kann.
struct HintSheet: View {
    let problem: Problem
    let onClose: () -> Void
    @State private var showWalkthrough = false

    var body: some View {
        let hint = problem.hint
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(problem.text)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("So gehst du vor", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        ForEach(hint.tips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text(tip)
                            }
                        }
                    }

                    if let mnemonic = hint.mnemonic {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Eselsbrücke", systemImage: "brain.head.profile")
                                .font(.headline)
                                .foregroundStyle(.purple)
                            Text(mnemonic)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if showWalkthrough {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Mit deinen Zahlen", systemImage: "list.number")
                                .font(.headline)
                                .foregroundStyle(.blue)
                            ForEach(Array(hint.walkthrough.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.body.monospacedDigit().bold())
                                    Text(step)
                                }
                            }
                            Text("Den letzten Schritt rechnest du selbst.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        Button {
                            withAnimation { showWalkthrough = true }
                        } label: {
                            Label("An dieser Aufgabe zeigen", systemImage: "eye")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("Die Uhr steht, solange der Tipp offen ist.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle(hint.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Weiterrechnen", action: onClose)
                }
            }
        }
    }
}
