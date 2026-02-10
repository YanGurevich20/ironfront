set shell := ["zsh", "-uc"]

default_instance := "ironfront-server"
default_zone := "europe-west1-b"
default_remote_dir := "~/ironfront"
default_server_port := "7000"

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

# Export dedicated Linux server executable.
server-export:
	mkdir -p build/server
	"${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}" --headless --path . --export-release "Linux Server" ./build/server/ironfront_server.x86_64
	chmod +x ./build/server/ironfront_server.x86_64

# Upload server executable to a GCP VM.
server-upload instance=default_instance zone=default_zone remote_dir=default_remote_dir:
	gcloud compute ssh {{instance}} --zone {{zone}} --command "mkdir -p {{remote_dir}}"
	gcloud compute scp ./build/server/ironfront_server.x86_64 {{instance}}:{{remote_dir}}/ironfront_server.x86_64 --zone {{zone}}

# Start server executable on a GCP VM (background process).
server-run instance=default_instance zone=default_zone remote_dir=default_remote_dir port=default_server_port:
	gcloud compute ssh {{instance}} --zone {{zone}} --command "cd {{remote_dir}} && nohup stdbuf -oL -eL ./ironfront_server.x86_64 --headless -- --port={{port}} > server.log 2>&1 < /dev/null & sleep 1 && pgrep -n -f 'ironfront_server.x86_64 --headless -- --port={{port}}' > server.pid && cat server.pid"

# Stop server process on a GCP VM.
server-stop instance=default_instance zone=default_zone remote_dir=default_remote_dir:
	gcloud compute ssh {{instance}} --zone {{zone}} --command "cd {{remote_dir}} && if test -f server.pid; then kill \$(cat server.pid) 2>/dev/null || true; fi && pkill -f 'ironfront_server.x86_64 --headless' 2>/dev/null || true && rm -f server.pid"

# Tail server logs on a GCP VM.
server-logs instance=default_instance zone=default_zone remote_dir=default_remote_dir:
	gcloud compute ssh {{instance}} --zone {{zone}} --command "cd {{remote_dir}} && tail -n 120 server.log"

# Follow server logs on a GCP VM.
server-logs-follow instance=default_instance zone=default_zone remote_dir=default_remote_dir:
	gcloud compute ssh {{instance}} --zone {{zone}} --command "cd {{remote_dir}} && tail -f server.log"
