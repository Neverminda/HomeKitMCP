import Foundation
import HomeKit

// MARK: - Event collection (delegates feed the event log)

extension HomeKitManager {
    /// Records an event from any thread; the log itself lives on the main actor.
    nonisolated func emit(_ kind: String, home: String?, subject: String?, detail: [String: any Sendable] = [:]) {
        Task { @MainActor in
            eventLog.add(kind: kind, home: home, subject: subject, detail: detail.mapValues { $0 as Any })
        }
    }

    /// Becomes the delegate of every home and accessory so changes made elsewhere are logged.
    func attachDelegates() {
        guard let manager = homeManager else { return }
        for home in manager.homes {
            home.delegate = self
            for accessory in home.accessories {
                accessory.delegate = self
            }
        }
    }

    // MARK: Reading events

    func getEvents(_ args: ToolArguments) async throws -> [String: Any] {
        let sinceID = args.int("since_id") ?? 0
        let limit = min(max(args.int("limit") ?? 100, 1), 500)
        let kinds = args.strings("kinds").map(Set.init)
        let wait = min(max(args.double("wait_seconds") ?? 0, 0), 60)

        var events = eventLog.events(after: sinceID, kinds: kinds, limit: limit)
        let deadline = Date().addingTimeInterval(wait)
        while events.isEmpty, Date() < deadline {
            try await Task.sleep(for: .milliseconds(250))
            events = eventLog.events(after: sinceID, kinds: kinds, limit: limit)
        }

        var result: [String: Any] = [
            "events": events.map(\.dictionary),
            "last_id": eventLog.lastID,
            "buffered": eventLog.events.count,
        ]
        if eventLog.droppedCount > 0 { result["dropped"] = eventLog.droppedCount }
        return result
    }

    func clearEvents() -> [String: Any] {
        let cleared = eventLog.events.count
        eventLog.clear()
        return ["success": true, "cleared": cleared, "last_id": eventLog.lastID]
    }

    // MARK: Watching characteristics

    /// Picks devices by `id`/`name`, or by `home`/`room`/`type` filters. At least one selector is required.
    func selectDevices(_ args: ToolArguments) throws -> [HMAccessory] {
        if args.string("id") != nil || args.string("name") != nil {
            return [try resolveDevice(args)]
        }
        let type = args.string("type")
        guard args.string("home") != nil || args.string("room") != nil || type != nil else {
            throw HomeKitError.invalidValue("give 'id', 'name', or at least one of 'home', 'room', 'type'")
        }
        let accessories = matchingAccessories(homeName: args.string("home"), roomName: args.string("room"))
        return accessories.filter { type == nil || deviceType(for: $0).lowercased() == type?.lowercased() }
    }

    func watchDevices(_ args: ToolArguments, enable: Bool) async throws -> [String: Any] {
        let accessories = try selectDevices(args)
        guard !accessories.isEmpty else {
            throw HomeKitError.invalidValue("no devices matched the given selection")
        }

        var changed = 0
        var failed: [[String: Any]] = []
        var skipped: [String] = []
        for accessory in accessories {
            guard accessory.isReachable else {
                skipped.append(accessory.name)
                continue
            }
            for service in accessory.services {
                for characteristic in service.characteristics
                where characteristic.properties.contains(HMCharacteristicPropertySupportsEventNotification)
                {
                    let id = characteristic.uniqueIdentifier
                    // Only undo what this server enabled; HomeKit may rely on the others itself.
                    if !enable, !watchedCharacteristics.contains(id) { continue }
                    if enable, watchedCharacteristics.contains(id) { continue }
                    do {
                        try await characteristic.enableNotification(enable)
                        if enable { watchedCharacteristics.insert(id) } else { watchedCharacteristics.remove(id) }
                        changed += 1
                    } catch {
                        failed.append([
                            "device": accessory.name,
                            "characteristic": characteristic.localizedDescription,
                            "error": error.localizedDescription,
                        ])
                    }
                }
            }
        }
        var result: [String: Any] = [
            "success": failed.isEmpty,
            "devices": accessories.count,
            "characteristicsChanged": changed,
            "watching": enable,
        ]
        if !skipped.isEmpty { result["skippedUnreachable"] = skipped }
        if !failed.isEmpty { result["failed"] = failed }
        return result
    }

    /// Devices watched through `watch_devices`.
    func listWatched() -> [[String: Any]] {
        guard let manager = homeManager else { return [] }
        return manager.homes.flatMap { home in
            home.accessories.compactMap { accessory -> [String: Any]? in
                let watched = accessory.services.flatMap(\.characteristics)
                    .filter { watchedCharacteristics.contains($0.uniqueIdentifier) }
                guard !watched.isEmpty else { return nil }
                return [
                    "device": accessory.name,
                    "room": accessory.room?.name ?? "Default Room",
                    "home": home.name,
                    "characteristics": watched.map(\.localizedDescription),
                ]
            }
        }
    }
}

// MARK: - HMHomeDelegate

extension HomeKitManager: HMHomeDelegate {
    nonisolated func homeDidUpdateName(_ home: HMHome) {
        emit("home_renamed", home: home.name, subject: home.name)
    }

    nonisolated func home(_ home: HMHome, didAdd accessory: HMAccessory) {
        emit("device_added", home: home.name, subject: accessory.name)
        Task { @MainActor in accessory.delegate = self }
    }

    nonisolated func home(_ home: HMHome, didRemove accessory: HMAccessory) {
        emit("device_removed", home: home.name, subject: accessory.name)
    }

    nonisolated func home(_ home: HMHome, didAdd user: HMUser) {
        emit("user_added", home: home.name, subject: user.name)
    }

    nonisolated func home(_ home: HMHome, didRemove user: HMUser) {
        emit("user_removed", home: home.name, subject: user.name)
    }

    nonisolated func home(_ home: HMHome, didUpdate room: HMRoom, for accessory: HMAccessory) {
        emit("device_moved", home: home.name, subject: accessory.name, detail: ["room": room.name])
    }

    nonisolated func home(_ home: HMHome, didAdd room: HMRoom) {
        emit("room_added", home: home.name, subject: room.name)
    }

    nonisolated func home(_ home: HMHome, didRemove room: HMRoom) {
        emit("room_removed", home: home.name, subject: room.name)
    }

    nonisolated func home(_ home: HMHome, didUpdateNameFor room: HMRoom) {
        emit("room_renamed", home: home.name, subject: room.name)
    }

    nonisolated func home(_ home: HMHome, didAdd zone: HMZone) {
        emit("zone_added", home: home.name, subject: zone.name)
    }

    nonisolated func home(_ home: HMHome, didRemove zone: HMZone) {
        emit("zone_removed", home: home.name, subject: zone.name)
    }

    nonisolated func home(_ home: HMHome, didUpdateNameFor zone: HMZone) {
        emit("zone_renamed", home: home.name, subject: zone.name)
    }

    nonisolated func home(_ home: HMHome, didAdd room: HMRoom, to zone: HMZone) {
        emit("room_added_to_zone", home: home.name, subject: room.name, detail: ["zone": zone.name])
    }

    nonisolated func home(_ home: HMHome, didRemove room: HMRoom, from zone: HMZone) {
        emit("room_removed_from_zone", home: home.name, subject: room.name, detail: ["zone": zone.name])
    }

    nonisolated func home(_ home: HMHome, didAdd actionSet: HMActionSet) {
        emit("scene_added", home: home.name, subject: actionSet.name)
    }

    nonisolated func home(_ home: HMHome, didRemove actionSet: HMActionSet) {
        emit("scene_removed", home: home.name, subject: actionSet.name)
    }

    nonisolated func home(_ home: HMHome, didUpdateNameFor actionSet: HMActionSet) {
        emit("scene_renamed", home: home.name, subject: actionSet.name)
    }

    nonisolated func home(_ home: HMHome, didUpdateActionsFor actionSet: HMActionSet) {
        emit("scene_changed", home: home.name, subject: actionSet.name)
    }

    nonisolated func home(_ home: HMHome, didAdd trigger: HMTrigger) {
        emit("automation_added", home: home.name, subject: trigger.name)
    }

    nonisolated func home(_ home: HMHome, didRemove trigger: HMTrigger) {
        emit("automation_removed", home: home.name, subject: trigger.name)
    }

    nonisolated func home(_ home: HMHome, didUpdateNameFor trigger: HMTrigger) {
        emit("automation_renamed", home: home.name, subject: trigger.name)
    }

    nonisolated func home(_ home: HMHome, didUpdate trigger: HMTrigger) {
        emit("automation_changed", home: home.name, subject: trigger.name, detail: ["enabled": trigger.isEnabled])
    }

    nonisolated func home(_ home: HMHome, didEncounterError error: any Error, for accessory: HMAccessory) {
        emit("device_error", home: home.name, subject: accessory.name, detail: ["error": error.localizedDescription])
    }
}

// MARK: - HMAccessoryDelegate

extension HomeKitManager {
    nonisolated func accessoryDidUpdateName(_ accessory: HMAccessory) {
        emit("device_renamed", home: nil, subject: accessory.name)
    }

    nonisolated func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        emit("device_reachability", home: nil, subject: accessory.name, detail: ["reachable": accessory.isReachable])
    }

    nonisolated func accessoryDidUpdateServices(_ accessory: HMAccessory) {
        emit("device_services_changed", home: nil, subject: accessory.name)
    }

    nonisolated func accessory(_ accessory: HMAccessory, didUpdateNameFor service: HMService) {
        emit("service_renamed", home: nil, subject: accessory.name, detail: ["service": service.name])
    }

    nonisolated func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        Task { @MainActor in
            var detail: [String: Any] = [
                "characteristic": characteristicKey(for: characteristic) ?? characteristic.localizedDescription,
                "service": service.name,
            ]
            if let value = characteristic.value { detail["value"] = formatValue(value, for: characteristic) }
            eventLog.add(kind: "characteristic_changed", home: nil, subject: accessory.name, detail: detail)
        }
    }
}
