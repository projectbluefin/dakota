# Security Policy

## Supported versions

The currently promoted `ghcr.io/projectbluefin/dakota:stable` image is the supported production release.

`testing`, `next`, and SHA-pinned images are useful for development, promotion, recovery, and verification, but support expectations follow the current published stream state rather than every historical SHA tag.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for a security vulnerability.

Report it privately through one of these channels:

- GitHub Security Advisories for `projectbluefin/dakota`
- Email: **bluefin@projectbluefin.io**

## Disclosure policy

We follow coordinated disclosure:

1. You report the issue privately.
2. We acknowledge receipt within 5 business days.
3. We investigate, coordinate fixes, and keep you informed.
4. We aim to ship a fix within 30 days of confirmation.
5. If upstream coordination is required, the window may extend to 90 days.
6. We disclose publicly after a fix is available or when the agreed disclosure deadline is reached.

We credit reporters in release notes unless you ask to remain anonymous.

## Supply-chain trust

Dakota publishes signed OCI images plus attestations and an attached SBOM.

Use these canonical sources for current verification details:

- [`docs/release.md`](docs/release.md) — trust, promotion, rollback, and SBOM contract
- `just verify <image-ref>` in the [`Justfile`](Justfile) — local trust verification entry point
- `.github/workflows/publish.yml` — publish, sign, attest, attach SBOM
- `.github/workflows/execute-release.yml` — promotion trust checks
- `.github/workflows/rollback-stable.yml` — verified rollback path
