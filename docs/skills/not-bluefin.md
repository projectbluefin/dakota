---
name: not-bluefin
description: Reset the Dakota mental model before doing any package or image work. Use when your plan mentions dnf, RPM, COPR, spec files, or Containerfile package layers, or whenever bluefin habits are leaking into a Dakota task.
metadata:
  context7-sources:
    - /apache/buildstream
---

# Not Bluefin

## Overview

Dakota is a **BuildStream-first** repo.
It is not a Fedora/CentOS overlay repo, not an RPM repo, and not a Containerfile package-install repo.

This skill exists to kill the most expensive wrong turn early.

## When to Use

Use when:
- your draft mentions `dnf`, RPM, COPR, `.spec`, or package repos
- you are about to change image contents
- you see `elements/bluefin/*` and start thinking "Bluefin workflow"
- you are onboarding into Dakota from another Project Bluefin repo

## When NOT to Use

- You already know you are editing the correct `.bst` element
- You are debugging a CI trigger or GitHub workflow issue unrelated to packaging

## Core Process

1. **Translate the request into BST terms before doing anything else.**
2. **Locate the actual Dakota path** (`elements/bluefin/*`, `elements/oci/*`, `Justfile`).
3. **Choose the right next skill**:
   - add/remove package → `add-package.md` / `remove-package.md`
   - BST syntax → `buildstream.md`
   - OCI assembly → `oci-layers.md`
4. **Refuse the wrong mechanism** even if it feels faster.

## Translation Table

| If you are thinking... | In Dakota, do this instead |
|---|---|
| `dnf install <pkg>` | create or edit a `.bst` element |
| enable a COPR / package repo | package it in BST terms |
| edit Containerfile to add packages | edit BST elements or OCI assembly elements |
| RPM package names are the source of truth | verify the actual BuildStream element or upstream source |
| `bluefin/` path means bluefin workflow | treat it as Dakota history, not process |

## Hard Facts

- `elements/bluefin/*` are **Dakota** paths.
- `elements/bluefin/deps.bst` is the package manifest for Dakota's build graph.
- `Containerfile` is for final OCI/image helper flows, **not** package installation.
- BuildStream element kinds such as `manual`, `meson`, `cmake`, `autotools`, `pip`, `stack`, `junction`, and `compose` are the real building blocks here.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "It's probably easier to add one `dnf install`." | That is the wrong repo model and creates factory debt. |
| "The path says bluefin, so it must use bluefin's process." | The name is legacy; the mechanism is Dakota. |
| "Containerfile is right there, I'll patch the image there." | Package/image-content changes belong in BST elements. |
| "I can translate later after I inspect the files." | Translate first, or you'll inspect the wrong files. |

## Red Flags

- Draft plan mentions dnf/RPM/COPR
- Editing `Containerfile` to change package content
- Treating `.spec` files or Fedora naming as the source of truth
- Reaching for bluefin habits because of the `bluefin` directory name

## Verification

- [ ] The task is expressed in BST terms before implementation starts
- [ ] The next skill loaded is package/buildstream/OCI-specific, not an RPM workflow
- [ ] No package or image-content change is routed through `Containerfile`
- [ ] The final plan names the actual Dakota files being changed

## Lessons Learned

### Historical bluefin path names are not workflow cues (2026-06-04)

Dakota still uses `bluefin` in several path names (`elements/bluefin/*`,
`oci/bluefin.bst`), which repeatedly causes agents to drift into dnf/RPM or
Containerfile-overlay assumptions. Treat those names as repo history only.
Actual Dakota image changes still happen in BuildStream elements, dependency
stacks, and OCI assembly elements.
