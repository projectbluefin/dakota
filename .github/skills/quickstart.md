# Agent Quickstart

Zero-context entry point for routine dakota maintenance — add package, remove package, update refs.

## 5 Always Rules

1. **Always run `just --list` first** — the Justfile is the ground truth for available recipes
2. **Always run `just validate <element>` before `just bst build`** — catches errors without building
3. **Always add new elements to `deps.bst`** (binary) or `gnome-shell-extensions.bst` (extensions)
4. **Always run `just remove-package <name>` before touching any files** — it prints the full checklist
5. **Always use `just bst` not bare `bst`** — BST must run inside the pinned container

## 5 Never Rules

1. **Never edit** `elements/freedesktop-sdk.bst` or `elements/gnome-build-meta.bst` without human review
2. **Never open a PR** to `projectbluefin/dakota` without running `just validate` first
3. **Never add Renovate entries** for elements already in the `track-tarballs` CI job — causes racing PRs
4. **Never call `bst` directly** — always `just bst ...`
5. **Never skip `just validate`** even if `just bst build` "looks right"

## Task Routing

| Task | Command | Skill |
|------|---------|-------|
| Add binary package | `just scaffold-binary <name> <owner/repo>` | `add-package.md` |
| Add Rust package | `just scaffold-rust <name> <owner/repo>` | `add-package.md` + `packaging-rust.md` |
| Add GNOME extension | `just scaffold-gnome-ext <name> <owner/repo>` | `packaging-gnome-extensions.md` |
| Remove package | `just remove-package <name>` | `remove-package.md` |
| Update tarball | `just track-tarball <element.bst> <ver>` | `update-refs.md` |
| Update git ref | `just track-one <element.bst>` | `update-refs.md` |
| Build failure | `just bst shell --build <element.bst>` | `debugging.md` |
| BST YAML reference | — | `buildstream.md` |
| CI failure | — | `ci.md` |

## Tracking Groups

| Group | When to use |
|-------|-------------|
| `auto-merge` | App packages, shell extensions — low-risk, squash-merged automatically |
| `manual-merge` | Junctions, Rust elements — requires human review |

## Commit Conventions

```
feat(bluefin): add <name>
chore(deps): update <name>
fix(bluefin): <description>
chore: remove <name>
```

## Key Paths

```
elements/bluefin/           All Bluefin-specific elements
elements/bluefin/deps.bst   Central dependency manifest
elements/bluefin/shell-extensions/         GNOME Shell extensions
elements/bluefin/gnome-shell-extensions.bst  Extension stack
files/templates/            Element scaffolds (binary, rust, gnome-ext, git-tracked)
include/aliases.yml         URL aliases
.github/workflows/track-bst-sources.yml    Tracking matrix
.github/renovate.json5      Renovate config
```

## Throughput Rule

If working through a backlog of issues, do not stop after the first fix. Work from the issue backlog in this order:

1. Issues labeled `queue/agent-ready`
2. Issues labeled `kind:bug`
3. Issues explicitly named by the user

## Lessons Learned

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`
