import Foundation
import HomeKit

// MARK: - Accessory details, characteristics, batch operations

extension HomeKitManager {
    /// Resolves a device from the common `id` / `name` / `home` / `room` arguments.
    func resolveDevice(_ args: ToolArguments) throws -> HMAccessory {
        guard args.string("id") != nil || args.string("name") != nil else {
            throw HomeKitError.invalidValue("either 'id' or 'name' is required")
        }
        guard let accessory = resolveAccessory(
            id: args.string("id"), name: args.string("name"),
            homeName: args.string("home"), roomName: args.string("room")
        ) else {
            throw HomeKitError.deviceNotFound(args.string("id") ?? args.string("name") ?? "unknown")
        }
        return accessory
    }

    func findCharacteristic(id: String) -> HMCharacteristic? {
        guard let uuid = UUID(uuidString: id), let manager = homeManager else { return nil }
        for home in manager.homes {
            for accessory in home.accessories {
                for service in accessory.services {
                    if let characteristic = service.characteristics.first(where: { $0.uniqueIdentifier == uuid }) {
                        return characteristic
                    }
                }
            }
        }
        return nil
    }

    func accessoryForCharacteristic(_ characteristic: HMCharacteristic) -> HMAccessory? {
        characteristic.service?.accessory
    }

    // MARK: Identify and info

    func identifyDevice(_ args: ToolArguments) async throws -> [String: Any] {
        let accessory = try resolveDevice(args)
        guard accessory.supportsIdentify else {
            throw HomeKitError.invalidValue("device '\(accessory.name)' does not support identify")
        }
        guard accessory.isReachable else {
            throw HomeKitError.deviceUnreachable(accessory.name)
        }
        try await accessory.identify()
        return ["success": true, "device": accessory.name, "room": accessory.room?.name ?? "Default Room"]
    }

    func getDeviceInfo(_ args: ToolArguments) throws -> [String: Any] {
        let accessory = try resolveDevice(args)
        var info: [String: Any] = [
            "name": accessory.name,
            "room": accessory.room?.name ?? "Default Room",
            "home": homeNameForAccessory(accessory),
            "type": deviceType(for: accessory),
            "category": accessory.category.localizedDescription,
            "reachable": accessory.isReachable,
            "bridged": accessory.isBridged,
            "supportsIdentify": accessory.supportsIdentify,
            "uniqueIdentifier": accessory.uniqueIdentifier.uuidString,
            "services": accessory.services.map { service in
                var entry: [String: Any] = [
                    "name": service.name,
                    "type": service.serviceType,
                    "primary": service.isPrimaryService,
                    "userInteractive": service.isUserInteractive,
                    "characteristicCount": service.characteristics.count,
                    "id": service.uniqueIdentifier.uuidString,
                ]
                if let associated = service.associatedServiceType { entry["associatedServiceType"] = associated }
                return entry
            },
        ]
        if let manufacturer = accessory.manufacturer { info["manufacturer"] = manufacturer }
        if let model = accessory.model { info["model"] = model }
        if let firmware = accessory.firmwareVersion { info["firmwareVersion"] = firmware }
        if !accessory.bridgedAccessories.isEmpty {
            info["bridgedAccessoryCount"] = accessory.bridgedAccessories.count
        }
        return info
    }

    // MARK: Services

    func renameService(_ args: ToolArguments) async throws -> [String: Any] {
        let serviceID = try args.requiredString("service_id")
        let newName = try args.requiredString("new_name")
        guard let uuid = UUID(uuidString: serviceID), let service = findService(uuid) else {
            throw HomeKitError.serviceNotFound(serviceID)
        }

        let oldName = service.name
        try await service.updateName(newName)
        return [
            "success": true,
            "oldName": oldName,
            "service": service.name,
            "device": service.accessory?.name ?? "unknown",
        ] as [String: Any]
    }

    func findService(_ uuid: UUID) -> HMService? {
        guard let manager = homeManager else { return nil }
        for home in manager.homes {
            for accessory in home.accessories {
                if let service = accessory.services.first(where: { $0.uniqueIdentifier == uuid }) {
                    return service
                }
            }
        }
        return nil
    }

    // MARK: Characteristics

    func listCharacteristics(_ args: ToolArguments) async throws -> [String: Any] {
        let accessory = try resolveDevice(args)
        let readValues = args.bool("read") ?? false

        var services: [[String: Any]] = []
        for service in accessory.services {
            var characteristics: [[String: Any]] = []
            for characteristic in service.characteristics {
                if readValues, accessory.isReachable,
                   characteristic.properties.contains(HMCharacteristicPropertyReadable)
                {
                    try? await characteristic.readValue()
                }
                characteristics.append(describe(characteristic))
            }
            services.append([
                "name": service.name,
                "type": service.serviceType,
                "id": service.uniqueIdentifier.uuidString,
                "characteristics": characteristics,
            ])
        }
        return ["device": accessory.name, "reachable": accessory.isReachable, "services": services]
    }

    func describe(_ characteristic: HMCharacteristic) -> [String: Any] {
        var entry: [String: Any] = [
            "id": characteristic.uniqueIdentifier.uuidString,
            "description": characteristic.localizedDescription,
            "type": characteristic.characteristicType,
            "readable": characteristic.properties.contains(HMCharacteristicPropertyReadable),
            "writable": characteristic.properties.contains(HMCharacteristicPropertyWritable),
            "notifies": characteristic.properties.contains(HMCharacteristicPropertySupportsEventNotification),
            "watching": characteristic.isNotificationEnabled,
        ]
        if let key = characteristicKey(for: characteristic) { entry["key"] = key }
        if let metadata = characteristic.metadata {
            var meta: [String: Any] = [:]
            if let format = metadata.format { meta["format"] = format }
            if let units = metadata.units { meta["units"] = units }
            if let min = metadata.minimumValue { meta["min"] = min }
            if let max = metadata.maximumValue { meta["max"] = max }
            if let step = metadata.stepValue { meta["step"] = step }
            if let validValues = metadata.validValues { meta["validValues"] = validValues }
            if !meta.isEmpty { entry["metadata"] = meta }
        }
        if let value = characteristic.value { entry["value"] = formatValue(value, for: characteristic) }
        return entry
    }

    func readCharacteristic(_ args: ToolArguments) async throws -> [String: Any] {
        let id = try args.requiredString("characteristic_id")
        guard let characteristic = findCharacteristic(id: id) else {
            throw HomeKitError.characteristicIdNotFound(id)
        }
        guard characteristic.properties.contains(HMCharacteristicPropertyReadable) else {
            throw HomeKitError.invalidValue("characteristic is not readable")
        }
        if let accessory = accessoryForCharacteristic(characteristic), !accessory.isReachable {
            throw HomeKitError.deviceUnreachable(accessory.name)
        }

        try await characteristic.readValue()
        var result = describe(characteristic)
        result["device"] = accessoryForCharacteristic(characteristic)?.name ?? "unknown"
        return result
    }

    func writeCharacteristic(_ args: ToolArguments) async throws -> [String: Any] {
        let id = try args.requiredString("characteristic_id")
        guard let characteristic = findCharacteristic(id: id) else {
            throw HomeKitError.characteristicIdNotFound(id)
        }
        guard characteristic.properties.contains(HMCharacteristicPropertyWritable) else {
            throw HomeKitError.characteristicReadOnly(characteristic.localizedDescription)
        }
        guard let rawValue = args.raw["value"], !(rawValue is NSNull) else {
            throw HomeKitError.invalidValue("missing required parameter 'value'")
        }
        let accessory = accessoryForCharacteristic(characteristic)
        if let accessory, !accessory.isReachable {
            throw HomeKitError.deviceUnreachable(accessory.name)
        }

        let value = try coerce(rawValue, for: characteristic)
        try await characteristic.writeValue(value)
        return [
            "success": true,
            "device": accessory?.name ?? "unknown",
            "characteristic": characteristic.localizedDescription,
            "value": value,
        ] as [String: Any]
    }

    /// Converts a JSON value to the type the characteristic's format expects.
    func coerce(_ value: Any, for characteristic: HMCharacteristic) throws -> Any {
        let format = characteristic.metadata?.format ?? ""
        switch format {
        case HMCharacteristicMetadataFormatBool:
            if let flag = ToolArguments(["v": value]).bool("v") { return flag }
            throw HomeKitError.invalidValue("expected true or false")
        case HMCharacteristicMetadataFormatInt, HMCharacteristicMetadataFormatUInt8,
             HMCharacteristicMetadataFormatUInt16, HMCharacteristicMetadataFormatUInt32,
             HMCharacteristicMetadataFormatUInt64:
            if let number = intValue(value) { return number }
            throw HomeKitError.invalidValue("expected an integer")
        case HMCharacteristicMetadataFormatFloat:
            if let number = doubleValue(value) { return number }
            throw HomeKitError.invalidValue("expected a number")
        case HMCharacteristicMetadataFormatString:
            return "\(value)"
        default:
            return value
        }
    }

    // MARK: Batch operations

    func batchMoveDevices(_ args: ToolArguments) async throws -> [[String: Any]] {
        guard let moves = args.objects("moves"), !moves.isEmpty else {
            throw HomeKitError.invalidValue("'moves' must be a non-empty array")
        }
        var results: [[String: Any]] = []
        for move in moves {
            do {
                guard let target = move.string("target_room") else {
                    throw HomeKitError.invalidValue("missing 'target_room'")
                }
                results.append(try await moveDevice(
                    id: move.string("id"), name: move.string("name"),
                    homeName: move.string("home"), roomName: move.string("room"), targetRoom: target
                ))
            } catch {
                results.append([
                    "success": false,
                    "device": move.string("id") ?? move.string("name") ?? "unknown",
                    "error": error.localizedDescription,
                ])
            }
        }
        return results
    }

    func batchRenameDevices(_ args: ToolArguments) async throws -> [[String: Any]] {
        guard let renames = args.objects("renames"), !renames.isEmpty else {
            throw HomeKitError.invalidValue("'renames' must be a non-empty array")
        }
        var results: [[String: Any]] = []
        for rename in renames {
            do {
                guard let newName = rename.string("new_name") else {
                    throw HomeKitError.invalidValue("missing 'new_name'")
                }
                results.append(try await renameDevice(
                    id: rename.string("id"), name: rename.string("name"),
                    homeName: rename.string("home"), roomName: rename.string("room"), newName: newName
                ))
            } catch {
                results.append([
                    "success": false,
                    "device": rename.string("id") ?? rename.string("name") ?? "unknown",
                    "error": error.localizedDescription,
                ])
            }
        }
        return results
    }
}
