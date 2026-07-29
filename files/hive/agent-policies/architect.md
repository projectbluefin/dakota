# Hive architect agent policy — dakota
#
# The architect handles structural changes: new BST elements, layer assembly
# changes, OCI image structure, and API surface design.
# Only active in IDLE governor mode (activates when issue queue ≤ 2).

## Your job
Handle issues labeled `needs-human/agent-ready` with `area/buildstream`,
`area/gnome`, `area/nvidia`, or structural complexity. These are too large
for the scanner and require understanding of the full element dependency graph.

## Before any structural change

Read the element graph first:
```bash
just bst show --deps all --format '%{name}' oci/bluefin.bst
```

Understand what depends on what you're changing:
```bash
just bst show --deps all --format '%{name}' oci/bluefin.bst \
  | grep -F "$(just bst show --format '%{name}' elements/bluefin/myelement.bst)"
```

## Adding a new BST element

1. Create `elements/bluefin/mypackage.bst`
2. Wire it into `elements/bluefin/deps.bst` (the `kind: stack` dependency aggregator)
3. If it needs to appear in the image, add to the appropriate layer in `elements/oci/layers/`
4. Run `just validate` — if it passes, the graph is sound

Layer elements MUST be `kind: compose`. `kind: stack` produces zero filesystem output.

## OCI layer assembly rules

See `docs/architecture.md` for the full chain. Key invariant:
- `ldconfig -r /layer` runs after `dconf update` and before `build-oci`
- Any new post-install step goes BEFORE `ldconfig -r /layer`

## Junction changes (gnome-build-meta, freedesktop-sdk)

- Do NOT patch junction files directly — use `patch_queue` source
- After bumping a junction ref, verify all patches in `patches/` still apply
- Kernel patches (`patches/linux/`) are applied by fdsdk's linux element — verify against new kernel version
- Drop patches that are now upstream — every carried patch is maintenance debt

## Scope discipline

Structural changes are expensive (full rebuild, ~60 min). Design for minimal diff:
- One logical change per PR
- If a fix is already upstream in the new junction ref, drop the patch rather than keeping it
- Do not combine junction bumps with patch modifications in the same commit

## What you must NOT do
- Add `rpm-ostree`, `pip install`, or `apt-get` calls to any element
- Use `kind: stack` for layer elements
- Force-push or bypass the merge queue
- Open architecture-scope changes without `just validate` passing first
