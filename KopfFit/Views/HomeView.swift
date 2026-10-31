import SwiftUI
import UserNotifications

struct HomeView: View {
    @EnvironmentObject private var store: ProgressStore
    @State private var showSession = false
    @State private var showSettings = false
    @State private var notificationStatus: UNAuthorizationStatus = .authorized

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if notificationStatus != .authorized {
                        notificationBanner
                    }
                    statusCard
                    streakCard
                    weekCard
                }
                .padding()
            }
            .navigationTitle("KopfFit")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { StatsView() } label: { Image(systemName: "chart.xyaxis.line") }
                        .accessibilityLabel("Statistik")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Einstellungen")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView().environmentObject(store) }
            .fullScreenCover(isPresented: $showSession) {
                SessionView(minutes: store.settings.sessionMinutes, startLevel: store.startLevel)
                    .environmentObject(store)
            }
            .task { await refreshNotificationStatus() }
            .onChange(of: store.startRequested) { _, requested in
                if requested {
                    store.startRequested = false
                    showSession = true
                }
            }
            .onAppear {
                if store.startRequested {
                    store.startRequested = false
                    showSession = true
                }
            }
        }
    }

    // MARK: - Karten

    private var statusCard: some View {
        VStack(spacing: 14) {
            Image(systemName: store.doneToday ? "checkmark.seal.fill" : "brain.head.profile")
                .font(.system(size: 56))
                .foregroundStyle(store.doneToday ? Color.green : Color.accentColor)

            if store.doneToday, let record = store.todayRecord {
                Text("Heute erledigt!").font(.title2.bold())
                Text("\(record.correct) von \(record.solved) richtig. Für heute ist Ruhe mit Erinnerungen.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Noch eine Runde (freiwillig)") { showSession = true }
                    .buttonStyle(.bordered)
            } else {
                Text("Tagesübung offen").font(.title2.bold())
                Text("\(store.settings.sessionMinutes) Minuten Kopfrechnen. Danach hören die Erinnerungen für heute auf.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button {
                    showSession = true
                } label: {
                    Text("Jetzt starten")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var streakCard: some View {
        HStack {
            stat(value: "\(store.currentStreak)", label: "Tage Serie", icon: "flame.fill", color: .orange)
            Divider()
            stat(value: "\(store.bestStreak)", label: "Rekord", icon: "trophy.fill", color: .yellow)
            Divider()
            stat(value: "\(store.level)", label: "Level", icon: "chart.line.uptrend.xyaxis", color: .accentColor)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func stat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.title.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Letzte 7 Tage").font(.headline)
            HStack {
                ForEach(store.lastSevenDays, id: \.date) { entry in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(entry.done ? Color.green : Color.secondary.opacity(0.2))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if entry.done {
                                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                }
                            }
                        Text(entry.date, format: .dateTime.weekday(.narrow))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text("Aktuell: \(ProblemGenerator.levelNames[store.level] ?? "")")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var notificationBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Erinnerungen sind aus", systemImage: "bell.slash.fill").font(.headline)
            Text("Ohne Mitteilungen kann dich KopfFit nicht nerven. Und genau dafür ist die App da.")
                .font(.subheadline)
            Button(notificationStatus == .notDetermined ? "Mitteilungen erlauben" : "In den Einstellungen aktivieren") {
                Task {
                    if notificationStatus == .notDetermined {
                        _ = await ReminderScheduler.requestAuthorization()
                        await refreshNotificationStatus()
                    } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        _ = await UIApplication.shared.open(url)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
    }

    private func refreshNotificationStatus() async {
        var status = await ReminderScheduler.authorizationStatus()
        // Beim ersten Start direkt um Erlaubnis fragen.
        if status == .notDetermined {
            _ = await ReminderScheduler.requestAuthorization()
            status = await ReminderScheduler.authorizationStatus()
        }
        notificationStatus = status
    }
}
