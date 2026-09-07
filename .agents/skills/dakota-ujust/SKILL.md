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
3. **Avoid Heredocs**: Replace multi-line heredocs with `printf '%s\n'` or `jq -n` to avoid Just tokenizer bugs.
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
- **Avoid Heredocs in Shebang Recipes**: Just aggressively tokenizes heredocs inside shebang recipes, breaking on lines starting with `-`, `...`, or long command substitutions. Pre-compute variables and output line-by-line with `printf`.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The argument is just a number, so quoting isn't strictly necessary." | Unquoted arguments allow arbitrary shell token expansion if malformed input is passed. |
| "A heredoc is cleaner than multiple `printf` lines." | Just's parser tokenizes heredocs before the shell runs, causing cryptic syntax errors on certain characters. |
| "Users only run `ujust` in terminal windows." | Scripts and background services invoke `ujust`; non-TTY safety must always be guarded. |

## Red Flags

- Unquoted recipe arguments: `{{ arg }}` instead of `{{ quote(arg) }}`
- Using heredocs (`<<'EOF'`) inside shebang recipes in `default.just`
- Missing non-interactive guards on destructive or public-posting commands
- Modifying the root `Justfile` when a user-facing command was requested

## Verification

- [ ] Every interpolated argument is wrapped in `{{ quote(...) }}`
- [ ] Argument syntax validation is enforced in shell
- [ ] Recipe exits with code != 0 when run non-interactively without required flags
- [ ] No heredocs are present in shebang recipe blocks
- [ ] `just bst build bluefin/just-overrides.bst` builds without errors

## References

- [`files/just-overrides/default.just`](../../../files/just-overrides/default.just)
- [`elements/bluefin/just-overrides.bst`](../../../elements/bluefin/just-overrides.bst)
- [`docs/feedback-loop.md`](../../../docs/feedback-loop.md)
