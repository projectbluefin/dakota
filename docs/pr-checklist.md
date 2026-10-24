# PR checklist

## All PRs

- [ ] The narrowest relevant validation passes and is reported accurately
- [ ] `just validate` passes for BST, image, or Justfile changes
- [ ] Image-affecting changes include lint/boot evidence from local testing or CI
- [ ] Commit trailer: `Assisted-by:` or `Signed-off-by:` — **not** `Co-authored-by:`
- [ ] `Closes #NNN` is present when the PR resolves an issue
- [ ] Existing guidance affected by the change is corrected; no unrelated documentation writeback is required
- [ ] I am using an agent and I take responsibility for this PR

## Secure Boot signing inputs (kernel, modules, shim, systemd-boot, fwupd, junction bumps)

- [ ] A maintainer booted the `:pr-N` image on real hardware with Secure Boot on
- [ ] `dakota-secure-boot status` and `ujust verify` pass on that boot

## Junction bumps (`gnome-build-meta.bst` or `freedesktop-sdk.bst`)

- [ ] Only junction `.bst` files changed — no `patches/` modifications in the same commit
- [ ] All existing patches in the relevant `patches/` directory still apply cleanly

> Junction bumps change Secure Boot signing inputs, so bumps from `mergeraptor[bot]` also need the maintainer boot above and are never auto-merged.

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
