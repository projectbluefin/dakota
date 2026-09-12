---
name: dakota-extensions
description: Package, update, and configure GNOME Shell extensions, Quick Settings panels, and schemas in Dakota. Use when editing elements/bluefin/shell-extensions/ or dconf extension defaults.
metadata:
  verified-sources:
    - https://buildstream.gitlab.io/buildstream-plugins-community/sources/zip.html
  context7-sources:
    - /git_gitlab_gnome_org/gnome_gnome-shell
---

# Dakota GNOME Extensions

Dakota packages curated GNOME Shell extensions built from source or upstream repositories directly into the immutable system image.

## When to Use

- Packaging a new GNOME Shell extension into `elements/bluefin/shell-extensions/`
- Updating or patching an existing extension in `elements/bluefin/shell-extensions/`
- Enabling or configuring default extension settings in dconf schemas
- Resolving extension compatibility for the tracked GNOME version (GNOME 45–50+)

## When NOT to Use

- Packaging native system software, CLI tools, or background daemons → load `dakota-packaging`
- Low-level OCI layer composition → load `dakota-image`
- Developer/CI workflows → load `dakota-ci`

## Core Process

1. **Verify Upstream Extension**:
   - Inspect `metadata.json` for supported `shell-version` entries (must match Dakota's GNOME release, currently targeting GNOME 50).
   - Ensure code uses modern ESM syntax (`import ... from 'resource:///...'`).
2. **Create Element**:
   - Add `elements/bluefin/shell-extensions/<name>.bst` using `kind: manual`.
   - Source from pinned git commit or release tag.
   - For release ZIPs with `metadata.json` at the archive root, set `base-dir: ""`
     in the `kind: zip` source. The plugin default (`'*'`) extracts a child
     directory instead, dropping root-level files. Inspect the pinned archive's
     layout before choosing an extraction root; source-tree archives may have a
     wrapper directory.
   - Extract UUID via `jq` and install files into:
     ```bash
     _uuid="$(jq -r .uuid metadata.json)"
     _dest="%{install-root}%{datadir}/gnome-shell/extensions/${_uuid}"
     install -d "${_dest}"
     cp -R * "${_dest}/"
     ```
3. **Compile Schemas**:
   - If the extension ships a `schemas/` directory, compile schemas in `install-commands`:
     ```bash
     glib-compile-schemas "${_dest}/schemas"
     ```
4. **Aggregate in Stack**:
   - Add the new extension element to `elements/bluefin/gnome-shell-extensions.bst`.
5. **Configure Default Enablement**:
   - Check both `files/dconf/` and `elements/bluefin/shell-extensions/disable-ext-validator.bst`, which generates Dakota's default `enabled-extensions` schema override.
   - Enable basic desktop behavior by default only when its pinned metadata supports the target Shell version and its backend services are available. Personal integrations (sync/VPN controls, clipboard history, extra audio controls, and power reminders) remain opt-in with their dependencies installed. BudsLink may stay enabled because its default panel is hidden without supported devices. A disabled version validator does not establish compatibility.
   - For administrator-managed prerequisites, provide explicit setup from the control rather than silently granting permissions. Dakota's Tailscale setup uses a narrowly scoped, administrator-authenticated helper; it does not authorize users at boot.
   - Diagnose live settings with `/usr/bin/gsettings` and `gnome-extensions`, not Homebrew's GSettings CLI. Existing user lists can mask new defaults; preserve those selections rather than installing login migrations to force new defaults.
6. **Validate & Build**:
   Graph validation (`bst show`) does not stage sources or execute installation
   commands. Build the changed extension and inspect its installed metadata and
   schemas; a green graph check alone cannot verify archive extraction.
   ```bash
   just validate
   just bst build bluefin/shell-extensions/<name>.bst
   ```

## Invariants

- **ESM Architecture**: GNOME 45+ requires standard JavaScript ESM imports (`import ... from 'resource:///org/gnome/shell/...'`). Legacy `imports.*` syntax is prohibited.
- **UUID Directory Invariant**: The installed extension folder under `%{datadir}/gnome-shell/extensions/` must match `metadata.json`'s `.uuid` string exactly.
- **Pure bootc Compliance**: Extensions must rely only on system services and pure bootc APIs. No dependencies on `rpm-ostree` or mutable package installers.
- **Schema Compilation**: Extensions with custom GSettings must include compiled schemas (`gschemas.compiled`) in their directory or rely on Dakota's root schema compiler during OCI assembly.
- **Disabled Binaries Strip**: Set `variables: { strip-binaries: "" }` in extension manual elements since extension JS/CSS files do not contain ELF binaries.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The extension works on GNOME 46, so it's fine for GNOME 50 without checking." | Shell internal APIs frequently change across major GNOME releases. Verify imports and Quick Settings classes. |
| "Users can just install the extension manually from extensions.gnome.org." | Dakota is an immutable, turnkey OS. Core desktop features must be shipped as pre-packaged system extensions. |
| "I'll edit the schema in `/etc/dconf/db/local.d/` directly at runtime." | All dconf overrides must be defined in source under `files/dconf/` and compiled during image build. |

## Red Flags

- Use of deprecated `const { ... } = imports.ui` or legacy extension classes
- Omitting the extension from `elements/bluefin/gnome-shell-extensions.bst`
- Hardcoded absolute paths to user home directories (`/var/home/...`) in extension JS
- Adding an extension without testing schema compilation

## Verification

- [ ] `just validate` passes cleanly
- [ ] `just bst build bluefin/shell-extensions/<name>.bst` succeeds
- [ ] `metadata.json` specifies compatibility with the current GNOME release
- [ ] Extension directory matches `.uuid` precisely
- [ ] `glib-compile-schemas` succeeds if schemas are present
- [ ] Added to `elements/bluefin/gnome-shell-extensions.bst`

## References

- [`elements/bluefin/gnome-shell-extensions.bst`](../../../elements/bluefin/gnome-shell-extensions.bst)
- [`elements/bluefin/shell-extensions/`](../../../elements/bluefin/shell-extensions/)
- [`docs/oci-assembly.md`](../../../docs/oci-assembly.md)