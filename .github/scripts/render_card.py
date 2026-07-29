#!/usr/bin/env python3
"""
render_card.py — Generate release card PNGs (light + dark) and release notes
markdown from a versions.json produced by sbom_diff.py.

Usage:
    python3 render_card.py \
        --versions versions.json \
        --sha      2294ec1abc1234567890abcd \
        --sha7     2294ec1 \
        --date     2026-05-14 \
        --tag      2026-05-14-2294ec1 \
        --repo     projectbluefin/dakota \
        --output-light release-card-light.png \
        --output-dark  release-card-dark.png \
        --release-notes release-notes.md
"""
import argparse
import json
import os
import sys
import html
import tempfile
import textwrap
from pathlib import Path

# ── HTML card template ────────────────────────────────────────────────────────
# Self-contained: no external resources, no web fonts.
# Dakota accent: #7c3aed (purple), matching OsReleaseCard.module.css .cardDakota.
# Rendered at 840 px wide; Playwright crops to .release-card bounding box.

CARD_HTML = """\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=840">
<style>
*, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}

/* ── Light theme ── */
:root {{
  --bg:        #ffffff;
  --bg-card:   #f9fafb;
  --border:    #e5e7eb;
  --accent:    #7c3aed;
  --text:      #111827;
  --text-muted:#6b7280;
  --chip-bg:   #f3f4f6;
  --chip-label:#6b7280;
  --chip-val:  #111827;
  --changed-bg:#fdf4ff;
  --changed-border:#c084fc;
  --changed-val:#7c3aed;
  --arrow:     #9ca3af;
  --diff-add:  #059669;
  --diff-chg:  #7c3aed;
  --diff-rem:  #dc2626;
  --tag-bg:    #f3f4f6;
}}
/* ── Dark theme ── */
@media (prefers-color-scheme: dark) {{
  :root {{
    --bg:        #0f172a;
    --bg-card:   #1e293b;
    --border:    #334155;
    --accent:    #a78bfa;
    --text:      #f1f5f9;
    --text-muted:#94a3b8;
    --chip-bg:   #334155;
    --chip-label:#94a3b8;
    --chip-val:  #f1f5f9;
    --changed-bg:#2e1065;
    --changed-border:#7c3aed;
    --changed-val:#c084fc;
    --arrow:     #64748b;
    --diff-add:  #34d399;
    --diff-chg:  #a78bfa;
    --diff-rem:  #f87171;
    --tag-bg:    #1e293b;
  }}
}}

body {{
  background: var(--bg);
  padding: 16px;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
               Helvetica, Arial, sans-serif;
}}

/* ── Card shell ── */
.release-card {{
  background:    var(--bg-card);
  border:        1px solid var(--border);
  border-left:   3px solid var(--accent);
  border-radius: 12px;
  padding:       20px 24px 16px;
  max-width:     800px;
}}

/* ── Header ── */
.card-header {{
  display:        flex;
  align-items:    flex-start;
  justify-content:space-between;
  margin-bottom:  14px;
}}
.card-title {{
  font-size:   1.25rem;
  font-weight: 700;
  color:       var(--accent);
  line-height: 1.2;
  margin-bottom: 4px;
}}
.card-meta {{
  display:    flex;
  align-items:center;
  gap:        10px;
  flex-wrap:  wrap;
}}
.card-tag {{
  font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
  font-size:   0.8rem;
  color:       var(--text-muted);
  background:  var(--tag-bg);
  padding:     2px 8px;
  border-radius: 6px;
}}
.card-date {{
  font-size:  0.8rem;
  color:      var(--text-muted);
}}
.card-badge {{
  font-size:    0.65rem;
  font-weight:  700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  padding:      2px 9px;
  border-radius:999px;
  background:   rgba(124,58,237,0.12);
  color:        var(--accent);
}}

/* ── Version chips ── */
.chips-row {{
  display:   flex;
  flex-wrap: wrap;
  gap:       6px;
  margin-bottom: 12px;
}}
.chip {{
  display:       inline-flex;
  align-items:   center;
  border-radius: 6px;
  overflow:      hidden;
  border:        1px solid var(--border);
  font-size:     0.78rem;
  line-height:   1;
}}
.chip.changed {{
  border-color: var(--changed-border);
  background:   var(--changed-bg);
}}
.chip-label {{
  background: var(--chip-bg);
  color:      var(--chip-label);
  padding:    5px 7px;
  font-weight:500;
}}
.chip-value {{
  background: transparent;
  color:      var(--chip-val);
  padding:    5px 7px;
  font-weight:600;
}}
.chip.changed .chip-value {{
  color: var(--changed-val);
}}
.chip-arrow {{
  color:      var(--accent);
  padding:    5px 3px 5px 0;
  font-size:  0.65rem;
  font-weight:700;
}}
.chip-prev {{
  color:      var(--text-muted);
  font-size:  0.72rem;
  padding:    5px 6px 5px 0;
  text-decoration:line-through;
}}

/* ── Diff summary bar ── */
.diff-bar {{
  display:     flex;
  gap:         14px;
  font-size:   0.8rem;
  color:       var(--text-muted);
  margin-bottom:12px;
  padding:     8px 12px;
  background:  var(--chip-bg);
  border-radius:8px;
}}
.diff-changed {{ color: var(--diff-chg); font-weight:600; }}
.diff-added   {{ color: var(--diff-add); font-weight:600; }}
.diff-removed {{ color: var(--diff-rem); font-weight:600; }}

/* ── Footer ── */
.card-footer {{
  display:    flex;
  align-items:center;
  justify-content:space-between;
  margin-top: 10px;
  padding-top:10px;
  border-top: 1px solid var(--border);
  font-size:  0.78rem;
  color:      var(--text-muted);
}}
.card-footer a {{
  color:           var(--accent);
  text-decoration: none;
  font-weight:     500;
}}
.image-ref {{
  font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
  font-size:   0.72rem;
}}
</style>
</head>
<body>
<div class="release-card">

  <div class="card-header">
    <div>
      <div class="card-title">Bluefin Dakota</div>
      <div class="card-meta">
        <span class="card-tag">{tag}</span>
        <span class="card-date">{date_long}</span>
        <span class="card-badge">Alpha</span>
      </div>
    </div>
  </div>

  <div class="chips-row">
{chips_html}
  </div>

{diff_bar_html}
  <div class="card-footer">
    <span class="image-ref">ghcr.io/projectbluefin/dakota:{sha7}</span>
    <a href="https://docs.projectbluefin.io/changelogs">docs.projectbluefin.io/changelogs →</a>
  </div>

</div>
</body>
</html>
"""

# ── Chip rendering ────────────────────────────────────────────────────────────

def render_chip(pkg: dict) -> str:
    label   = pkg["name"]
    version = pkg["version"]
    prev    = pkg.get("prev")
    changed = pkg.get("changed", False)

    changed_class = " changed" if changed else ""
    prev_html = ""
    arrow_html = ""
    if changed and prev:
        prev_html  = f'    <span class="chip-prev">{html.escape(prev)}</span>\n'
        arrow_html = '    <span class="chip-arrow">↑</span>\n'

    return (
        f'    <span class="chip{changed_class}">\n'
        f'      <span class="chip-label">{html.escape(label)}</span>\n'
        f'{prev_html}'
        f'{arrow_html}'
        f'      <span class="chip-value">{html.escape(version)}</span>\n'
        f'    </span>'
    )


def render_diff_bar(diff: dict, has_prev: bool) -> str:
    if not has_prev:
        return ""
    parts = []
    if diff["changed_count"]:
        parts.append(
            f'<span class="diff-changed">↑ {diff["changed_count"]} updated</span>'
        )
    if diff["added_count"]:
        parts.append(
            f'<span class="diff-added">+ {diff["added_count"]} added</span>'
        )
    if diff["removed_count"]:
        parts.append(
            f'<span class="diff-removed">− {diff["removed_count"]} removed</span>'
        )
    if not parts:
        parts.append('<span>No package changes since last release</span>')
    items = "\n    ".join(parts)
    return f'  <div class="diff-bar">\n    {items}\n  </div>\n'


def build_html(versions: dict, sha7: str, tag: str, date: str) -> str:
    from datetime import datetime
    dt = datetime.strptime(date, "%Y-%m-%d")
    date_long = dt.strftime("%B %-d, %Y")

    chips_html = "\n".join(render_chip(p) for p in versions["notable"])
    diff_bar_html = render_diff_bar(versions["diff"], versions["has_prev"])

    return CARD_HTML.format(
        tag=tag,
        date_long=date_long,
        sha7=sha7,
        chips_html=chips_html,
        diff_bar_html=diff_bar_html,
    )


# ── Playwright screenshot ─────────────────────────────────────────────────────

def screenshot(html_path: str, output_path: str) -> None:
    from playwright.sync_api import sync_playwright

    with sync_playwright() as p:
        browser = p.chromium.launch()
        ctx = browser.new_context(
            viewport={"width": 840, "height": 600},
            device_scale_factor=2,
            color_scheme="light",
        )
        page = ctx.new_page()
        page.goto(f"file://{os.path.abspath(html_path)}")
        page.wait_for_load_state("networkidle")
        card = page.locator(".release-card").first
        card.screenshot(path=output_path)
        browser.close()

    print(f"  Screenshot: {output_path}")


# ── Release notes markdown ────────────────────────────────────────────────────

def build_release_notes(
    versions: dict,
    sha: str,
    sha7: str,
    tag: str,
    date: str,
    repo: str,
) -> str:
    image_ref   = f"ghcr.io/{repo.split('/')[0]}/dakota"
    cert_regexp = (
        rf"^https://github\.com/{repo}/\.github/workflows/publish\.yml"
        r"@refs/heads/(main|gh-readonly-queue/main/.+)$"
    )

    # Diff summary line
    diff = versions["diff"]
    has_prev = versions["has_prev"]
    if has_prev:
        parts = []
        if diff["changed_count"]:
            parts.append(f"{diff['changed_count']} updated")
        if diff["added_count"]:
            parts.append(f"{diff['added_count']} added")
        if diff["removed_count"]:
            parts.append(f"{diff['removed_count']} removed")
        diff_line = (
            f"**{', '.join(parts)}** packages since last release."
            if parts else "No package changes since last release."
        )
    else:
        diff_line = "First automated release — no previous baseline."

    # Notable versions table
    notable_rows = "\n".join(
        f"| {p['name']} | `{p['version']}`"
        + (f" | `{p['prev']}` → `{p['version']}`" if p.get("changed") and p.get("prev") else " | —")
        + " |"
        for p in versions["notable"]
    )

    # Full diff sections — only when we have a previous baseline
    full_diff_section: list[str] = []
    if has_prev:
        # Updated
        if diff["changed"]:
            changed_rows = "\n".join(
                f"| {c['name']} | `{c['prev']}` | `{c['curr']}` |"
                for c in diff["changed"]
            )
            full_diff_section += [
                f"<details><summary>↑ {diff['changed_count']} updated packages</summary>",
                "",
                "| Package | From | To |",
                "|---|---|---|",
                *changed_rows.splitlines(),
                "",
                "</details>",
                "",
            ]
        # Added
        if diff["added"]:
            added_rows = "\n".join(
                f"| {a['name']} | `{a['version']}` |"
                for a in diff["added"]
            )
            full_diff_section += [
                f"<details><summary>+ {diff['added_count']} added packages</summary>",
                "",
                "| Package | Version |",
                "|---|---|",
                *added_rows.splitlines(),
                "",
                "</details>",
                "",
            ]
        # Removed
        if diff["removed"]:
            removed_rows = "\n".join(
                f"| {r['name']} | `{r['version']}` |"
                for r in diff["removed"]
            )
            full_diff_section += [
                f"<details><summary>− {diff['removed_count']} removed packages</summary>",
                "",
                "| Package | Last version |",
                "|---|---|",
                *removed_rows.splitlines(),
                "",
                "</details>",
                "",
            ]
        if not full_diff_section:
            full_diff_section = ["No package changes since last release.", ""]

    # Build lines with no leading whitespace — 4-space indent renders as code in GitHub MD
    image_lines = [f"ghcr.io/{repo.split('/')[0]}/dakota:stable"]
    image_lines.append(f"ghcr.io/{repo.split('/')[0]}/dakota:{sha}")

    L = [
        f"![Bluefin Dakota {tag}](https://github.com/{repo}/releases/download/{tag}/release-card.png)",
        "",
        diff_line,
        "",
        "## Key component versions",
        "",
        "| Component | Version | Change |",
        "|---|---|---|",
        *notable_rows.splitlines(),
        "",
        *((["## All package changes", ""] + full_diff_section) if has_prev else []),
        "## Images",
        "",
        "```",
        *image_lines,
        "```",
        "",
        "## Verify your image",
        "",
        "```bash",
        "# Requires: cosign  oras  gh",
        "# Install via Homebrew: brew install cosign oras gh",
        "",
        "# 1. Cosign keyless signature",
        "cosign verify \\",
        f"  --certificate-identity-regexp '{cert_regexp}' \\",
        "  --certificate-oidc-issuer https://token.actions.githubusercontent.com \\",
        f"  {image_ref}:{sha}",
        "",
        "# 2. SBOM OCI referrer",
        f"oras discover {image_ref}:{sha}",
        "",
        "# 3. SLSA provenance",
        f"gh attestation verify oci://{image_ref}:{sha} \\",
        f"  --repo {repo}",
        "",
        "# Or all three at once (requires dakota checkout):",
        f"just verify {image_ref}:{sha}",
        "```",
        "",
        "## Supply chain",
        "",
        f"- **SBOM (SPDX 2.3):** [`dakota.spdx.json`](https://github.com/{repo}/releases/download/{tag}/dakota.spdx.json) attached below",
        "- **Cosign:** keyless, Sigstore OIDC via GitHub Actions",
        f"- **SLSA provenance:** `gh attestation verify oci://{image_ref}:{sha} --repo {repo}`",
        "",
        "Full changelog → https://docs.projectbluefin.io/changelogs",
    ]
    notes = "\n".join(L) + "\n"


    return notes


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--versions",       required=True)
    ap.add_argument("--sha",            required=True)
    ap.add_argument("--sha7",           required=True)
    ap.add_argument("--date",           required=True)
    ap.add_argument("--tag",            required=True)
    ap.add_argument("--repo",           required=True)
    ap.add_argument("--output",         default="release-card.png")
    ap.add_argument("--release-notes",  default="release-notes.md")
    args = ap.parse_args()

    with open(args.versions, encoding="utf-8") as f:
        versions = json.load(f)

    html = build_html(versions, args.sha7, args.tag, args.date)

    with tempfile.NamedTemporaryFile(
        suffix=".html", mode="w", delete=False, dir="."
    ) as tmp:
        tmp.write(html)
        html_path = tmp.name

    try:
        print("Rendering release card...")
        screenshot(html_path, args.output)
    finally:
        os.unlink(html_path)

    notes = build_release_notes(
        versions=versions,
        sha=args.sha,
        sha7=args.sha7,
        tag=args.tag,
        date=args.date,
        repo=args.repo,
    )
    with open(args.release_notes, "w", encoding="utf-8") as f:
        f.write(notes)
    print(f"Release notes: {args.release_notes}")


if __name__ == "__main__":
    main()
