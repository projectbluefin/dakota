# Updating Package Refs

Load when updating an existing package's version in `projectbluefin/dakota`.

## When NOT to Use

- Adding a new package → `add-package.md`
- Bumping junction refs (gnome-build-meta, freedesktop-sdk) → `patch-junctions.md`
- Debugging a post-update build failure → `debugging.md`

## Quick Reference

| Task | Command |
|------|---------|
| Update tarball to version X | Edit `version:` variable in element, then `just bst source track bluefin/<name>.bst` |
| Update git-tracked element to latest | `just bst source track bluefin/<name>.bst` |
| Update all elements in a group | See `.github/workflows/track-bst-sources.yml` |
| Regenerate cargo2 sources for a Rust element | `python3 files/scripts/generate_cargo_sources.py path/to/Cargo.lock` |

The real tracking command is `just bst source track <element>` — it updates the `ref:` field in the element's source block to the latest matching version/commit.

**Rust elements:** After bumping the git ref, regenerate the `cargo2` source block manually:
```bash
# Get Cargo.lock from the new source, then:
python3 files/scripts/generate_cargo_sources.py path/to/Cargo.lock
```

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

After `just bst source track`:
1. `ref:` is updated in the element
2. Run `just bst build bluefin/<name>.bst` to verify

### Git-Tracked Element

```yaml
sources:
- kind: git_repo
  url: alias:project
  track: main
  ref: abc123def456...
```

After `just bst source track`:
1. `ref:` is updated to the latest commit on the tracked branch/tag
2. For Rust elements: regenerate `cargo2` manually with `generate_cargo_sources.py`
3. Run `just bst build bluefin/<name>.bst` to verify

## Rust Elements — Cargo Lock

For Rust elements, after tracking a new git ref:
1. Update `ref:` in the git source via `just bst source track bluefin/<name>.bst`
2. Get the new `Cargo.lock` from the source (enter build sandbox: `just bst shell --build bluefin/<name>.bst`)
3. Regenerate the `cargo2` source block:
   ```bash
   python3 files/scripts/generate_cargo_sources.py path/to/Cargo.lock
   ```

The `cargo2` block is generated output — never hand-edit it.

## Post-Update Verification

```bash
just validate                            # full graph check
just bst build bluefin/<name>.bst        # build only this element
just build                               # full image build (when unsure)
```

## Junction Bumps

For `elements/gnome-build-meta.bst` or `elements/freedesktop-sdk.bst` ref updates, see `patch-junctions.md`. Junction bumps require patch verification and are a separate workflow.

## Lessons Learned

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`
