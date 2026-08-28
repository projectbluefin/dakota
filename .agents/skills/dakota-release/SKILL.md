---
name: dakota-release
description: Stable promotion, image signing, digest locking, rollback, and release automation for Dakota.
---

# Dakota release and promotion

Release changes cross a security boundary. Stop for human approval before
changing signing identities, token permissions, provenance, or promotion gates.

## Current invariants

- `testing` is built and published before promotion.
- `main` is a release bookmark, not a development target.
- `next` and `btw` are rolling streams and never promote to `stable`.
- Stable promotion intentionally does not add the testsuite e2e gate. Preserve
  its freshness check, cosign verification, and digest-based copy.
- Promotion operates on immutable digests or the tested source SHA, never on a
  tag re-resolved after verification.

## Safe change process

1. Read `.github/workflows/execute-release.yml`, its reusable callees, and
   `.github/workflows/rollback-stable.yml`.
2. Draw the exact SHA/digest flow from build receipt to target tag.
3. Verify cosign, skopeo, GitHub permissions, and reusable-workflow behavior in
   current official documentation.
4. Preserve least privilege and fail closed on missing evidence.
5. Validate workflow syntax and test non-destructive resolution steps.
6. Require human approval before any live dispatch, tag copy, rollback, or merge.

## Security details

- Anchor `--certificate-identity-regexp` with `^...$` and restrict it to the
  publishing workflow and allowed refs.
- Lock the SHA that was tested. Compare live branch state to that SHA and fail
  if it advanced; never lock a newly resolved head after testing.
- Install privileged runner binaries through a temporary file and `sudo
  install`; do not assume the runner user can write `/usr/local/bin`.
- Treat missing signatures, digest mismatches, stale source state, and partial
  variant sets as hard failures.
- Keep all image variants paired through promotion and rollback.

## References

- [`.github/workflows/execute-release.yml`](../../../.github/workflows/execute-release.yml)
- [`.github/workflows/rollback-stable.yml`](../../../.github/workflows/rollback-stable.yml)
- [`docs/ci.md`](../../../docs/ci.md)
