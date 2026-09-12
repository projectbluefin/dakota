---
name: dakota-release
description: Stable promotion, image signing, digest locking, rollback, and release automation for Dakota.
metadata:
  context7-sources:
    - /sigstore/cosign
    - /bootc-dev/bootc
---

# Dakota Release and Promotion

Release workflows cross a cryptographic and security boundary. Stop for human approval before changing signing identities, token permissions, provenance, or promotion gates.

## When to Use

- Modifying `.github/workflows/execute-release.yml` or `rollback-stable.yml`
- Auditing or updating cosign keyless OIDC signatures or SLSA build provenance attestations
- Managing image digest pinning, release receipts, or immutable tag promotion
- Managing the Mon/Wed/Fri stable promotion schedule or rollback procedures

## When NOT to Use

- Routine CI build or validation workflow updates → load `dakota-ci`
- Local container image builds or testing → load `dakota-image`
- PR review workflows → load `dakota-review`

## Core Process

1. **Trace Digest Flow**: Map the exact SHA/digest path from build receipt to the target publication tag.
2. **Verify Cryptographic Policy**: Confirm cosign certificate identity and issuer rules match repository policy.
3. **Lock Tested SHA**: Always pin and verify the tested source commit SHA; fail closed if upstream advanced during testing.
4. **Verify Variant Coverage**: Inspect the actual promotion and rollback workflows independently. `rollback-stable.yml` currently rolls back only `dakota` and `dakota-nvidia`, plus optional default-image multiarch tags. It does not roll back `gaming` or `nvidia-gaming`; recovery of those variants needs a separately reviewed plan, not an assumption of four-variant parity.
5. **Human Gate**: Stop and obtain human confirmation before executing any production promotion, signing change, or tag rollback.

## Invariants

- **Bookmark Invariant**: `main` is a stable-release bookmark, not a branch for contributor PRs.
- **Rolling Streams**: `next` and `btw` are rolling development streams; they never promote to `:stable`.
- **Promotion Gates**: Stable promotion intentionally avoids the testsuite e2e gate. It enforces freshness locking, cosign verification, and digest-based copy.
- **Cryptographic Anchoring**: Anchor `--certificate-identity-regexp` with `^...$` and restrict it strictly to the authorized publishing workflow and branch.
- **Digest-Based Promotion**: Promotion operates on immutable digests (`@sha256:...`) or tested source SHAs, never by re-resolving a mutable tag name.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Adding an e2e test gate to promotion makes stable safer." | Promotion occurs hours after build. Re-running e2e adds flakiness and delays security hotfixes. CI owns test gates during build. |
| "A regex without `^` and `$` is good enough for cosign identity." | Unanchored regular expressions allow malicious forks or subpaths to forge signatures. Always anchor with `^` and `$`. |
| "The rollback workflow covers every published variant." | Its current coverage is the default/NVIDIA pair, not the gaming variants. Verify each affected tag before claiming recovery. |

## Red Flags

- Pull requests targeting `main` instead of `testing`
- Adding testsuite e2e gates into `execute-release.yml`
- Re-resolving mutable tags instead of copying by immutable digest
- Unanchored `--certificate-identity-regexp` in cosign verification commands
- Promoting a new release without human approval

## Verification

- [ ] All third-party release actions are pinned to 40-character commit SHAs
- [ ] Certificate identity regex is anchored with `^` and `$`
- [ ] Digest copy commands use skopeo/cosign without intermediate re-tagging
- [ ] Every affected variant is accounted for; the default/NVIDIA rollback is not reported as recovery of gaming variants
- [ ] Human approval obtained before any release execution

## References

- [`.github/workflows/execute-release.yml`](../../../.github/workflows/execute-release.yml)
- [`.github/workflows/rollback-stable.yml`](../../../.github/workflows/rollback-stable.yml)
- [`docs/ci.md`](../../../docs/ci.md)
- [`SECURITY.md`](../../../SECURITY.md)
