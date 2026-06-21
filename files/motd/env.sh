#!/usr/bin/env sh
# Exports image info variables for MOTD template substitution.
# shellcheck source=/dev/null
. /usr/lib/os-release 2>/dev/null || true
MOTD_IMAGE_NAME="${IMAGE_NAME:-dakota}"
MOTD_IMAGE_TAG="${IMAGE_TAG:-unknown}"
export MOTD_IMAGE_NAME MOTD_IMAGE_TAG
