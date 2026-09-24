# vim: set ft=make :

alias changelog := changelogs

# Show the changelog
changelogs:
    #!/usr/bin/bash

    # The tag baked into image-info.json is a compose-time placeholder;
    # promotion retags the same digest, so read the followed stream from the
    # booted ref that ublue-booted-image.service records each boot.
    BOOTED_REF=""
    [[ -r /run/ublue-os/booted-image ]] && read -r BOOTED_REF < /run/ublue-os/booted-image
    TAG="${BOOTED_REF##*:}"

    # Stable releases are tagged stable-<IMAGE_VERSION> (the build date).
    if [[ "$BOOTED_REF" == *:* && "$TAG" == "stable" ]]; then
        DATE="$(. /usr/lib/os-release && echo "${IMAGE_VERSION:-}")"
        if [[ "$DATE" =~ ^[0-9]{8}$ ]]; then
            CONTENT="$(curl -Ls "https://api.github.com/repos/projectbluefin/dakota/releases/tags/stable-${DATE}" | jq -r '.body // empty')"
        fi
    fi

    # Render with glow when available (brew-preinstall), otherwise plain output.
    # glow was moved from the BST image to Homebrew's cli.Brewfile in 49382c5.
    if command -v glow &>/dev/null; then
        RENDER=(glow -p)
    else
        RENDER=(cat)
    fi
    if [[ -n "${CONTENT:-}" ]]; then
        echo "$CONTENT" | "${RENDER[@]}"
    else
        echo "WARN: Could not find a release specific to your image"
        curl -Ls "https://api.github.com/repos/projectbluefin/dakota/releases/latest" | jq -r ".body" | "${RENDER[@]}"
    fi
