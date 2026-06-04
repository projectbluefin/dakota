# NOT Bluefin — Dakota Build Context

**Load this skill FIRST before any dakota task.** Dakota is fundamentally different from bluefin.

---

## Dakota uses BuildStream 2 (BST). Not dnf. Not RPM. Not Containerfile.

| Bluefin Pattern | Dakota Reality | What to do instead |
|---|---|---|
| `dnf5 install <pkg>` | ❌ PROHIBITED | Write a `.bst` element file |
| `dnf5 copr enable` | ❌ PROHIBITED | BST has no COPR concept |
| `copr_install_isolated()` | ❌ PROHIBITED | Not applicable |
| `copr-helpers.sh` | ❌ PROHIBITED | Does not exist in dakota |
| Containerfile `RUN dnf5...` stage | ❌ PROHIBITED | Use BST elements for packages |
| `.spec` files / RPM build | ❌ PROHIBITED | BST elements only |
| Fedora package names (RPM) | ⚠️  May differ | Verify in BST element definitions |

## What dakota DOES use

- **BuildStream 2** (`.bst` files) — the only way to add packages
- **BST element kinds**: `autotools`, `cmake`, `meson`, `pip`, `manual`, `stack`, `junction`
- **Upstream junctions**: `freedesktop-sdk.bst` and `gnome-build-meta.bst` provide most packages
- **OCI assembly**: A `Containerfile` exists for final image assembly only — not for package installation

## Historical name trap: `bluefin/` paths still mean Dakota

- `elements/bluefin/*.bst`, `elements/bluefin/deps.bst`, `elements/oci/bluefin.bst`, and `elements/oci/layers/bluefin.bst` are Dakota's main build paths.
- Those names are historical carry-over from the broader Bluefin project. They do **not** mean "use the bluefin repo workflow" or "install packages with dnf in a Containerfile."

## Translate the request before acting

| If someone asks for... | In Dakota, do this |
|---|---|
| "Add/remove a package" | Add/remove a `.bst` element and wire/unwire it in `elements/bluefin/deps.bst` |
| "Enable a service by default" | Ship the unit/preset from a `.bst` element |
| "Change what ends up in the image" | Edit BST elements or `elements/oci/*`, not the repo `Containerfile` |
| "Enable a COPR / add an RPM repo" | Stop — Dakota has no COPR/RPM repo layer; package the software in BST terms |

## Adding a package to dakota

See `docs/skills/add-package.md`. Never reach for `dnf5`.

## The Containerfile is NOT for packages

Dakota has a `Containerfile` for final OCI image assembly (copying BST artifacts into the image). It does NOT install packages. Do not add `RUN dnf5 install` to it.

## Common file traps

| File / path | What it actually is | What it is **not** |
|---|---|---|
| `Containerfile` | Local bootc lint helper for an already-built Dakota image | A package overlay or install stage |
| `Justfile` `build-containerfile` recipe | Convenience wrapper around that lint helper | The primary image build path |
| `elements/bluefin/deps.bst` | Dakota's package manifest | An RPM package list |
| `elements/oci/bluefin.bst` | Final BuildStream OCI assembly step | A signal to switch to bluefin repo habits |

## The Justfile is NOT the same as bluefin's

Dakota's `Justfile` has different semantics. `just lint` validates BST templates. There is no `just check` equivalent.

## Lessons Learned

### Historical bluefin path names are not workflow cues (2026-06-04)

Dakota still uses `bluefin` in several path names (`elements/bluefin/*`,
`oci/bluefin.bst`), which repeatedly causes agents to drift into dnf/RPM or
Containerfile-overlay assumptions. Treat those names as repo history only.
Actual Dakota image changes still happen in BuildStream elements, dependency
stacks, and OCI assembly elements.
