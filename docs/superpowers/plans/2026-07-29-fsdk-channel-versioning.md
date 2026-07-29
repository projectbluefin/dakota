# FSDK Channel Versioning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Dakota's legacy rolling image tag with FSDK-versioned tags and stable/testing/next/btw channel aliases while preserving daily publishing and stable promotion.

**Architecture:** Derive the FSDK release and minor line from the pinned `elements/freedesktop-sdk.bst` ref in the Justfile. The Justfile passes that metadata into OCI export and local tooling; OCI elements retain bootc ref names without the legacy rolling tag. Publish and release workflows promote immutable SHA images into versioned channel tags and their unversioned aliases, with `btw` mirroring `next`.

**Tech Stack:** BuildStream 2, Just, Podman, Skopeo, GitHub Actions, bootc OCI metadata, Bash.

## Global Constraints

- The FSDK junction ref is the only image version source; do not introduce an arbitrary Dakota application version.
- Publish `stable`, `testing`, `next`, and `btw` aliases plus FSDK-versioned channel tags such as `25.08-stable`.
- Retain immutable point-release and minor-line FSDK tags where the existing workflow supports them.
- Remove the legacy rolling tag from every tracked file, including workflows, scripts, OCI labels, Containerfiles, docs, and install examples.
- Keep build logic, package selection, and image contents unchanged.
- Preserve daily `testing` and `next` publishing, automated testing-to-stable promotion, signing, boot-checks, SHA freshness checks, and branch bookmark behavior.
- `btw` must point to the same image content as `next`; it must never enter the stable promotion path.
- External GitHub Actions remain pinned; `projectbluefin/actions@v1` remains the repository's managed-tag exception.
- Update the relevant `docs/skills/` file with any non-obvious tag derivation or promotion rule discovered during implementation.

---

### Task 1: Add FSDK-derived tag and metadata helpers

**Files:**
- Modify: `Justfile:1-30, 180-285`
- Test: `Justfile` command outputs and `just validate`

**Interfaces:**
- Consumes: `elements/freedesktop-sdk.bst` `ref:` value.
- Produces: `fsdk_version`, `fsdk_minor`, and a deterministic `just tags` output consumed by export and workflow scripts.

- [ ] **Step 1: Add FSDK version parsing**

  Parse the pinned junction ref once in the Justfile, stripping the
  `freedesktop-sdk-` prefix and trailing commit decoration. Derive the minor
  line from the first `major.minor` component. Preserve prerelease suffixes,
  matching the reference repository's point and beta tag behavior.

- [ ] **Step 2: Define the complete tag set**

  Change `just tags` to emit, in stable deterministic order:

  ```text
  <fsdk-version>
  <fsdk-minor>
  <fsdk-minor>-testing
  <fsdk-minor>-stable
  <fsdk-minor>-next
  <fsdk-minor>-btw
  testing
  stable
  next
  btw
  ```

  Treat the exact point-release tag as immutable in push logic. For a
  prerelease or a ref with no point component, use the same derived value for
  the immutable FSDK tag and do not invent a separate arbitrary version.

- [ ] **Step 3: Remove the legacy rolling tag from local export helpers**

  Replace the default `image_tag`, export references, build comments, lint
  helper image reference, Containerfile build tag, and bootable-image examples
  with an explicit channel default (`testing` for development tooling) or the
  caller-supplied `BUILD_IMAGE_TAG`.

- [ ] **Step 4: Validate the helper behavior**

  Run:

  ```bash
  cd /var/home/jorge/src/dakota/.worktrees/update-versioning
  just tags
  just check-publish-workflow
  ```

  Confirm output contains the FSDK version and all four channel aliases, and
  contains no legacy rolling tag.

- [ ] **Step 5: Commit**

  ```bash
  git add Justfile
  git commit -m "build(release): derive FSDK channel tags"
  ```

### Task 2: Align OCI labels and bootc origin annotations

**Files:**
- Modify: `elements/oci/bluefin.bst`
- Modify: `elements/oci/bluefin-nvidia.bst`
- Modify: `include/os-release.yml`
- Modify: `.github/workflows/publish.yml` export environment
- Modify: `.github/workflows/build-aarch64.yml` export environment
- Modify: `Containerfile`

**Interfaces:**
- Consumes: Justfile `fsdk_version`, `fsdk_ref`, and explicit image tag variables.
- Produces: OCI images whose version/provenance labels identify the FSDK release and whose bootc origin never points at the legacy rolling tag.

- [ ] **Step 1: Add FSDK labels at export time**

  Extend the Justfile export label arguments with:

  ```text
  org.opencontainers.image.version=<FSDK_VERSION>
  io.projectbluefin.fsdk.version=<FSDK_VERSION>
  io.projectbluefin.fsdk.ref=<exact junction ref>
  ```

  Preserve created, revision, title, description, URL, source, vendor, and
  license metadata already emitted by Dakota.

- [ ] **Step 2: Update OCI ref-name annotations**

  Replace the hard-coded legacy rolling ref name in both OCI elements with an
  explicit channel ref. Keep the repository and variant naming unchanged so
  `bootc upgrade` continues to use the correct default, NVIDIA, and gaming
  origins.

- [ ] **Step 3: Set os-release channel defaults**

  Change `IMAGE_TAG` in `include/os-release.yml` to the development channel
  alias and ensure CI supplies the actual channel or immutable SHA context
  during export. Do not change `IMAGE_NAME`, flavor, version ID, or package
  content.

- [ ] **Step 4: Update lint helper inputs**

  Make `Containerfile` and its comments pull the stable channel instead of the
  removed rolling tag. Keep it as a lint-only helper with no package
  installation or overlay logic.

- [ ] **Step 5: Validate OCI source text**

  Run:

  ```bash
  just bst show --deps all oci/bluefin.bst oci/bluefin-nvidia.bst
  git diff --check
  ```

  Confirm only metadata/ref-name strings changed and no package or layer
  dependency changed.

- [ ] **Step 6: Commit**

  ```bash
  git add Justfile elements/oci/bluefin.bst elements/oci/bluefin-nvidia.bst include/os-release.yml Containerfile
  git commit -m "build(oci): label images with FSDK release"
  ```

### Task 3: Publish versioned testing and next channel tags

**Files:**
- Modify: `.github/workflows/publish.yml`
- Modify: `.github/workflows/build-aarch64.yml`
- Modify: `.github/workflows/nightly-next-build.yml`
- Modify: `.github/workflows/build.yml` only where trigger comments or channel inputs require alignment

**Interfaces:**
- Consumes: build SHA, source branch, FSDK tags emitted by the checked-out Justfile, and existing GHCR credentials.
- Produces: immutable SHA tags, versioned channel tags, and moving `testing`/`next`/`btw` aliases.

- [ ] **Step 1: Resolve FSDK tags in publish setup**

  Add a setup step that invokes the checked-out Justfile's FSDK derivation
  without building the image, then exposes `fsdk_version` and `fsdk_minor`
  outputs for all publish jobs. Keep merge-queue refs SHA-only.

- [ ] **Step 2: Export with FSDK metadata**

  Replace the legacy rolling-tag `OCI_IMAGE_VERSION` with the resolved FSDK version and pass
  the explicit local channel tag used by `just export`. Keep the build SHA in
  the immutable registry tag and preserve all existing signing and SBOM
  inputs.

- [ ] **Step 3: Promote testing images to both versioned and alias tags**

  For direct `testing` builds, copy the SHA source image to the immutable FSDK
  version tag (if absent), the FSDK minor tag, and:

  ```text
  <FSDK_VERSION>
  <FSDK_MINOR>
  <FSDK_MINOR>-testing
  testing
  ```

  Skip an existing exact point-release tag rather than overwriting it.

  Use `--preserve-digests`, retries, credentials, and post-copy visibility
  checks already used by the current promote job. Keep merge-queue builds
  from moving public stream tags.

- [ ] **Step 4: Promote next images to next and btw**

  For direct `next` builds, copy the SHA source image to the immutable FSDK
  version tag (if absent), the FSDK minor tag, and:

  ```text
  <FSDK_VERSION>
  <FSDK_MINOR>
  <FSDK_MINOR>-next
  <FSDK_MINOR>-btw
  next
  btw
  ```

  Skip an existing exact point-release tag rather than overwriting it.

  Ensure all four destinations resolve to the same digest per variant.

- [ ] **Step 5: Update ARM publication**

  Replace the floating `aarch64` comments and local tag assumptions with
  explicit `aarch64-<sha>` provenance plus channel-specific versioned/alias
  tags only when the source event identifies a direct channel build. Preserve
  ARM's non-blocking behavior and decoupled CAS concurrency.

- [ ] **Step 6: Validate workflow syntax and tag wiring**

  Run:

  ```bash
  just check-publish-workflow
  actionlint .github/workflows/publish.yml .github/workflows/build-aarch64.yml .github/workflows/nightly-next-build.yml
  ```

  Confirm workflow expressions reference defined outputs and no publish path
  can move stable from a next build.

- [ ] **Step 7: Commit**

  ```bash
  git add .github/workflows/publish.yml .github/workflows/build-aarch64.yml .github/workflows/nightly-next-build.yml .github/workflows/build.yml
  git commit -m "ci(publish): publish FSDK channel tags"
  ```

### Task 4: Promote and roll back stable with FSDK channel tags

**Files:**
- Modify: `.github/workflows/execute-release.yml`
- Modify: `.github/workflows/rollback-stable.yml`

**Interfaces:**
- Consumes: the exact SHA published by the testing workflow and FSDK minor output from the checked-out source.
- Produces: stable versioned tags and the `stable` alias, with rollback preserving both destinations.

- [ ] **Step 1: Resolve the tested FSDK minor**

  In the release workflow, check out the tested SHA or read the version
  metadata from the published image/source context and expose
  `FSDK_MINOR` to promotion jobs. Keep `workflow_run.head_sha` and
  `promote_sha` as the only source-SHA authorities.

- [ ] **Step 2: Promote stable destinations**

  Extend the reusable release variant matrix so each default, NVIDIA, and
  gaming image copies the tested SHA to:

  ```text
  <FSDK_MINOR>-stable
  stable
  ```

  Keep the stable digest freshness check, cosign identity restriction,
  release gate, main bookmark update, release notes, and multi-arch manifest
  behavior unchanged.

- [ ] **Step 3: Update stable verification and release summaries**

  Verify both the versioned stable tag and `stable` resolve to the promoted
  digest. Update release notes, summaries, and variant tables to name the
  channel aliases/versioned tags without the removed rolling tag.

- [ ] **Step 4: Mirror stable rollback**

  Roll back both the versioned stable tag and `stable` alias for each supported
  variant. Preserve pair invariants, digest verification, cosign checks, and
  optional multi-arch reconstruction.

- [ ] **Step 5: Validate release workflow text**

  Run:

  ```bash
  actionlint .github/workflows/execute-release.yml .github/workflows/rollback-stable.yml
  just check-publish-workflow
  ```

  Confirm no release job promotes `next` or `btw`, and rollback cannot leave
  versioned and alias stable tags pointing at different digests.

- [ ] **Step 6: Commit**

  ```bash
  git add .github/workflows/execute-release.yml .github/workflows/rollback-stable.yml
  git commit -m "ci(release): promote versioned stable tags"
  ```

### Task 5: Remove legacy rolling-tag references from docs and tooling

**Files:**
- Modify: `README.md`
- Modify: `SECURITY.md`
- Modify: `cliff.toml`
- Modify: `.pre-commit-config.yaml`
- Modify: `.github/copilot-instructions.md`
- Modify: `AGENTS.md`
- Modify: `.github/scripts/render_card.py`
- Modify: `files/just-overrides/changelog.just`
- Modify: `docs/skills/aarch64.md`
- Modify: `docs/skills/add-package.md`
- Modify: `docs/skills/bst-overrides.md`
- Modify: `docs/skills/ci.md`
- Modify: `docs/skills/ci-reference.md`
- Modify: `docs/skills/debugging.md`
- Modify: `docs/skills/local-ota.md`
- Modify: `docs/skills/overview.md`
- Modify: `docs/skills/quickstart.md`
- Modify: `docs/skills/release-promotion.md`
- Modify: `docs/skills/update-refs.md`

**Interfaces:**
- Consumes: the final alias/versioned tag contract from Tasks 1–4.
- Produces: documentation, helper commands, policies, and examples that never instruct users or agents to pull the removed tag.

- [ ] **Step 1: Replace pull/install examples**

  Use `stable` for production examples, `testing` for development examples,
  and `next`/`btw` for rolling GNOME examples. Where reproducibility matters,
  show an FSDK minor or point tag.

- [ ] **Step 2: Replace helper image URLs**

  Update external tool bootstrap URLs and container helper images that
  currently contain the legacy rolling tag in a path/tag to a pinned release or a
  repository-supported explicit channel. Do not change unrelated dependencies
  or package selections.

- [ ] **Step 3: Update release documentation**

  Document the FSDK-versioned channel format, daily testing/next cadence,
  stable promotion, `btw` aliasing, `packages: write` permissions, GHCR
  credentials, and branch expectations (`testing` development trunk, `next`
  rolling stream, `main` stable bookmark).

- [ ] **Step 4: Update the relevant skill learning**

  Add a concise lesson to `docs/skills/release-promotion.md` describing that
  channel tags are derived from the FSDK junction and that versioned and
  unversioned channel tags must be moved together.

- [ ] **Step 5: Scan all tracked files**

  Run:

  ```bash
  needle=$(printf '\154\141\164\145\163\164')
  if git grep -n -i "$needle"; then
    echo "legacy rolling-tag references remain" >&2
    exit 1
  fi
  ```

  Resolve every match rather than excluding policy or planning files.

- [ ] **Step 6: Commit**

  ```bash
  git add README.md SECURITY.md cliff.toml .pre-commit-config.yaml AGENTS.md .github/copilot-instructions.md .github/scripts/render_card.py files/just-overrides/changelog.just docs/skills
  git commit -m "docs(release): remove legacy rolling tag references"
  ```

### Task 6: Run targeted validation and record maintainer configuration

**Files:**
- Modify: `docs/skills/ci.md` only if validation uncovers a durable CI-specific rule
- Modify: `docs/skills/release-promotion.md` only if Task 5 did not already capture the learned rule

**Interfaces:**
- Consumes: all implementation changes.
- Produces: verified tag derivation/workflow syntax and a concise maintainer handoff.

- [ ] **Step 1: Run Justfile and graph validation**

  ```bash
  just tags
  just check-publish-workflow
  just bst show --deps all oci/bluefin.bst oci/bluefin-nvidia.bst
  ```

- [ ] **Step 2: Run workflow and repository checks**

  ```bash
  actionlint .github/workflows
  git diff --check
  needle=$(printf '\154\141\164\145\163\164')
  if git grep -n -i "$needle"; then exit 1; fi
  ```

- [ ] **Step 3: Verify scope**

  ```bash
  git diff --stat upstream/main...HEAD
  git diff -- elements patches project.conf
  ```

  Confirm no package, source, layer, or BuildStream build logic changed.

- [ ] **Step 4: Record manual maintainer configuration**

  In the final handoff, state that maintainers must ensure:

  - GHCR publishing uses `packages: write`.
  - Signing/attestation permissions remain `id-token: write` and
    `attestations: write`.
  - `CASD_CLIENT_CERT`, `CASD_CLIENT_KEY`, and `GITHUB_TOKEN` are configured
    as required by existing workflows.
  - `testing` is the default/development branch for scheduled builds.
  - `next` exists and is the rolling nightly branch.
  - `main` remains the protected stable bookmark.

- [ ] **Step 5: Commit validation-only documentation if needed**

  ```bash
  git status --short
  ```

  If the prior tasks already contain all durable learning, make no new commit.
  Otherwise commit only the focused skill update:

  ```bash
  git add docs/skills/ci.md docs/skills/release-promotion.md
  git commit -m "docs(ci): record FSDK channel promotion rules"
  ```

## Final verification

Before handoff, read the final diff and run the exact repository-wide absence
check:

```bash
git diff --check
needle=$(printf '\154\141\164\145\163\164')
git grep -n -i "$needle" && exit 1 || true
just check-publish-workflow
actionlint .github/workflows
```

Report the final tag/label scheme, file-by-file changes, the deliberate
`fsdk-containers` divergence (explicit channels replacing its rolling tag),
and the maintainer configuration requirements listed in Task 6.
