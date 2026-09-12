---
name: dakota-ujust
description: Author safe end-user ujust recipes in files/just-overrides/default.just, including quoting, gum, JSON, and public-post confirmation.
metadata:
  context7-sources:
    - /bootc-dev/bootc
---

# Dakota ujust Recipes

`just <recipe>` is for developers and CI from the root repository `Justfile`.
`ujust <recipe>` is for end users inside the booted image, authored in `files/just-overrides/default.just` and built via `elements/bluefin/just-overrides.bst`.

## When to Use

- Adding, editing, or testing end-user convenience recipes in `files/just-overrides/default.just`
- Modifying data donation commands (`ujust report`, `ujust confirm`, `ujust verify`)
- Handling CLI interaction tools like Charm `gum`, desktop notifications, or system diagnostics

## When NOT to Use

- Editing repository-level developer commands in the root `Justfile` → load `dakota-buildstream`
- Modifying host Homebrew wrapper recipes → load `dakota-workstation`
- Adding BST elements → load `dakota-packaging`

## Core Process

1. **Author Recipe**: Add or edit the recipe in `files/just-overrides/default.just`.
2. **Quote & Validate Arguments**: Pass all arguments through `quote()` and validate with bash regular expressions:
   ```just
   ISSUE={{ quote(issue_number) }}
   [[ "$ISSUE" =~ ^[1-9][0-9]*$ ]] || exit 2
   ```
3. **Check Recipe Parsing**: Parse the file with the Just version shipped in the target image: `just --justfile files/just-overrides/default.just --list`. Heredocs are allowed when their indentation and delimiters parse correctly. Prefer `jq -n` for constructing JSON.
4. **Guard Interactive Steps**: Ensure commands requiring a TTY fail closed when run in non-interactive environments:
   ```bash
   if [ ! -t 0 ]; then
       echo "Interactive terminal required" >&2
       exit 1
   fi
   ```
5. **Rebuild & Verify**:
   ```bash
   just bst build bluefin/just-overrides.bst
   ```

## Invariants

- **Mandatory Quoting**: Just interpolates recipe arguments textually before bash parses them. Every parameter MUST pass through `{{ quote(...) }}` to prevent shell injection.
- **No Global Positional Arguments**: Never add `set positional-arguments` to `files/just-overrides/default.just`; this file merges into the global system recipe set.
- **Fail Closed Without TTY**: Any recipe posting data publicly (e.g. creating GitHub issues or gists) must fail closed when stdin is not a terminal. Never treat a failed `gum confirm` as affirmative consent.
- **Non-Interactive Sudo**: Use `sudo -n` for status checks so scripted recipe execution does not hang waiting for a password prompt.
- **Version-Specific Parsing**: Older Just versions (including previously reported 1.47.1 cases) had heredoc parsing problems; that is not a blanket prohibition. Existing recipes parse with 1.58.0. Check the target image's version and test both Just parsing and the rendered shell syntax before changing valid heredocs.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The argument is just a number, so quoting isn't strictly necessary." | Unquoted arguments allow arbitrary shell token expansion if malformed input is passed. |
| "A heredoc parsed on my host, so it works everywhere." | Validate with the target image's Just version and preserve literal shell/JSON quoting. |
| "Users only run `ujust` in terminal windows." | Scripts and background services invoke `ujust`; non-TTY safety must always be guarded. |

## Red Flags

- Unquoted recipe arguments: `{{ arg }}` instead of `{{ quote(arg) }}`
- Heredoc delimiters or indentation that fail parsing with the target image's Just version
- Missing non-interactive guards on destructive or public-posting commands
- Modifying the root `Justfile` when a user-facing command was requested

## Verification

- [ ] Every interpolated argument is wrapped in `{{ quote(...) }}`
- [ ] Argument syntax validation is enforced in shell
- [ ] Recipe exits with code != 0 when run non-interactively without required flags
- [ ] The recipe file parses with the target image's Just version; rendered shell syntax is valid
- [ ] `just bst build bluefin/just-overrides.bst` builds without errors

## References

- [`files/just-overrides/default.just`](../../../files/just-overrides/default.just)
- [`elements/bluefin/just-overrides.bst`](../../../elements/bluefin/just-overrides.bst)
- [`docs/feedback-loop.md`](../../../docs/feedback-loop.md)
