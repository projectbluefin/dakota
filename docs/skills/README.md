# docs/skills — In-Repo Knowledge Base

Accumulated lessons from real work on this repo. Every agent working here
should read the relevant file before starting in that area.

When you discover a new pattern or fix a recurring mistake, add it here in the
same PR as your change. This is the feedback loop: lessons land here and help
every future agent and contributor — not just you, and not just on one machine.

## Routing Table — load only what you need

| Task | Load |
|------|------|
| Zero-context routine maintenance | [`quickstart.md`](quickstart.md) |
| Adding a package | [`add-package.md`](add-package.md) |
| Removing a package | [`remove-package.md`](remove-package.md) |
| Updating a package version | [`update-refs.md`](update-refs.md) |
| BST YAML reference, variables, kinds | [`buildstream.md`](buildstream.md) |
| Debugging a build failure | [`debugging.md`](debugging.md) |
| OCI image layer assembly | [`oci-layers.md`](oci-layers.md) |
| Junction overrides (when to, when not to) | [`bst-overrides.md`](bst-overrides.md) |
| Patching junction elements | [`patch-junctions.md`](patch-junctions.md) |
| Pre-built binary packaging | [`packaging-binaries.md`](packaging-binaries.md) |
| Go project packaging | [`packaging-go.md`](packaging-go.md) |
| Rust/Cargo project packaging | [`packaging-rust.md`](packaging-rust.md) |
| Zig project packaging | [`packaging-zig.md`](packaging-zig.md) |
| GNOME Shell extension packaging | [`packaging-gnome-extensions.md`](packaging-gnome-extensions.md) |
| Local OTA testing with QEMU | [`local-ota.md`](local-ota.md) |
| Hardware testlab dev loop | [`testlab.md`](testlab.md) |
| Hardware testlab one-time setup | [`testlab-setup.md`](testlab-setup.md) |
| CI pipeline, remote cache, GHCR | [`ci.md`](ci.md) |
| Manual promotion (testing → stable) and release | [`ci.md`](ci.md) — *Manual stable promotion flow* |
| Clearing stuck merge queue | [`merge-queue.md`](merge-queue.md) |
| Actionadon lifecycle, issue queue, data donation | [`actionadon.md`](actionadon.md) |
| Project overview and what Bluefin is | [`overview.md`](overview.md) |
| ujust recipes in `files/just-overrides/` | [`.github/skills/ujust-recipes.md`](../../.github/skills/ujust-recipes.md) |
| Installer (bootc-installer) | [`installer.md`](installer.md) |
| Merging dep-update PRs into testing | [`merge-queue.md`](merge-queue.md) |
| PR review workflow | [`pr-review.md`](pr-review.md) |

## Mandatory skill contribution

**All agents must improve skills.** If you discover a new pattern, fix a recurring
mistake, or learn something that would help future contributors, update the
relevant skill file in this directory — in the same PR as your change.

- If no relevant skill file exists, create one and add it to the routing table above.
- If your lesson applies to an existing skill, add it under `## Lessons Learned`.
- Skills are living documents. Every agent and human contributor improves them.

### How to add a lesson

1. Open the relevant skill file (or create a new one)
2. Add a section under `## Lessons Learned`: `### <pattern name> (YYYY-MM-DD)`
3. What failed → why → the fix → code example
4. Commit it in the same PR as your change

## Related

- Role policies for Hive agents: [`../../files/hive/agent-policies/`](../../files/hive/agent-policies/)
- Top-level agent rules: [`../../AGENTS.md`](../../AGENTS.md)

