import MCP

enum ToolDefinitions {
    static let listHomes = Tool(
        name: "list_homes",
        description: "List all HomeKit homes configured on this Mac",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
        ])
    )

    static let listRooms = Tool(
        name: "list_rooms",
        description: "List rooms in a HomeKit home. Returns room names with device counts.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "home": .object([
                    "type": .string("string"),
                    "description": .string("Home name to filter by. Omit to list rooms from all homes."),
                ]),
            ]),
        ])
    )

    static let listDevices = Tool(
        name: "list_devices",
        description: "List HomeKit devices, optionally filtered by home, room, or device type.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "home": .object([
                    "type": .string("string"),
                    "description": .string("Filter by home name"),
                ]),
                "room": .object([
                    "type": .string("string"),
                    "description": .string("Filter by room name"),
                ]),
                "type": .object([
                    "type": .string("string"),
                    "description": .string("Filter by device type (light, switch, outlet, fan, thermostat, lock, garage_door, temperature_sensor, humidity_sensor, motion_sensor, contact_sensor, occupancy_sensor, window, window_covering, door)"),
                ]),
            ]),
        ])
    )

    static let getDeviceState = Tool(
        name: "get_device_state",
        description: "Get the current state and properties of a HomeKit device. Returns power state, brightness, temperature, lock state, etc. depending on device type. Specify the device by name or by unique ID (from list_devices). Use ID when multiple devices share the same name.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object([
                    "type": .string("string"),
                    "description": .string("Device unique identifier (from list_devices uniqueIdentifier). If provided, name/home/room are ignored."),
                ]),
                "name": .object([
                    "type": .string("string"),
                    "description": .string("Device name (case-insensitive). Required if id is not provided."),
                ]),
                "home": .object([
                    "type": .string("string"),
                    "description": .string("Home name to disambiguate devices with the same name"),
                ]),
                "room": .object([
                    "type": .string("string"),
                    "description": .string("Room name to disambiguate devices with the same name"),
                ]),
            ]),
        ])
    )

    static let controlDevice = Tool(
        name: "control_device",
        description: """
            Control a HomeKit device. Specify the device by name or by unique ID (from list_devices). \
            Use ID when multiple devices share the same name. \
            Supported actions: \
            on, off, toggle (lights/switches/outlets/fans), \
            set_brightness (0-100), set_hue (0-360), set_saturation (0-100), \
            set_color ({hue, saturation}), \
            lock, unlock (locks), \
            open, close (garage doors), \
            set_temperature (celsius), set_thermostat_mode (off/heat/cool/auto)
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object([
                    "type": .string("string"),
                    "description": .string("Device unique identifier (from list_devices uniqueIdentifier). If provided, name/home/room are ignored."),
                ]),
                "name": .object([
                    "type": .string("string"),
                    "description": .string("Device name (case-insensitive). Required if id is not provided."),
                ]),
                "home": .object([
                    "type": .string("string"),
                    "description": .string("Home name to disambiguate devices with the same name"),
                ]),
                "room": .object([
                    "type": .string("string"),
                    "description": .string("Room name to disambiguate devices with the same name"),
                ]),
                "action": .object([
                    "type": .string("string"),
                    "description": .string("Action to perform: on, off, toggle, set_brightness, set_hue, set_saturation, set_color, lock, unlock, open, close, set_temperature, set_thermostat_mode"),
                    "enum": .array([
                        .string("on"), .string("off"), .string("toggle"),
                        .string("set_brightness"), .string("set_hue"),
                        .string("set_saturation"), .string("set_color"),
                        .string("lock"), .string("unlock"),
                        .string("open"), .string("close"),
                        .string("set_temperature"), .string("set_thermostat_mode"),
                    ]),
                ]),
                "value": .object([
                    "description": .string("Value for the action. Required for set_brightness (int 0-100), set_hue (number 0-360), set_saturation (number 0-100), set_color ({hue, saturation}), set_temperature (number, celsius), set_thermostat_mode (string: off/heat/cool/auto)."),
                ]),
            ]),
            "required": .array([.string("action")]),
        ])
    )

    static let batchControlDevices = Tool(
        name: "batch_control_devices",
        description: """
            Control multiple HomeKit devices in a single call. Each command specifies a device and action. \
            All commands run independently — failures on one device do not affect others. \
            Returns per-device results with success/failure status.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "commands": .object([
                    "type": .string("array"),
                    "description": .string("Array of device control commands"),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "id": .object([
                                "type": .string("string"),
                                "description": .string("Device unique identifier. If provided, name/home/room are ignored."),
                            ]),
                            "name": .object([
                                "type": .string("string"),
                                "description": .string("Device name (case-insensitive). Required if id is not provided."),
                            ]),
                            "action": .object([
                                "type": .string("string"),
                                "description": .string("Action to perform (on, off, toggle, set_brightness, etc.)"),
                            ]),
                            "home": .object([
                                "type": .string("string"),
                                "description": .string("Home name to disambiguate"),
                            ]),
                            "room": .object([
                                "type": .string("string"),
                                "description": .string("Room name to disambiguate"),
                            ]),
                            "value": .object([
                                "description": .string("Value for the action, if needed"),
                            ]),
                        ]),
                        "required": .array([.string("action")]),
                    ]),
                ]),
            ]),
            "required": .array([.string("commands")]),
        ])
    )

    static let batchGetDeviceState = Tool(
        name: "batch_get_device_state",
        description: """
            Get the current state of multiple HomeKit devices in a single call. \
            Each device is specified by name or unique ID. \
            All queries run independently — failures on one device do not affect others. \
            Returns per-device state with success/failure status.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "devices": .object([
                    "type": .string("array"),
                    "description": .string("Array of devices to query"),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "id": .object([
                                "type": .string("string"),
                                "description": .string("Device unique identifier. If provided, name/home/room are ignored."),
                            ]),
                            "name": .object([
                                "type": .string("string"),
                                "description": .string("Device name (case-insensitive). Required if id is not provided."),
                            ]),
                            "home": .object([
                                "type": .string("string"),
                                "description": .string("Home name to disambiguate"),
                            ]),
                            "room": .object([
                                "type": .string("string"),
                                "description": .string("Room name to disambiguate"),
                            ]),
                        ]),
                    ]),
                ]),
            ]),
            "required": .array([.string("devices")]),
        ])
    )

    static let controlDevicesByFilter = Tool(
        name: "control_devices_by_filter",
        description: """
            Apply a single action to all HomeKit devices matching a filter. \
            At least one filter (home, room, or type) is required. \
            All matching devices are controlled independently — failures on one do not affect others.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "action": .object([
                    "type": .string("string"),
                    "description": .string("Action to perform on all matching devices (on, off, toggle, set_brightness, etc.)"),
                    "enum": .array([
                        .string("on"), .string("off"), .string("toggle"),
                        .string("set_brightness"), .string("set_hue"),
                        .string("set_saturation"), .string("set_color"),
                        .string("lock"), .string("unlock"),
                        .string("open"), .string("close"),
                        .string("set_temperature"), .string("set_thermostat_mode"),
                    ]),
                ]),
                "home": .object([
                    "type": .string("string"),
                    "description": .string("Filter by home name"),
                ]),
                "room": .object([
                    "type": .string("string"),
                    "description": .string("Filter by room name"),
                ]),
                "type": .object([
                    "type": .string("string"),
                    "description": .string("Filter by device type (light, switch, outlet, fan, thermostat, lock, garage_door, etc.)"),
                ]),
                "value": .object([
                    "description": .string("Value for the action, if needed"),
                ]),
            ]),
            "required": .array([.string("action")]),
        ])
    )

    static let listScenes = Tool(
        name: "list_scenes",
        description: "List HomeKit scenes (action sets), optionally filtered by home. Returns scene names, types, and action counts.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "home": .object([
                    "type": .string("string"),
                    "description": .string("Home name to filter by. Omit to list scenes from all homes."),
                ]),
            ]),
        ])
    )

    static let executeScene = Tool(
        name: "execute_scene",
        description: """
            Execute (trigger) a HomeKit scene by name or unique ID. \
            Specify the scene by name or by unique ID (from list_scenes). \
            Use ID when multiple scenes share the same name across homes.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object([
                    "type": .string("string"),
                    "description": .string("Scene unique identifier (from list_scenes uniqueIdentifier). If provided, name/home are ignored."),
                ]),
                "name": .object([
                    "type": .string("string"),
                    "description": .string("Scene name (case-insensitive). Required if id is not provided."),
                ]),
                "home": .object([
                    "type": .string("string"),
                    "description": .string("Home name to disambiguate scenes with the same name"),
                ]),
            ]),
        ])
    )

    static let createRoom = Tool(
        name: "create_room",
        description: "Create a new room in a HomeKit home. Fails if a room with that name already exists. Changes the real home immediately.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "name": .object([
                    "type": .string("string"),
                    "description": .string("Name of the new room"),
                ]),
                "home": .object([
                    "type": .string("string"),
                    "description": .string("Home name. Omit to use the only or primary home."),
                ]),
            ]),
            "required": .array([.string("name")]),
        ])
    )

    static let renameRoom = Tool(
        name: "rename_room",
        description: "Rename an existing room in a HomeKit home. Changes the real home immediately.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "name": .object([
                    "type": .string("string"),
                    "description": .string("Current room name (case-insensitive)"),
                ]),
                "new_name": .object([
                    "type": .string("string"),
                    "description": .string("New room name"),
                ]),
                "home": .object([
                    "type": .string("string"),
                    "description": .string("Home name to disambiguate rooms with the same name"),
                ]),
            ]),
            "required": .array([.string("name"), .string("new_name")]),
        ])
    )

    static let deleteRoom = Tool(
        name: "delete_room",
        description: """
            Delete an empty room from a HomeKit home. Fails if the room still contains devices (move them out first with move_device). \
            'confirm_name' must equal the room's exact name, otherwise nothing is deleted. \
            Changes the real home immediately and may affect scenes and automations that use the room. \
            Only call this after the user explicitly approved deleting this specific room.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "name": .object([
                    "type": .string("string"),
                    "description": .string("Room name (case-insensitive)"),
                ]),
                "home": .object([
                    "type": .string("string"),
                    "description": .string("Home name to disambiguate rooms with the same name"),
                ]),
                "confirm_name": .object([
                    "type": .string("string"),
                    "description": .string("Exact name of the room to delete, as safety confirmation"),
                ]),
            ]),
            "required": .array([.string("name"), .string("confirm_name")]),
        ])
    )

    static let moveDevice = Tool(
        name: "move_device",
        description: """
            Move a HomeKit device to another room in the same home. \
            Specify the device by name or by unique ID (from list_devices). \
            Use ID when multiple devices share the same name. \
            Changes the real home immediately and may affect scenes and automations.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object([
                    "type": .string("string"),
                    "description": .string("Device unique identifier (from list_devices uniqueIdentifier). If provided, name/home/room are ignored."),
                ]),
                "name": .object([
                    "type": .string("string"),
                    "description": .string("Device name (case-insensitive). Required if id is not provided."),
                ]),
                "home": .object([
                    "type": .string("string"),
                    "description": .string("Home name to disambiguate devices with the same name"),
                ]),
                "room": .object([
                    "type": .string("string"),
                    "description": .string("Current room of the device, to disambiguate devices with the same name"),
                ]),
                "target_room": .object([
                    "type": .string("string"),
                    "description": .string("Name of the room to move the device into"),
                ]),
            ]),
            "required": .array([.string("target_room")]),
        ])
    )

    static let removeDevice = Tool(
        name: "remove_device",
        description: """
            Remove a device from HomeKit (unpair it from the home), e.g. to hand it over to another system such as Home Assistant. \
            The device has to be paired again afterwards, and it is removed from all scenes and automations. \
            Specify the device by unique ID (from list_devices) or name. \
            'confirm_name' must equal the device's exact name, otherwise nothing is removed. \
            Only call this after the user explicitly approved removing this specific device.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object([
                    "type": .string("string"),
                    "description": .string("Device unique identifier (from list_devices uniqueIdentifier). If provided, name/home/room are ignored."),
                ]),
                "name": .object([
                    "type": .string("string"),
                    "description": .string("Device name (case-insensitive). Required if id is not provided."),
                ]),
                "home": .object([
                    "type": .string("string"),
                    "description": .string("Home name to disambiguate devices with the same name"),
                ]),
                "room": .object([
                    "type": .string("string"),
                    "description": .string("Room name to disambiguate devices with the same name"),
                ]),
                "confirm_name": .object([
                    "type": .string("string"),
                    "description": .string("Exact name of the device to remove, as safety confirmation"),
                ]),
            ]),
            "required": .array([.string("confirm_name")]),
        ])
    )

    static let all: [Tool] = [
        listHomes, listRooms, listDevices, getDeviceState, controlDevice,
        batchControlDevices, batchGetDeviceState, controlDevicesByFilter,
        listScenes, executeScene,
        createRoom, renameRoom, deleteRoom, moveDevice, removeDevice,
    ]
}
