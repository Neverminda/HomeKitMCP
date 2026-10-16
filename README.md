# HomeKit MCP

A macOS app that bridges Apple HomeKit with the [Model Context Protocol](https://modelcontextprotocol.io), letting Claude (or other MCP-compatible LLMs) control your smart home devices over natural language.

Built as a Mac Catalyst app using the native HomeKit framework and the [official Swift MCP SDK](https://github.com/modelcontextprotocol/swift-sdk). Runs headless with an optional menu bar status item.

> **Fork notice:** This is a fork of [grahamaloo/HomeKitMCP](https://github.com/grahamaloo/HomeKitMCP). Branch `feature/launchd-socket` adds write tools (rooms, devices, scenes, automations, zones), a Unix-socket mode for running under launchd, and a truly invisible headless mode (no Dock icon, no visible window).

## Prerequisites

- **macOS 15.0+**
- **Xcode 26+** (includes Swift, Mac Catalyst support, and the iOS SDK)
- **Apple Developer account** (free or paid) for code signing — HomeKit requires a signed app with entitlements
- **HomeKit-configured home** — at least one home set up in the Apple Home app on your Mac or iOS device

## Building

1. **Clone the repository:**
   ```bash
   git clone -b feature/launchd-socket https://github.com/Neverminda/HomeKitMCP.git
   cd HomeKitMCP
   ```

2. **Configure your development team and bundle identifier:**
   ```bash
   cp team.xcconfig.template team.xcconfig
   ```
   Open `team.xcconfig` and replace `YOUR_TEAM_ID_HERE` with your [Apple Development Team ID](https://developer.apple.com/help/account/manage-your-team/locate-your-team-id/), and `com.example.homekitmcp` with a bundle identifier you own (the tests use the same identifier plus `.tests`).
   This file is gitignored so your credentials stay local.

3. **Open in Xcode:**
   ```bash
   open HomeKitMCP.xcodeproj
   ```
   The project will pick up your team ID and bundle identifier from `team.xcconfig` automatically. The HomeKit entitlement is already configured.

4. **Set the destination** to **My Mac (Mac Catalyst)** in the Xcode toolbar

5. **Build and run** (`Cmd+R`)

6. **Grant HomeKit access** when macOS prompts for permission on first launch

The built app will be located at:
```
~/Library/Developer/Xcode/DerivedData/HomeKitMCP-<hash>/Build/Products/Debug-maccatalyst/HomeKitMCP.app
```

> **Tip:** To find the exact path, right-click the app in Xcode's Products group and select "Show in Finder", or use `xcodebuild -showBuildSettings | grep BUILT_PRODUCTS_DIR`.

## Configuration

### Claude Code

Add to `~/.claude/mcp.json`:

```json
{
  "mcpServers": {
    "homekit": {
      "command": "/path/to/HomeKitMCP.app/Contents/MacOS/HomeKitMCP",
      "args": ["--headless"]
    }
  }
}
```

### Claude Desktop

Add to your Claude Desktop MCP config (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "homekit": {
      "command": "/path/to/HomeKitMCP.app/Contents/MacOS/HomeKitMCP",
      "args": ["--headless"]
    }
  }
}
```

Replace `/path/to/` with the actual path to your built `.app` bundle.

The `--headless` flag runs the server without the menu bar status item and without a visible window, which is recommended when launched by an MCP client. As a Mac Catalyst app it still needs one window scene, so in headless mode the window is reduced to 1×1 pixel, made transparent, and parked at the top center edge of the main screen; the app runs as an accessory (no Dock icon).

## Capabilities

### MCP Tools

| Area | Tools |
|------|-------|
| Homes and rooms | `list_homes`, `rename_home`, `list_rooms`, `create_room`, `rename_room`, `delete_room` |
| Zones | `list_zones`, `create_zone`, `rename_zone`, `delete_zone`, `add_room_to_zone`, `remove_room_from_zone` |
| Devices (read) | `list_devices`, `get_device_info`, `get_device_state`, `batch_get_device_state`, `list_characteristics`, `read_characteristic`, `list_users` |
| Devices (control) | `control_device`, `batch_control_devices`, `control_devices_by_filter`, `write_characteristic`, `identify_device` |
| Devices (manage) | `rename_device`, `batch_rename_devices`, `move_device`, `batch_move_devices`, `rename_service`, `remove_device` |
| Scenes | `list_scenes`, `get_scene`, `execute_scene`, `create_scene`, `rename_scene`, `delete_scene`, `add_scene_actions`, `remove_scene_actions` |
| Automations | `list_automations`, `get_automation`, `create_automation`, `rename_automation`, `enable_automation`, `update_automation_scenes`, `delete_automation` |
| Events | `watch_devices`, `unwatch_devices`, `list_watched`, `get_events`, `clear_events` |

> **Caution:** The write tools act on your real home immediately (locks, garage doors, heating). `remove_device` and the delete tools are destructive; require explicit confirmation in your MCP client.

### Supported Device Types

| Type | Read | Control |
|------|------|---------|
| Lights | Power, brightness, hue, saturation | on, off, toggle, set_brightness, set_hue, set_saturation, set_color |
| Switches / Outlets | Power | on, off, toggle |
| Fans | Power | on, off, toggle |
| Locks | Lock state | lock, unlock |
| Garage Doors | Door state | open, close |
| Thermostats | Current temp, target temp, mode | set_temperature, set_thermostat_mode (off/heat/cool/auto) |
| Temperature Sensors | Temperature | read-only |
| Humidity Sensors | Humidity | read-only |
| Motion Sensors | Motion detected | read-only |
| Contact Sensors | Contact state | read-only |
| Occupancy Sensors | Occupancy | read-only |
| Windows / Doors / Coverings | Position | read-only |

### Device Addressing

Devices can be addressed by:
- **Name** (case-insensitive): `"name": "Living Room Light"`
- **Unique ID** (from `list_devices`): `"id": "ABC123-DEF456"` — preferred when multiple devices share a name
- **Name + qualifiers**: add `"home"` and/or `"room"` to disambiguate

## Example Usage

Once configured, you can ask Claude (or any MCP-compatible LLM) things like:

- "Turn off all the lights in the bedroom"
- "What's the temperature in the living room?"
- "Set the thermostat to 72 degrees"
- "Lock the front door"
- "Dim the kitchen lights to 30%"
- "Run the Good Night scene"

## Architecture

```
MCP Client (Claude, etc.)
        | (stdin/stdout JSON-RPC 2.0)
        v
+---------------------------+
|  HomeKitMCP.app            |
|  (Mac Catalyst)            |
|                            |
|  +----------------------+  |
|  |  MCPServerManager    |  |  <- JSON-RPC over stdio
|  |  (StdioTransport)    |  |
|  +----------+-----------+  |
|             |              |
|  +----------v-----------+  |
|  |  HomeKitManager      |  |  <- async/await actor
|  |  (HMHomeManager)     |  |
|  +----------+-----------+  |
|             |              |
|  +----------v-----------+  |
|  |  Apple HomeKit       |  |  <- native framework
|  |  Framework           |  |
|  +----------------------+  |
+---------------------------+
```

## Troubleshooting

**"HomeKit permission denied" or no devices found:**
- Open **System Settings > Privacy & Security > HomeKit** and ensure HomeKitMCP is allowed
- Make sure you have at least one home configured in the Apple Home app
- The Mac must be signed into the same iCloud account as your Home setup

**Build fails with signing errors:**
- Make sure you've created `team.xcconfig` from the template and set your Team ID and bundle identifier
- Alternatively, select a team manually in Xcode under Signing & Capabilities
- A free Apple Developer account works, but the app must be re-signed every 7 days
- A paid account ($99/year) provides longer-lived signing

**MCP client can't connect:**
- Verify the path in your MCP config points to the actual built `.app` bundle
- Make sure you're pointing to `Contents/MacOS/HomeKitMCP` inside the `.app`
- Check that the app has been run at least once manually to grant HomeKit permission

## License

MIT

## Running under launchd (Unix socket)

Instead of starting one app per MCP client, the app can run permanently under launchd and listen on a Unix socket:

```
HomeKitMCP.app --headless --socket ~/.mcp/homekit/homekit.sock
```

- The socket has mode `0600` (current user only). Every connection gets its own MCP server speaking the stdio protocol; the HomeKit connection is shared. Without `--socket` the app works over stdio as before.
- `launchd/de.example.homekit-mcp.plist.template` (LaunchAgent with `KeepAlive`) and `launchd/homekit-mcp-service.template` (starter script) are templates. The script starts the app via `open -W -g -j -a`, so macOS checks the HomeKit permission for the app itself and no window appears. On start and stop it kills the app instance holding the socket (otherwise orphaned instances remain after a restart, because `open` is not the app's parent process).
- Setup: copy the script to `~/.mcp/homekit/bin/homekit-mcp-service` (executable), copy the plist (replace `__HOME__`) to `~/Library/LaunchAgents/`, then run `launchctl bootstrap gui/$(id -u) <file>`.
- MCP client configuration: `"command": "/usr/bin/nc", "args": ["-U", "/Users/<name>/.mcp/homekit/homekit.sock"]`.
- If the app is restarted, running client connections break; the client must reconnect the server.
