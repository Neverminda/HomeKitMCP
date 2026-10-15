import Foundation
@testable import HomeKitMCP

@MainActor
final class MockHomeKitManager: HomeKitProviding {
    // MARK: - Stub data

    var stubbedHomes: [[String: Any]] = []
    var stubbedRooms: [[String: Any]] = []
    var stubbedDevices: [[String: Any]] = []
    var stubbedDeviceState: [String: Any] = [:]
    var stubbedControlResult: [String: Any] = [:]

    var stubbedBatchControlResult: [[String: Any]] = []
    var stubbedBatchGetDeviceStateResult: [[String: Any]] = []
    var stubbedControlByFilterResult: [[String: Any]] = []
    var stubbedScenes: [[String: Any]] = []
    var stubbedExecuteSceneResult: [String: Any] = [:]
    var stubbedCreateRoomResult: [String: Any] = [:]
    var stubbedRenameRoomResult: [String: Any] = [:]
    var stubbedDeleteRoomResult: [String: Any] = [:]
    var stubbedRenameDeviceResult: [String: Any] = [:]
    var stubbedPerformResult: Any = [String: Any]()
    var stubbedMoveDeviceResult: [String: Any] = [:]
    var stubbedRemoveDeviceResult: [String: Any] = [:]

    // MARK: - Error stubs

    var getDeviceStateError: Error?
    var controlDeviceError: Error?
    var executeSceneError: Error?
    var createRoomError: Error?
    var renameRoomError: Error?
    var deleteRoomError: Error?
    var renameDeviceError: Error?
    var performError: Error?
    var moveDeviceError: Error?
    var removeDeviceError: Error?

    // MARK: - Call recording

    var startCalled = false
    var listHomesCalled = false
    var listRoomsCalledWith: String??
    var listDevicesCalledWith: (homeName: String?, roomName: String?, type: String?)?
    var getDeviceStateCalledWith: (id: String?, name: String?, homeName: String?, roomName: String?)?
    var controlDeviceCalledWith: (id: String?, name: String?, homeName: String?, roomName: String?, action: String, value: Any?)?
    var batchControlDevicesCalledWith: [[String: Any]]?
    var batchGetDeviceStateCalledWith: [[String: Any]]?
    var controlDevicesByFilterCalledWith: (homeName: String?, roomName: String?, type: String?, action: String, value: Any?)?
    var listScenesCalledWith: String??
    var executeSceneCalledWith: (name: String?, homeName: String?, id: String?)?
    var createRoomCalledWith: (name: String, homeName: String?)?
    var renameRoomCalledWith: (name: String, newName: String, homeName: String?)?
    var deleteRoomCalledWith: (name: String, homeName: String?, confirmName: String)?
    var renameDeviceCalledWith: (id: String?, name: String?, homeName: String?, roomName: String?, newName: String)?
    var performCalledWith: (operation: String, arguments: [String: Any])?
    var moveDeviceCalledWith: (id: String?, name: String?, homeName: String?, roomName: String?, targetRoom: String)?
    var removeDeviceCalledWith: (id: String?, name: String?, homeName: String?, roomName: String?, confirmName: String)?

    // MARK: - Protocol conformance

    func start() async {
        startCalled = true
    }

    func listHomes() -> [[String: Any]] {
        listHomesCalled = true
        return stubbedHomes
    }

    func listRooms(homeName: String?) -> [[String: Any]] {
        listRoomsCalledWith = .some(homeName)
        return stubbedRooms
    }

    func listDevices(homeName: String?, roomName: String?, type: String?) -> [[String: Any]] {
        listDevicesCalledWith = (homeName, roomName, type)
        return stubbedDevices
    }

    func getDeviceState(id: String?, name: String?, homeName: String?, roomName: String?) async throws -> [String: Any] {
        getDeviceStateCalledWith = (id, name, homeName, roomName)
        if let error = getDeviceStateError { throw error }
        return stubbedDeviceState
    }

    func controlDevice(
        id: String?,
        name: String?,
        homeName: String?,
        roomName: String?,
        action: String,
        value: Any?
    ) async throws -> [String: Any] {
        controlDeviceCalledWith = (id, name, homeName, roomName, action, value)
        if let error = controlDeviceError { throw error }
        return stubbedControlResult
    }

    func batchControlDevices(commands: [[String: Any]]) async -> [[String: Any]] {
        batchControlDevicesCalledWith = commands
        return stubbedBatchControlResult
    }

    func batchGetDeviceState(devices: [[String: Any]]) async -> [[String: Any]] {
        batchGetDeviceStateCalledWith = devices
        return stubbedBatchGetDeviceStateResult
    }

    func controlDevicesByFilter(
        homeName: String?,
        roomName: String?,
        type: String?,
        action: String,
        value: Any?
    ) async -> [[String: Any]] {
        controlDevicesByFilterCalledWith = (homeName, roomName, type, action, value)
        return stubbedControlByFilterResult
    }

    func listScenes(homeName: String?) -> [[String: Any]] {
        listScenesCalledWith = .some(homeName)
        return stubbedScenes
    }

    func executeScene(name: String?, homeName: String?, id: String?) async throws -> [String: Any] {
        executeSceneCalledWith = (name, homeName, id)
        if let error = executeSceneError { throw error }
        return stubbedExecuteSceneResult
    }

    func createRoom(name: String, homeName: String?) async throws -> [String: Any] {
        createRoomCalledWith = (name, homeName)
        if let error = createRoomError { throw error }
        return stubbedCreateRoomResult
    }

    func renameRoom(name: String, newName: String, homeName: String?) async throws -> [String: Any] {
        renameRoomCalledWith = (name, newName, homeName)
        if let error = renameRoomError { throw error }
        return stubbedRenameRoomResult
    }

    func deleteRoom(name: String, homeName: String?, confirmName: String) async throws -> [String: Any] {
        deleteRoomCalledWith = (name, homeName, confirmName)
        if let error = deleteRoomError { throw error }
        return stubbedDeleteRoomResult
    }

    func renameDevice(id: String?, name: String?, homeName: String?, roomName: String?, newName: String) async throws -> [String: Any] {
        renameDeviceCalledWith = (id, name, homeName, roomName, newName)
        if let error = renameDeviceError { throw error }
        return stubbedRenameDeviceResult
    }

    func perform(_ operation: String, arguments: [String: Any]) async throws -> Any {
        performCalledWith = (operation, arguments)
        if let error = performError { throw error }
        return stubbedPerformResult
    }

    func moveDevice(id: String?, name: String?, homeName: String?, roomName: String?, targetRoom: String) async throws -> [String: Any] {
        moveDeviceCalledWith = (id, name, homeName, roomName, targetRoom)
        if let error = moveDeviceError { throw error }
        return stubbedMoveDeviceResult
    }

    func removeDevice(id: String?, name: String?, homeName: String?, roomName: String?, confirmName: String) async throws -> [String: Any] {
        removeDeviceCalledWith = (id, name, homeName, roomName, confirmName)
        if let error = removeDeviceError { throw error }
        return stubbedRemoveDeviceResult
    }
}
