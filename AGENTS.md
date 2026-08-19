# Dakota agent guide

Dakota is Project Bluefin's bootc OCI desktop image, assembled from source with
BuildStream 2. This is not the RPM-based Bluefin build: do not use `dnf`,
`rpm-ostree`, COPRs, Containerfile package overlays, or post-build package
installation. Make image changes through BST elements.

Project skills live in `.agents/skills/` and are discovered by Pi and GitHub
Copilot. Load only the skill matching the task; do not read every skill.

## Non-negotiable safety

- **Never write to any `ublue-os/*` repository.** No issues, comments, PRs,
  forks, dispatches, webhooks, or automated reports. Ask the human to report
  upstream manually.
- Do not post GitHub comments, reviews, or edit PR bodies unless explicitly
  asked. When asked, post at most one combined comment and do not restate UI
  status.
- Never expose secrets or weaken signing, provenance, or supply-chain checks.
- Never push directly to `main` or `testing`. Work on a feature branch and leave
  final approval and merge to a human.

## Sources of truth

1. Read the file being changed and its callers before editing it.
2. Use the relevant `.agents/skills/` package for task-specific guidance.
3. Treat workflows, elements, the Justfile, and tests as current truth; prose
   that disagrees with executable configuration is stale.
4. Verify external syntax and behavior in current official documentation before
   changing BuildStream, bootc, GitHub Actions, cosign, or skopeo usage.
5. Preserve useful knowledge by correcting existing guidance. Do not append
   dated session notes, changelogs, or mandatory “lessons learned” entries.

## Development workflow

- Branch from `upstream/testing` unless the task explicitly targets `next`.
- Push PR branches to `upstream`, never a personal fork.
- Run `just --list` before inventing maintenance commands. Add a Justfile recipe
  when a repeatable repository operation has no existing entry.
- Run `just validate` for BST or image changes. Use the narrowest additional
  check that exercises the change; CI performs full image verification.
- Before claiming completion, inspect the diff and report the checks actually
  run. Do not claim CI is green while runs are pending or failing.

## Architecture invariants

- BuildStream elements are the only package/build mechanism.
- OCI filesystem-producing layers use `kind: compose`; `kind: stack` only
  aggregates dependencies and produces no filesystem output.
- Cargo source blocks are generated with
  `python3 files/scripts/generate_cargo_sources.py <Cargo.lock>`.
- Patch junctions through `patch_queue`; do not edit staged junction contents.
- Keep install commands deterministic: no network access, timestamps, hostname,
  user identity, or mutable branch refs.
- Internal `projectbluefin/actions@v1` references are managed tags. Pin other
  third-party actions to full commit SHAs with a version comment.
- `main` is the stable-release bookmark. Do not add an e2e gate to stable
  promotion; preserve freshness locking, cosign verification, and digest checks.

## Human decision gates

Stop and ask before:

- architecture or new-subsystem decisions;
- user-visible behavior changes without agreed acceptance criteria;
- authentication, signing, secrets, or third-party supply-chain changes;
- cross-repository breaking changes;
- final PR approval or merge.

## GitHub workflow

- Work from scoped, queued issues; respect `hold`, `do-not-merge`, and existing
  ownership.
- If an issue says `report: attached`, read the donated report before asking for
  more logs. Hardware verification is not interchangeable with CI.
- Follow `docs/workflow.md` and `docs/pr-checklist.md` when preparing or
  reviewing a PR.
- Commits use `<type>(<scope>): <description>` and the repo-local
  `Assisted-by:` trailer, never `Co-authored-by:`.
