# vim: set ft=make :

alias changelog := changelogs

# Show the changelog
changelogs:
    #!/usr/bin/bash

    # Get Image Tag
    TAG="$(jq -r '.["image-tag"]' < /usr/share/ublue-os/image-info.json)"

    # If stable or gts, get changelogs from Github Releases
    if [[ "$TAG" =~ gts$|stable$ ]]; then
        DATE="$(grep -oP "OSTREE_VERSION=.*\d{2}\.\K\d{8}" /etc/os-release)"
        CONTENT="$(curl -Ls "https://api.github.com/repos/projectbluefin/dakota/releases" | jq -r ".[] | select(.tag_name==\"${TAG}-${DATE}\") | .body")"
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
