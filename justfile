set shell := ["zsh", "-uc"]

default_instance := "ironfront-server"
default_zone := "europe-west1-b"
default_remote_dir := "~/ironfront"
default_server_port := "7000"

# Dry run to compile the project
build:
	"${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}" --headless --verbose --path . --quit

# Run local dedicated server runtime.
server-local port=default_server_port:
	"${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}" --headless --path . -- --server --port={{port}}

# Lint all GDScript files (static checks).
lint:
	rg --files -g '*.gd' | xargs "${GDLINT_BIN:-/Users/yan/Library/Python/3.12/bin/gdlint}"

# Check formatting without modifying files.
fmt-check:
	rg --files -g '*.gd' | xargs "${GDFORMAT_BIN:-/Users/yan/Library/Python/3.12/bin/gdformat}" --check

# Auto-format GDScript files.
fmt:
	rg --files -g '*.gd' | xargs "${GDFORMAT_BIN:-/Users/yan/Library/Python/3.12/bin/gdformat}"

# Run formatter then lint.
fix: build fmt lint

# Export dedicated Linux server executable.
server-export:
	mkdir -p dist/server
	"${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}" --headless --path . --export-release "Linux Server" ./dist/server/ironfront_server.x86_64
	chmod +x ./dist/server/ironfront_server.x86_64

# Ship server in one command: truncate logs, export, stop, upload, run.
server-ship instance=default_instance zone=default_zone remote_dir=default_remote_dir port=default_server_port:
	gcloud compute ssh {{instance}} --zone {{zone}} --command "mkdir -p {{remote_dir}}"
	mkdir -p dist/server
	"${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}" --headless --path . --export-release "Linux Server" ./dist/server/ironfront_server.x86_64
	chmod +x ./dist/server/ironfront_server.x86_64
	gcloud compute ssh {{instance}} --zone {{zone}} --command "cd {{remote_dir}} && if test -f server.pid; then kill \$(cat server.pid) 2>/dev/null || true; fi && pkill -f '[i]ronfront_server.x86_64 --headless' 2>/dev/null || true && rm -f server.pid"
	gcloud compute ssh {{instance}} --zone {{zone}} --command "cd {{remote_dir}} && : > server.log && rm -f server.pid"
	gcloud compute scp ./dist/server/ironfront_server.x86_64 {{instance}}:{{remote_dir}}/ironfront_server.x86_64.new --zone {{zone}}
	gcloud compute ssh {{instance}} --zone {{zone}} --command "cd {{remote_dir}} && mv ironfront_server.x86_64.new ironfront_server.x86_64 && chmod +x ironfront_server.x86_64"
	gcloud compute ssh {{instance}} --zone {{zone}} --ssh-flag=-T --command "cd {{remote_dir}} && ( stdbuf -oL -eL ./ironfront_server.x86_64 --headless -- --port={{port}} > server.log 2>&1 < /dev/null & echo \$! > server.pid ); sleep 1; cat server.pid"

# Upload server executable to a GCP VM.
server-upload instance=default_instance zone=default_zone remote_dir=default_remote_dir:
	gcloud compute ssh {{instance}} --zone {{zone}} --command "mkdir -p {{remote_dir}}"
	gcloud compute ssh {{instance}} --zone {{zone}} --command "cd {{remote_dir}} && pkill -f '[i]ronfront_server.x86_64 --headless' 2>/dev/null || true && rm -f server.pid"
	gcloud compute scp ./dist/server/ironfront_server.x86_64 {{instance}}:{{remote_dir}}/ironfront_server.x86_64.new --zone {{zone}}
	gcloud compute ssh {{instance}} --zone {{zone}} --command "cd {{remote_dir}} && mv ironfront_server.x86_64.new ironfront_server.x86_64 && chmod +x ironfront_server.x86_64"

# Start server executable on a GCP VM (background process).
server-run instance=default_instance zone=default_zone remote_dir=default_remote_dir port=default_server_port:
	gcloud compute ssh {{instance}} --zone {{zone}} --ssh-flag=-T --command "cd {{remote_dir}} && ( stdbuf -oL -eL ./ironfront_server.x86_64 --headless -- --port={{port}} > server.log 2>&1 < /dev/null & echo \$! > server.pid ); sleep 1; cat server.pid"

# Stop server process on a GCP VM.
server-stop instance=default_instance zone=default_zone remote_dir=default_remote_dir:
	gcloud compute ssh {{instance}} --zone {{zone}} --command "cd {{remote_dir}} && if test -f server.pid; then kill \$(cat server.pid) 2>/dev/null || true; fi && pkill -f '[i]ronfront_server.x86_64 --headless' 2>/dev/null || true && rm -f server.pid"

# Tail server logs on a GCP VM.
server-logs instance=default_instance zone=default_zone remote_dir=default_remote_dir:
	gcloud compute ssh {{instance}} --zone {{zone}} --command "cd {{remote_dir}} && tail -n 120 server.log"

# Follow server logs on a GCP VM.
server-logs-follow instance=default_instance zone=default_zone remote_dir=default_remote_dir:
	gcloud compute ssh {{instance}} --zone {{zone}} --command "cd {{remote_dir}} && tail -f server.log"

install-apk:
	adb install -r dist/android/Ironfront.apk

gcloud-config:
	gcloud config configurations activate ironfront