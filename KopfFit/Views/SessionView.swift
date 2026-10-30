import SwiftUI

struct SessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: SessionModel
    @State private var confirmAbort = false

    init(minutes: Int, startLevel: Int) {
        _model = StateObject(wrappedValue: SessionModel(minutes: minutes, startLevel: startLevel))
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
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button { confirmAbort = true } label: {
                    Image(systemName: "xmark").font(.headline)
                }
                .accessibilityLabel("Abbrechen")
                Spacer()
                Text(timeString(model.remainingSeconds))
                    .font(.title3.monospacedDigit().bold())
                Spacer()
                Text("\(model.correct)/\(model.solved)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: model.progress)
                .tint(model.isIdle ? .orange : .accentColor)
            Text("Level \(model.level) · \(ProblemGenerator.levelNames[model.level] ?? "")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var problemArea: some View {
        VStack(spacing: 24) {
            Text(model.problem.text)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal)

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(answerBackground)
                    .frame(width: 200, height: 76)
                Text(answerText)
                    .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(answerForeground)
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
            } else if model.isIdle {
                VStack(spacing: 6) {
                    Label("Uhr angehalten", systemImage: "pause.circle.fill")
                        .font(.title2.bold())
                    Text("Die Zeit läuft nur, während du rechnest.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
                .allowsHitTesting(false)
            }
        }
    }

    private var answerText: String {
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
