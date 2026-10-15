import Foundation
import MCP
import Testing
@testable import HomeKitMCP

struct ManagementToolDefinitionsTests {
    @Test func namesAreUniqueAndRegistered() {
        let names = ManagementToolDefinitions.all.map(\.name)
        #expect(Set(names).count == names.count, "management tool names must be unique")
        #expect(ManagementToolDefinitions.names == Set(names))

        let registered = Set(ToolDefinitions.all.map(\.name))
        #expect(registered.isSuperset(of: names))
        #expect(ToolDefinitions.all.count == Set(ToolDefinitions.all.map(\.name)).count, "no duplicate tool names overall")
    }

    @Test func everyToolHasADescriptionAndObjectSchema() {
        for tool in ManagementToolDefinitions.all {
            #expect(!(tool.description ?? "").isEmpty, "\(tool.name) needs a description")
            if case .object(let schema) = tool.inputSchema {
                #expect(schema["type"] == .string("object"))
            } else {
                Issue.record("\(tool.name) schema is not an object")
            }
        }
    }

    @Test func destructiveToolsRequireNameConfirmation() {
        for name in ["delete_zone", "delete_scene", "delete_automation"] {
            #expect(ManagementToolDefinitions.requiredParameters(of: name).contains("confirm_name"),
                    "\(name) must require confirm_name")
        }
    }

    @Test func requiredParametersAreReadFromTheSchema() {
        #expect(ManagementToolDefinitions.requiredParameters(of: "create_zone") == ["name"])
        #expect(ManagementToolDefinitions.requiredParameters(of: "rename_zone") == ["name", "new_name"])
        #expect(ManagementToolDefinitions.requiredParameters(of: "create_automation") == ["name", "type", "scenes"])
        #expect(ManagementToolDefinitions.requiredParameters(of: "list_zones").isEmpty)
        #expect(ManagementToolDefinitions.requiredParameters(of: "does_not_exist").isEmpty)
    }
}

@MainActor
struct ManagementToolRoutingTests {
    private func makeSUT() -> (manager: MCPServerManager, mock: MockHomeKitManager) {
        let mock = MockHomeKitManager()
        return (MCPServerManager(homeKitManager: mock, startServer: false), mock)
    }

    @Test func everyManagementToolIsForwardedToPerform() async {
        for tool in ManagementToolDefinitions.all {
            let (manager, mock) = makeSUT()
            var arguments: [String: Value] = [:]
            for key in ManagementToolDefinitions.requiredParameters(of: tool.name) {
                arguments[key] = .string("x")
            }

            let result = await manager.handleToolCall(CallTool.Parameters(name: tool.name, arguments: arguments))

            #expect(mock.performCalledWith?.operation == tool.name, "\(tool.name) was not forwarded")
            #expect(result.isError != true, "\(tool.name) reported an error")
        }
    }

    @Test func argumentsArePassedAsNativeValues() async {
        let (manager, mock) = makeSUT()
        let params = CallTool.Parameters(
            name: "enable_automation",
            arguments: ["name": .string("Abends"), "enabled": .bool(true)]
        )

        _ = await manager.handleToolCall(params)

        #expect(mock.performCalledWith?.arguments["name"] as? String == "Abends")
        #expect(mock.performCalledWith?.arguments["enabled"] as? Bool == true)
    }

    @Test func missingRequiredParameterIsRejectedBeforeCallingHomeKit() async {
        let (manager, mock) = makeSUT()

        let result = await manager.handleToolCall(
            CallTool.Parameters(name: "rename_zone", arguments: ["name": .string("EG")])
        )

        #expect(result.isError == true)
        #expect(mock.performCalledWith == nil)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("new_name"))
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test func nullCountsAsMissing() async {
        let (manager, mock) = makeSUT()

        let result = await manager.handleToolCall(
            CallTool.Parameters(name: "create_zone", arguments: ["name": .null])
        )

        #expect(result.isError == true)
        #expect(mock.performCalledWith == nil)
    }

    @Test func errorsFromHomeKitAreReported() async {
        let (manager, mock) = makeSUT()
        mock.performError = HomeKitError.zoneNotFound("EG")

        let result = await manager.handleToolCall(CallTool.Parameters(name: "list_zones", arguments: [:]))

        #expect(result.isError == true)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("Zone 'EG' not found"))
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test func resultIsReturnedAsJson() async {
        let (manager, mock) = makeSUT()
        mock.stubbedPerformResult = [["name": "EG", "rooms": ["Küche", "Bad"]]]

        let result = await manager.handleToolCall(CallTool.Parameters(name: "list_zones", arguments: [:]))

        #expect(result.isError != true)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("Küche"))
        } else {
            Issue.record("Expected text content")
        }
    }
}

struct ToolArgumentsTests {
    @Test func stringsAreTrimmedAndEmptyCountsAsMissing() {
        let args = ToolArguments(["a": "  Küche ", "b": "   ", "c": 3])
        #expect(args.string("a") == "Küche")
        #expect(args.string("b") == nil)
        #expect(args.string("c") == nil)
        #expect(args.string("missing") == nil)
    }

    @Test func requiredStringThrowsWhenMissing() {
        let args = ToolArguments([:])
        #expect(throws: HomeKitError.self) { try args.requiredString("name") }
    }

    @Test func booleansAcceptCommonSpellings() {
        let args = ToolArguments(["a": true, "b": "off", "c": "yes", "d": "maybe"])
        #expect(args.bool("a") == true)
        #expect(args.bool("b") == false)
        #expect(args.bool("c") == true)
        #expect(args.bool("d") == nil)
    }

    @Test func numbersAreConvertedBetweenTypes() {
        let args = ToolArguments(["i": 5, "d": 2.5, "s": "7"])
        #expect(args.int("i") == 5)
        #expect(args.int("d") == 2)
        #expect(args.int("s") == 7)
        #expect(args.double("i") == 5.0)
        #expect(args.double("s") == 7.0)
    }

    @Test func listsAndObjects() {
        let args = ToolArguments([
            "rooms": ["A", "B"], "single": "A",
            "items": [["id": "1"], ["id": "2"]], "window": ["from": "08:00"],
        ])
        #expect(args.strings("rooms") == ["A", "B"])
        #expect(args.strings("single") == ["A"])
        #expect(args.objects("items")?.compactMap { $0.string("id") } == ["1", "2"])
        #expect(args.object("window")?.string("from") == "08:00")
        #expect(args.objects("rooms") == nil)
    }
}

@MainActor
struct EventLogTests {
    @Test func eventsGetIncreasingIdsAndCanBeReadIncrementally() {
        let log = EventLog()
        log.add(kind: "room_added", home: "Zuhause", subject: "A")
        log.add(kind: "room_removed", home: "Zuhause", subject: "B")
        log.add(kind: "room_added", home: "Zuhause", subject: "C")

        #expect(log.lastID == 3)
        #expect(log.events(after: 0, kinds: nil, limit: 10).map(\.id) == [1, 2, 3])
        #expect(log.events(after: 2, kinds: nil, limit: 10).map(\.subject) == ["C"])
        #expect(log.events(after: 0, kinds: ["room_added"], limit: 10).map(\.subject) == ["A", "C"])
        #expect(log.events(after: 0, kinds: nil, limit: 2).map(\.id) == [1, 2])
    }

    @Test func bufferIsBoundedAndCountsDroppedEvents() {
        let log = EventLog()
        for index in 0..<(EventLog.capacity + 25) {
            log.add(kind: "k", home: nil, subject: "\(index)")
        }

        #expect(log.events.count == EventLog.capacity)
        #expect(log.droppedCount == 25)
        #expect(log.events.first?.id == 26)
        #expect(log.lastID == EventLog.capacity + 25)
    }

    @Test func clearKeepsTheIdCounter() {
        let log = EventLog()
        log.add(kind: "k", home: nil, subject: nil)
        log.clear()
        log.add(kind: "k", home: nil, subject: nil)

        #expect(log.events.map(\.id) == [2])
    }

    @Test func dictionaryOmitsEmptyFields() {
        let log = EventLog()
        log.add(kind: "device_added", home: nil, subject: "Lampe")

        let dictionary = log.events[0].dictionary
        #expect(dictionary["kind"] as? String == "device_added")
        #expect(dictionary["subject"] as? String == "Lampe")
        #expect(dictionary["home"] == nil)
        #expect(dictionary["detail"] == nil)
    }
}

struct NewHomeKitErrorTests {
    @Test func messagesNameTheItem() {
        #expect(HomeKitError.zoneNotFound("EG").errorDescription == "Zone 'EG' not found")
        #expect(HomeKitError.zoneAlreadyExists("EG").errorDescription == "Zone 'EG' already exists")
        #expect(HomeKitError.automationNotFound("Abend").errorDescription == "Automation 'Abend' not found")
        #expect(HomeKitError.sceneAlreadyExists("Kino").errorDescription == "Scene 'Kino' already exists")
        #expect(HomeKitError.unknownOperation("x").errorDescription == "Unknown operation 'x'")
    }

    @Test func confirmationMismatchSaysNothingWasChanged() {
        let message = HomeKitError.confirmationMismatch(expected: "EG", given: "OG").errorDescription ?? ""
        #expect(message.contains("EG"))
        #expect(message.contains("OG"))
        #expect(message.contains("Nothing was removed"))
    }
}
