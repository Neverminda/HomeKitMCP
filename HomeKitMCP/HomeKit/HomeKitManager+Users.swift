import Foundation
import HomeKit

// MARK: - People and access rights (read only)

extension HomeKitManager {
    /// Reads the current user and their role. Read only.
    /// HomeKit does not give Mac Catalyst apps the list of the other people (`HMHome.users` is unavailable there),
    /// so only the person using this Mac is reported.
    func listUsers(_ args: ToolArguments) -> [String: Any] {
        let entries = matchingHomes(name: args.string("home")).map { home -> [String: Any] in
            let current = home.currentUser
            return [
                "name": current.name,
                "home": home.name,
                "isCurrentUser": true,
                "isAdministrator": home.homeAccessControl(for: current).isAdministrator,
                "uniqueIdentifier": current.uniqueIdentifier.uuidString,
            ]
        }
        return [
            "users": entries,
            "note": "Only the current user is available on macOS. Other people of the home cannot be listed through the Mac HomeKit API.",
        ]
    }
}
