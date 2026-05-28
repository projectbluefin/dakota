# Debugging Build Failures

Load when a BST element build fails, or when diagnosing element errors from CI logs.

## When NOT to Use

- Diagnosing CI pipeline failures (cache, GHCR, mTLS) → `ci.md`
- Writing or modifying element files → `buildstream.md`
- Debugging OCI layer content issues → `oci-layers.md`

## Quick Reference

| Action | Command |
|--------|---------|
| Build one element | `just bst build bluefin/<name>.bst` |
| Enter build sandbox | `just bst shell --build bluefin/<name>.bst` |
| Inspect element sources | `just bst show bluefin/<name>.bst` |
| Find what depends on an element | `grep -r "<name>" elements/` |
| View last build log | `just bst artifact log bluefin/<name>.bst` |
| List files in built element | `just bst artifact list-contents bluefin/<name>.bst` |
| Delete cached failure | `just bst artifact delete bluefin/<name>.bst` |
| Full image build (after fixing) | `just build` |

## Debugging Workflow

1. **Read the build log** — The exact failure is in the last 20-50 lines. Look for `[FAILURE]` lines.

2. **Enter build sandbox** — Drop into the BST sandbox to reproduce manually:
   ```bash
   just bst shell --build bluefin/<name>.bst
   ```
   Inside the sandbox: run the failing configure/build command step-by-step.

3. **Check BST show output** — Verify all deps resolve and the element parses correctly:
   ```bash
   just bst show bluefin/<name>.bst
   ```
   A `Error loading project` here is a YAML/option error, not a build failure.

4. **List element content** — Verify installed files after a successful build:
   ```bash
   just bst artifact list-contents bluefin/<name>.bst
   ```

## Common Failures

### YAML / Option Errors

Symptom: `Error loading project` — element never starts building.

| Cause | Fix |
|-------|-----|
| Hyphenated option name | Options only allow alphanumeric + underscores (`my_option`, not `my-option`) |
| Invalid type for `options:` | Valid types: `bool`, `enum`, `flags`, `element-mask`, `arch`, `os` (not `string`) |
| Indentation error | Run `just bst show` to pinpoint the line |
| Missing alias | Add to `include/aliases.yml` |

### Source Fetch Failures

| Cause | Fix |
|-------|-----|
| Wrong `ref:` hash | Run `just bst source track bluefin/<name>.bst` to update |
| URL changed upstream | Update URL + alias in `include/aliases.yml` |
| Tarball has no wrapping directory | Add `base-dir: ""` to `kind: tar` source |

### Compile Failures

| Cause | Fix |
|-------|-----|
| Missing build dep | Add to `build-depends:` in element YAML |
| Wrong path assumption | GNOME OS is merged-usr; `/usr/sbin` → `/usr/bin`, `/lib` → `/usr/lib` |
| `/usr/sbin` hardcoded in upstream | Patch the configure or Makefile |
| Autotools can't find pkg | Check `PKG_CONFIG_PATH` and that the dep is in `build-depends:` |

### Install / Staging Failures

| Cause | Fix |
|-------|-----|
| Missing `strip-binaries: ""` | Required for non-ELF elements (fonts, pre-built binaries, configs) |
| `mkdir` before `ln -sf` missing | Always `mkdir -p` before any symlink creation |
| Overlap conflict | Add conflicting path to `overlap-whitelist:` |
| File installed outside `/usr` | GNOME OS: everything must be under `/usr`. Patch install paths. |

### Image Build Failures

| Cause | Fix |
|-------|-----|
| New package not appearing in image | `deps.bst` cache invalidation bug — see BST Weak-Key Caching Bug in `buildstream.md` |
| `ldconfig` error in OCI script | Run `ldconfig -r %{install-root}` after all installs, before `build-oci` |
| Missing compose element content | OCI layer must be `kind: compose`, not `kind: stack` |

## BST Shell Tips

```bash
# Enter build sandbox for failing element
just bst shell --build bluefin/<name>.bst

# Inside the sandbox, run the failing step manually:
./configure --prefix=/usr   # or whatever configure step is failing
make -j$(nproc)
make install DESTDIR=/path/to/staging

# Check what's already installed in staging:
find %{install-root} -type f | head -50

# Check pkg-config sees expected deps:
pkg-config --list-all | grep <libname>
```

## Lessons Learned

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`
