#!/usr/bin/env python3
"""
sbom_diff.py — Parse one or two SPDX 2.3 SBOMs and produce a versions.json
for the release card and release notes.

Usage:
    python3 sbom_diff.py --current PATH [--previous PATH] --output PATH

Output JSON schema:
{
  "notable": [
    {"name": "Kernel", "version": "6.19.14", "prev": null, "changed": false}
    ...
  ],
  "diff": {
    "changed_count": 12,
    "added_count": 3,
    "removed_count": 1,
    "changed": [{"name": "...", "prev": "...", "curr": "..."}],
    "added":   [{"name": "...", "version": "..."}],
    "removed": [{"name": "...", "version": "..."}]
  },
  "has_prev": false
}
"""
import argparse
import json
import os
import re
import sys

# ── Notable package definitions ───────────────────────────────────────────────
# (sbom_name, display_label, optional SPDXID substring filter)
# Order matches the OsReleaseCard HEADER_CHIP_NAMES row, then Dakota extras.
NOTABLE: list[tuple[str, str, str | None]] = [
    ("linux",            "Kernel",         "components-linux.bst"),
    ("gnome-shell",      "GNOME",          None),
    ("mesa",             "Mesa",           None),
    ("podman",           "Podman",         None),
    ("bootc",            "bootc",          None),
    ("systemd",          "systemd",        None),
    ("pipewire",         "pipewire",       None),
    ("flatpak",          "flatpak",        None),
    ("sudo-rs",          "sudo-rs",        None),
    ("uutils-coreutils", "uutils",         None),
    ("distrobox",        "distrobox",      None),
    ("ghostty",          "ghostty",        None),
    ("fish-shell",       "fish",           None),
    ("common",           "common",         None),
    ("JetBrainsMono",    "JetBrains Mono", None),
    ("gum",              "gum",            None),
]

# ── Version string helpers ────────────────────────────────────────────────────

def clean_version(raw: str | None) -> str | None:
    """
    Normalise a BST versionInfo string to something human-readable.

    BST ref strings come in several formats:
      • Semver:           "1.15.2"
      • Git-describe:     "2.0.0-rc.2-9-gc74dc52ac1b796557a6ef3eb18b8884a0c722324"
      • Bare 40-char SHA: "965cd7b99b04faf55819606178a5e8233cfd8b9e"
      • Empty / None

    Returns None for bare long SHAs so they can be handled specially (short SHA).
    """
    if not raw:
        return None
    v = raw.strip()
    # Strip git-describe suffix "-N-gSHA"
    v = re.sub(r"-\d+-g[0-9a-f]{7,}$", "", v).rstrip("-").strip()
    # If what remains is still a 40-char hex SHA, return None (use short form)
    if re.match(r"^[0-9a-f]{40}$", v):
        return None
    # Multi-segment content hash (e.g. "abc123.../167") — skip
    if re.match(r"^[0-9a-f]{32,}", v):
        return None
    return v or None


def short_sha(raw: str | None) -> str | None:
    """Return first 8 chars of a bare SHA, or None."""
    if raw and re.match(r"^[0-9a-f]{40}$", raw.strip()):
        return raw.strip()[:8]
    return None


def best_version(raw: str | None) -> str | None:
    """Return clean semver if available, else short SHA, else None."""
    v = clean_version(raw)
    if v:
        return v
    return short_sha(raw)


# ── SBOM loading ──────────────────────────────────────────────────────────────

def load_pkg_map(sbom_path: str) -> dict[str, dict]:
    """
    Build {name -> {ver, spdxid}} from an SPDX 2.3 JSON file.

    Deduplication rule: for each package name, prefer:
      1. A clean semver string over a short SHA
      2. Any version over None
    For "linux" we keep ALL entries indexed by SPDXID so the caller can
    filter by SPDXID substring.
    """
    with open(sbom_path, encoding="utf-8") as f:
        sbom = json.load(f)

    pkgs: dict[str, dict] = {}
    linux_entries: list[dict] = []

    for p in sbom.get("packages", []):
        name: str = p.get("name", "")
        raw: str = p.get("versionInfo", "")
        spdxid: str = p.get("SPDXID", "")
        ver = best_version(raw)

        if name == "linux":
            linux_entries.append({"ver": ver, "raw": raw, "spdxid": spdxid})
            continue

        if name not in pkgs:
            pkgs[name] = {"ver": ver, "spdxid": spdxid}
        else:
            curr = pkgs[name]["ver"]
            # Prefer semver over None/short-SHA
            if ver and (not curr or (re.match(r"^[0-9]+\.[0-9]+", ver) and
                                     not re.match(r"^[0-9]+\.[0-9]+", curr))):
                pkgs[name] = {"ver": ver, "spdxid": spdxid}

    # Resolve linux kernel: prefer entry whose SPDXID contains "components-linux.bst"
    # and has the best (semver) version — multiple entries match the filter.
    candidates = [e for e in linux_entries if "components-linux.bst" in e["spdxid"]]
    if not candidates:
        candidates = linux_entries
    # Sort: semver entries first, then SHA, then None
    def _ver_rank(e):
        v = e["ver"]
        if v and re.match(r"^[0-9]+\.[0-9]+", v):
            return 0
        if v:
            return 1
        return 2
    candidates.sort(key=_ver_rank)
    kernel_entry = candidates[0] if candidates else None
    if kernel_entry:
        pkgs["linux"] = {"ver": kernel_entry["ver"], "spdxid": kernel_entry["spdxid"]}

    return pkgs


# ── Notable extraction ────────────────────────────────────────────────────────

def extract_notable(
    curr_map: dict,
    prev_map: dict | None,
) -> list[dict]:
    """Return notable package list with optional prev version for changed chips.

    The SPDXID filter was used during SBOM loading (load_pkg_map) to select
    the correct linux kernel entry.  By the time we reach here, curr_map already
    has the right entry under 'linux'.  Re-filtering by SPDXID here is redundant
    and will silently drop the Kernel chip if the SPDXID naming convention ever
    drifts, so we skip it.
    """
    result = []
    for sbom_name, label, _spdxid_filter in NOTABLE:
        entry = curr_map.get(sbom_name)
        if entry is None:
            continue
        ver = entry["ver"]

        prev_ver = None
        if prev_map and sbom_name in prev_map:
            pv = prev_map[sbom_name]["ver"]
            if pv != ver:
                prev_ver = pv

        result.append({
            "name":    label,
            "version": ver or "(unknown)",
            "prev":    prev_ver,
            "changed": prev_ver is not None,
        })
    return result


# ── Full diff ─────────────────────────────────────────────────────────────────

def diff_sboms(curr_map: dict, prev_map: dict) -> dict:
    """Compute full added/changed/removed diff between two package maps."""
    all_names = set(curr_map) | set(prev_map)

    added:   list[dict] = []
    changed: list[dict] = []
    removed: list[dict] = []

    for name in sorted(all_names):
        c_entry = curr_map.get(name)
        p_entry = prev_map.get(name)

        c_ver = c_entry["ver"] if c_entry else None
        p_ver = p_entry["ver"] if p_entry else None

        if c_entry and not p_entry:
            added.append({"name": name, "version": c_ver or "(unknown)"})
        elif not c_entry and p_entry:
            removed.append({"name": name, "version": p_ver or "(unknown)"})
        elif c_ver and p_ver and c_ver != p_ver:
            changed.append({"name": name, "prev": p_ver, "curr": c_ver})

    return {
        "changed_count": len(changed),
        "added_count":   len(added),
        "removed_count": len(removed),
        "changed": changed,
        "added":   added,
        "removed": removed,
    }


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--current",  required=True, help="Path to current dakota.spdx.json")
    ap.add_argument("--previous", default=None,  help="Path to previous dakota.spdx.json (optional)")
    ap.add_argument("--output",   required=True, help="Output versions.json path")
    args = ap.parse_args()

    if not os.path.isfile(args.current):
        print(f"ERROR: current SBOM not found: {args.current}", file=sys.stderr)
        sys.exit(1)

    print(f"Loading current SBOM: {args.current}")
    curr_map = load_pkg_map(args.current)
    print(f"  → {len(curr_map)} unique packages")

    prev_map: dict | None = None
    has_prev = False
    if args.previous and os.path.isfile(args.previous):
        print(f"Loading previous SBOM: {args.previous}")
        prev_map = load_pkg_map(args.previous)
        print(f"  → {len(prev_map)} unique packages")
        has_prev = True
    else:
        print("No previous SBOM — skipping diff")

    notable = extract_notable(curr_map, prev_map)
    print(f"Notable packages found: {len(notable)}")

    diff_data: dict
    if prev_map is not None:
        diff_data = diff_sboms(curr_map, prev_map)
        print(f"Diff: {diff_data['changed_count']} changed, "
              f"{diff_data['added_count']} added, "
              f"{diff_data['removed_count']} removed")
    else:
        diff_data = {
            "changed_count": 0, "added_count": 0, "removed_count": 0,
            "changed": [], "added": [], "removed": [],
        }

    output = {
        "notable":  notable,
        "diff":     diff_data,
        "has_prev": has_prev,
    }

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2)
    print(f"Written: {args.output}")


if __name__ == "__main__":
    main()
