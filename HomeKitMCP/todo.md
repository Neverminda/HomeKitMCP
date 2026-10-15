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
- [x] `rename_device`: Zubehör umbenennen (`HMAccessory.updateName`), noch nicht live getestet

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

## Stand der Werkzeuge (Stand 16.10.2026)

Alle Werkzeuge bauen und sind durch Mock-Tests (96 Tests) abgedeckt. Am 16.10.2026 wurden fast alle live gegen das echte Haus geprüft (Testnamen `ZZ-HKMCP-…`, danach aufgeräumt, Zustand verglichen): 59 von 61 Prüfungen im ersten Lauf, die zwei Ausreißer lagen am Testaufbau (HomeKit erlaubt nur eine Aktion je Merkmal und Szene) und bestanden im Wiederholungslauf. Nicht live getestet: `rename_home`, `remove_device`, `delete_room` an Räumen mit Geräten, Ausführen von Szenen und Automationen, aktivierte Automationen im Betrieb.

### Umgesetzt und live getestet (außer wie oben genannt)
- [x] Zonen: `list_zones` (live geprüft), `create_zone`, `rename_zone`, `delete_zone`, `add_room_to_zone`, `remove_room_from_zone`, `rename_home`
- [x] Zubehör: `identify_device`, `get_device_info` (live), `list_characteristics` (live), `read_characteristic`, `write_characteristic`, `rename_service`, `rename_device`, `move_device`, `remove_device`, `batch_move_devices`, `batch_rename_devices`
- [x] Szenen: `get_scene`, `create_scene`, `add_scene_actions`, `remove_scene_actions`, `rename_scene`, `delete_scene`
- [x] Automationen: `list_automations` (live), `get_automation` (live), `create_automation` (Zeit- und Ereignisauslöser, startet deaktiviert), `enable_automation`, `rename_automation`, `update_automation_scenes`, `delete_automation`
- [x] Ereignisse: `get_events` (live, auch mit `wait_seconds`), `clear_events`, `watch_devices` / `unwatch_devices` / `list_watched` (live mit einem Gerät)
- [x] Personen: `list_users` (live), nur lesend

### Grenzen der Mac-API (nicht umsetzbar oder unvollständig)
- `HMHome.users` ist auf Mac Catalyst nicht verfügbar: `list_users` zeigt nur den aktuellen Benutzer. Andere Personen und Zugriffsrechte lassen sich nicht lesen, Rechte ändern ebenfalls nicht.
- `HMTrigger.lastFireDate` ist veraltet („No longer supported“): kein Zeitpunkt der letzten Ausführung bei Automationen.
- Automationen, die in der Home-App mit direkt eingetragenen Aktionen angelegt wurden, zeigen als Szene „(own actions: n)“; die Aktionen selbst liefert HomeKit teils nicht (n = 0). Manche Ereignisauslöser (z. B. Heimkino LG OLED aktiv) melden eine leere Ereignisliste.
- Geräte ausblenden oder die Dashboard-Anzeige ändern ist über die API nicht möglich.
- MAC oder HAA-Kennung eines Zubehörs lässt sich nicht lesen.
- Ereignisse kommen nur, solange der Server läuft; es gibt keinen Verlauf (Puffer: 1000 Ereignisse im Speicher), und MCP-Push-Benachrichtigungen gibt es nicht, nur Abfragen mit `get_events` (auch wartend bis 60 s).

### Noch offen
- [x] Live-Test der Schreibwerkzeuge mit harmlosem Eintrag und Namenskollisionsprüfung (Zone, Szene, Automation deaktiviert, `rename_device`, `move_device`, `rename_service`, `write_characteristic` mit gelesenem Wert, `identify_device`)
- [ ] Offen: Eigene Änderungen löst HomeKit nicht als Ereignis im eigenen Prozess aus (nur Änderungen aus der Home-App oder anderen Geräten), daher bleibt `get_events` nach Schreibzugriffen leer
- [ ] Ereignisauslöser: `condition` zeigt noch die rohe `NSDateComponents`-Beschreibung, besser als „HH:mm bis HH:mm“ ausgeben
- [ ] `remove_device` bewusst nur bei echtem Bedarf testen (Gerät muss danach neu gekoppelt werden)
- [ ] Weitere Häuser anlegen oder entfernen (`HMHomeManager.addHome`): in der Home-App auf dem Mac nicht möglich, per API nicht geprüft
- [ ] Kameras (`HMCameraProfile`), Zubehör koppeln (`HMAccessorySetupManager`): vermutlich für ein MCP-Werkzeug nicht sinnvoll
- [ ] Zugriff über Unix-Socket oder XPC statt FIFO-Wrapper, falls ein echtes CLI gewünscht ist

### Installieren
- `make install` baut Release und kopiert die App nach `~/.mcp/homekit/bin/HomeKitMCP.app` (anderer Ort: `make install PREFIX=/pfad`). Das Skript `bin/homekit-mcp` und `config/` bleiben unberührt. Danach den MCP-Server neu starten.
- `xcodebuild install` taugt dafür nicht: das Schema macht daraus einen Archive-Lauf, der nicht an den Zielort schreibt.

## Hinweise
- Start über `homekitmcp-wrapper.sh` (LaunchServices, damit macOS die App selbst für den HomeKit-Zugriff prüft). In `~/.claude.json` steht aktuell der direkte Pfad zur Binärdatei; funktioniert, bei Rechte-Problemen auf den Wrapper umstellen.
- Bekannt, nicht lösbar mit dem MCP: MAC oder HAA-Kennung eines Zubehörs lesen (nur Name, Raum, Typ, ID).

