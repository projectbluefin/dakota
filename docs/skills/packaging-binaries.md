# Packaging Pre-Built Binaries

Load when packaging a project that provides official pre-built static binaries (GitHub Releases, official downloads), or when building from source is impractical.

## When to Use Pre-Built Binaries

| Situation | Pre-built? |
|---|---|
| Official static binary available from upstream | ✅ Yes |
| Upstream has no build system we can use in BST | ✅ Yes |
| Bootstrap compiler needed (e.g., Zig for Zig builds) | ✅ Yes |
| Source available and build system is standard | ❌ Build from source instead |

## Element Template

```yaml
kind: manual
description: <Package name>

build-depends:
- freedesktop-sdk.bst:bootstrap-import.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  version: '1.2.3'

public:
  bst:
    # Required for non-ELF elements (or elements with pre-built binaries)
    strip-binaries: ""

sources:
- kind: tar
  url: alias:releases/owner/project/v%{version}/project-linux-amd64.tar.gz
  ref: sha256hex...

install-commands:
- install -Dm755 project "%{install-root}%{bindir}/project"
- '%{install-extra}'
```

## Architecture Dispatch

For projects with architecture-specific binaries:

```yaml
variables:
  version: '1.2.3'
  (?):
  - arch == "x86_64":
      arch-tag: "amd64"
  - arch == "aarch64":
      arch-tag: "arm64"

sources:
- kind: tar
  url: alias:releases/owner/project/v%{version}/project-linux-%{arch-tag}.tar.gz
  ref: sha256hex...
```

## Source Kinds for Binaries

| Source kind | Use when |
|---|---|
| `tar` | Binary is inside a `.tar.gz`/`.tar.xz` archive |
| `remote` | Single file download (not extracted) |

For `remote` sources, use `directory:` to control placement in the staging dir:
```yaml
sources:
- kind: remote
  url: alias:releases/owner/project/v%{version}/project-linux-amd64
  ref: sha256hex...
  directory: bin
```

## Adding URL Aliases

Binary download domains need an alias in `include/aliases.yml`:

```yaml
aliases:
  github: 'https://github.com/'
  releases: 'https://github.com/'    # for /releases/ paths
  objects-gh: 'https://objects.githubusercontent.com/'
```

Use the alias in the element URL:
```yaml
url: releases:owner/project/releases/download/v%{version}/binary.tar.gz
```

## Checklist

- [ ] `strip-binaries: ""` set (non-ELF content won't strip cleanly)
- [ ] `ref:` is a pinned SHA256 hash (for tarballs) or commit SHA (for git sources)
- [ ] URL alias added to `include/aliases.yml` if domain is new
- [ ] Element added to `elements/bluefin/deps.bst`
- [ ] `just bst show bluefin/<name>.bst` passes
- [ ] `just bst build bluefin/<name>.bst` passes

## Lessons Learned

> Add entries here when you discover a new pattern or fix a recurring mistake.
> Format: `### <pattern name> (YYYY-MM-DD)`
