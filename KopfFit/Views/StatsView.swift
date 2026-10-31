import SwiftUI
import Charts

/// Verlauf der letzten 30 Tage: Tempo, Level, Trefferquote und Zahlen merken.
struct StatsView: View {
    @EnvironmentObject private var store: ProgressStore

    private struct Point: Identifiable {
        let id: String
        let date: Date
        let record: DayRecord
    }

    private var points: [Point] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Calendar.current.startOfDay(for: Date()))!
        return store.history
            .compactMap { r in r.date.map { Point(id: r.day, date: $0, record: r) } }
            .filter { $0.date > cutoff }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summary
                chartCard("Tempo", subtitle: "Sekunden pro Rechenaufgabe, weniger ist besser") { tempoChart }
                chartCard("Level", subtitle: "Level am Ende des Tages") { levelChart }
                chartCard("Trefferquote", subtitle: "Anteil richtiger Antworten in %") { accuracyChart }
                chartCard("Zahlen merken", subtitle: "Längste richtig gemerkte Reihe") { spanChart }
            }
            .padding()
        }
        .navigationTitle("Statistik")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Kennzahlen

    private var summary: some View {
        let tempos = store.history
            .sorted { $0.day < $1.day }
            .compactMap(\.secondsPerProblem)
        let total = store.history.reduce(0) { $0 + $1.solved }

        return VStack(spacing: 12) {
            HStack {
                tile("\(store.history.count)", "Trainingstage")
                tile("\(total)", "Aufgaben gelöst")
            }
            if let first = tempos.first, let last = tempos.last, tempos.count >= 2 {
                let change = (first - last) / first * 100
                Text("Tempo: \(format(first)) s → \(format(last)) s pro Aufgabe"
                     + (change > 0 ? " (\(Int(change.rounded())) % schneller)" : ""))
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func tile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Diagramme

    private var tempoChart: some View {
        let data = points.filter { $0.record.secondsPerProblem != nil }
        return chartOrEmpty(data.isEmpty) {
            Chart(data) { p in
                LineMark(x: .value("Tag", p.date, unit: .day), y: .value("Sekunden", p.record.secondsPerProblem!))
                PointMark(x: .value("Tag", p.date, unit: .day), y: .value("Sekunden", p.record.secondsPerProblem!))
            }
        }
    }

    private var levelChart: some View {
        chartOrEmpty(points.isEmpty) {
            Chart(points) { p in
                LineMark(x: .value("Tag", p.date, unit: .day), y: .value("Level", p.record.endLevel))
                    .interpolationMethod(.stepEnd)
                PointMark(x: .value("Tag", p.date, unit: .day), y: .value("Level", p.record.endLevel))
            }
            .chartYScale(domain: 1...ProblemGenerator.maxLevel)
        }
    }

    private var accuracyChart: some View {
        let data = points.filter { $0.record.accuracy != nil }
        return chartOrEmpty(data.isEmpty) {
            Chart(data) { p in
                BarMark(x: .value("Tag", p.date, unit: .day), y: .value("Prozent", p.record.accuracy!))
                    .foregroundStyle(.green)
            }
            .chartYScale(domain: 0...100)
        }
    }

    private var spanChart: some View {
        let data = points.filter { ($0.record.bestSpan ?? 0) > 0 }
        return chartOrEmpty(data.isEmpty) {
            Chart(data) { p in
                BarMark(x: .value("Tag", p.date, unit: .day), y: .value("Ziffern", p.record.bestSpan ?? 0))
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Bausteine

    private func chartCard<C: View>(_ title: String, subtitle: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
            content()
                .frame(height: 160)
                .padding(.top, 6)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func chartOrEmpty<C: View>(_ isEmpty: Bool, @ViewBuilder chart: () -> C) -> some View {
        if isEmpty {
            Text("Noch keine Daten. Die füllen sich mit jeder Runde.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            chart()
        }
    }

    private func format(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(1)))
    }
}
