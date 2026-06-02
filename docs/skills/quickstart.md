# Agent Quickstart

Zero-context entry point for routine dakota maintenance — add package, remove package, update refs.

## 5 Always Rules

1. **Always run `just --list` first** — the Justfile is the ground truth for available recipes
2. **Always run `just validate`, `just lint`, and `just boot-test` before opening a PR** — graph check, image lint, and automated boot smoke test
3. **Always add new elements to `deps.bst`** (binary) or `gnome-shell-extensions.bst` (extensions)
4. **Always grep for all references before removing** — `grep -r <name> elements/ .github/workflows/ files/`
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
| Add binary package | Create `elements/bluefin/<name>.bst` manually | `add-package.md` |
| Add Rust package | Create element + run `generate_cargo_sources.py` | `add-package.md` + `packaging-rust.md` |
| Add GNOME extension | Create `elements/bluefin/shell-extensions/<name>.bst` | `packaging-gnome-extensions.md` |
| Remove package | `grep -r <name> elements/ .github/workflows/` then delete | `remove-package.md` |
| Update tarball version | Edit version var, then `just bst source track bluefin/<name>.bst` | `update-refs.md` |
| Update git ref | `just bst source track bluefin/<name>.bst` | `update-refs.md` |
| Build failure | `just bst shell --build bluefin/<name>.bst` | `debugging.md` |
| BST YAML reference | — | `buildstream.md` |
| CI failure | — | `ci.md` |

## Tracking Groups

| Group | When to use |
|-------|-------------|
| `auto-merge` | App packages, shell extensions — low-risk, squash-merged automatically |
| `manual-merge` | Junctions, Rust elements — requires human review |

## Fix an Issue — End-to-End

```bash
# 1. Claim the issue
gh issue comment 635 --repo projectbluefin/dakota --body "/claim"

# 2. Branch from upstream/main
git checkout upstream/main -b fix/short-description

# 3. Make changes, validate
just validate && just lint

# 4. Commit with correct trailer
git commit -m "fix(bluefin): short description

Closes #635

Assisted-by: Copilot <223556219+Copilot@users.noreply.github.com>"

# 5. Push to upstream (never castrojo fork)
git push upstream fix/short-description

# 6. Open PR with checklist checkbox checked
gh pr create --repo projectbluefin/dakota ...
```

If the issue is still `needs-triage` (not yet `status/approved`), ask the user before claiming — agents don't self-approve issues.

## Commit Conventions

```text
feat(bluefin): add <name>
chore(deps): update <name>
fix(bluefin): <description>
chore: remove <name>
```

**Trailer:** Always `Assisted-by:` or `Signed-off-by:` — never `Co-authored-by:`. This is a hard rule from `docs/pr-checklist.md`.

## Key Paths

```text
elements/bluefin/                           All Bluefin-specific elements
elements/bluefin/deps.bst                   Central dependency manifest
elements/bluefin/shell-extensions/          GNOME Shell extensions
elements/bluefin/gnome-shell-extensions.bst Extension stack
include/aliases.yml                         URL aliases
.github/workflows/track-bst-sources.yml    Tracking matrix
.github/renovate.json5                      Renovate config
```

## Throughput Rule

If working through a backlog of issues, do not stop after the first fix. Work from the issue backlog in this order:

1. Issues labeled `queue/agent-ready`
2. Issues labeled `kind:bug`
3. Issues explicitly named by the user

## Lessons Learned

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`
