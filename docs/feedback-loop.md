# Dakota Feedback Loop Architecture

Dakota's primary design goal is a **built-in quality feedback loop** where every
layer of the system — users, contributors, agents, maintainers, and hardware —
produces structured evidence that flows back into the next iteration.

This is not telemetry. Dakota never phones home. Every piece of data is donated
by a human who reviews it first and owns it afterward.

## The Data Donation Principle

A `ujust report` submission is a deliberate, informed data donation. The user
reviews the gist before the issue is filed. The gist belongs to them. They
control what leaves their machine and can delete it afterward. This is not
telemetry. It is a voluntary act of trust.

Automation exists to serve that donation. Without it, a maintainer spends the
first round of triage asking the same questions every time: can you reproduce
it, what kernel are you on, what hardware is this, does it happen on every
boot, what services were running. With automation, the report already contains
kernel version, hardware context, logs, and service state. The maintainer's
time goes to diagnosis and fixes instead of comment-thread archaeology. The
work-per-report ratio drops dramatically.

This creates a design contract with reporters: every automation decision must
answer one question first — does this make the user's data donation more
visible, more valued, and more likely to result in a fix? If the answer is no,
it should not exist.

That is why the pipeline widget shows `report: attached` so the reporter can
see that their gist was received. It shows `confirms:` so they can see community
signal and know they are not alone. It shows `verified: N/3` so closure is tied
to observed fixes, not assumption. It shows `next action:` so the loop always
ends with a concrete command, not guesswork.

The multiplier effect is the point. One `ujust report` gist removes five or
more rounds of back-and-forth. One `ujust confirm` adds new hardware coverage
without opening a duplicate issue. One `ujust verify` closes the issue with
fresh evidence after the fix ships. The automation turns individual data
donations into collective intelligence.

This also defines what agents and automation must not do:

- Never remove or replace the pipeline widget sentinel block
  (`<!-- actionadon-pipeline -->`).
- Never close an issue without checking `verified:` count — three verifies or an
  explicit maintainer decision.
- Treat a high `confirms:` count as priority signal. It means the impact spans
  more hardware.
- Treat `report: attached` as meaning full structured evidence is already
  available. Do not ask the reporter to re-describe what is already in the
  gist.

---

## Principle

> The intelligence of a from-source OS lives not in any single build, but in
> the infrastructure of feedback loops that surround it. Users are the sensor
> network. Contributors are the actuators. The issue tracker is the bus.

---

## The Three Evidence Sources

```
┌─────────────────────────────────────────────────────────────────┐
│                     DAKOTA FEEDBACK LOOP                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐    ┌──────────────┐    ┌───────────────────────┐ │
│  │  USERS   │    │ CONTRIBUTORS │    │     GHOST LAB         │ │
│  │          │    │              │    │                       │ │
│  │ ujust    │    │ just build   │    │ ghost build           │ │
│  │ report   │───▶│ just boot-   │───▶│ zot publish           │ │
│  │ confirm  │    │      test    │    │ exo-dakota bootc      │ │
│  │ verify   │◀───│ just lint    │◀───│      switch           │ │
│  │          │    │              │    │ PASS/FAIL report      │ │
│  └──────────┘    └──────────────┘    └───────────────────────┘ │
│       │                │                       │                │
│       ▼                ▼                       ▼                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              ISSUE TRACKER (the bus)                     │   │
│  │                                                         │   │
│  │  Bug filed → discussed → approved → claimed →           │   │
│  │  PR opened → CI validates → e2e tests pass → merged →   │   │
│  │  nightly ships → community verifies → closed            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Evidence by Role

### Users (running Dakota on real hardware)

| Verb | When | Evidence produced |
|------|------|-------------------|
| `ujust report` | Hit a bug | System state → gist → issue |
| `ujust confirm <issue>` | Same bug, different hardware | Hardware fingerprint → issue comment |
| `ujust verify <issue>` | Fix shipped, testing | Attestation + system context → gist + issue comment |

Users are the ground truth. They have the hardware the lab doesn't. Their
reports tell us what works and what doesn't across the real fleet.

### Contributors (building from source)

| Command | When | Evidence produced |
|---------|------|-------------------|
| `just validate` | Before any PR | Element graph is sound |
| `just build default` | After changes | Image builds successfully |
| `just boot-test` | After build | Desktop boots, GDM starts (exit 0/1) |
| `just lint` | Before PR | bootc container lint passes |
| `just boot-fast` | Deep debugging | Interactive SSH into ephemeral VM |

Contributors can verify fixes on their own machines before merge. For
hardware-specific bugs, contributors with the affected hardware build the
PR branch and test directly.

### CI (automated e2e tests on GitHub Actions)

| Step | What happens | Evidence produced |
|------|-------------|-------------------|
| Build | Full BST build on GHA runner | Build success/failure |
| QEMU boot | Desktop image boots in QEMU | Automated boot verification |
| e2e suite | projectbluefin/testsuite reusable workflow | PASS/FAIL status on PR |

The e2e CI workflow gates merge. It runs automatically on every PR and confirms
the image boots and the desktop works before any code lands on main.

---

## How Evidence Flows Through the Lifecycle

```
Stage              User evidence          Contributor evidence     CI evidence
─────              ──────────────         ────────────────────     ───────────
Bug filed          ujust report gist      —                        —
Discussion         ujust confirm (me too) —                        —
Fix in PR          —                      just validate/build/test CI validate
e2e gate           —                      —                        e2e tests pass
Merged             —                      —                        —
Nightly ships      —                      —                        —
Verification       ujust verify           —                        —
Closed             3x verified-fixed      —                        —
```

Each stage has a structured way to produce evidence. No stage requires blind
trust — there is always a command to run and a result to share.

---

## Design Rules

1. **Every bot comment includes the next command.** When actionadon moves an
   issue forward, it tells the relevant role exactly what to type next.

2. **Evidence is always user-owned.** Gists belong to the user. CI reports
   belong to the repo. Nothing is aggregated into a central database.

3. **The Justfile is the single source of truth.** Every verification step is a
   `just` or `ujust` command. No loose shell. No "run this incantation."

4. **Three tiers of verification confidence:**

   | Tier | Who | How | Confidence |
   |------|-----|-----|-----------|
   | 1 | User | Reboot into nightly + `ujust verify` | Good |
   | 2 | Contributor | `just build` + `just boot-fast` | Better |
   | 3 | CI | e2e suite in QEMU on GHA | Best |

   Most issues need Tier 1. Hardware bugs need Tier 2 or 3.

5. **CI supplements, never replaces, community feedback.** Automated tests run
   on a standard QEMU image. Users have hundreds of different hardware
   combinations. Both signals matter.

6. **No telemetry. No metrics. No phone-home.** Dakota's feedback loop is
   human-initiated, human-reviewed, and human-owned. The user decides what
   to share, when to share it, and can delete it anytime.

---

## What This Enables

- **Upstream bugs get closed with confidence.** When kernel 6.18.5 ships and 3
  users with affected hardware run `ujust verify` and attest "fixed," the
  maintainer closes with evidence, not hope.

- **Contributors can verify on affected hardware before merge.** A Framework
  laptop owner can build the PR branch, boot it, confirm the logout bug is
  fixed, and post structured evidence — all from their couch.

- **CI catches what users can't.** Build regressions, boot failures, and
  service crashes are caught by the e2e suite before they ever reach
  users.

- **Agents produce the same evidence as humans.** An agent claiming an issue
  runs the same `just validate → build → boot-test → lint` pipeline. The
  evidence is identical in structure to what a human contributor produces.

---

## Actionadon and the Pipeline Widget

Actionadon makes the feedback loop visible inside the issue itself. The widget
is a compact status view of where the issue is, what evidence is attached, and
what should happen next.

```text
<!-- actionadon-pipeline -->
DAKOTA  ·  issue pipeline
─────────────────────────────────────────────────
  ✓  filed      report received
  ✓  approved   cleared for the build queue
  ▶  queued     open for contributors
  ·  claimed    —
  ·  done       —
─────────────────────────────────────────────────
  report:       attached    ·  confirms: 2
  area:         hardware    ·  priority: high
  verified:     0/3         ·  next action: comment /claim to take this
```

The `<!-- actionadon-pipeline -->` sentinel block is the anchor Actionadon uses
to update the widget in place. It must not be removed, renamed, or replaced.
Without it, the issue loses its stable pipeline view and the reporter loses the
most visible proof that their donation was received and acted on.

Each metadata row maps directly to the feedback loop:

- `report:` answers whether data was donated.
- `confirms:` shows how many other users hit the same problem.
- `area:` and `priority:` show where the issue lands in the build and how urgent
  it is.
- `verified:` shows whether the fix is proven on real systems.
- `next action:` is the MOTD line. It should always be a concrete `ujust`
  command or slash command.

---

## Related

- [AGENTS.md](../AGENTS.md) — Full contributor workflow and PR checklist
- [Justfile](../Justfile) — All commands (`just --list`)
- Issues: #535 (verify epic), #536 (report friction), #537 (verify-steps), #538 (probes)
