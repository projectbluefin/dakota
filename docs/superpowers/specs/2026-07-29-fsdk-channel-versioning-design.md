# FSDK Channel Versioning Design

**Date:** 2026-07-29

## Goal

Align Dakota's published image tags and OCI metadata with the
`projectbluefin/fsdk-containers` convention: freedesktop-sdk is the version
axis, tags are version-first, and image metadata records the exact FSDK
release and junction ref. Remove the legacy rolling tag completely while preserving simple
channel pulls and the existing daily build/promotion model.

Build logic, package selection, and image contents are out of scope.

## Tag contract

The pinned `elements/freedesktop-sdk.bst` ref is the single source of truth.
The pipeline derives:

- `FSDK_VERSION`, such as `25.08.14` or a prerelease value
- `FSDK_MINOR`, such as `25.08`

Each image variant publishes:

- Immutable point-release tag: `25.08.14`
- Minor-line tag: `25.08`
- Versioned channel tags: `25.08-testing`, `25.08-stable`,
  `25.08-next`, and `25.08-btw`
- Moving channel aliases: `testing`, `stable`, `next`, and `btw`

The point-release and minor-line tags follow the reference repository's
version-first ordering. Versioned channel tags add the channel suffix so the
same FSDK release can be identified in each stream. `btw` is an alias of the
`next` stream and must receive the same content. No tracked file may contain
the legacy rolling tag.

SHA tags remain immutable provenance tags used to connect a build to its
source commit. They are not channel tags and are not replaced by the FSDK
version tags.

## OCI metadata

OCI labels are generated at export time:

- `org.opencontainers.image.created` from the build timestamp
- `org.opencontainers.image.revision` from the source commit
- `org.opencontainers.image.version` from `FSDK_VERSION`
- Existing Dakota title, description, source, URL, vendor, and license labels
- `io.projectbluefin.fsdk.version` from `FSDK_VERSION`
- `io.projectbluefin.fsdk.ref` from the exact junction ref

OCI `org.opencontainers.image.ref.name` annotations and local lint helper references use `stable`, `testing`, or
`next` as appropriate. They never use the legacy rolling tag.

## Workflow behavior

The existing BuildStream build remains unchanged. The publishing workflow:

1. Resolves the build SHA and source branch.
2. Exports and validates the image with FSDK-derived metadata.
3. Pushes the immutable SHA tag.
4. For direct `testing` builds, updates `FSDK_MINOR-testing` and `testing`.
5. For direct `next` builds, updates `FSDK_MINOR-next`, `FSDK_MINOR-btw`,
   `next`, and `btw`.

Stable promotion continues to run automatically after a successful testing
publish. It verifies the exact tested SHA, then copies that image to
`FSDK_MINOR-stable` and `stable`; it does not promote `next` or `btw`.
Existing signing, boot-check, digest freshness, and main-bookmark behavior
remain in place.

Daily publishing remains enabled for both streams: `testing` uses the existing
daily BuildStream schedule and `next` uses the existing daily dispatcher.
Manual dispatch remains available for recovery, not as the only way to update
a channel.

## Documentation and compatibility

All tracked documentation, Containerfiles, compose/install examples, workflow
comments, and verification commands are updated to use the moving channel
aliases or explicit FSDK-versioned tags. Existing consumers using
`stable`, `testing`, `next`, or `btw` continue to work. Consumers using the
legacy rolling tag must switch to an explicit channel; no compatibility alias
is kept because removing that tag is a hard requirement.

## Validation

The implementation will:

- Validate tag derivation for release and prerelease FSDK refs.
- Run the repository's existing targeted validation for Justfile/workflow
  consistency.
- Search all tracked files and fail if the legacy rolling tag remains.
- Avoid full image builds as a prerequisite; CI performs full-image
  verification.

## Repository divergence from fsdk-containers

`fsdk-containers` currently publishes a rolling tag, minor tags, and immutable
point-release tags. Dakota cannot copy the rolling tag because it is explicitly
prohibited and Dakota has separate stable, testing, and next streams. Dakota
therefore keeps the reference's version-first FSDK
axis and metadata labels, replacing the rolling tag with explicit channel
aliases and versioned channel tags. Dakota's existing SHA-pinned promotion
and boot-check pipeline is retained because it is specific to bootc image
release safety and has no equivalent in the distroless reference pipeline.
