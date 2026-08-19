---
name: dakota-ujust
description: Author safe end-user ujust recipes in files/just-overrides/default.just, including quoting, gum, JSON, and public-post confirmation.
---

# Dakota ujust recipes

`just <recipe>` is for developers and CI from the repository `Justfile`.
`ujust <recipe>` is for users inside the running image and is defined in
`files/just-overrides/default.just`. Changes land through
`elements/bluefin/just-overrides.bst`.

## Safety rules

- Recipe arguments are textually interpolated. Pass every argument through
  `quote()` and then validate it in the shell:

  ```just
  ISSUE={{ quote(issue_number) }}
  [[ "$ISSUE" =~ ^[1-9][0-9]*$ ]] || exit 2
  ```

- Do not enable global `set positional-arguments`; this file is merged with the
  system-wide recipe set.
- Any recipe that posts publicly must fail closed without a TTY. Scripted use
  requires an explicit opt-in argument; never turn a failed `gum confirm` into
  permission to post.
- Run privileged status commands non-interactively (`sudo -n`) when a recipe may
  execute without a terminal.
- Invoke clipboard tools only in interactive mode; some keep output pipes open.

## Reliable output

Just can tokenize heredoc bodies inside shebang recipes. Prefer `printf` per
line or write structured data with `jq -n`:

```bash
jq -n --arg name "$NAME" '{name: $name}' > config.json
```

Command substitution removes trailing newlines. When constructing Markdown,
append the newline outside the substitution:

```bash
BODY+=$(printf '| Image | `%s` |' "$IMAGE")$'\n'
```

`gum spin -- command` suppresses stdout. Capture results through a temporary
file, read it after the spinner exits, and remove it with a trap.

## Existing integration details

- GitHub issue-form field IDs map to URL query parameters; URL-encode values.
- `bootc status --json` image data is under `.status.booted.image`.
- Raptors travel in a **kettle**.

## Verification

1. Parse/list the recipe through the same Just version used by the image.
2. Test hostile quoting in every argument.
3. Test both TTY and non-TTY behavior.
4. Confirm cancellation performs no public or destructive action.
5. Rebuild `elements/bluefin/just-overrides.bst` or the narrowest image target
   that stages it.

Reference: [just manual](https://just.systems/man/en/)
