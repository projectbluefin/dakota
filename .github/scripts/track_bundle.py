#!/usr/bin/env python3
"""Record tracked BuildStream source updates and compose the bundle PR.

Driven by .github/workflows/track-bst-sources.yml:

    record-element  After `bst source track`, decide whether an element really
                    changed and, if so, record it for the bundle.
    record          Record an update whose version facts the caller already
                    knows (the release-asset steps).
    compose         Commit every recorded update onto the base branch, one
                    commit per element, and open or refresh the bundle PR.

A record is the changed files copied under <out>/files/ at their repository
paths plus <out>/meta/<slug>.json. Records from every tracking job are merged
into one directory by actions/download-artifact before `compose` runs.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path

REMOTE = "origin"
BOT_NAME = "github-actions[bot]"
BOT_EMAIL = "41898282+github-actions[bot]@users.noreply.github.com"

REF_LINE = re.compile(r"^\s*ref:\s+(\S+)", re.MULTILINE)
DIFF_REF = re.compile(r"ref:\s+(\S+)")
SHA40 = re.compile(r"[0-9a-f]{40}$")
DESCRIBE_SHA = re.compile(r"(?<=g)[0-9a-f]+$")
VERSION = re.compile(r"v?\d+[\d.\-]+")
GITHUB_SLUG = re.compile(r"url:\s+github:([^\s.]+)")


@dataclass
class Update:
    slug: str
    title: str
    files: list[str]
    change: str = ""
    links: str = ""
    note: str = ""

    @property
    def element(self) -> str:
        return self.files[0].removeprefix("elements/")

    def row(self) -> str:
        return f"| `{self.element}` | {self.change} | {self.links} | {self.note} |"


@dataclass
class ComposeResult:
    count: int = 0
    pushed: bool = False
    pr: str = ""
    rows: list[str] = field(default_factory=list)


def run(*args: str, cwd: Path | None = None, input: str | None = None,
        check: bool = True) -> subprocess.CompletedProcess:
    # Never inherit stdin: a prompting tool must fail, not hang the job.
    stdin = {"input": input} if input is not None else {"stdin": subprocess.DEVNULL}
    return subprocess.run(args, cwd=cwd, text=True, capture_output=True, check=check,
                          **stdin)


def git(*args: str, cwd: Path | None = None, check: bool = True) -> str:
    return run("git", *args, cwd=cwd, check=check).stdout.strip()


def git_quiet(*args: str, cwd: Path | None = None) -> bool:
    """True when a `git ... --quiet` style command reports no difference."""
    return run("git", *args, cwd=cwd, check=False).returncode == 0


def gh(*args: str, cwd: Path | None = None, input: str | None = None) -> str:
    return run("gh", *args, cwd=cwd, input=input).stdout.strip()


def ref_shas(text: str) -> list[str]:
    """Sorted 40-char commit ids at the end of every `ref:` value."""
    return sorted(m.group(0) for ref in REF_LINE.findall(text)
                  if (m := SHA40.search(ref)))


def diff_refs(diff: str) -> tuple[str, str]:
    """First removed and first added `ref:` value in a unified diff."""
    old = new = ""
    for line in diff.splitlines():
        if line.startswith(("---", "+++")):
            continue
        m = DIFF_REF.search(line)
        if not m:
            continue
        if line.startswith("-") and not old:
            old = m.group(1)
        elif line.startswith("+") and not new:
            new = m.group(1)
    return old, new


def ref_version(ref: str) -> str:
    """Version from a tag or git-describe ref, or "" for a raw commit id.

    "v2026.08-204-gabc" -> "v2026.08-204", "4.4.15-3-gabc" -> "4.4.15-3".
    """
    m = VERSION.match(ref)
    if not m or "." not in m.group(0):
        return ""
    return m.group(0).removesuffix("-")


def ref_sha(ref: str) -> str:
    """Commit id from a git-describe ref, else the ref itself."""
    m = DESCRIBE_SHA.search(ref)
    return m.group(0) if m else ref


def upstream_slug(element_text: str) -> str:
    m = GITHUB_SLUG.search(element_text)
    return m.group(1) if m else ""


def describe_element_update(slug: str, base_title: str, path: str, new_text: str,
                            diff: str, note: str = "") -> Update:
    old_ref, new_ref = diff_refs(diff)
    old_ver, new_ver = ref_version(old_ref), ref_version(new_ref)
    old_sha, new_sha = ref_sha(old_ref), ref_sha(new_ref)

    if old_ver and new_ver and old_ver != new_ver:
        title = f"{base_title}: {old_ver} -> {new_ver}"
        change = f"`{old_ver}` → `{new_ver}`"
    else:
        title = base_title
        change = f"`{old_sha[:8]}` → `{new_sha[:8]}`"

    links = ""
    repo = upstream_slug(new_text)
    if repo and old_sha and new_sha:
        links = f"[compare](https://github.com/{repo}/compare/{old_sha}...{new_sha})"

    return Update(slug=slug, title=title, files=[path], change=change, links=links,
                  note=note)


def default_out() -> Path:
    if "TRACK_OUT" in os.environ:
        return Path(os.environ["TRACK_OUT"])
    if "RUNNER_TEMP" in os.environ:
        return Path(os.environ["RUNNER_TEMP"]) / "tracked"
    raise SystemExit("track_bundle: set --out, TRACK_OUT, or RUNNER_TEMP")


def write_record(update: Update, out: Path, repo: Path = Path(".")) -> None:
    if not update.files:
        raise ValueError(f"{update.slug}: no files to record")
    for path in update.files:
        target = out / "files" / path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(repo / path, target)
    meta = out / "meta"
    meta.mkdir(parents=True, exist_ok=True)
    (meta / f"{update.slug}.json").write_text(json.dumps(asdict(update), indent=2) + "\n")


def load_records(tracked: Path) -> list[Update]:
    return [Update(**json.loads(p.read_text()))
            for p in sorted((tracked / "meta").glob("*.json"))]


def set_output(name: str, value: str) -> None:
    path = os.environ.get("GITHUB_OUTPUT")
    if path:
        with open(path, "a") as f:
            f.write(f"{name}={value}\n")


def render_body(updates: list[Update], run_url: str) -> str:
    lines = [
        "## BuildStream source updates",
        "",
        "| Element | Change | Links | Note |",
        "| --- | --- | --- | --- |",
        *(u.row() for u in updates),
        "",
    ]
    if any(u.note for u in updates):
        lines += ["> [!IMPORTANT]", "> Rows with a note need review before this merges.", ""]
    lines += [
        "Each element is its own commit. To hold one out, add its slug to the",
        "`TRACK_BUNDLE_SKIP` repository variable and re-run the tracker.",
        "",
        "---",
        f"*Generated by [Track BuildStream Sources]({run_url})*",
    ]
    return "\n".join(lines) + "\n"


def bundle_title(updates: list[Update]) -> str:
    if len(updates) == 1:
        return updates[0].title
    return f"chore(deps): update {len(updates)} BuildStream sources"


def bundle_changed(repo: Path, base: str, branch: str) -> bool:
    """Whether HEAD changes any bundled path relative to the published branch.

    Compares only paths the old or new bundle touches, so the branch merely
    sitting on an older base does not count as a change: rebasing alone would
    restart a multi-hour labeled PR build.
    """
    remote_branch = f"{REMOTE}/{branch}"
    if not git_quiet("rev-parse", "-q", "--verify", f"refs/remotes/{remote_branch}",
                     cwd=repo):
        return True
    paths = sorted(set(git("diff", "--name-only", f"{REMOTE}/{base}", "HEAD",
                           cwd=repo).split())
                   | set(git("diff", "--name-only", f"{REMOTE}/{base}...{remote_branch}",
                             cwd=repo).split()))
    return not git_quiet("diff", "--quiet", remote_branch, "HEAD", "--", *paths, cwd=repo)


def compose(tracked: Path, branch: str, base: str, skip: set[str], run_url: str,
            repo: Path = Path(".")) -> ComposeResult:
    result = ComposeResult()
    git("config", "user.name", BOT_NAME, cwd=repo)
    git("config", "user.email", BOT_EMAIL, cwd=repo)
    git("checkout", "-B", branch, f"{REMOTE}/{base}", cwd=repo)

    # One commit per element, in a stable order, so a bad bump can be
    # identified and reverted on its own.
    bundled: list[Update] = []
    for update in load_records(tracked):
        if update.slug in skip:
            print(f"{update.slug}: held out by TRACK_BUNDLE_SKIP")
            continue
        for path in update.files:
            target = repo / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(tracked / "files" / path, target)
        git("add", "--", *update.files, cwd=repo)
        if git_quiet("diff", "--cached", "--quiet", cwd=repo):
            print(f"{update.slug}: already on {base}")
            continue
        git("commit", "-q", "-m", update.title, cwd=repo)
        bundled.append(update)

    result.count = len(bundled)
    result.rows = [u.row() for u in bundled]
    if not bundled:
        print("No source updates to bundle")
        return result

    existing = gh("pr", "list", "--head", branch, "--base", base, "--state", "open",
                  "--json", "number", "--jq", ".[0].number // empty", cwd=repo)

    if existing and not bundle_changed(repo, base, branch):
        print("Bundled updates unchanged; not pushing")
    else:
        git("push", "--force-with-lease", REMOTE, branch, cwd=repo)
        result.pushed = True

    # The body is refreshed even without a push, so rows for updates that
    # already landed on the base branch drop out.
    title, body = bundle_title(bundled), render_body(bundled, run_url)
    if existing:
        gh("pr", "edit", existing, "--title", title, "--body-file", "-", input=body, cwd=repo)
        result.pr = existing
        print(f"Updated PR #{existing}")
    else:
        result.pr = gh("pr", "create", "--base", base, "--head", branch, "--title", title,
                       "--body-file", "-", input=body, cwd=repo)
        print(f"PR: {result.pr}")
    return result


def cmd_record_element(args: argparse.Namespace) -> int:
    path = f"elements/{args.element}"
    slug = Path(args.element).stem
    new_text = Path(path).read_text()
    if git_quiet("diff", "--quiet", "--", path):
        print(f"No changes detected for {args.element}")
        return 0

    # bst source track can normalize ref format without changing the underlying
    # commit (e.g. plain SHA -> git-describe "v0.2.13-0-g<sha>"). Identical
    # commit sets mean only formatting changed: no real update.
    old_text = git("show", f"HEAD:{path}")
    old_shas = ref_shas(old_text)
    if old_shas and old_shas == ref_shas(new_text):
        print("Ref format normalized but same underlying commit(s), no update")
        return 0

    update = describe_element_update(slug, args.title, path, new_text,
                                     git("diff", "--", path), args.note)
    write_record(update, args.out or default_out())
    set_output("slug", slug)
    print(f"Recorded {update.title}")
    return 0


def cmd_record(args: argparse.Namespace) -> int:
    update = Update(slug=args.slug, title=args.title, files=args.files,
                    change=args.change, links=args.links, note=args.note)
    write_record(update, args.out or default_out())
    print(f"Recorded {update.title}")
    return 0


def cmd_compose(args: argparse.Namespace) -> int:
    compose(args.tracked, args.branch, args.base, set(args.skip.split()), args.run_url)
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("record-element", help="record a `bst source track` result")
    p.add_argument("--element", required=True, help="element path under elements/")
    p.add_argument("--title", required=True, help="commit title without versions")
    p.add_argument("--note", default="", help="review note for the PR table")
    p.add_argument("--out", type=Path)
    p.set_defaults(func=cmd_record_element)

    p = sub.add_parser("record", help="record an update with known version facts")
    p.add_argument("--slug", required=True)
    p.add_argument("--title", required=True)
    p.add_argument("--change", default="")
    p.add_argument("--links", default="")
    p.add_argument("--note", default="")
    p.add_argument("--out", type=Path)
    p.add_argument("files", nargs="+")
    p.set_defaults(func=cmd_record)

    p = sub.add_parser("compose", help="commit records and open or refresh the PR")
    p.add_argument("--tracked", type=Path, required=True)
    p.add_argument("--branch", required=True)
    p.add_argument("--base", default="testing")
    p.add_argument("--skip", default="", help="space-separated slugs to hold out")
    p.add_argument("--run-url", required=True)
    p.set_defaults(func=cmd_compose)

    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except subprocess.CalledProcessError as e:
        sys.stderr.write(e.stderr or "")
        print(f"::error::{' '.join(e.cmd)} exited {e.returncode}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
