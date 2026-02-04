.PHONY: build release dmg clean help

# Default target
help:
	@echo "MCP Control Build Commands"
	@echo ""
	@echo "  make build    - Build debug configuration"
	@echo "  make release  - Build release configuration"
	@echo "  make dmg      - Build release and create DMG"
	@echo "  make clean    - Clean build artifacts"
	@echo ""
	@echo "Configuration:"
	@echo "  Copy .env.example to .env and fill in your signing credentials"

build:
	xcodebuild -scheme MCPControl -configuration Debug build

release:
	xcodebuild -scheme MCPControl -configuration Release build

dmg:
	./scripts/build-dmg.sh

clean:
	rm -rf build/
	rm -rf dist/*.dmg
	xcodebuild clean -scheme MCPControl 2>/dev/null || true
