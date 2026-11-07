import EventKit
import SwiftUI

struct Entry: Identifiable {
    let id: String, title: String, time: String, sort: Date, color: Color, isReminder: Bool
    var done: Bool
}

final class CalendarModel: ObservableObject {
    private let store = EKEventStore()
    private var reminders: [String: EKReminder] = [:]
    @Published var entries: [Entry] = []
    @Published var date = Date() { didSet { reload() } }

    init() {
        store.requestFullAccessToEvents { [weak self] _, _ in DispatchQueue.main.async { self?.reload() } }
        store.requestFullAccessToReminders { [weak self] _, _ in DispatchQueue.main.async { self?.reload() } }
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in self?.reload() }
    }

    func reload() {
        let cal = Calendar.current
        let s = cal.startOfDay(for: date), e = cal.date(byAdding: .day, value: 1, to: s)!
        let f = DateFormatter(); f.timeStyle = .short
        var out: [Entry] = store.events(matching: store.predicateForEvents(withStart: s, end: e, calendars: nil)).map {
            Entry(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "Event", time: $0.isAllDay ? "All day" : f.string(from: $0.startDate),
                  sort: $0.startDate, color: Color(nsColor: $0.calendar.color), isReminder: false, done: false)
        }
        store.fetchReminders(matching: store.predicateForReminders(in: nil)) { [weak self] rs in
            var map: [String: EKReminder] = [:]
            for r in rs ?? [] {
                guard let comps = r.dueDateComponents, let d = Calendar.current.date(from: comps), d >= s, d < e else { continue }
                let id = r.calendarItemIdentifier; map[id] = r
                out.append(Entry(id: id, title: r.title ?? "Task", time: r.dueDateComponents?.hour == nil ? "Task" : f.string(from: d),
                                 sort: d, color: Color(nsColor: r.calendar.color), isReminder: true, done: r.isCompleted))
            }
            DispatchQueue.main.async { self?.reminders = map; self?.entries = out.sorted { $0.sort < $1.sort } }
        }
    }

    func toggle(_ e: Entry) {
        guard let r = reminders[e.id] else { return }
        r.isCompleted.toggle()
        try? store.save(r, commit: true)
        reload()
    }
}
