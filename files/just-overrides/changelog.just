# vim: set ft=make :

alias changelog := changelogs

# Show the changelog
changelogs:
    #!/usr/bin/bash

    # Get Image Tag
    TAG="$(jq -r '.["image-tag"]' < /usr/share/ublue-os/image-info.json)"

    # If stable or gts, get changelogs from Github Releases
    if [[ "$TAG" =~ gts$|stable$ ]]; then
        DATE="$(grep -oP "OSTREE_VERSION=.*\d{2}\.\K\d{8}[.0-9]*" /etc/os-release)"
        CONTENT="$(curl -Ls "https://api.github.com/repos/projectbluefin/dakota/releases" | jq -r ".[] | select(.tag_name==\"${TAG}-${DATE}\") | .body")"
    fi

    # Display Content with Glow, otherwise fallback to the current Dakota release notes
    if [[ -n "${CONTENT:-}" ]]; then
        echo "$CONTENT" | glow -p
    else
        echo "WARN: Could not find a release specific to your image"
        curl -Ls "https://api.github.com/repos/projectbluefin/dakota/releases?per_page=1" | jq -r '.[0].body' | glow -p
    fi
