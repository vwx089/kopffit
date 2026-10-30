import SwiftUI

struct ResultView: View {
    @ObservedObject var model: SessionModel
    @EnvironmentObject private var store: ProgressStore
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            Text("Geschafft!")
                .font(.largeTitle.bold())
            Text("Für heute hören die Erinnerungen auf.")
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                row("Aufgaben gelöst", "\(model.solved)")
                row("Davon richtig", "\(model.correct) (\(model.accuracy) %)")
                row("Level", levelChange)
                row("Serie", "\(store.currentStreak) \(store.currentStreak == 1 ? "Tag" : "Tage") 🔥")
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)

            Spacer()

            Button(action: onDone) {
                Text("Fertig")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
        }
    }

    private var levelChange: String {
        if model.level > model.startLevel { return "\(model.startLevel) → \(model.level) ⬆️" }
        if model.level < model.startLevel { return "\(model.startLevel) → \(model.level)" }
        return "\(model.level)"
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).bold().monospacedDigit()
        }
    }
}
