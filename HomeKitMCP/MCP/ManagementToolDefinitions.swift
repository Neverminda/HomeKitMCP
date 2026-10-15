import MCP

/// Tools for zones, accessory details, scenes, automations, people and events.
/// They are executed through `HomeKitProviding.perform(_:arguments:)`.
enum ManagementToolDefinitions {
    // MARK: Schema helpers

    private static func property(_ type: String, _ description: String) -> Value {
        .object(["type": .string(type), "description": .string(description)])
    }

    private static func stringList(_ description: String) -> Value {
        .object([
            "type": .string("array"),
            "description": .string(description),
            "items": .object(["type": .string("string")]),
        ])
    }

    private static func objectList(_ description: String, properties: [String: Value], required: [String] = []) -> Value {
        var items: [String: Value] = ["type": .string("object"), "properties": .object(properties)]
        if !required.isEmpty { items["required"] = .array(required.map { .string($0) }) }
        return .object(["type": .string("array"), "description": .string(description), "items": .object(items)])
    }

    private static func tool(
        _ name: String, _ description: String, _ properties: [String: Value] = [:], required: [String] = []
    ) -> Tool {
        var schema: [String: Value] = ["type": .string("object"), "properties": .object(properties)]
        if !required.isEmpty { schema["required"] = .array(required.map { .string($0) }) }
        return Tool(name: name, description: description, inputSchema: .object(schema))
    }

    // MARK: Shared properties

    private static let home = property("string", "Home name. Omit to use the only or primary home.")
    private static let homeFilter = property("string", "Home name to filter by or to disambiguate. Omit for all homes.")
    private static let confirmName = property("string", "Exact name of the item, as safety confirmation. Nothing is changed if it does not match.")
    private static let deviceID = property("string", "Device unique identifier (from list_devices). If provided, name/home/room are ignored.")
    private static let deviceName = property("string", "Device name (case-insensitive). Required if id is not provided.")
    private static let deviceHome = property("string", "Home name to disambiguate devices with the same name")
    private static let deviceRoom = property("string", "Room name to disambiguate devices with the same name")

    private static let deviceProperties: [String: Value] = [
        "id": deviceID, "name": deviceName, "home": deviceHome, "room": deviceRoom,
    ]

    private static let sceneProperties: [String: Value] = [
        "id": property("string", "Scene unique identifier (from list_scenes). If provided, name/home are ignored."),
        "name": property("string", "Scene name (case-insensitive). Required if id is not provided."),
        "home": property("string", "Home name to disambiguate scenes with the same name"),
    ]

    private static let automationProperties: [String: Value] = [
        "id": property("string", "Automation unique identifier (from list_automations). If provided, name/home are ignored."),
        "name": property("string", "Automation name (case-insensitive). Required if id is not provided."),
        "home": property("string", "Home name to disambiguate automations with the same name"),
    ]

    private static let propertyNames = "power, brightness, hue, saturation, target_temperature, lock, door, thermostat_mode, fan_speed, motion, contact, occupancy"

    private static let actionProperties: [String: Value] = [
        "characteristic_id": property("string", "Characteristic id (from list_characteristics). Alternative to device + property."),
        "id": deviceID, "name": deviceName, "home": deviceHome, "room": deviceRoom,
        "property": property("string", "Friendly property of the device: \(propertyNames)"),
        "value": .object(["description": .string("Target value, e.g. true, 50, \"locked\", \"open\", \"heat\"")]),
    ]

    // MARK: Zones and home

    static let listZones = tool("list_zones", "List zones (groups of rooms, e.g. a floor) with their rooms.", ["home": homeFilter])

    static let createZone = tool(
        "create_zone",
        "Create a zone, optionally with rooms. Changes the real home immediately.",
        ["name": property("string", "Name of the new zone"), "home": home,
         "rooms": stringList("Names of rooms to put into the zone")],
        required: ["name"]
    )

    static let renameZone = tool(
        "rename_zone", "Rename a zone.",
        ["name": property("string", "Current zone name"), "new_name": property("string", "New zone name"), "home": home],
        required: ["name", "new_name"]
    )

    static let deleteZone = tool(
        "delete_zone",
        "Delete a zone. Its rooms are kept. Only call this after the user explicitly approved deleting this specific zone.",
        ["name": property("string", "Zone name"), "home": home, "confirm_name": confirmName],
        required: ["name", "confirm_name"]
    )

    static let addRoomToZone = tool(
        "add_room_to_zone", "Add a room to a zone. A room can be in several zones.",
        ["zone": property("string", "Zone name"), "room": property("string", "Room name"), "home": home],
        required: ["zone", "room"]
    )

    static let removeRoomFromZone = tool(
        "remove_room_from_zone", "Remove a room from a zone. The room itself is kept.",
        ["zone": property("string", "Zone name"), "room": property("string", "Room name"), "home": home],
        required: ["zone", "room"]
    )

    static let renameHome = tool(
        "rename_home", "Rename a home.",
        ["new_name": property("string", "New home name"), "home": home],
        required: ["new_name"]
    )

    // MARK: Accessories

    static let identifyDevice = tool(
        "identify_device",
        "Make a device identify itself (blink or beep), useful to find out which physical device it is.",
        deviceProperties
    )

    static let getDeviceInfo = tool(
        "get_device_info",
        "Get details of a device: manufacturer, model, firmware, category, services and bridge info. The MAC address is not available through HomeKit.",
        deviceProperties
    )

    static let renameService = tool(
        "rename_service",
        "Rename a service of a device, e.g. one socket of a multi-socket outlet. Get service ids from get_device_info or list_characteristics.",
        ["service_id": property("string", "Service id"), "new_name": property("string", "New service name")],
        required: ["service_id", "new_name"]
    )

    static let listCharacteristics = tool(
        "list_characteristics",
        "List all services and characteristics of a device with id, type, permissions, metadata (min/max/step/units) and cached value. Use the ids with read_characteristic and write_characteristic.",
        deviceProperties.merging(["read": property("boolean", "Read current values from the device first (slower). Default false.")]) { $1 }
    )

    static let readCharacteristic = tool(
        "read_characteristic", "Read the current value of one characteristic.",
        ["characteristic_id": property("string", "Characteristic id (from list_characteristics)")],
        required: ["characteristic_id"]
    )

    static let writeCharacteristic = tool(
        "write_characteristic",
        "Write one characteristic directly. Changes the real device immediately. Prefer control_device for common actions; use this for anything else.",
        ["characteristic_id": property("string", "Characteristic id (from list_characteristics)"),
         "value": .object(["description": .string("Value to write; booleans, numbers or text depending on the characteristic")])],
        required: ["characteristic_id", "value"]
    )

    static let batchMoveDevices = tool(
        "batch_move_devices",
        "Move several devices to rooms in one call. Each entry runs independently; failures do not affect the others.",
        ["moves": objectList(
            "Devices to move",
            properties: deviceProperties.merging(["target_room": property("string", "Room to move the device into")]) { $1 },
            required: ["target_room"]
        )],
        required: ["moves"]
    )

    static let batchRenameDevices = tool(
        "batch_rename_devices",
        "Rename several devices in one call. Each entry runs independently; failures do not affect the others.",
        ["renames": objectList(
            "Devices to rename",
            properties: deviceProperties.merging(["new_name": property("string", "New device name")]) { $1 },
            required: ["new_name"]
        )],
        required: ["renames"]
    )

    // MARK: Scenes

    static let getScene = tool("get_scene", "Get a scene with all its actions (device, characteristic, target value).", sceneProperties)

    static let createScene = tool(
        "create_scene",
        "Create a scene with actions. All actions are validated first; nothing is created if one is invalid. The scene is not executed.",
        ["name": property("string", "Name of the new scene"), "home": home,
         "actions": objectList("Actions of the scene", properties: actionProperties)],
        required: ["name"]
    )

    static let addSceneActions = tool(
        "add_scene_actions", "Add actions to an existing scene.",
        sceneProperties.merging(["actions": objectList("Actions to add", properties: actionProperties)]) { $1 },
        required: ["actions"]
    )

    static let removeSceneActions = tool(
        "remove_scene_actions",
        "Remove actions from a scene, by index (from get_scene) or by characteristic id.",
        sceneProperties.merging([
            "indexes": .object(["type": .string("array"), "description": .string("Action indexes from get_scene"),
                                "items": .object(["type": .string("integer")])]),
            "characteristic_ids": stringList("Remove all actions that write these characteristics"),
        ]) { $1 }
    )

    static let renameScene = tool(
        "rename_scene", "Rename a scene.",
        sceneProperties.merging(["new_name": property("string", "New scene name")]) { $1 },
        required: ["new_name"]
    )

    static let deleteScene = tool(
        "delete_scene",
        "Delete a user-defined scene (built-in scenes such as wake up or sleep are refused by HomeKit). Automations that used it lose it. Only call this after the user explicitly approved deleting this specific scene.",
        sceneProperties.merging(["confirm_name": confirmName]) { $1 },
        required: ["confirm_name"]
    )

    // MARK: Automations

    static let listAutomations = tool(
        "list_automations", "List automations (timer and event triggers) with status, scenes and trigger details.",
        ["home": homeFilter]
    )

    static let getAutomation = tool("get_automation", "Get one automation with its details.", automationProperties)

    static let createAutomation = tool(
        "create_automation",
        """
        Create an automation that runs scenes. It stays disabled unless 'enabled' is true. \
        type 'timer': needs fire_date (ISO 8601) and optional recurrence (hourly, daily, weekly, monthly, yearly). \
        type 'event': needs events, optionally weekdays (1 = Sunday ... 7 = Saturday) and only_between {from, to} as HH:mm. \
        Event types: characteristic (device + property + value, or characteristic_id), sunrise or sunset (optional offset_minutes), time (hour, minute). \
        Changes the real home; an enabled automation can act on its own later.
        """,
        [
            "name": property("string", "Name of the automation"),
            "type": property("string", "timer or event"),
            "home": home,
            "scenes": stringList("Scenes to run, by name or id (at least one)"),
            "enabled": property("boolean", "Enable right after creating. Default false."),
            "fire_date": property("string", "Timer: first fire date, ISO 8601, e.g. 2026-10-20T07:30:00+02:00"),
            "recurrence": property("string", "Timer: hourly, daily, weekly, monthly or yearly"),
            "events": objectList(
                "Event: what triggers the automation",
                properties: actionProperties.merging([
                    "type": property("string", "characteristic, sunrise, sunset or time"),
                    "offset_minutes": property("integer", "sunrise/sunset: minutes before (negative) or after"),
                    "hour": property("integer", "time: hour 0-23"),
                    "minute": property("integer", "time: minute 0-59"),
                ]) { $1 },
                required: ["type"]
            ),
            "weekdays": .object(["type": .string("array"), "description": .string("Event: only on these weekdays, 1 = Sunday ... 7 = Saturday"),
                                 "items": .object(["type": .string("integer")])]),
            "only_between": .object([
                "type": .string("object"), "description": .string("Event: only between two times of day"),
                "properties": .object(["from": property("string", "HH:mm"), "to": property("string", "HH:mm")]),
            ]),
        ],
        required: ["name", "type", "scenes"]
    )

    static let enableAutomation = tool(
        "enable_automation", "Enable or disable an automation. Enabling lets it act on its own.",
        automationProperties.merging(["enabled": property("boolean", "true to enable, false to disable")]) { $1 },
        required: ["enabled"]
    )

    static let renameAutomation = tool(
        "rename_automation", "Rename an automation.",
        automationProperties.merging(["new_name": property("string", "New automation name")]) { $1 },
        required: ["new_name"]
    )

    static let updateAutomationScenes = tool(
        "update_automation_scenes", "Add or remove scenes of an automation. At least one scene must remain.",
        automationProperties.merging([
            "add": stringList("Scene names or ids to add"),
            "remove": stringList("Scene names or ids to remove"),
        ]) { $1 }
    )

    static let deleteAutomation = tool(
        "delete_automation",
        "Delete an automation. Only call this after the user explicitly approved deleting this specific automation.",
        automationProperties.merging(["confirm_name": confirmName]) { $1 },
        required: ["confirm_name"]
    )

    // MARK: People

    static let listUsers = tool(
        "list_users", "Read the current user of a home and whether they are an administrator. Read only. On macOS HomeKit does not expose the other people of a home, so only the current user is listed.",
        ["home": homeFilter]
    )

    // MARK: Events

    static let getEvents = tool(
        "get_events",
        """
        Read HomeKit changes collected since the server started: rooms, zones, devices, scenes and automations added, \
        removed or renamed, device reachability and, for watched devices, characteristic changes. \
        Pass the last_id of the previous call as since_id to get only new events. \
        wait_seconds (max 60) waits for new events, so repeated calls behave like a subscription.
        """,
        [
            "since_id": property("integer", "Only events after this id. Default 0 (all buffered events)."),
            "limit": property("integer", "Maximum number of events (1-500). Default 100."),
            "kinds": stringList("Only these event kinds, e.g. characteristic_changed, device_added, room_renamed"),
            "wait_seconds": property("number", "Wait up to this many seconds for new events (max 60). Default 0."),
        ]
    )

    static let clearEvents = tool("clear_events", "Empty the event buffer.")

    static let watchDevices = tool(
        "watch_devices",
        "Start collecting characteristic changes (on/off, temperature, motion, ...) of devices into the event log. Select by id or name, or by home, room and type (at least one selector).",
        deviceProperties.merging(["type": property("string", "Device type filter, e.g. light, lock, motion_sensor")]) { $1 }
    )

    static let unwatchDevices = tool(
        "unwatch_devices", "Stop collecting characteristic changes for the selected devices. Same selectors as watch_devices.",
        deviceProperties.merging(["type": property("string", "Device type filter, e.g. light, lock, motion_sensor")]) { $1 }
    )

    static let listWatched = tool("list_watched", "List devices that were set to be watched with watch_devices. HomeKit may deliver changes of other devices as well.")

    // MARK: All

    static let all: [Tool] = [
        listZones, createZone, renameZone, deleteZone, addRoomToZone, removeRoomFromZone, renameHome,
        identifyDevice, getDeviceInfo, renameService, listCharacteristics, readCharacteristic,
        writeCharacteristic, batchMoveDevices, batchRenameDevices,
        getScene, createScene, addSceneActions, removeSceneActions, renameScene, deleteScene,
        listAutomations, getAutomation, createAutomation, enableAutomation, renameAutomation,
        updateAutomationScenes, deleteAutomation,
        listUsers,
        getEvents, clearEvents, watchDevices, unwatchDevices, listWatched,
    ]

    static let names: Set<String> = Set(all.map(\.name))

    /// Required parameter names of a tool, read from its input schema.
    static func requiredParameters(of name: String) -> [String] {
        guard let tool = all.first(where: { $0.name == name }),
              case .object(let schema) = tool.inputSchema,
              case .array(let required)? = schema["required"]
        else { return [] }
        return required.compactMap { value in
            if case .string(let text) = value { return text }
            return nil
        }
    }
}
