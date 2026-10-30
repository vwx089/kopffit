import SwiftUI
import UserNotifications

@main
struct KopfFitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ProgressStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            // Bei jedem Öffnen neu planen, damit immer genug Erinnerungen in der Warteschlange sind.
            if phase == .active || phase == .background {
                ReminderScheduler.reschedule(store: store)
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        ReminderScheduler.registerCategories()
        return true
    }

    // Erinnerung kommt, während die App offen ist: nur zeigen, wenn heute noch nichts erledigt ist.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let done = await MainActor.run { ProgressStore.shared.doneToday }
        return done ? [] : [.banner, .sound]
    }

    // Tipp auf die Erinnerung: Übung direkt starten.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        await MainActor.run {
            let store = ProgressStore.shared
            if !store.doneToday { store.startRequested = true }
        }
    }
}
