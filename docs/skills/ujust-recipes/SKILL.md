---
name: ujust-recipes
description: How to write and test ujust recipes for the Dakota image. Load when adding, editing, or debugging user-facing ujust commands in files/just-overrides/.
---

# ujust Recipe Authoring

## Overview

`ujust` recipes are user-facing commands available inside the running Dakota image. They live in `files/just-overrides/` and are installed into the image at `/usr/share/ublue-os/just/` by `elements/bluefin/just-overrides.bst`. This is distinct from the developer-facing `just` (the repo-root `Justfile`).

## When to use

- Adding a new user-facing command to the image
- Editing an existing `ujust` recipe
- Debugging recipe behavior (heredoc issues, gum patterns)

## When not to use

- Developer build recipes → edit the repo-root `Justfile` directly
- CI workflow changes → see the relevant workflow file

## Authoritative sources

- `files/just-overrides/default.just` — primary recipe file
- `files/just-overrides/*.just` — additional recipe modules (`system.just`, `changelog.just`, `flutter.just`, `bluefin-cli.just`)
- `elements/bluefin/just-overrides.bst` — the BST element that installs recipes into the image

## Workflow

1. **Add or edit the recipe** in the appropriate file under `files/just-overrides/`.
2. **If adding a new `.just` file**, add a corresponding `install -Dm644` line in `elements/bluefin/just-overrides.bst` — otherwise the file never reaches the image.
3. **Use shebang recipes** (`#!/usr/bin/bash` with `set -euo pipefail`) for anything beyond trivial one-liners.
4. **Use `gum` for user interaction:**
   - `gum confirm` — yes/no prompts (guards destructive actions)
   - `gum choose` — selection menus
   - `gum style` — formatted output messages
5. **Avoid heredocs** in shebang recipes — just's tokenizer may reject lines starting with `-`, `...`, or containing expressions like `(1/5/15 min)`. Use `printf '%s\n'` per line instead.
6. **Pre-compute command substitutions** (e.g., `KERNEL=$(uname -r)`) into variables before any printf block.
7. **Use `jq -n` for JSON generation** instead of heredocs — it handles escaping correctly and avoids tokenizer issues.
8. **Naming**: use lowercase kebab-case recipe names. Include a comment above the recipe describing its purpose.
9. **Idempotence**: recipes that modify system state should be safe to run multiple times.

## Failure modes

- **Missing install-commands entry**: a new `.just` file in `files/just-overrides/` without a matching line in `elements/bluefin/just-overrides.bst` is silently absent from the image.
- **Heredoc tokenizer rejection**: just parses heredoc content and may reject valid shell constructs. Replace with `printf` lines.
- **gum not available**: recipes using `gum` assume it is pre-installed in the image. Verify the image includes `gum` before depending on it.

## Verification

```bash
# Rebuild the element to pick up recipe changes
just bst build bluefin/just-overrides.bst

# Boot an ephemeral VM and run the recipe
just boot-fast
# Inside the VM:
ujust <recipe-name>
```

Test by executing the recipe and checking output — `test -f /path/to/file` only proves the file was installed, not that the recipe functions correctly.

## Related skills

- [local-ota](../local-ota/SKILL.md)
- [add-package](../add-package/SKILL.md)
- [buildstream](../buildstream/SKILL.md)
