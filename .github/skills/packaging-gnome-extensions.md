# Packaging GNOME Shell Extensions

Load when packaging a GNOME Shell extension for BuildStream in dakota.

## Creating an Extension Element

Create the element file manually under `elements/bluefin/shell-extensions/<name>.bst`. Copy an existing extension as a starting point:

```bash
ls elements/bluefin/shell-extensions/   # see existing examples
cp elements/bluefin/shell-extensions/caffeine.bst elements/bluefin/shell-extensions/<name>.bst
```

## UUID Discovery

Every GNOME Shell extension has a UUID that defines its install path. Find it from:

```bash
# From the extension's metadata.json
grep '"uuid"' metadata.json

# From a downloaded extension zip
unzip -p extension.zip metadata.json | python3 -m json.tool | grep uuid
```

The UUID determines the install path: `%{datadir}/gnome-shell/extensions/<uuid>/`

## Element Structure

### Simple Extension (no build system)

```yaml
kind: import
description: GNOME Shell extension — some description

build-depends:
- freedesktop-sdk.bst:bootstrap-import.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  extension-uuid: "uuid@example.com"

public:
  bst:
    strip-binaries: ""  # Extensions are JavaScript, not ELF

sources:
- kind: git_repo
  url: github:owner/extension.git
  track: main
  ref: abc123...

install-commands:
- |
  install -d "%{install-root}%{datadir}/gnome-shell/extensions/%{extension-uuid}"
  cp -r . "%{install-root}%{datadir}/gnome-shell/extensions/%{extension-uuid}/"
- '%{install-extra}'
```

### Extension with Meson Build

```yaml
kind: meson
# ... standard meson element ...
```

### Extension with Make/npm Build

```yaml
kind: make
# ... override build/install targets as needed ...
```

## GSettings Schema Compilation

If the extension provides a GSettings schema, it must be compiled. The schema compilation happens as part of the OCI assembly (via `glib-compile-schemas`), not in the individual element.

If the schema is not compiled at image assembly time, add it to the element:
```yaml
install-commands:
  # ... install extension files ...
  - glib-compile-schemas "%{install-root}%{datadir}/glib-2.0/schemas/"
```

## Adding to the Extension Stack

Extensions must be added to `elements/bluefin/gnome-shell-extensions.bst` (the extension stack), NOT to `elements/bluefin/deps.bst`:

```yaml
# In elements/bluefin/gnome-shell-extensions.bst
kind: stack
depends:
- bluefin/shell-extensions/existing-extension.bst
- bluefin/shell-extensions/<new-name>.bst   # ← add here
```

## dconf Keyfiles for Extension Settings

To set default extension preferences, install a dconf keyfile:

```yaml
install-commands:
  # ... install extension ...
  - |
    install -Dm644 /dev/stdin \
      "%{install-root}%{datadir}/glib-2.0/schemas/10-<name>.gschema.override" <<'OVERRIDE'
    [org.gnome.shell]
    enabled-extensions=['<uuid>@example.com']
    OVERRIDE
```

**Note:** `[org/gnome/settings-daemon/plugins/media-keys] custom-keybindings` is last-writer-wins — if multiple keyfiles set this value, only the last alphabetically wins. When adding keybindings, include ALL entries from lower-numbered files too.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Missing `strip-binaries: ""` | Required — extensions are JS, not ELF |
| Wrong install path | Path must be exactly `%{datadir}/gnome-shell/extensions/<uuid>/` |
| Added to `deps.bst` instead of `gnome-shell-extensions.bst` | Extensions go in the extension stack |
| UUID typo | Verify from `metadata.json` — must be exact match |

## Checklist

- [ ] `strip-binaries: ""` set
- [ ] UUID discovered from `metadata.json` and set as variable
- [ ] Extension files installed under correct UUID path
- [ ] Element added to `elements/bluefin/gnome-shell-extensions.bst`
- [ ] `just validate` passes
- [ ] `just bst build bluefin/shell-extensions/<name>.bst` passes

## Lessons Learned

### dconf custom-keybindings list is last-writer-wins

`[org/gnome/settings-daemon/plugins/media-keys] custom-keybindings` is a single dconf value — the last file alphabetically wins and overwrites earlier files. When adding a new keyfile that sets `custom-keybindings`, include ALL entries from lower-numbered files too.

> Add further entries here when you discover a new pattern.
> Format: `### <pattern name> (YYYY-MM-DD)`
