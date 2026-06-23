#!/usr/bin/env python3
"""BST build progress monitor for GitHub Actions.

Pipe BST build stdout through this script to get live progress lines and a
final step summary without losing any of the original output.

Usage (in build.yml):
    just bst build oci/bluefin.bst 2>&1 | python3 files/scripts/bst-progress.py

Environment variables:
    ELEMENT_TOTAL       Total element count from a preceding `bst show` step.
                        If unset, progress shows absolute counts without %.
    GITHUB_STEP_SUMMARY Path to the GHA step summary file (set by runner).
    BST_PROGRESS_INTERVAL Seconds between progress lines (default: 30).

Exit code:
    Exits 0 on clean EOF. The build step must use `set -o pipefail` so that
    a non-zero exit from `just bst build` propagates through the pipe.

Element completion detection:
    BST emits a terminal SUCCESS line whose message field is a log file path
    (ends in .log). One such line per element operation (pull, build, fetch).
    We deduplicate by artifact hash so each element counts exactly once,
    regardless of how many sub-operations it runs.
"""

import os
import re
import sys
import time
import collections

TOTAL = int(os.environ.get("ELEMENT_TOTAL", "0"))
INTERVAL = int(os.environ.get("BST_PROGRESS_INTERVAL", "30"))
SUMMARY_FILE = os.environ.get("GITHUB_STEP_SUMMARY", "")

# Strip ANSI color/control codes before matching (just bst passes --colors by default).
ANSI_ESCAPE = re.compile(r"\x1b\[[0-9;]*[mABCDEFGHJKLMSTsuhl]")

# Matches a terminal SUCCESS/SKIPPED line whose message is a log file path.
# Groups: (artifact_hash, action_type, element_name, state)
# Example line (GHA prefix and ANSI codes stripped):
#   [23:37:43][00:00:04][d37613a5][    pull:fds.bst:steam-devices.bst] SUCCESS fds/.../d37613a5-pull.20260622.log
TERMINAL = re.compile(
    r"\[([0-9a-f]+)\]\[[ ]*(pull|build|fetch|push):([^\]]+)\] "
    r"(SUCCESS|SKIPPED)\s+\S+\.log\s*$"
)

# Priority: build (local compile, highest) > pull (CAS hit) > fetch (source) > push
ACTION_PRIORITY: dict[str, int] = {"build": 3, "pull": 2, "fetch": 1, "push": 0}

done_hashes: dict[str, str] = {}  # artifact_hash -> best action seen so far
action_counts: collections.Counter = collections.Counter()
start_time = time.monotonic()
last_report = start_time


def _format_elapsed(seconds: float) -> str:
    m, s = divmod(int(seconds), 60)
    h, m = divmod(m, 60)
    return f"{h:02d}:{m:02d}:{s:02d}" if h else f"{m:02d}:{s:02d}"


def _emit_progress(done: int, elapsed: float, final: bool = False) -> None:
    pct = int(done * 100 / TOTAL) if TOTAL else 0
    rate = done / elapsed * 60 if elapsed > 0 else 0
    remaining = int((TOTAL - done) / (done / elapsed)) if done > 0 and elapsed > 0 and TOTAL > done else 0

    label = "Final" if final else "Progress"
    if TOTAL:
        eta = f"  ETA ~{remaining // 60}m{remaining % 60:02d}s" if not final else ""
        line = (
            f"\n>>> BST {label}: {done}/{TOTAL} ({pct}%) "
            f"pull:{action_counts['pull']} build:{action_counts['build']} "
            f"fetch:{action_counts['fetch']}  "
            f"{rate:.0f} elem/min{eta}\n"
        )
        notice = (
            f"::notice::BST {pct}% — {done}/{TOTAL} elements  "
            f"pull:{action_counts['pull']} build:{action_counts['build']}"
            + (f"  ETA ~{remaining // 60}m" if not final else "  done")
        )
    else:
        line = (
            f"\n>>> BST {label}: {done} elements completed "
            f"pull:{action_counts['pull']} build:{action_counts['build']} "
            f"fetch:{action_counts['fetch']}  "
            f"{rate:.0f} elem/min  elapsed:{_format_elapsed(elapsed)}\n"
        )
        notice = (
            f"::notice::BST {done} elements — "
            f"pull:{action_counts['pull']} build:{action_counts['build']}"
        )

    print(line, end="", flush=True)
    print(notice, flush=True)


def _write_summary(done: int, elapsed: float) -> None:
    if not SUMMARY_FILE:
        return

    pct = f"{done * 100 / TOTAL:.1f}" if TOTAL else "n/a"
    miss_pct = (
        f"{action_counts['build'] * 100 / done:.1f}" if done else "0.0"
    )
    rate = f"{done / elapsed * 60:.0f}" if elapsed > 0 else "0"

    table = f"""
## BST Cache Performance

| Metric | Value |
|---|---|
| Total elements | {TOTAL or "unknown"} |
| Completed | {done} ({pct}%) |
| Cache hits (pull) | {action_counts['pull']} |
| Local builds (miss) | {action_counts['build']} |
| Fetches | {action_counts['fetch']} |
| Cache miss rate | {miss_pct}% |
| Wall time | {_format_elapsed(elapsed)} |
| Throughput | {rate} elem/min |

"""
    try:
        with open(SUMMARY_FILE, "a") as f:
            f.write(table)
    except OSError:
        pass


def main() -> None:
    global last_report
    done = 0

    for raw_line in sys.stdin.buffer:
        # Pass every byte through unchanged
        sys.stdout.buffer.write(raw_line)
        sys.stdout.buffer.flush()

        line = raw_line.decode("utf-8", errors="replace")
        m = TERMINAL.search(ANSI_ESCAPE.sub("", line))
        if m:
            artifact_hash, action, _element, _state = m.groups()
            prev_action = done_hashes.get(artifact_hash)
            if prev_action is None:
                # First terminal line for this hash — count it as a new element
                done_hashes[artifact_hash] = action
                action_counts[action] += 1
                done += 1
            elif ACTION_PRIORITY.get(action, 0) > ACTION_PRIORITY.get(prev_action, 0):
                # Higher-priority action for same element (e.g. build after fetch)
                action_counts[prev_action] -= 1
                action_counts[action] += 1
                done_hashes[artifact_hash] = action

            now = time.monotonic()
            elapsed = now - start_time
            if now - last_report >= INTERVAL:
                _emit_progress(done, elapsed)
                last_report = now

    elapsed = time.monotonic() - start_time
    done = len(done_hashes)
    _emit_progress(done, elapsed, final=True)
    _write_summary(done, elapsed)


if __name__ == "__main__":
    main()
