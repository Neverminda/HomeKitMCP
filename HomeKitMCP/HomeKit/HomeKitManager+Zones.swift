import Foundation
import HomeKit

// MARK: - Zones and home name

extension HomeKitManager {
    func findZone(name: String, in home: HMHome) -> HMZone? {
        home.zones.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
    }

    func listZones(_ args: ToolArguments) -> [[String: Any]] {
        matchingHomes(name: args.string("home")).flatMap { home in
            home.zones.map { zone in
                [
                    "name": zone.name,
                    "home": home.name,
                    "rooms": zone.rooms.map(\.name),
                    "uniqueIdentifier": zone.uniqueIdentifier.uuidString,
                ] as [String: Any]
            }
        }
    }

    func createZone(_ args: ToolArguments) async throws -> [String: Any] {
        let name = try args.requiredString("name")
        let home = try resolveHome(name: args.string("home"))
        guard findZone(name: name, in: home) == nil else {
            throw HomeKitError.zoneAlreadyExists(name)
        }

        let zone: HMZone = try await withCheckedThrowingContinuation { continuation in
            home.addZone(withName: name) { zone, error in
                if let zone {
                    continuation.resume(returning: zone)
                } else {
                    continuation.resume(throwing: error ?? HomeKitError.invalidValue("HomeKit did not create the zone"))
                }
            }
        }

        var addedRooms: [String] = []
        for roomName in args.strings("rooms") ?? [] {
            guard let room = findRoom(name: roomName, in: home) else {
                throw HomeKitError.roomNotFound(roomName)
            }
            try await zone.addRoom(room)
            addedRooms.append(room.name)
        }
        return ["success": true, "zone": zone.name, "home": home.name, "rooms": addedRooms]
    }

    func renameZone(_ args: ToolArguments) async throws -> [String: Any] {
        let name = try args.requiredString("name")
        let newName = try args.requiredString("new_name")
        let home = try resolveHome(name: args.string("home"), containingZone: name)
        guard let zone = findZone(name: name, in: home) else {
            throw HomeKitError.zoneNotFound(name)
        }
        if let existing = findZone(name: newName, in: home), existing.uniqueIdentifier != zone.uniqueIdentifier {
            throw HomeKitError.zoneAlreadyExists(newName)
        }

        let oldName = zone.name
        try await zone.updateName(newName)
        return ["success": true, "oldName": oldName, "zone": zone.name, "home": home.name]
    }

    /// Deletes the zone only. The rooms in it stay untouched.
    func deleteZone(_ args: ToolArguments) async throws -> [String: Any] {
        let name = try args.requiredString("name")
        let confirmName = try args.requiredString("confirm_name")
        let home = try resolveHome(name: args.string("home"), containingZone: name)
        guard let zone = findZone(name: name, in: home) else {
            throw HomeKitError.zoneNotFound(name)
        }
        guard zone.name.localizedCaseInsensitiveCompare(confirmName) == .orderedSame else {
            throw HomeKitError.confirmationMismatch(expected: zone.name, given: confirmName)
        }

        let removedName = zone.name
        let rooms = zone.rooms.map(\.name)
        try await home.removeZone(zone)
        return ["success": true, "zone": removedName, "home": home.name, "roomsKept": rooms]
    }

    func addRoomToZone(_ args: ToolArguments) async throws -> [String: Any] {
        let zoneName = try args.requiredString("zone")
        let roomName = try args.requiredString("room")
        let home = try resolveHome(name: args.string("home"), containingZone: zoneName)
        guard let zone = findZone(name: zoneName, in: home) else { throw HomeKitError.zoneNotFound(zoneName) }
        guard let room = findRoom(name: roomName, in: home) else { throw HomeKitError.roomNotFound(roomName) }
        guard !zone.rooms.contains(where: { $0.uniqueIdentifier == room.uniqueIdentifier }) else {
            throw HomeKitError.invalidValue("room '\(room.name)' is already in zone '\(zone.name)'")
        }

        try await zone.addRoom(room)
        return ["success": true, "zone": zone.name, "room": room.name, "home": home.name]
    }

    func removeRoomFromZone(_ args: ToolArguments) async throws -> [String: Any] {
        let zoneName = try args.requiredString("zone")
        let roomName = try args.requiredString("room")
        let home = try resolveHome(name: args.string("home"), containingZone: zoneName)
        guard let zone = findZone(name: zoneName, in: home) else { throw HomeKitError.zoneNotFound(zoneName) }
        guard let room = zone.rooms.first(where: { $0.name.localizedCaseInsensitiveCompare(roomName) == .orderedSame })
        else {
            throw HomeKitError.invalidValue("room '\(roomName)' is not in zone '\(zone.name)'")
        }

        try await zone.removeRoom(room)
        return ["success": true, "zone": zone.name, "room": room.name, "home": home.name]
    }

    func renameHome(_ args: ToolArguments) async throws -> [String: Any] {
        let newName = try args.requiredString("new_name")
        let home = try resolveHome(name: args.string("home"))
        if let existing = homeManager?.homes.first(where: {
            $0.name.localizedCaseInsensitiveCompare(newName) == .orderedSame
        }), existing.uniqueIdentifier != home.uniqueIdentifier {
            throw HomeKitError.invalidValue("a home named '\(newName)' already exists")
        }

        let oldName = home.name
        try await home.updateName(newName)
        return ["success": true, "oldName": oldName, "home": home.name]
    }
}
