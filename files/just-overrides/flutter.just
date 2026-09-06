# vim: set ft=make :

# alias for install-flutter
[group('Apps')]
flutter:
    @ujust install-flutter

# Install Flutter DevContainer development environment | https://flutter.dev
[group('Apps')]
[no-cd]
install-flutter:
    #!/usr/bin/env bash
    set -euo pipefail

    # --- Step 0: brew guard ---
    if ! command -v brew &>/dev/null; then
        gum style --foreground 196 "Homebrew not found."
        echo "Install it first: https://brew.sh"
        exit 1
    fi

    # --- Step 1: Header + mental model ---
    gum style \
        --border normal \
        --border-foreground 212 \
        --padding "1 2" \
        --bold \
        "Flutter DevContainer Setup"
    gum style "Flutter runs inside a Podman container — not on the host."
    gum style "Requires Antigravity IDE for devcontainer support."
    echo ""

    # --- Step 2: Antigravity IDE gate ---
    if ! command -v antigravity-ide &>/dev/null; then
        gum style --foreground 214 "Antigravity IDE not found."
        if gum confirm "Install Antigravity IDE from ublue-os tap?"; then
            brew tap ublue-os/homebrew-tap
            brew install --cask antigravity-ide-linux
            eval "$(brew shellenv)"
        else
            echo ""
            gum style "Antigravity IDE is required for devcontainer support."
            gum style "Alternatively: install the Dev Containers extension in any"
            gum style "VS Code-compatible editor and re-run."
            exit 1
        fi
    fi

    # --- Step 3: Directory context + CWD guard ---
    echo ""
    if [[ "$PWD" == "$HOME" ]]; then
        gum style --foreground 196 "⚠ You are in your home directory."
        gum style "Run this from inside a Flutter project directory, or create one now."
        echo ""
    fi

    gum style "Current directory: $(gum style --bold "$PWD")"
    echo ""

    ACTION=$(gum choose "Scaffold here" "Create new project" "Cancel")

    case "$ACTION" in
      "Create new project")
        PROJECT_NAME=$(gum input --placeholder "my_flutter_app")
        if [[ -z "$PROJECT_NAME" ]]; then
            gum style --foreground 196 "No project name entered."
            exit 1
        fi
        mkdir -p "$PROJECT_NAME"
        cd "$PROJECT_NAME"
        gum style "Working in: $(gum style --bold "$PWD")"
        echo ""
        ;;
      "Cancel")
        exit 0
        ;;
    esac

    # --- Step 4: Idempotency check ---
    USER_UID=$(id -u)
    SCAFFOLD=true
    if [[ -d .devcontainer ]]; then
        gum style --foreground 214 "Existing .devcontainer/ found."
        gum style "Skipping scaffold: Dockerfile, devcontainer.json"
        gum style "Continuing:        podman socket, IDE settings"
        echo ""
        SCAFFOLD=false
    fi

    # --- Step 5: Scaffold .devcontainer/ ---
    if [[ "$SCAFFOLD" == "true" ]]; then
        if ! gum confirm "Scaffold Flutter DevContainer in $PWD?"; then
            exit 0
        fi

        mkdir -p .devcontainer

        {
            printf '%s\n' 'FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04'
            printf '%s\n' '# Ubuntu-based: matches Flutter official Linux toolchain requirements'
            printf '%s\n' '# (libgtk-3-dev, clang, cmake -- unavailable in distroless base images)'
            printf '\n'
            printf '%s\n' 'RUN apt-get update && apt-get install -y \'
            printf '%s\n' '    curl git unzip xz-utils zip libglu1-mesa \'
            printf '%s\n' '    clang cmake ninja-build pkg-config libgtk-3-dev \'
            printf '%s\n' '    && rm -rf /var/lib/apt/lists/*'
            printf '\n'
            printf '%s\n' 'USER vscode'
            printf '%s\n' 'WORKDIR /home/vscode'
            printf '\n'
            printf '%s\n' 'RUN git clone https://github.com/flutter/flutter.git -b stable /home/vscode/flutter'
            printf '%s\n' 'ENV PATH="/home/vscode/flutter/bin:${PATH}"'
            printf '\n'
            printf '%s\n' 'RUN flutter config --no-analytics && flutter precache --linux --web'
        } > .devcontainer/Dockerfile

        jq -n \
            --arg uid "$USER_UID" \
            '{
                "name": "Local Flutter DX",
                "build": {"dockerfile": "Dockerfile"},
                "remoteUser": "vscode",
                "customizations": {
                    "vscode": {
                        "extensions": [
                            "Dart-Code.flutter",
                            "Dart-Code.dart-code",
                            "ms-vscode.cpptools",
                            "ms-vscode.cmake-tools"
                        ]
                    }
                },
                "runArgs": ["--net=host", "--ipc=host"],
                "mounts": [
                    ("source=${localEnv:XDG_RUNTIME_DIR}/wayland-0,target=/run/user/" + $uid + "/wayland-0,type=bind")
                ],
                "containerEnv": {
                    "WAYLAND_DISPLAY": "wayland-0",
                    "XDG_RUNTIME_DIR": ("/run/user/" + $uid)
                },
                "forwardPorts": [8080]
            }' > .devcontainer/devcontainer.json

        gum style --foreground 82 "✓ Created .devcontainer/Dockerfile"
        gum style --foreground 82 "✓ Created .devcontainer/devcontainer.json"
        echo ""
    fi

    # --- Step 6: Podman socket + DOCKER_HOST ---
    gum style "Enabling Podman socket (required for devcontainer support)..."
    if ! systemctl --user enable --now podman.socket; then
        echo ""
        gum style --foreground 196 "Could not enable podman.socket."
        gum style "Devcontainers require it. Diagnose with:"
        gum style "  systemctl --user status podman.socket"
        exit 1
    fi
    gum style --foreground 82 "✓ Podman socket active"

    # The per-user Podman socket does not need Docker daemon permissions.
    gum style "Rootless Podman needs no docker group membership or reboot."
    echo ""

    # --- Step 7: Antigravity IDE settings (safe merge) ---
    SETTINGS_DIR="$HOME/.config/Antigravity IDE/User"
    SETTINGS_FILE="$SETTINGS_DIR/settings.json"
    mkdir -p "$SETTINGS_DIR"

    PODMAN_SOCKET="unix:///run/user/${USER_UID}/podman/podman.sock"

    if command -v jq &>/dev/null; then
        if [[ -f "$SETTINGS_FILE" ]]; then
            tmp=$(mktemp)
            jq --arg sock "$PODMAN_SOCKET" '. + {
                "dev.containers.dockerPath": "podman",
                "dev.containers.dockerSocketPath": $sock
            }' "$SETTINGS_FILE" > "$tmp"
            mv "$tmp" "$SETTINGS_FILE"
        else
            jq -n --arg sock "$PODMAN_SOCKET" '{
                "dev.containers.dockerPath": "podman",
                "dev.containers.dockerSocketPath": $sock
            }' > "$SETTINGS_FILE"
        fi
        gum style --foreground 82 "✓ Antigravity IDE configured to use Podman"
    else
        gum style --foreground 214 "jq not found — skipping automatic IDE settings merge."
        gum style "Add these manually to $SETTINGS_FILE :"
        gum style "  \"dev.containers.dockerPath\": \"podman\""
        gum style "  \"dev.containers.dockerSocketPath\": \"$PODMAN_SOCKET\""
    fi
    echo ""

    # --- Step 8: Success message ---
    gum style \
        --border normal \
        --border-foreground 82 \
        --padding "1 2" \
        --bold --foreground 82 \
        "✓ Flutter DevContainer ready."
    echo ""
    gum style --foreground 212 "⚠  First build: ~5-10 minutes (cloning Flutter SDK ~3GB)."
    gum style "   Watch the build log in the IDE — this is normal."
    echo ""
    gum style "Next:"
    gum style "  Ctrl+Shift+P → Dev Containers: Reopen in Container"
    echo ""

    # --- Step 9: IDE launch (opt-out) ---
    if gum confirm --default=yes "Open Antigravity IDE now?"; then
        antigravity-ide .
    else
        gum style "When ready:  antigravity-ide ."
    fi
