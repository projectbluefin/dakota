# Dakota Skill Router

Agent entry point. Load only the skill for your current task — do not load everything.

If your first draft says "use dnf/RPM/COPR" or "edit the Containerfile to add a package", stop and reload `docs/skills/not-bluefin.md`. Dakota image changes happen in `.bst` elements and `elements/bluefin/deps.bst`, even though those paths still say `bluefin`.

## Task → Skill

| I need to... | Load |
|---|---|
| **Load the dakota build context first** | **⚠️ REQUIRED FIRST — `docs/skills/not-bluefin.md` before any other skill, especially if you have bluefin context. If your plan mentions dnf/RPM/Containerfile overlays, reload it and translate the task into BST terms first.** |
| Review a pull request | `docs/workflow.md` + `docs/pr-checklist.md` |
| Add a package to Dakota | `docs/skills/add-package.md` |
| Remove a package | `docs/skills/remove-package.md` |
| Update a package version | `docs/skills/update-refs.md` |
| Understand BST element syntax | `docs/skills/buildstream.md` |
| Debug a build failure | `docs/skills/debugging.md` |
| Understand OCI layer assembly | `docs/skills/oci-layers.md` |
| Work with junction overrides | `docs/skills/bst-overrides.md` |
| Add/rebase a patch | `docs/skills/patch-junctions.md` |
| Package pre-built binaries | `docs/skills/packaging-binaries.md` |
| Package a Go project | `docs/skills/packaging-go.md` |
| Package a Rust project | `docs/skills/packaging-rust.md` |
| Package a Zig project | `docs/skills/packaging-zig.md` |
| Package a GNOME extension | `docs/skills/packaging-gnome-extensions.md` |
| Test OTA updates locally or on hardware | `docs/skills/local-ota.md` |
| Debug CI failures | `docs/skills/ci.md` |
| Understand what dakota/Bluefin is | `docs/skills/overview.md` |
| Write ujust recipes | `.github/skills/ujust-recipes.md` |
| Work on the installer | `docs/skills/installer.md` |
| Routine maintenance (add/remove/update) | `docs/skills/quickstart.md` |

## Reference Docs

| Topic | File |
|---|---|
| Build workflow, repo layout, dev loop | [`build.md`](build.md) |
| PR checklist by change type | [`pr-checklist.md`](pr-checklist.md) |
| Patch lifecycle and junction bumps | [`patches.md`](patches.md) |
| CI jobs, schedule, published images | [`ci.md`](ci.md) |
| Community workflow, labels, Hive, Actionadon | [`workflow.md`](workflow.md) |
| OCI assembly (ldconfig, dconf, build-oci) | [`oci-assembly.md`](oci-assembly.md) |

## Full Skill Index

`docs/skills/README.md` — complete routing table with all 20 skills.
