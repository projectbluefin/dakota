# Dakota Skill Router

Load the smallest skill that answers the job. Do not read the whole repo memory bank unless the task is genuinely cross-cutting.

If your first draft says "use dnf", "edit the Containerfile", or "enable a COPR", stop and load `docs/skills/not-bluefin.md` first.

## Fast Path

1. **Reset the mental model** → `docs/skills/not-bluefin.md`
2. **Classify the task** → package / build / CI / issue lifecycle / review / installer
3. **Load one focused skill** from the table below
4. **Read the actual file** you will edit
5. **Verify external tool behavior with Context7** before changing syntax or flags

## Task → Skill

| I need to... | Load |
|---|---|
| Reset Dakota vs bluefin mental model | `docs/skills/not-bluefin.md` |
| Start routine maintenance with little context | `docs/skills/quickstart.md` |
| Add or remove a package | `docs/skills/add-package.md` / `docs/skills/remove-package.md` |
| Update a package version or ref | `docs/skills/update-refs.md` |
| Understand BST syntax or element kinds | `docs/skills/buildstream.md` |
| Debug a build failure | `docs/skills/debugging.md` |
| Understand OCI layer assembly | `docs/skills/oci-layers.md` |
| Work with junction overrides or patches | `docs/skills/bst-overrides.md` / `docs/skills/patch-junctions.md` |
| Package a Go/Rust/Zig/binary/extension project | `docs/skills/packaging-*.md` |
| Test OTA updates locally or on hardware | `docs/skills/local-ota.md` |
| Identify which CI workflow owns the problem | `docs/skills/workflow-map.md` |
| Fix reusable workflow / token / cache / startup failures | `docs/skills/ci-tooling.md` |
| Change boot-check, smoke, testsuite, or QEMU CI | `docs/skills/e2e-ci.md` |
| Change promotion PR or stable release flow | `docs/skills/release-promotion.md` |
| Need historical CI edge cases | `docs/skills/ci-reference.md` |
| Clear stuck queue or conflicting chore PRs | `docs/skills/merge-queue.md` |
| Work on issues, triage, or Actionadon | `docs/skills/actionadon.md` |
| Understand what Dakota is | `docs/skills/overview.md` |
| Write ujust recipes | `.github/skills/ujust-recipes.md` |
| Work on the installer | `docs/skills/installer.md` |
| Review a pull request | `docs/workflow.md` + `docs/pr-checklist.md` + `docs/skills/pr-review.md` |

## Reference Docs

| Topic | File |
|---|---|
| Build workflow, repo layout, dev loop | `docs/build.md` |
| PR checklist by change type | `docs/pr-checklist.md` |
| Patch lifecycle and junction bumps | `docs/patches.md` |
| CI jobs, publish, and release | `docs/ci.md` |
| Community workflow and labels | `docs/workflow.md` |
| OCI assembly internals | `docs/oci-assembly.md` |

## Routing Rule

If a skill starts turning into a dumping ground, split it. Dakota should optimize for:
- fast agent loading
- narrow task targeting
- factory memory that compounds instead of sprawling

Full index: `docs/skills/README.md`
