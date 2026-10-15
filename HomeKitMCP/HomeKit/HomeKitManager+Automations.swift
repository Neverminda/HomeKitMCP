import Foundation
import HomeKit

// MARK: - Automations (triggers)

extension HomeKitManager {
    func findAutomation(_ args: ToolArguments) throws -> (trigger: HMTrigger, home: HMHome) {
        guard args.string("id") != nil || args.string("name") != nil else {
            throw HomeKitError.invalidValue("either 'id' or 'name' is required")
        }
        let homes = matchingHomes(name: args.string("home"))
        if let id = args.string("id"), let uuid = UUID(uuidString: id) {
            for home in homes {
                if let trigger = home.triggers.first(where: { $0.uniqueIdentifier == uuid }) { return (trigger, home) }
            }
            throw HomeKitError.automationNotFound(id)
        }
        let name = args.string("name") ?? ""
        for home in homes {
            if let trigger = home.triggers.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                return (trigger, home)
            }
        }
        throw HomeKitError.automationNotFound(name)
    }

    // MARK: Reading

    func listAutomations(_ args: ToolArguments) -> [[String: Any]] {
        matchingHomes(name: args.string("home")).flatMap { home in
            home.triggers.map { describeAutomation($0, in: home) }
        }
    }

    func getAutomation(_ args: ToolArguments) throws -> [String: Any] {
        let (trigger, home) = try findAutomation(args)
        return describeAutomation(trigger, in: home)
    }

    func describeAutomation(_ trigger: HMTrigger, in home: HMHome) -> [String: Any] {
        var info: [String: Any] = [
            "name": trigger.name,
            "home": home.name,
            "enabled": trigger.isEnabled,
            "uniqueIdentifier": trigger.uniqueIdentifier.uuidString,
            "scenes": trigger.actionSets.map(sceneLabel),
        ]

        if let timer = trigger as? HMTimerTrigger {
            info["type"] = "timer"
            info["fireDate"] = ISO8601DateFormatter().string(from: timer.fireDate)
            if let recurrence = timer.recurrence { info["recurrence"] = describeRecurrence(recurrence) }
        } else if let event = trigger as? HMEventTrigger {
            info["type"] = "event"
            info["events"] = event.events.map(describeEvent)
            if !event.endEvents.isEmpty { info["endEvents"] = event.endEvents.map(describeEvent) }
            if let recurrences = event.recurrences {
                info["weekdays"] = recurrences.compactMap(\.weekday)
            }
            if let predicate = event.predicate { info["condition"] = predicate.predicateFormat }
            info["executeOnce"] = event.executeOnce
        } else {
            info["type"] = "other"
        }
        return info
    }

    /// The Home app stores actions typed in directly in hidden action sets with an empty or UUID name.
    func sceneLabel(_ scene: HMActionSet) -> String {
        if scene.name.isEmpty || UUID(uuidString: scene.name) != nil {
            return "(own actions: \(scene.actions.count))"
        }
        return scene.name
    }

    func describeRecurrence(_ components: DateComponents) -> String {
        if components.minute == 5 { return "every 5 minutes" }
        if components.hour == 1 { return "hourly" }
        if components.day == 1 { return "daily" }
        if components.weekOfYear == 1 { return "weekly" }
        if components.month == 1 { return "monthly" }
        if components.year == 1 { return "yearly" }
        return "\(components)"
    }

    func describeEvent(_ event: HMEvent) -> [String: Any] {
        switch event {
        case let event as HMCharacteristicEvent<NSCopying>:
            var entry: [String: Any] = [
                "type": "characteristic",
                "device": event.characteristic.service?.accessory?.name ?? "unknown",
                "characteristic": event.characteristic.localizedDescription,
                "characteristic_id": event.characteristic.uniqueIdentifier.uuidString,
            ]
            if let key = characteristicKey(for: event.characteristic) { entry["property"] = key }
            if let value = event.triggerValue { entry["value"] = formatTargetValue(value, for: event.characteristic) }
            return entry
        case let event as HMCharacteristicThresholdRangeEvent:
            var entry: [String: Any] = [
                "type": "threshold",
                "device": event.characteristic.service?.accessory?.name ?? "unknown",
                "characteristic": event.characteristic.localizedDescription,
            ]
            if let min = event.thresholdRange.minValue { entry["min"] = min }
            if let max = event.thresholdRange.maxValue { entry["max"] = max }
            return entry
        case let event as HMSignificantTimeEvent:
            var entry: [String: Any] = [
                "type": event.significantEvent == .sunrise ? "sunrise" : "sunset",
            ]
            if let offset = event.offset, let minutes = offset.minute ?? offset.hour.map({ $0 * 60 }) {
                entry["offset_minutes"] = minutes
            }
            return entry
        case let event as HMCalendarEvent:
            return [
                "type": "time",
                "hour": event.fireDateComponents.hour ?? 0,
                "minute": event.fireDateComponents.minute ?? 0,
            ]
        case let event as HMDurationEvent:
            return ["type": "duration", "seconds": event.duration]
        case is HMPresenceEvent:
            return ["type": "presence"]
        case is HMLocationEvent:
            return ["type": "location"]
        default:
            return ["type": "other"]
        }
    }

    // MARK: Creating

    func makeEvents(from specs: [ToolArguments]) throws -> [HMEvent] {
        try specs.map { spec in
            let type = try spec.requiredString("type").lowercased()
            switch type {
            case "characteristic":
                let characteristic = try resolveCharacteristic(spec)
                guard characteristic.properties.contains(HMCharacteristicPropertySupportsEventNotification) else {
                    throw HomeKitError.invalidValue("'\(characteristic.localizedDescription)' cannot trigger automations")
                }
                var trigger: NSCopying?
                if let raw = spec.raw["value"], !(raw is NSNull) {
                    trigger = try normalizedValue(raw, for: characteristic) as? NSCopying
                }
                return HMCharacteristicEvent(characteristic: characteristic, triggerValue: trigger)
            case "sunrise", "sunset":
                let significant = type == "sunrise" ? HMSignificantEvent.sunrise : HMSignificantEvent.sunset
                var offset: DateComponents?
                if let minutes = spec.int("offset_minutes"), minutes != 0 {
                    offset = DateComponents(minute: minutes)
                }
                return HMSignificantTimeEvent(significantEvent: significant, offset: offset)
            case "time":
                guard let hour = spec.int("hour"), (0...23).contains(hour),
                      let minute = spec.int("minute"), (0...59).contains(minute)
                else {
                    throw HomeKitError.invalidValue("event type 'time' needs 'hour' (0-23) and 'minute' (0-59)")
                }
                return HMCalendarEvent(fire: DateComponents(hour: hour, minute: minute))
            default:
                throw HomeKitError.invalidValue("unknown event type '\(type)'. Use characteristic, sunrise, sunset, time")
            }
        }
    }

    func recurrenceComponents(_ name: String) throws -> DateComponents {
        switch name.lowercased() {
        case "hourly": return DateComponents(hour: 1)
        case "daily": return DateComponents(day: 1)
        case "weekly": return DateComponents(weekOfYear: 1)
        case "monthly": return DateComponents(month: 1)
        case "yearly": return DateComponents(year: 1)
        default: throw HomeKitError.invalidValue("unknown recurrence '\(name)'. Use hourly, daily, weekly, monthly, yearly")
        }
    }

    func timeWindowPredicate(_ window: ToolArguments) throws -> NSPredicate {
        func components(_ key: String) throws -> DateComponents {
            let text = try window.requiredString(key)
            let parts = text.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else {
                throw HomeKitError.invalidValue("'\(key)' must look like HH:mm")
            }
            return DateComponents(hour: parts[0], minute: parts[1])
        }
        return HMEventTrigger.predicateForEvaluatingTriggerOccurringBetweenDate(
            with: try components("from"), secondDateWith: try components("to")
        )
    }

    func resolveScenes(_ args: ToolArguments, in home: HMHome, allowEmpty: Bool = false) throws -> [HMActionSet] {
        let names = args.strings("scenes") ?? []
        guard allowEmpty || !names.isEmpty else {
            throw HomeKitError.invalidValue("'scenes' must list at least one scene name or id")
        }
        return try names.map { entry in
            let match = home.actionSets.first { scene in
                scene.uniqueIdentifier.uuidString.caseInsensitiveCompare(entry) == .orderedSame
                    || scene.name.localizedCaseInsensitiveCompare(entry) == .orderedSame
            }
            guard let match else { throw HomeKitError.sceneNotFound(entry) }
            return match
        }
    }

    /// Creates an automation. It stays disabled unless `enabled` is true.
    func createAutomation(_ args: ToolArguments) async throws -> [String: Any] {
        let name = try args.requiredString("name")
        let type = try args.requiredString("type").lowercased()
        let home = try resolveHome(name: args.string("home"))
        guard !home.triggers.contains(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else {
            throw HomeKitError.automationAlreadyExists(name)
        }
        let scenes = try resolveScenes(args, in: home)

        // Build the whole trigger before touching HomeKit.
        let trigger: HMTrigger
        switch type {
        case "timer":
            guard let dateText = args.string("fire_date"),
                  let fireDate = ISO8601DateFormatter().date(from: dateText)
            else {
                throw HomeKitError.invalidValue("'fire_date' must be an ISO 8601 date, e.g. 2026-10-20T07:30:00+02:00")
            }
            let recurrence = try args.string("recurrence").map(recurrenceComponents)
            trigger = HMTimerTrigger(name: name, fireDate: fireDate, recurrence: recurrence)
        case "event":
            guard let specs = args.objects("events"), !specs.isEmpty else {
                throw HomeKitError.invalidValue("'events' must be a non-empty array")
            }
            let events = try makeEvents(from: specs)
            let recurrences = args.raw["weekdays"] == nil ? nil : try weekdayRecurrences(args)
            let predicate = try args.object("only_between").map(timeWindowPredicate)
            let eventTrigger = HMEventTrigger(
                name: name, events: events, end: nil, recurrences: recurrences, predicate: predicate
            )
            trigger = eventTrigger
        default:
            throw HomeKitError.invalidValue("'type' must be 'timer' or 'event'")
        }

        try await home.addTrigger(trigger)
        do {
            for scene in scenes {
                try await trigger.addActionSet(scene)
            }
            if args.bool("enabled") ?? false {
                try await trigger.enable(true)
            }
        } catch {
            try? await home.removeTrigger(trigger)
            throw error
        }
        return describeAutomation(trigger, in: home).merging(["success": true]) { current, _ in current }
    }

    func weekdayRecurrences(_ args: ToolArguments) throws -> [DateComponents] {
        guard let raw = args.raw["weekdays"] as? [Any] else {
            throw HomeKitError.invalidValue("'weekdays' must be an array of 1-7 (1 = Sunday)")
        }
        let days = raw.compactMap { ToolArguments(["v": $0]).int("v") }
        guard !days.isEmpty, days.count == raw.count, days.allSatisfy({ (1...7).contains($0) }) else {
            throw HomeKitError.invalidValue("'weekdays' must be numbers from 1 (Sunday) to 7 (Saturday)")
        }
        return days.map { DateComponents(weekday: $0) }
    }

    // MARK: Changing

    func enableAutomation(_ args: ToolArguments) async throws -> [String: Any] {
        guard let enabled = args.bool("enabled") else {
            throw HomeKitError.invalidValue("missing required parameter 'enabled' (true or false)")
        }
        let (trigger, home) = try findAutomation(args)
        try await trigger.enable(enabled)
        return ["success": true, "automation": trigger.name, "home": home.name, "enabled": trigger.isEnabled]
    }

    func renameAutomation(_ args: ToolArguments) async throws -> [String: Any] {
        let newName = try args.requiredString("new_name")
        let (trigger, home) = try findAutomation(args)
        if let existing = home.triggers.first(where: {
            $0.name.localizedCaseInsensitiveCompare(newName) == .orderedSame
        }), existing.uniqueIdentifier != trigger.uniqueIdentifier {
            throw HomeKitError.automationAlreadyExists(newName)
        }

        let oldName = trigger.name
        try await trigger.updateName(newName)
        return ["success": true, "oldName": oldName, "automation": trigger.name, "home": home.name]
    }

    func updateAutomationScenes(_ args: ToolArguments) async throws -> [String: Any] {
        let (trigger, home) = try findAutomation(args)
        let addNames = args.strings("add") ?? []
        let removeNames = args.strings("remove") ?? []
        guard !addNames.isEmpty || !removeNames.isEmpty else {
            throw HomeKitError.invalidValue("give 'add' and/or 'remove' with scene names")
        }
        let toAdd = try resolveScenes(ToolArguments(["scenes": addNames]), in: home, allowEmpty: true)
        let toRemove = try resolveScenes(ToolArguments(["scenes": removeNames]), in: home, allowEmpty: true)
        let remaining = trigger.actionSets.count + toAdd.count - toRemove.count
        guard remaining >= 1 else {
            throw HomeKitError.invalidValue("an automation needs at least one scene")
        }

        for scene in toAdd where !trigger.actionSets.contains(where: { $0.uniqueIdentifier == scene.uniqueIdentifier }) {
            try await trigger.addActionSet(scene)
        }
        for scene in toRemove where trigger.actionSets.contains(where: { $0.uniqueIdentifier == scene.uniqueIdentifier }) {
            try await trigger.removeActionSet(scene)
        }
        return ["success": true, "automation": trigger.name, "home": home.name, "scenes": trigger.actionSets.map(sceneLabel)]
    }

    func deleteAutomation(_ args: ToolArguments) async throws -> [String: Any] {
        let confirmName = try args.requiredString("confirm_name")
        let (trigger, home) = try findAutomation(args)
        guard trigger.name.localizedCaseInsensitiveCompare(confirmName) == .orderedSame else {
            throw HomeKitError.confirmationMismatch(expected: trigger.name, given: confirmName)
        }

        let removedName = trigger.name
        try await home.removeTrigger(trigger)
        return ["success": true, "automation": removedName, "home": home.name]
    }
}
