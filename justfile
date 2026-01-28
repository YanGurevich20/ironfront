set shell := ["zsh", "-uc"]

# Dry run to compile the project
build:
	"${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}" --headless --verbose --path . --quit

# Lint all GDScript files (static checks).
lint:
	"${GDLINT_BIN:-/Users/yan/Library/Python/3.12/bin/gdlint}" .

# Check formatting without modifying files.
fmt-check:
	"${GDFORMAT_BIN:-/Users/yan/Library/Python/3.12/bin/gdformat}" --check .

# Auto-format GDScript files.
fmt:
	"${GDFORMAT_BIN:-/Users/yan/Library/Python/3.12/bin/gdformat}" .

# Run formatter then lint.
fix: build fmt lint
