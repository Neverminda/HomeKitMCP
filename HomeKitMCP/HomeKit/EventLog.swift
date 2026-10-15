import Foundation

/// One change reported by HomeKit (home layout, accessory or characteristic update).
struct HomeEvent {
    let id: Int
    let time: Date
    let kind: String
    let home: String?
    let subject: String?
    let detail: [String: Any]

    var dictionary: [String: Any] {
        var result: [String: Any] = [
            "id": id,
            "time": ISO8601DateFormatter().string(from: time),
            "kind": kind,
        ]
        if let home { result["home"] = home }
        if let subject { result["subject"] = subject }
        if !detail.isEmpty { result["detail"] = detail }
        return result
    }
}

/// Bounded in-memory buffer of HomeKit events, read by polling with `get_events`.
@MainActor
final class EventLog {
    static let capacity = 1000

    private(set) var events: [HomeEvent] = []
    private var nextID = 1
    private(set) var droppedCount = 0

    var lastID: Int { nextID - 1 }

    func add(kind: String, home: String?, subject: String?, detail: [String: Any] = [:]) {
        events.append(HomeEvent(id: nextID, time: Date(), kind: kind, home: home, subject: subject, detail: detail))
        nextID += 1
        if events.count > Self.capacity {
            let overflow = events.count - Self.capacity
            events.removeFirst(overflow)
            droppedCount += overflow
        }
    }

    func events(after id: Int, kinds: Set<String>?, limit: Int) -> [HomeEvent] {
        let matching = events.filter { event in
            event.id > id && (kinds?.contains(event.kind) ?? true)
        }
        return Array(matching.prefix(limit))
    }

    func clear() {
        events.removeAll()
    }
}
