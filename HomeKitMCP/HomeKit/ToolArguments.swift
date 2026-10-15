import Foundation

/// Typed access to the loosely typed arguments of a management tool call.
nonisolated struct ToolArguments {
    let raw: [String: Any]

    init(_ raw: [String: Any]) {
        self.raw = raw
    }

    func string(_ key: String) -> String? {
        guard let value = raw[key] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func requiredString(_ key: String) throws -> String {
        guard let value = string(key) else {
            throw HomeKitError.invalidValue("missing required parameter '\(key)'")
        }
        return value
    }

    func bool(_ key: String) -> Bool? {
        if let value = raw[key] as? Bool { return value }
        if let value = raw[key] as? String {
            switch value.lowercased() {
            case "true", "yes", "on", "1": return true
            case "false", "no", "off", "0": return false
            default: return nil
            }
        }
        return nil
    }

    func int(_ key: String) -> Int? {
        if let value = raw[key] as? Int { return value }
        if let value = raw[key] as? Double { return Int(value) }
        if let value = raw[key] as? String { return Int(value) }
        return nil
    }

    func double(_ key: String) -> Double? {
        if let value = raw[key] as? Double { return value }
        if let value = raw[key] as? Int { return Double(value) }
        if let value = raw[key] as? String { return Double(value) }
        return nil
    }

    func strings(_ key: String) -> [String]? {
        if let values = raw[key] as? [String] { return values }
        if let value = raw[key] as? String { return [value] }
        return nil
    }

    func objects(_ key: String) -> [ToolArguments]? {
        (raw[key] as? [[String: Any]])?.map(ToolArguments.init)
    }

    func object(_ key: String) -> ToolArguments? {
        (raw[key] as? [String: Any]).map(ToolArguments.init)
    }
}
