import Foundation
import UserNotifications
import UIKit

/// Plant die "penetranten" Erinnerungen.
///
/// iOS erlaubt maximal 64 geplante lokale Benachrichtigungen pro App. Deshalb plant die App
/// heute und morgen im vollen Takt (z. B. alle 30 Minuten) und die Tage danach nur noch
/// einige Erinnerungen, damit du auch dann genervt wirst, wenn du die App ein paar Tage nicht öffnest.
/// Bei jedem Öffnen der App wird neu geplant.
@MainActor
enum ReminderScheduler {
    static let categoryId = "KOPFFIT_REMINDER"
    static let startActionId = "KOPFFIT_START"
    private static let budget = 60
    private static let fullDays = 2
    private static let sparseDaysAhead = 12
    private static let sparseTimesPerDay = 3

    static func registerCategories() {
        let start = UNNotificationAction(identifier: startActionId, title: "Jetzt 5 Minuten rechnen", options: [.foreground])
        let category = UNNotificationCategory(identifier: categoryId, actions: [start], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func requestAuthorization() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted { reschedule(store: .shared) }
        return granted
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Wird aufgerufen, sobald die Tagesübung erledigt ist.
    static func markTodayDone(store: ProgressStore) {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.setBadgeCount(0)
        reschedule(store: store)
    }

    /// Löscht alle geplanten Erinnerungen und plant sie neu.
    static func reschedule(store: ProgressStore) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let s = store.settings
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        let streak = store.currentStreak
        var scheduled = 0

        var fullTimes: [Int] = []
        var m = s.startMinute
        while m <= s.endMinute {
            fullTimes.append(m)
            m += max(5, s.intervalMinutes)
        }
        // Für spätere Tage: Start, Mitte und Ende des Fensters.
        let sparseTimes = Array(Set([s.startMinute, (s.startMinute + s.endMinute) / 2, s.endMinute]))
            .sorted()
            .prefix(sparseTimesPerDay)

        for dayOffset in 0..<(fullDays + sparseDaysAhead) {
            if dayOffset == 0 && store.doneToday { continue }
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let times = dayOffset < fullDays ? fullTimes : Array(sparseTimes)

            for (index, minute) in times.enumerated() {
                guard scheduled < budget else { return }
                guard let fire = cal.date(byAdding: .minute, value: minute, to: day), fire > now else { continue }

                let content = UNMutableNotificationContent()
                let message = text(index: index, of: times.count, streak: dayOffset == 0 ? streak : nil)
                content.title = message.title
                content.body = message.body
                content.sound = .default
                content.badge = 1
                content.categoryIdentifier = categoryId
                content.interruptionLevel = .timeSensitive
                content.relevanceScore = 1.0

                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let id = "kopffit-\(ProgressStore.dayKey(day))-\(minute)"
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                scheduled += 1
            }
        }
    }

    /// Je später am Tag, desto deutlicher werden die Nachrichten.
    private static func text(index: Int, of total: Int, streak: Int?) -> (title: String, body: String) {
        let progress = total <= 1 ? 1.0 : Double(index) / Double(total - 1)
        let isLast = index == total - 1

        if isLast, let streak, streak > 0 {
            return ("Letzte Chance heute! 🔥", "Deine Serie von \(streak) \(streak == 1 ? "Tag" : "Tagen") endet um Mitternacht. 5 Minuten. Jetzt.")
        }

        let gentle = [
            ("Kurz den Kopf aufwärmen? 🧠", "5 Minuten Kopfrechnen, dann ist für heute Ruhe."),
            ("Dein Gehirn wartet", "Eine Runde Kopfrechnen, bevor du wieder scrollst?"),
            ("5 Minuten für dich", "Kleine Aufgaben, kleiner Aufwand. Leg los."),
        ]
        let firm = [
            ("Immer noch offen", "Die Tagesübung ist noch nicht erledigt. Ich höre erst auf, wenn du sie machst."),
            ("Hallo? Kopfrechnen!", "Statt 5 Minuten Feed: 5 Minuten Zahlen. Tipp hier."),
            ("Nicht aufschieben", "Jetzt ist der beste Moment. Später wird es nicht leichter."),
        ]
        let insistent = [
            ("Ich nerve weiter. 😤", "Bis die 5 Minuten erledigt sind, kommt alle paar Minuten diese Nachricht."),
            ("Du weißt, was zu tun ist", "Eine Runde. 5 Minuten. Dann ist für heute Schluss mit Nerven."),
            ("Der Tag ist bald vorbei", "Hol dir den Haken für heute, bevor es zu spät ist."),
        ]
        let pool = progress < 0.34 ? gentle : (progress < 0.67 ? firm : insistent)
        return pool[index % pool.count]
    }
}
