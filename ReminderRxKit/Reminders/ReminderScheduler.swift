//
//  ReminderScheduler.swift
//  ReminderRxKit
//

import Foundation
import OSLog
import SwiftData
import UserNotifications

/// The slice of `UNUserNotificationCenter` the scheduler uses, so tests can substitute it.
@MainActor
public protocol NotificationScheduling: AnyObject {
    func pendingIdentifiers() async -> [String]
    func deliveredIdentifiers() async -> [String]
    func add(_ request: UNNotificationRequest) async throws
    func removePending(_ identifiers: [String])
    func removeDelivered(_ identifiers: [String])
}

extension UNUserNotificationCenter: NotificationScheduling {
    public func pendingIdentifiers() async -> [String] {
        await pendingNotificationRequests().map(\.identifier)
    }

    public func deliveredIdentifiers() async -> [String] {
        await deliveredNotifications().map(\.request.identifier)
    }

    public func removePending(_ identifiers: [String]) {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    public func removeDelivered(_ identifiers: [String]) {
        removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

/// Keeps pending local notifications in sync with the data. Runs in the app and in extensions.
@MainActor
public enum ReminderScheduler {
    private static let refillAlertDatesKey = "refillAlertDates"
    private static let logger = Logger(subsystem: "com.Swifttom.ReminderRx", category: "Reminders")
    private static var pendingRefresh: Task<Void, Never>?

    /// `nil` outside an app or app extension (e.g. unit tests), where there's no notification center.
    public static var center: (any NotificationScheduling)? = {
        ["app", "appex"].contains(Bundle.main.bundleURL.pathExtension) ? UNUserNotificationCenter.current() : nil
    }()

    public static func registerCategories() {
        let take = UNNotificationAction(identifier: ReminderAction.take, title: "Taken", icon: UNNotificationActionIcon(systemImageName: "checkmark.circle.fill"))
        let snooze = UNNotificationAction(identifier: ReminderAction.snooze, title: "Snooze 10 min", icon: UNNotificationActionIcon(systemImageName: "clock.arrow.circlepath"))
        let skip = UNNotificationAction(identifier: ReminderAction.skip, title: "Skip", options: [.destructive], icon: UNNotificationActionIcon(systemImageName: "forward.fill"))
        let refilled = UNNotificationAction(identifier: ReminderAction.refilled, title: "I Refilled It", icon: UNNotificationActionIcon(systemImageName: "arrow.clockwise.circle.fill"))
        let tomorrow = UNNotificationAction(identifier: ReminderAction.remindTomorrow, title: "Remind Me Tomorrow", icon: UNNotificationActionIcon(systemImageName: "bell"))

        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: ReminderCategory.dose, actions: [take, snooze, skip], intentIdentifiers: []),
            UNNotificationCategory(identifier: ReminderCategory.refill, actions: [refilled, tomorrow], intentIdentifiers: []),
        ])
    }

    /// Coalesces bursts of changes into one reschedule shortly after.
    public static func setNeedsReschedule() {
        guard center != nil else { return }
        pendingRefresh?.cancel()
        pendingRefresh = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await rescheduleNow()
        }
    }

    /// Rebuilds every planned reminder from the store. Await this from extensions and intents,
    /// which may be suspended before a debounced reschedule runs.
    public static func rescheduleNow(context: ModelContext? = nil, now: Date = .now) async {
        guard let center else { return }
        let context = context ?? SharedStore.container.mainContext
        let medications = (try? context.fetch(FetchDescriptor<Medication>(predicate: #Predicate { $0.archivedAt == nil }))) ?? []
        let inputs = medications.map(\.reminderInput)

        let plan = ReminderPlanner().plan(
            for: inputs,
            settings: .current,
            refillAlertDates: refillAlertDates,
            now: now
        )
        refillAlertDates = plan.refillAlertDates
        await apply(plan, loggedDoses: loggedDoseKeys(inputs), to: center)
        logger.info("Scheduled \(plan.reminders.count) reminders, truncated: \(plan.isTruncated), next: \(plan.reminders.first?.identifier ?? "none")")
    }

    /// Re-delivers a dose reminder in `minutes`.
    public static func snooze(_ reference: ReminderReference, title: String, body: String, minutes: Int = 10) async {
        guard let center, let scheduledDate = reference.scheduledDate else { return }
        let key = DoseKey(medicationID: reference.medicationID, scheduledDate: scheduledDate)
        let reminder = PlannedReminder(
            kind: .snooze,
            identifier: ReminderKind.snooze.identifier(key.rawValue),
            fireDate: .now.addingTimeInterval(TimeInterval(minutes * 60)),
            title: title,
            body: body,
            reference: reference,
            category: ReminderCategory.dose,
            threadID: reference.medicationID.uuidString
        )
        do {
            try await center.add(request(for: reminder))
        } catch {
            logger.error("Failed to snooze: \(error)")
        }
    }

    /// Pushes a medication's refill alert to tomorrow morning.
    public static func remindRefillTomorrow(medicationID: UUID, now: Date = .now) async {
        let planner = ReminderPlanner()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        refillAlertDates[medicationID] = planner.nextOccurrence(ofHour: ReminderSettings().refillHour, after: Calendar.current.startOfDay(for: tomorrow))
        await rescheduleNow(now: now)
    }

    public static func request(for reminder: PlannedReminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.threadIdentifier = reminder.threadID
        content.interruptionLevel = reminder.kind == .keepAlive ? .active : .timeSensitive
        if let category = reminder.category {
            content.categoryIdentifier = category
        }
        if let reference = reminder.reference {
            content.userInfo = reference.userInfo
        }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
    }

    // MARK: - Internals

    static func apply(_ plan: ReminderPlan, loggedDoses: Set<String>, to center: any NotificationScheduling) async {
        let desired = Set(plan.reminders.map(\.identifier))
        let pending = await center.pendingIdentifiers()

        // Drop planned reminders that are no longer wanted, and snoozes for doses since logged.
        let stale = pending.filter { identifier in
            guard let kind = ReminderKind.kind(of: identifier) else { return false }
            if kind == .snooze { return loggedDoses.contains(suffix(of: identifier)) }
            return ReminderKind.planned.contains(kind) && !desired.contains(identifier)
        }
        center.removePending(stale)

        // Clear delivered reminders for doses that have been logged.
        let delivered = await center.deliveredIdentifiers().filter { identifier in
            guard let kind = ReminderKind.kind(of: identifier), [.dose, .nudge, .snooze].contains(kind) else { return false }
            return loggedDoses.contains(suffix(of: identifier))
        }
        center.removeDelivered(delivered)

        for reminder in plan.reminders {
            do {
                try await center.add(request(for: reminder))
            } catch {
                logger.error("Failed to schedule \(reminder.identifier): \(error)")
            }
        }
    }

    private static func loggedDoseKeys(_ medications: [ReminderMedication]) -> Set<String> {
        Set(medications.flatMap { medication in
            medication.loggedDates.map { DoseKey(medicationID: medication.id, scheduledDate: $0).rawValue }
        })
    }

    private static func suffix(of identifier: String) -> String {
        String(identifier.drop { $0 != "." }.dropFirst())
    }

    private static var refillAlertDates: [UUID: Date] {
        get {
            let stored = SharedStore.defaults.dictionary(forKey: refillAlertDatesKey) as? [String: TimeInterval] ?? [:]
            return Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in
                UUID(uuidString: key).map { ($0, Date(timeIntervalSince1970: value)) }
            })
        }
        set {
            let stored = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.uuidString, $0.value.timeIntervalSince1970) })
            SharedStore.defaults.set(stored, forKey: refillAlertDatesKey)
        }
    }
}
