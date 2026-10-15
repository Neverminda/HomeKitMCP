import Foundation

// MARK: - Dispatch for the management tools (zones, accessories, scenes, automations, people, events)

extension HomeKitManager {
    func perform(_ operation: String, arguments: [String: Any]) async throws -> Any {
        let args = ToolArguments(arguments)
        switch operation {
        // Zones and home
        case "list_zones": return listZones(args)
        case "create_zone": return try await createZone(args)
        case "rename_zone": return try await renameZone(args)
        case "delete_zone": return try await deleteZone(args)
        case "add_room_to_zone": return try await addRoomToZone(args)
        case "remove_room_from_zone": return try await removeRoomFromZone(args)
        case "rename_home": return try await renameHome(args)

        // Accessories
        case "identify_device": return try await identifyDevice(args)
        case "get_device_info": return try getDeviceInfo(args)
        case "rename_service": return try await renameService(args)
        case "list_characteristics": return try await listCharacteristics(args)
        case "read_characteristic": return try await readCharacteristic(args)
        case "write_characteristic": return try await writeCharacteristic(args)
        case "batch_move_devices": return try await batchMoveDevices(args)
        case "batch_rename_devices": return try await batchRenameDevices(args)

        // Scenes
        case "get_scene": return try getScene(args)
        case "create_scene": return try await createScene(args)
        case "add_scene_actions": return try await addSceneActions(args)
        case "remove_scene_actions": return try await removeSceneActions(args)
        case "rename_scene": return try await renameScene(args)
        case "delete_scene": return try await deleteScene(args)

        // Automations
        case "list_automations": return listAutomations(args)
        case "get_automation": return try getAutomation(args)
        case "create_automation": return try await createAutomation(args)
        case "enable_automation": return try await enableAutomation(args)
        case "rename_automation": return try await renameAutomation(args)
        case "update_automation_scenes": return try await updateAutomationScenes(args)
        case "delete_automation": return try await deleteAutomation(args)

        // People
        case "list_users": return listUsers(args)

        // Events
        case "get_events": return try await getEvents(args)
        case "clear_events": return clearEvents()
        case "watch_devices": return try await watchDevices(args, enable: true)
        case "unwatch_devices": return try await watchDevices(args, enable: false)
        case "list_watched": return listWatched()

        default: throw HomeKitError.unknownOperation(operation)
        }
    }
}
