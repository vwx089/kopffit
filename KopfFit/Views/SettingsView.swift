import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ProgressStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Erste Erinnerung", selection: timeBinding(\.startMinute), displayedComponents: .hourAndMinute)
                    DatePicker("Letzte Erinnerung", selection: timeBinding(\.endMinute), displayedComponents: .hourAndMinute)
                    Picker("Wiederholen alle", selection: $store.settings.intervalMinutes) {
                        ForEach([15, 20, 30, 45, 60, 90], id: \.self) { Text("\($0) Min.").tag($0) }
                    }
                } header: {
                    Text("Erinnerungen")
                } footer: {
                    Text("Solange die Tagesübung offen ist, meldet sich KopfFit in diesem Zeitfenster immer wieder.")
                }

                Section {
                    Stepper("Dauer: \(store.settings.sessionMinutes) Min.", value: $store.settings.sessionMinutes, in: 3...20)
                } header: {
                    Text("Übung")
                }

                Section {
                    Text("Damit die Erinnerungen auch im Fokus-Modus durchkommen: Einstellungen › Mitteilungen › KopfFit › „Dringliche Mitteilungen“ einschalten.")
                    Button("Mitteilungs-Einstellungen öffnen") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } header: {
                    Text("Noch penetranter")
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    /// Wandelt "Minuten seit Mitternacht" in ein Date für den DatePicker um.
    private func timeBinding(_ keyPath: WritableKeyPath<ReminderSettings, Int>) -> Binding<Date> {
        Binding {
            Calendar.current.date(byAdding: .minute, value: store.settings[keyPath: keyPath],
                                  to: Calendar.current.startOfDay(for: Date())) ?? Date()
        } set: { date in
            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
            store.settings[keyPath: keyPath] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
    }
}
