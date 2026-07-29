# Documentation Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Dakota's duplicated documentation routers and oversized flat skill manuals with one canonical, validated documentation contract.

**Architecture:** Root entry documents provide orientation and hard rules. Stable conceptual references live directly under `docs/`. Task-specific agent guidance lives in one lazy-loaded router, `docs/skills/index.md`, with one `SKILL.md` module per topic. A repository-local checker, tests, `just docs-check`, and advisory hygiene workflow enforce the structure without changing image or release behavior.

**Tech Stack:** Markdown, Python 3 standard library, `unittest`, Just, GitHub Actions.

## Global Constraints

- Complete the flat-file-to-directory `SKILL.md` migration; do not add compatibility wrappers.
- Do not modify issue templates, product code, or unrelated dirty worktree files.
- Do not change build, publish, release, or other CI behavior.
- Treat `Justfile`, workflows, scripts, and BuildStream elements as executable sources of truth.
- Keep every implementation step reproducible through repository commands.

---

### Task 1: Establish the migration file map and documentation-check tests

**Files:**
- Create: `scripts/test_check_docs.py`
- Create: `scripts/check_docs.py`
- Modify: `Justfile`

**Interfaces:**
- Produces `python3 scripts/check_docs.py` as the documentation validation command.
- Produces `just docs-check` as the human-facing wrapper.
- Produces `python3 -m unittest scripts/test_check_docs.py` as the focused test command.

- [ ] **Step 1: Write tests for broken links, legacy routers, and malformed skill modules**

Add temporary-directory tests that create Markdown fixtures and assert the checker rejects:

```python
def test_rejects_broken_relative_link(self):
    write("README.md", "[missing](docs/missing.md)\n")
    self.assertIn("broken relative markdown link", run_check())

def test_rejects_legacy_router_reference(self):
    write("README.md", "See docs/skills/README.md\n")
    self.assertIn("legacy router path", run_check())

def test_rejects_skill_without_frontmatter(self):
    write("docs/skills/example/SKILL.md", "# Example\n")
    self.assertIn("frontmatter", run_check())
```

- [ ] **Step 2: Run the focused tests and verify they fail**

Run:

```bash
python3 -m unittest scripts/test_check_docs.py
```

Expected: the test module or required checker behavior is absent, so the tests fail.

- [ ] **Step 3: Implement the checker with standard-library-only logic**

Implement `scripts/check_docs.py` to:

- enumerate tracked Markdown files with Git;
- ignore fenced code blocks while scanning prose;
- resolve and validate relative Markdown links;
- enforce at most one H1 and sequential heading levels;
- enforce the canonical `docs/skills/<topic>/SKILL.md` layout and size budgets;
- reject `docs/skills/README.md`, `docs/skills/INDEX.md`, and
  `.github/copilot-instructions.md` references;
- reject stale planning/history artifact names and client-specific instruction strings.

- [ ] **Step 4: Add the Just recipe**

Add a `docs-check` recipe in `Justfile`:

```make
docs-check:
    python3 scripts/check_docs.py
```

- [ ] **Step 5: Run the focused tests and checker**

Run:

```bash
python3 -m unittest scripts/test_check_docs.py
just docs-check
```

Expected: the unit tests pass; the repository check may report migration failures until Tasks 2–4 complete.

- [ ] **Step 6: Commit the validation foundation**

```bash
git add scripts/check_docs.py scripts/test_check_docs.py Justfile
git commit -m "test(docs): add documentation contract checks"
```

### Task 2: Consolidate canonical entry points and reference pages

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`
- Modify: `CONTRIBUTING.md`
- Modify: `SECURITY.md`
- Delete: `.github/copilot-instructions.md`
- Delete: `docs/SKILL.md`
- Delete: `docs/build.md`
- Delete: `docs/ci.md`
- Delete: `docs/oci-assembly.md`
- Delete: `docs/patches.md`
- Delete: `docs/pr-checklist.md`
- Delete: `docs/workflow.md`
- Create: `docs/architecture.md`
- Create: `docs/qa.md`
- Create: `docs/release.md`

**Interfaces:**
- `AGENTS.md` must route agents to `README.md`, `CONTRIBUTING.md`, and `docs/skills/index.md`.
- `docs/architecture.md`, `docs/qa.md`, and `docs/release.md` must link to current executable sources rather than duplicate workflow details.

- [ ] **Step 1: Replace duplicated entry-point instructions**

Rewrite `AGENTS.md` so it contains the Dakota mental model, read order, hard repository boundaries, stable command entry points, human decision gates, and links to the skill router. Keep commands such as `just validate`, `just build`, `just export`, `just lint`, `just boot-test`, and `just docs-check` as stable entry points; direct readers to `just --list` for the complete recipe list.

- [ ] **Step 2: Move durable conceptual content into reference pages**

Create:

```text
docs/architecture.md  # BuildStream, composefs, layer, assembly, and common-layer boundaries
docs/qa.md            # evidence and validation expectations
docs/release.md       # stable-tag trust, signing, attestations, promotion, rollback, and SBOM contract
```

Each page must identify the authoritative workflow, script, Just recipe, or element path for mutable details.

- [ ] **Step 3: Remove superseded duplicate documents**

Delete the old router and overlapping reference pages only after all links have been updated. Do not delete `docs/feedback-loop.md`; preserve it as the product feedback-loop reference.

- [ ] **Step 4: Update contributor and security navigation**

Make `CONTRIBUTING.md` describe the human branch/check/PR workflow and link to the new reference pages. Make `SECURITY.md` retain security reporting guidance without agent-client-specific instructions.

- [ ] **Step 5: Run link and structure checks**

Run:

```bash
python3 scripts/check_docs.py
```

Expected: failures are limited to remaining flat skill paths and their links.

- [ ] **Step 6: Commit canonical references**

```bash
git add AGENTS.md README.md CONTRIBUTING.md SECURITY.md docs
git rm .github/copilot-instructions.md docs/SKILL.md docs/build.md docs/ci.md docs/oci-assembly.md docs/patches.md docs/pr-checklist.md docs/workflow.md
git commit -m "docs: establish canonical repository references"
```

### Task 3: Migrate and split agent skills

**Files:**
- Create: `docs/skills/index.md`
- Create: `docs/skills/*/SKILL.md` for every retained topic
- Delete: `docs/skills/README.md`
- Delete: `docs/skills/INDEX.md`
- Delete: all flat `docs/skills/*.md` skill files

**Interfaces:**
- `docs/skills/index.md` is the only router and links directly to each module.
- Every module has frontmatter with `name` and `description`, exactly one H1, and one focused responsibility.
- CI guidance is exposed through `ci-triage`, `ci-tooling`, `e2e-ci`, `release-promotion`, `merge-queue`, and `aarch64` modules.

- [ ] **Step 1: Create the canonical router**

Write `docs/skills/index.md` with sections for orientation, build/packaging, CI/release, and review/maintenance. Each row must link to `topic/SKILL.md`, not to a flat compatibility path.

- [ ] **Step 2: Move each retained skill into its module directory**

Use the refactor branch's focused contents as the starting point, preserving the current branch's relevant updates where they overlap. Ensure these modules exist:

```text
not-bluefin, installer, vm-stack, bluefin-cli,
add-package, remove-package, update-refs, buildstream, debugging,
oci-layers, bst-overrides, patch-junctions,
packaging-go, packaging-rust, packaging-zig, packaging-binaries,
packaging-gnome-extensions, local-ota, aarch64,
ci-triage, ci-tooling, e2e-ci, release-promotion, merge-queue,
actionadon, pr-review, skill-authoring, ujust-recipes
```

- [ ] **Step 3: Remove old routers and flat files**

Delete `docs/skills/README.md`, `docs/skills/INDEX.md`, and each old `docs/skills/<topic>.md` only after all tracked links point to the new module path.

- [ ] **Step 4: Update all tracked links**

Search for old paths:

```bash
rg -n 'docs/(SKILL|workflow|build|ci|patches|oci-assembly|pr-checklist)\.md|docs/skills/(README|INDEX)\.md|docs/skills/[^/]+\.md' --glob '*.md' --glob '*.yml' --glob '*.yaml'
```

Replace every result with the canonical reference or `docs/skills/<topic>/SKILL.md` destination.

- [ ] **Step 5: Run the skill tests and checker**

Run:

```bash
python3 -m unittest scripts/test_check_docs.py
just docs-check
```

Expected: both commands pass with no legacy-path or skill-layout errors.

- [ ] **Step 6: Commit the skill migration**

```bash
git add docs/skills
git commit -m "docs(skills): migrate to focused skill modules"
```

### Task 4: Add advisory documentation hygiene CI

**Files:**
- Create: `.github/workflows/docs-hygiene.yml`
- Modify: `scripts/check_docs.py`
- Modify: `scripts/test_check_docs.py`

**Interfaces:**
- The workflow runs only documentation checks and does not build, publish, promote, or mutate releases.
- The workflow invokes `python3 scripts/check_docs.py` from the repository checkout.

- [ ] **Step 1: Add workflow coverage**

Create a workflow triggered by pull requests and pushes that touch Markdown, documentation scripts, `Justfile`, or the workflow itself. Use the repository's existing action pinning conventions and run the focused unit tests followed by `just docs-check`.

- [ ] **Step 2: Add tests for CI-relevant hygiene rules**

Cover stale planning/history headings, banned client-specific strings, oversize skill documents, and invalid relative links outside fenced code blocks.

- [ ] **Step 3: Run the complete documentation validation**

Run:

```bash
python3 -m unittest scripts/test_check_docs.py
just docs-check
```

Expected: PASS with no output other than successful checks.

- [ ] **Step 4: Commit documentation hygiene automation**

```bash
git add .github/workflows/docs-hygiene.yml scripts/check_docs.py scripts/test_check_docs.py
git commit -m "ci(docs): enforce documentation hygiene"
```

### Task 5: Verify footprint, links, and protected worktree state

**Files:**
- Modify: only files already listed in Tasks 1–4 if validation exposes a direct documentation defect.

- [ ] **Step 1: Run the focused validation suite**

```bash
python3 -m unittest scripts/test_check_docs.py
just docs-check
git diff --check
```

- [ ] **Step 2: Compare the final tracked Markdown footprint**

Run:

```bash
for ref in HEAD docs/agent-documentation-overhaul; do
  files=$(git ls-tree -r --name-only "$ref" -- '*.md' | wc -l)
  lines=$(git ls-tree -r --name-only "$ref" -- '*.md' | while read -r f; do git show "$ref:$f"; done | wc -l)
  bytes=$(git ls-tree -r --name-only "$ref" -- '*.md' | while read -r f; do git show "$ref:$f"; done | wc -c)
  printf '%s files=%s lines=%s bytes=%s\n' "$ref" "$files" "$lines" "$bytes"
done
```

Also report the simpler per-tree counts from `git ls-tree` and `git show` so the final handoff includes files, lines, and bytes for the baseline and resulting tree.

- [ ] **Step 3: Confirm unrelated changes remain untouched**

Run:

```bash
git status --short
git diff --stat -- .github/ISSUE_TEMPLATE .github/copilot-instructions.md AGENTS.md README.md docs/skills/e2e-ci.md docs/skills/pr-review.md .github/workflows/label-enforcement.yml files/agent-policies
```

Review overlapping files manually; preserve user changes where they are unrelated, and stop for clarification if a user edit directly conflicts with the documentation contract.

- [ ] **Step 4: Commit any validation-only documentation corrections**

```bash
git add $(git diff --name-only -- docs .github/workflows/docs-hygiene.yml scripts/check_docs.py scripts/test_check_docs.py Justfile)
git commit -m "docs: finalize documentation contract validation"
```
