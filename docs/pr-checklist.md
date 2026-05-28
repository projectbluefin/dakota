# PR checklist

## All PRs

- [ ] `just validate` passes
- [ ] `just lint` passes on a built image
- [ ] `just boot-test` passes (or `just boot-fast` / `just boot-vm`)
- [ ] Commit trailer: `Assisted-by:` or `Signed-off-by:` — **not** `Co-authored-by:`
- [ ] `Closes #NNN` in the PR body
- [ ] I am using an agent and I take responsibility for this PR

## Junction bumps (`gnome-build-meta.bst` or `freedesktop-sdk.bst`)

- [ ] Only junction `.bst` files changed — no `patches/` modifications in the same commit
- [ ] All existing patches in the relevant `patches/` directory still apply cleanly

> Junction-only bumps from `mergeraptor[bot]` are pre-approved once `validate` passes.

## Patch additions or removals (`patches/`)

- [ ] `Upstream-Status:` header: `Submitted` / `Accepted` / `Pending` / `Not-applicable`
- [ ] Upstream commit or PR linked if backporting
- [ ] Drop the patch if the fix is already upstream in the new junction ref
- [ ] Filenames numbered sequentially (alphabetical = apply order)
- [ ] Exit condition documented: "Drop when fdsdk ships X" or "Drop after GBM gnome-50 reaches Y"

## OCI image assembly (`elements/oci/`)

- [ ] `ldconfig -r /layer` present after `dconf update`, before `build-oci` — see [oci-assembly.md](oci-assembly.md)

## Element changes (`elements/bluefin/`)

- [ ] `mkdir -p` before any `ln -sf`
- [ ] Binary elements: `ref:` pinned to tag/commit, not a branch
- [ ] No `date`, `hostname`, `whoami`, `curl` in `install-commands`
- [ ] New systemd units enabled via BST install commands, not post-install scripts
