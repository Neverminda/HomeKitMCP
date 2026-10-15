# HomeKitMCP – To-do

Stand: 15.10.2026. Projekt: `~/Developer/HomeKitMCP` (Swift, MIT, 1 Commit, rund 1.200 Zeilen).

## Räume und Zubehör in Apple Home verwalten (schreibende Werkzeuge)

Ziel: Apple Home aufräumen können, ohne die Home-App von Hand zu bedienen, zum Beispiel Räume nach dem Schema `<Etage> <Raum>` anlegen und Zubehör verschieben.

### Neue MCP-Werkzeuge
- [x] `create_room`: Raum in einem Haushalt anlegen (`HMHome.addRoom(withName:)`)
- [x] `rename_room`: Raum umbenennen (`HMRoom.updateName`)
- [x] `delete_room`: Raum löschen (`HMHome.removeRoom`), nur wenn er leer ist, mit Namensbestätigung (`confirm_name`)
- [x] `move_device`: Zubehör in einen anderen Raum verschieben (`HMHome.assignAccessory(_:to:)`)
- [x] `remove_device`: Zubehör aus dem Haushalt abmelden (`HMHome.removeAccessory`), mit Namensbestätigung
- [ ] `rename_device`: Zubehör umbenennen (`HMAccessory.updateName`)

### Wo im Code
- `HomeKit/HomeKitProviding.swift`: Protokoll um die neuen Funktionen erweitern
- `HomeKit/HomeKitManager.swift`: Umsetzung mit der HomeKit-Schnittstelle
- `MCP/ToolDefinitions.swift`: Werkzeugbeschreibungen und Parameter
- `MCP/MCPServerManager.swift`: Weiterleitung (Muster wie bei `list_rooms`)
- `HomeKitMCPTests/`: Tests und `MockHomeKitManager.swift` ergänzen

### Vorgehen
- [x] Eigenen Git-Zweig anlegen (`feature/write-tools`)
- [x] Zuerst nur `create_room`, `rename_room`, `move_device`
- [x] Mit einem Testraum prüfen: create_room, rename_room, delete_room einmalig im echten Haus getestet (15.10.2026), inkl. Fehlerfälle; move_device und remove_device bewusst noch nicht live getestet
- [ ] App neu bauen und signieren (`Local.xcconfig` aus `Local.xcconfig.template`, Entwicklerzertifikat nötig)
- [ ] Neue Sitzung starten, damit die neuen Werkzeuge sichtbar sind

### Sicherheit
- Schreibende Funktionen wirken sofort auf das echte Zuhause (Haustür, Garage, Heizung).
- Jede Änderung einzeln benennen und nur nach ausdrücklicher Freigabe ausführen.
- Raum löschen oder Zubehör verschieben kann Szenen und Automationen in Apple Home beeinträchtigen. Vorher Szenen notieren (`list_scenes`).
- `remove_device` (Zubehör aus HomeKit abmelden, z. B. zur Übergabe an Home Assistant) ist bewusst eingebaut: verlangt `confirm_name` mit exaktem Gerätenamen und darf nur nach ausdrücklicher Freigabe für genau dieses Gerät laufen.

## Hinweise
- Start über `homekitmcp-wrapper.sh` (LaunchServices, damit macOS die App selbst für den HomeKit-Zugriff prüft). In `~/.claude.json` steht aktuell der direkte Pfad zur Binärdatei; funktioniert, bei Rechte-Problemen auf den Wrapper umstellen.
- Bekannt, nicht lösbar mit dem MCP: MAC oder HAA-Kennung eines Zubehörs lesen (nur Name, Raum, Typ, ID).

