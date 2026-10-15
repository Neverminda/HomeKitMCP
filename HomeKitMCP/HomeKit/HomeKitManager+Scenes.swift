import Foundation
import HomeKit

// MARK: - Scenes (action sets)

extension HomeKitManager {
    /// Friendly property names accepted in scene actions and automation events.
    static let propertyCharacteristicTypes: [String: String] = [
        "power": HMCharacteristicTypePowerState,
        "brightness": HMCharacteristicTypeBrightness,
        "hue": HMCharacteristicTypeHue,
        "saturation": HMCharacteristicTypeSaturation,
        "target_temperature": HMCharacteristicTypeTargetTemperature,
        "lock": HMCharacteristicTypeTargetLockMechanismState,
        "door": HMCharacteristicTypeTargetDoorState,
        "thermostat_mode": HMCharacteristicTypeTargetHeatingCooling,
        "fan_speed": HMCharacteristicTypeRotationSpeed,
        "motion": HMCharacteristicTypeMotionDetected,
        "contact": HMCharacteristicTypeContactState,
        "occupancy": HMCharacteristicTypeOccupancyDetected,
    ]

    /// Resolves the characteristic of an action or event spec, by `characteristic_id` or by `device` + `property`.
    func resolveCharacteristic(_ spec: ToolArguments) throws -> HMCharacteristic {
        if let id = spec.string("characteristic_id") {
            guard let characteristic = findCharacteristic(id: id) else {
                throw HomeKitError.characteristicIdNotFound(id)
            }
            return characteristic
        }
        guard let property = spec.string("property") else {
            throw HomeKitError.invalidValue("each entry needs 'characteristic_id' or 'property' with a device")
        }
        guard let type = Self.propertyCharacteristicTypes[property.lowercased()] else {
            throw HomeKitError.invalidValue(
                "unknown property '\(property)'. Use one of: \(Self.propertyCharacteristicTypes.keys.sorted().joined(separator: ", "))"
            )
        }
        let accessory = try resolveDevice(spec)
        guard let characteristic = findCharacteristic(accessory: accessory, type: type) else {
            throw HomeKitError.characteristicNotFound("\(property) on '\(accessory.name)'")
        }
        return characteristic
    }

    /// Converts friendly values ("locked", "open", "heat", "on") into HomeKit values.
    func normalizedValue(_ value: Any, for characteristic: HMCharacteristic) throws -> Any {
        if let text = value as? String {
            switch characteristic.characteristicType {
            case HMCharacteristicTypeTargetLockMechanismState:
                switch text.lowercased() {
                case "locked", "lock", "secured": return HMCharacteristicValueLockMechanismState.secured.rawValue
                case "unlocked", "unlock", "unsecured": return HMCharacteristicValueLockMechanismState.unsecured.rawValue
                default: break
                }
            case HMCharacteristicTypeTargetDoorState:
                switch text.lowercased() {
                case "open": return HMCharacteristicValueDoorState.open.rawValue
                case "closed", "close": return HMCharacteristicValueDoorState.closed.rawValue
                default: break
                }
            case HMCharacteristicTypeTargetHeatingCooling:
                switch text.lowercased() {
                case "off": return HMCharacteristicValueHeatingCooling.off.rawValue
                case "heat": return HMCharacteristicValueHeatingCooling.heat.rawValue
                case "cool": return HMCharacteristicValueHeatingCooling.cool.rawValue
                case "auto": return HMCharacteristicValueHeatingCooling.auto.rawValue
                default: break
                }
            default:
                break
            }
        }
        return try coerce(value, for: characteristic)
    }

    func describeAction(_ action: HMAction, index: Int) -> [String: Any] {
        var entry: [String: Any] = ["index": index]
        if let write = action as? HMCharacteristicWriteAction<NSCopying> {
            let characteristic = write.characteristic
            entry["type"] = "characteristic_write"
            entry["device"] = characteristic.service?.accessory?.name ?? "unknown"
            entry["room"] = characteristic.service?.accessory?.room?.name ?? "Default Room"
            entry["characteristic"] = characteristic.localizedDescription
            entry["characteristic_id"] = characteristic.uniqueIdentifier.uuidString
            if let key = characteristicKey(for: characteristic) { entry["property"] = key }
            entry["value"] = formatTargetValue(write.targetValue, for: characteristic)
        } else {
            entry["type"] = "other"
        }
        return entry
    }

    /// Like `formatValue`, but also maps the target-state variants of locks, doors and thermostats.
    func formatTargetValue(_ value: Any, for characteristic: HMCharacteristic) -> Any {
        guard let raw = value as? Int else { return value }
        switch characteristic.characteristicType {
        case HMCharacteristicTypeTargetLockMechanismState:
            return raw == HMCharacteristicValueLockMechanismState.secured.rawValue ? "locked" : "unlocked"
        case HMCharacteristicTypeTargetDoorState:
            return raw == HMCharacteristicValueDoorState.open.rawValue ? "open" : "closed"
        default:
            return formatValue(value, for: characteristic)
        }
    }

    func findScene(_ args: ToolArguments) throws -> (scene: HMActionSet, home: HMHome) {
        guard args.string("id") != nil || args.string("name") != nil else {
            throw HomeKitError.invalidValue("either 'id' or 'name' is required")
        }
        guard let scene = resolveActionSet(name: args.string("name"), homeName: args.string("home"), id: args.string("id")),
              let home = homeForActionSet(scene)
        else {
            throw HomeKitError.sceneNotFound(args.string("id") ?? args.string("name") ?? "unknown")
        }
        return (scene, home)
    }

    func getScene(_ args: ToolArguments) throws -> [String: Any] {
        let (scene, home) = try findScene(args)
        var info: [String: Any] = [
            "name": scene.name,
            "home": home.name,
            "uniqueIdentifier": scene.uniqueIdentifier.uuidString,
            "executing": scene.isExecuting,
            "actions": scene.actions.enumerated().map { describeAction($1, index: $0) },
        ]
        if let type = actionSetType(for: scene) { info["type"] = type }
        if let last = scene.lastExecutionDate { info["lastExecution"] = ISO8601DateFormatter().string(from: last) }
        return info
    }

    func makeWriteActions(from specs: [ToolArguments]) throws -> [HMCharacteristicWriteAction<NSCopying>] {
        try specs.map { spec in
            let characteristic = try resolveCharacteristic(spec)
            guard characteristic.properties.contains(HMCharacteristicPropertyWritable) else {
                throw HomeKitError.characteristicReadOnly(characteristic.localizedDescription)
            }
            guard let raw = spec.raw["value"], !(raw is NSNull) else {
                throw HomeKitError.invalidValue("each action needs a 'value'")
            }
            guard let value = try normalizedValue(raw, for: characteristic) as? NSCopying else {
                throw HomeKitError.invalidValue("unsupported value type")
            }
            return HMCharacteristicWriteAction(characteristic: characteristic, targetValue: value)
        }
    }

    func createScene(_ args: ToolArguments) async throws -> [String: Any] {
        let name = try args.requiredString("name")
        let home = try resolveHome(name: args.string("home"))
        guard !home.actionSets.contains(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else {
            throw HomeKitError.sceneAlreadyExists(name)
        }
        // Resolve and validate every action first, so a bad entry never leaves a half-built scene behind.
        let actions = try makeWriteActions(from: args.objects("actions") ?? [])

        let scene: HMActionSet = try await withCheckedThrowingContinuation { continuation in
            home.addActionSet(withName: name) { scene, error in
                if let scene {
                    continuation.resume(returning: scene)
                } else {
                    continuation.resume(throwing: error ?? HomeKitError.invalidValue("HomeKit did not create the scene"))
                }
            }
        }
        do {
            for action in actions {
                try await scene.addAction(action)
            }
        } catch {
            try? await home.removeActionSet(scene)
            throw error
        }
        return ["success": true, "scene": scene.name, "home": home.name, "actionCount": actions.count]
    }

    func addSceneActions(_ args: ToolArguments) async throws -> [String: Any] {
        let (scene, home) = try findScene(args)
        guard let specs = args.objects("actions"), !specs.isEmpty else {
            throw HomeKitError.invalidValue("'actions' must be a non-empty array")
        }
        let actions = try makeWriteActions(from: specs)
        for action in actions {
            try await scene.addAction(action)
        }
        return ["success": true, "scene": scene.name, "home": home.name, "added": actions.count,
                "actionCount": scene.actions.count]
    }

    /// Removes actions by their `index` (from `get_scene`) or by `characteristic_id`.
    func removeSceneActions(_ args: ToolArguments) async throws -> [String: Any] {
        let (scene, home) = try findScene(args)
        let indexes = (args.raw["indexes"] as? [Any])?.compactMap { ToolArguments(["v": $0]).int("v") } ?? []
        let ids = Set(args.strings("characteristic_ids") ?? [])
        guard !indexes.isEmpty || !ids.isEmpty else {
            throw HomeKitError.invalidValue("give 'indexes' or 'characteristic_ids'")
        }

        let current = Array(scene.actions)
        var toRemove: [HMAction] = []
        for (index, action) in current.enumerated() {
            var matches = indexes.contains(index)
            if let write = action as? HMCharacteristicWriteAction<NSCopying>,
               ids.contains(write.characteristic.uniqueIdentifier.uuidString)
            {
                matches = true
            }
            if matches { toRemove.append(action) }
        }
        guard !toRemove.isEmpty else {
            throw HomeKitError.invalidValue("no action matched")
        }
        for action in toRemove {
            try await scene.removeAction(action)
        }
        return ["success": true, "scene": scene.name, "home": home.name, "removed": toRemove.count,
                "actionCount": scene.actions.count]
    }

    func renameScene(_ args: ToolArguments) async throws -> [String: Any] {
        let newName = try args.requiredString("new_name")
        let (scene, home) = try findScene(args)
        if let existing = home.actionSets.first(where: {
            $0.name.localizedCaseInsensitiveCompare(newName) == .orderedSame
        }), existing.uniqueIdentifier != scene.uniqueIdentifier {
            throw HomeKitError.sceneAlreadyExists(newName)
        }

        let oldName = scene.name
        try await scene.updateName(newName)
        return ["success": true, "oldName": oldName, "scene": scene.name, "home": home.name]
    }

    /// Deletes a user-defined scene. Built-in scenes (wake up, sleep, arrive, leave) are refused by HomeKit.
    func deleteScene(_ args: ToolArguments) async throws -> [String: Any] {
        let confirmName = try args.requiredString("confirm_name")
        let (scene, home) = try findScene(args)
        guard scene.name.localizedCaseInsensitiveCompare(confirmName) == .orderedSame else {
            throw HomeKitError.confirmationMismatch(expected: scene.name, given: confirmName)
        }

        let removedName = scene.name
        let usedBy = home.triggers.filter { $0.actionSets.contains(where: { $0.uniqueIdentifier == scene.uniqueIdentifier }) }
            .map(\.name)
        try await home.removeActionSet(scene)
        return ["success": true, "scene": removedName, "home": home.name, "wasUsedByAutomations": usedBy]
    }
}
