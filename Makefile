# Builds the Release app and installs it next to the start script.
#   make install                       -> ~/.mcp/homekit/bin/HomeKitMCP.app
#   make install PREFIX=/other/place   -> /other/place/bin/HomeKitMCP.app
# The start script (bin/homekit-mcp) and config/ are left untouched.

PREFIX  ?= $(HOME)/.mcp/homekit
PROJECT := HomeKitMCP.xcodeproj
SCHEME  := HomeKitMCP
DEST    := generic/platform=macOS,variant=Mac Catalyst
XCODEBUILD = xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination '$(DEST)'

.PHONY: build install

build:
	$(XCODEBUILD) build

install: build
	@products=$$($(XCODEBUILD) -showBuildSettings 2>/dev/null | awk '/^ +BUILT_PRODUCTS_DIR = /{print $$3; exit}'); \
	app="$$products/HomeKitMCP.app"; \
	test -d "$$app" || { echo "Build product not found: $$app" >&2; exit 1; }; \
	mkdir -p "$(PREFIX)/bin"; \
	rm -rf "$(PREFIX)/bin/HomeKitMCP.app"; \
	ditto "$$app" "$(PREFIX)/bin/HomeKitMCP.app"; \
	codesign --verify --deep --strict "$(PREFIX)/bin/HomeKitMCP.app"; \
	echo "Installed $(PREFIX)/bin/HomeKitMCP.app"; \
	echo "Restart the MCP server to use the new version."
