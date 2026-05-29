# Hardware Testlab — Active Dev Loop

Load when running the live dakota validation loop: build → publish → bootc upgrade on physical hardware.

## When NOT to Use

- Local-only VM testing → `local-ota.md`
- One-time hardware provisioning → `testlab-setup.md`
- CI pipeline questions → `ci.md`

## Hardware Loop Pattern

```bash
Build host (your machine):
  1. just build               # build OCI image
  2. just export              # export OCI image to podman
  3. sudo podman push <build-host-ip>:5000/dakota:latest  # push to local zot

Test machine (physical hardware running dakota):
  4. sudo bootc upgrade       # pull from build host's registry
  5. sudo systemctl reboot
  6. Verify: bootc status + systemctl --failed + GDM active
```

## Lab Rules

- **Build host alone is not a lab result.** Full loop = build → push → `bootc switch` on test hardware → reboot → verify.
- **Use exact digest for bootc switch** — tag-based switch silently skips if the tag already matches the booted digest (see Lessons Learned).
- **BUILD FAILURES = FILE AN ISSUE.** Any element that fails during a lab build must be filed as a GitHub issue — even if it appears pre-existing.

## PR Review — lab:fail Reset Policy

When reviewing a PR with the `lab:fail` label, trigger a new lab run AND update the existing status comment. Never post a new comment — update in place.

**Why:** Each retry cycle appending a new comment spams the PR thread (see PR #561 with 8 separate failure comments). One comment, kept current, is the policy.

**How to find the existing status comment:**
```bash
PR=561
COMMENT_ID=$(gh api repos/projectbluefin/dakota/issues/${PR}/comments \
  --jq '.[] | select(.body | contains("<!-- lab-status -->")) | .id' | tail -1)
```

**How to update it (not post new):**
```bash
gh api --method PATCH \
  repos/projectbluefin/dakota/issues/comments/${COMMENT_ID} \
  --field body="❌ **lab:fail** — BST build failed (Argo workflow \`dakota-pr-${PR}-xxxxx\`). <!-- lab-status -->
\`\`\`
<error snippet>
\`\`\`
_Reset triggered $(date -u +%Y-%m-%dT%H:%M:%SZ) — see workflow for details._"
```

**If no `<!-- lab-status -->` comment exists yet**, post one with the sentinel so future resets can find it:
```bash
gh pr comment ${PR} --repo projectbluefin/dakota \
  --body "❌ **lab:fail** — <details> <!-- lab-status -->"
```

**Workflow:**
1. Spot `lab:fail` label during PR review
2. Find or create the single `<!-- lab-status -->` comment
3. Trigger a new lab run (Argo workflow or `just boot-test`)
4. When the run completes, PATCH the comment with the new result
5. On pass: update comment to `✅ lab:pass`, remove `lab:fail` label, add `lgtm` if code review is also clean

## Commands

| Command | Where | What |
|---------|-------|------|
| `just build` | Build host | Build OCI image |
| `just export` | Build host | Export OCI image to podman |
| `sudo podman push <build-host-ip>:5000/dakota:latest` | Build host | Push image to local zot registry |
| `sudo bootc upgrade` | Test machine | Pull latest from registry |
| `bootc status` | Test machine | Verify booted image ref |
| `systemctl --failed` | Test machine | Check for failed units |
| `journalctl -p err --since boot` | Test machine | Check boot errors |

## Configuring the Test Machine

On the test machine, configure it to pull from your build host's registry:
```bash
sudo tee /etc/containers/registries.conf.d/50-lab-dev.conf <<'EOF'
[[registry]]
location = "<build-host-ip>:5000"
insecure = true
EOF
```

Switch to the local registry:
```bash
sudo bootc switch <build-host-ip>:5000/dakota:latest
```

## Reverting to GHCR

When lab testing is done:
```bash
sudo bootc switch ghcr.io/projectbluefin/dakota:latest
sudo systemctl reboot
```

---

## Lessons Learned

> Patterns observed in the hardware validation loop.
> Read before running or scripting lab builds.

---

## bootc switch same-content trap

`bootc switch <tag>` silently does nothing if the tag resolves to the
already-booted digest. Always force the upgrade with the exact digest:

```bash
DIGEST=$(curl -sI http://<zot-registry>/v2/dakota/manifests/<TAG> \
  -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
  | grep -i docker-content-digest | awk '{print $2}' | tr -d '\r')
sudo bootc switch --transport registry <zot-registry>/dakota@${DIGEST}
```

---

## Assertions must execute — not just check file presence

`test -f /path/to/file` is not a functional test. Any recipe that runs in a
terminal must also be tested via SSH assertions that **execute it** and check
output:

```bash
# ❌ BAD — only confirms the file exists
--assert 'installed:test -f /usr/share/ublue-os/just/default.just'

# ✅ GOOD — confirms the recipe actually runs
--assert 'recipe-runs:echo n | TERM=dumb ujust report 2>&1 | grep -qiE "Collecting"'
```

Do not mark PASS until the recipe has executed on hardware and produced
expected output.

---

## BUILD_SKIP_NVIDIA

Skip the nvidia variant for local builds to cut build time from ~20 min to
~3 min:

```bash
export BUILD_SKIP_NVIDIA=1
just build default
```

CI still builds both variants. Same pattern as `BUILD_SKIP_CHUNKIFY`.

---

## BST failure cache trap

When BST caches a failed build, retrying without clearing the cache will
immediately fail again with `[00:00:00]` elapsed — the dead giveaway.

```bash
# Clear the cached failure and retry
just bst artifact delete bluefin/myelement.bst
just bst build bluefin/myelement.bst
```

---

## Pre-existing failures vs your changes

Before attributing a build failure to your branch, confirm the same element
fails on `upstream/main`:

```bash
git stash
git checkout upstream/main
just bst build bluefin/<failing-element>.bst
git checkout -
git stash pop
```

If it fails on upstream too, file an issue immediately and continue. Do not
block your PR on a pre-existing failure.

---

### just 1.47.1 heredoc tokenizer

just 1.47.1 aggressively tokenizes heredoc content in shebang recipes, rejecting:
- Lines starting with `-`
- `...` (three dots)
- `$(uname -m)` — flags inside `$(...)` past column 25
- `(1/5/15 min)` — `(` followed by digits

**Fix:** Replace heredocs with `printf '%s\n'` per line.

```bash
# BAD — just tokenizes this
cat <<SUMMARY
- Kernel: ${KERNEL_VER}
SUMMARY

# GOOD — just never sees these strings
printf '* Kernel: %s\n' "${KERNEL_VER}"
```

Pre-compute ALL command substitutions with flags into variables before any printf block.

---

### ujust vs just distinction

- `just` = developer build system in repo root `Justfile` (build/test/deploy)
- `ujust` = user-facing commands inside the running image (`files/just-overrides/default.just`)

Never confuse them. Changes to `files/just-overrides/default.just` require a BST element rebuild to land in the image.
