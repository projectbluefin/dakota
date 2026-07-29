---
name: packaging-binaries
description: Packages a project using official pre-built static binaries from upstream releases. Load when upstream provides release binaries and a source build is unnecessary.
---

# Packaging Pre-Built Binaries

## Overview

Pre-built binary elements use `kind: manual` with `kind: tar` or `kind: remote` sources pointing at official upstream release artifacts. This is the simplest packaging path in Dakota — no compiler toolchain, no vendoring. Most Go-based CLI tools in Dakota (gum, fzf, glow) use this pattern.

Reference elements: `elements/bluefin/gum.bst`, `elements/bluefin/zig.bst`.

## When to use

- Upstream ships trusted, static release binaries (GitHub Releases or official site).
- Building from source would require bootstrapping a compiler not otherwise needed.
- The binary is architecture-specific and upstream provides per-arch artifacts.

## When not to use

- Source is straightforward to build and a language-specific skill applies — use [packaging-rust](../packaging-rust/SKILL.md), [packaging-go](../packaging-go/SKILL.md), or [packaging-zig](../packaging-zig/SKILL.md).
- The project has no official binary releases or provenance is unclear.

## Authoritative sources

- `elements/bluefin/gum.bst` — arch-conditional tarball with completions
- `elements/bluefin/zig.bst` — arch-conditional tarball with lib tree
- `include/aliases.yml` — URL alias definitions

## Workflow

1. Locate the official release artifact URLs for both `x86_64` and `aarch64`.
2. Create the element under `elements/bluefin/<name>.bst` with `kind: manual`.
3. Set `variables: strip-binaries: ""` (pre-built binaries are already stripped or contain non-ELF content that the strip tool would corrupt).
4. Add architecture-conditional sources using the `(?):` BST conditional syntax:
   ```yaml
   sources:
   - kind: tar
     (?):
     - arch == "x86_64":
         url: github_files:owner/project/releases/download/v1.0/project_linux_amd64.tar.gz
         ref: <sha256>
     - arch == "aarch64":
         url: github_files:owner/project/releases/download/v1.0/project_linux_arm64.tar.gz
         ref: <sha256>
   ```
5. Write install commands to place binaries in `%{install-root}%{bindir}/`.
6. If the domain is not already in `include/aliases.yml`, add an alias.
7. Add the element to `elements/bluefin/deps.bst`.
8. Build: `just bst build bluefin/<name>.bst`.

## Failure modes

- **Missing `strip-binaries: ""`** — BST attempts to strip non-ELF content (shell completions, man pages) and fails or corrupts files. Always set this variable.
- **No `base-dir: ""`** — some tarballs have no wrapping directory; without `base-dir: ""` BST fails expecting a top-level dir. Check the tarball structure first.
- **Single-file downloads** — for raw binaries (no archive), use `kind: remote` with `filename:` to name the downloaded file:
  ```yaml
  sources:
  - kind: remote
    filename: tool-name
    url: github_files:owner/project/releases/download/v1.0/tool-linux-amd64
    ref: <sha256>
  ```

## Verification

```bash
just bst build bluefin/<name>.bst
just bst shell bluefin/<name>.bst -- /usr/bin/<name> --version
```

## Related skills

- [packaging-go](../packaging-go/SKILL.md) — when a Go project needs source build instead
- [add-package](../add-package/SKILL.md) — general element addition workflow
- [buildstream](../buildstream/SKILL.md) — BST element syntax reference
