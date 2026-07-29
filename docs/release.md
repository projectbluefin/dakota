# Dakota release and trust model

Dakota publishes signed OCI images and promotes `:stable` from previously published development builds.

This page describes the durable trust contract. For exact triggers, job structure, and flags, read the owning workflow or Just recipe.

## Stream model

| Stream | Branch owner | Tag behavior |
|---|---|---|
| Development | `testing` | publishes immutable `:<sha>` images and advances `:testing` |
| Stable | release automation | promotes a verified published build to `:stable` and updates `main` as the release bookmark |
| Rolling | `next` | publishes `:next` / `:btw` |

`main` is not the development trunk. It is the stable-release bookmark moved by promotion automation.

## Publish contract

The release pipeline is built around immutable published artifacts:

1. the build pipeline produces OCI artifacts from BuildStream
2. publish pushes immutable `:<sha>` images
3. publish signs and attests those images
4. publish attaches a BST-native SBOM as an OCI referrer
5. only after boot validation and trust checks does automation advance the floating stream tags

Authoritative sources:
- [`.github/workflows/build.yml`](../.github/workflows/build.yml)
- [`.github/workflows/publish.yml`](../.github/workflows/publish.yml)

## What `:stable` means

`:stable` is **not** built independently.

It is a promotion of a previously published, SHA-pinned image that already passed the publish pipeline's checks. Promotion verifies trust on that published artifact before moving the stable tag.

Authoritative source:
- [`.github/workflows/execute-release.yml`](../.github/workflows/execute-release.yml)

## Signing, attestations, and SBOMs

Dakota's supply-chain contract includes:

- **keyless signing** for published OCI images
- **build attestations** for the published image
- **a BST-native SPDX SBOM** attached as an OCI referrer and used by release automation

Current verification entry points:
- `just verify <image-ref>` in the [`Justfile`](../Justfile)
- the signing and SBOM steps in [`.github/workflows/publish.yml`](../.github/workflows/publish.yml)

## Rollback contract

Rollback is a **verified tag move**, not a rebuild-from-memory exercise.

The rollback workflow resolves a previously published SHA-tagged image, verifies its signatures, and then moves the stable tags back to that exact published artifact.

Authoritative source:
- [`.github/workflows/rollback-stable.yml`](../.github/workflows/rollback-stable.yml)

## Source of truth map

| Topic | Canonical file |
|---|---|
| Build → publish handoff | [`.github/workflows/build.yml`](../.github/workflows/build.yml) + [`.github/workflows/publish.yml`](../.github/workflows/publish.yml) |
| Stable promotion | [`.github/workflows/execute-release.yml`](../.github/workflows/execute-release.yml) |
| Rollback | [`.github/workflows/rollback-stable.yml`](../.github/workflows/rollback-stable.yml) |
| Local trust verification | [`Justfile`](../Justfile) (`just verify`, `just sbom`) |

When release behavior matters, treat these files as authoritative and this page as the orientation layer.
