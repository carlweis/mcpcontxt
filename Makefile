.PHONY: build release dmg clean help

# Default target
help:
	@echo "MCP Contxt Build Commands"
	@echo ""
	@echo "  make build    - Build debug configuration"
	@echo "  make release  - Build release configuration"
	@echo "  make dmg      - Build release and create DMG"
	@echo "  make clean    - Clean build artifacts"
	@echo ""
	@echo "Configuration:"
	@echo "  Copy .env.example to .env and fill in your signing credentials"

build:
	xcodebuild -scheme MCPContxt -configuration Debug build

release:
	xcodebuild -scheme MCPContxt -configuration Release build

dmg:
	./scripts/build-dmg.sh

clean:
	rm -rf build/
	rm -rf dist/*.dmg
	xcodebuild clean -scheme MCPContxt 2>/dev/null || true
