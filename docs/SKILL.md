# Dakota Skill Router

Agent entry point. Load only the skill for your current task — do not load everything.

## Task → Skill

| I need to... | Load |
|---|---|
| Add a package to Bluefin | `.github/skills/add-package.md` |
| Remove a package | `.github/skills/remove-package.md` |
| Update a package version | `.github/skills/update-refs.md` |
| Understand BST element syntax | `.github/skills/buildstream.md` |
| Debug a build failure | `.github/skills/debugging.md` |
| Understand OCI layer assembly | `.github/skills/oci-layers.md` |
| Work with junction overrides | `.github/skills/bst-overrides.md` |
| Add/rebase a patch | `.github/skills/patch-junctions.md` |
| Package pre-built binaries | `.github/skills/packaging-binaries.md` |
| Package a Go project | `.github/skills/packaging-go.md` |
| Package a Rust project | `.github/skills/packaging-rust.md` |
| Package a Zig project | `.github/skills/packaging-zig.md` |
| Package a GNOME extension | `.github/skills/packaging-gnome-extensions.md` |
| Test OTA updates locally (QEMU) | `.github/skills/local-ota.md` |
| Test on physical hardware | `.github/skills/testlab.md` |
| Set up hardware test lab | `.github/skills/testlab-setup.md` |
| Debug CI failures | `.github/skills/ci.md` |
| Understand what dakota/Bluefin is | `.github/skills/overview.md` |
| Write ujust recipes | `.github/skills/ujust-recipes.md` |
| Work on the installer | `.github/skills/installer.md` |
| Routine maintenance (add/remove/update) | `.github/skills/quickstart.md` |

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

`.github/skills/README.md` — complete routing table with all 20 skills.
