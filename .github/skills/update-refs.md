# Updating Package Refs

Load when updating an existing package's version in `projectbluefin/dakota`.

## When NOT to Use

- Adding a new package → `add-package.md`
- Bumping junction refs (gnome-build-meta, freedesktop-sdk) → `patch-junctions.md`
- Debugging a post-update build failure → `debugging.md`

## Quick Reference

| Task | Command |
|------|---------|
| Update tarball to version X | `just track-tarball elements/bluefin/<name>.bst <version>` |
| Update git-tracked element to latest | `just track-one elements/bluefin/<name>.bst` |
| Update all git-tracked elements | `just track-all-git` |
| Update all tarballs | `just track-all-tarballs` |
| Regenerate cargo2 sources for a Rust element | `just track-one elements/bluefin/<name>.bst` |

`just track-one` on a Rust element automatically regenerates the `cargo2` source block. No need to call `generate_cargo_sources.py` manually for existing elements.

## Tracking Groups

| Group | When to use | Examples |
|-------|-------------|---------|
| `auto-merge` | Low-risk app packages, shell extensions | Solaar, Gear Lever, extensions |
| `manual-merge` | Junctions, Rust elements, anything with patch debt | fdsdk, GBM, tailscale |

Set `tracking-group:` in the element or tracking workflow accordingly.

## Element Source Types

### Tarball Element (`kind: tar`)

```yaml
sources:
- kind: tar
  url: alias:releases/owner/project/v%{version}.tar.gz
  ref: sha256hex...
```

After `just track-tarball`:
1. `ref:` is updated in the element
2. Run `just bst build elements/bluefin/<name>.bst` to verify

### Git-Tracked Element

```yaml
sources:
- kind: git_repo
  url: alias:project
  track: main
  ref: abc123def456...
```

After `just track-one`:
1. `ref:` is updated to the latest commit on the tracked branch/tag
2. For Rust elements: `cargo2` source block is regenerated automatically
3. Run `just bst build elements/bluefin/<name>.bst` to verify

## Rust Elements — Cargo Lock

For Rust elements, `just track-one` automatically:
1. Updates `ref:` in the git source
2. Generates a fresh Cargo.lock from the new source
3. Regenerates the `cargo2` source block

**Manual fallback** (if `just track-one` fails):
```bash
# Generate cargo sources from an existing Cargo.lock
python3 files/scripts/generate_cargo_sources.py path/to/Cargo.lock
```

The `cargo2` block is generated output — never hand-edit it.

## Post-Update Verification

```bash
just validate elements/bluefin/<name>.bst   # graph check
just bst build elements/bluefin/<name>.bst  # build only this element
just build                                   # full image build (when unsure)
```

## Junction Bumps

For `elements/gnome-build-meta.bst` or `elements/freedesktop-sdk.bst` ref updates, see `patch-junctions.md`. Junction bumps require patch verification and are a separate workflow.

## Lessons Learned

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`
