#!/usr/bin/env python3
"""Dispatch stable promotion and check publication readiness without shell parsing.

Dispatch always uses projectbluefin/dakota's testing workflow, not a local
checkout or its default remote. check-publish runs inside that workflow; it
resolves testing HEAD unless the operator explicitly supplies a recovery SHA.
"""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys


REPOSITORY = "projectbluefin/dakota"
WORKFLOW = "execute-release.yml"
WORKFLOW_REF = "testing"


class ReleaseError(Exception):
    """A release precondition was not satisfied."""


def full_sha(value: str) -> str:
    if not re.fullmatch(r"[0-9a-fA-F]{40}", value):
        raise ValueError("SHA must be a full 40-character hexadecimal commit SHA")
    return value.lower()


def candidate_argument(value: str) -> str:
    if not value.startswith("sha="):
        raise argparse.ArgumentTypeError("expected sha=<full-40-character-SHA>")
    try:
        return full_sha(value.removeprefix("sha="))
    except ValueError as error:
        raise argparse.ArgumentTypeError(str(error)) from error


def dispatch(apply: bool, sha: str | None) -> None:
    dry_run = not apply
    mode = "APPLY — stable promotion enabled" if apply else "DRY RUN — preflight only; no promotion"
    print(f"{mode}\nRepository: {REPOSITORY}\nWorkflow ref: {WORKFLOW_REF}", flush=True)
    print(f"Candidate: {sha or 'testing HEAD (resolved by the workflow)'}", flush=True)
    if sha:
        print("Recovery SHA: bypassing the successful-publish-run lookup.", flush=True)
    if dry_run:
        print("Preflight does not run the promotion workflow's signature checks."
              " Use --apply to promote.", flush=True)
    command = [
        "gh", "workflow", "run", WORKFLOW, "--repo", REPOSITORY,
        "--ref", WORKFLOW_REF, "--raw-field", f"dry_run={str(dry_run).lower()}",
    ]
    if sha:
        command.extend(["--raw-field", f"promote_sha={sha}"])
    subprocess.run(command, check=True, shell=False)
    print("Dispatched the remote testing workflow (not local uncommitted edits).")
    print(f"Watch: gh run list --repo {REPOSITORY} --workflow {WORKFLOW} --limit 5")


def gh_json(*arguments: str):
    result = subprocess.run(
        ["gh", *arguments], check=True, capture_output=True, text=True, shell=False,
    )
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise ReleaseError("GitHub CLI returned invalid JSON") from error


def check_publish() -> None:
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        raise ReleaseError("check-publish requires GITHUB_OUTPUT (run it inside the release workflow)")
    repository = os.environ.get("GITHUB_REPOSITORY", REPOSITORY)
    override = os.environ.get("PROMOTE_SHA", "")
    run_id = ""
    if override:
        sha = full_sha(override)
        print(f"Recovery mode: using {sha}; skipping successful-publish-run lookup.")
    else:
        ref = gh_json("api", f"repos/{repository}/git/ref/heads/testing")
        try:
            sha = full_sha(ref["object"]["sha"])
        except (KeyError, TypeError, ValueError) as error:
            raise ReleaseError("GitHub returned an invalid testing HEAD SHA") from error
        runs = gh_json(
            "run", "list", "--repo", repository, "--workflow", "publish.yml",
            "--branch", "testing", "--commit", sha, "--status", "success",
            "--limit", "100", "--json", "databaseId,headSha,status,conclusion",
        )
        if not isinstance(runs, list):
            raise ReleaseError("GitHub returned an invalid publish-run list")
        for run in runs:
            if not isinstance(run, dict):
                raise ReleaseError("GitHub returned an invalid publish-run entry")
            if (run.get("headSha") == sha and run.get("status") == "completed"
                    and run.get("conclusion") == "success"):
                if type(run.get("databaseId")) is not int or run["databaseId"] <= 0:
                    raise ReleaseError("GitHub returned an invalid publish-run ID")
                run_id = str(run["databaseId"])
                break
        if not run_id:
            raise ReleaseError(
                f"No successful publish for testing SHA {sha}; no promotion. "
                "Wait for that SHA's publish.yml run to succeed before retrying."
            )
        print(f"Found successful publish run {run_id} for testing SHA {sha}.")

    # Emit outputs only after readiness succeeds. Missing publication is an
    # error, whereas an already-stable digest remains the downstream no-op.
    with Path(output).open("a", encoding="utf-8") as stream:
        stream.write(
            f"should-release=true\nbuild_sha={sha}\npublish_run_id={run_id}\nproceed=true\n"
        )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    commands = parser.add_subparsers(dest="command", required=True)
    release = commands.add_parser("dispatch", help="dispatch remote preflight or promotion", allow_abbrev=False)
    release.add_argument("--apply", action="store_true", help="promote instead of preflight")
    release.add_argument("sha", nargs="?", type=candidate_argument, metavar="sha=<full-SHA>",
                         help="recovery only: use an already-published SHA; skips publish-run lookup")
    commands.add_parser("check-publish", help="workflow-only publication readiness check", allow_abbrev=False)
    arguments = parser.parse_args(argv)
    try:
        if arguments.command == "dispatch":
            dispatch(arguments.apply, arguments.sha)
        else:
            check_publish()
    except subprocess.CalledProcessError as error:
        print(f"ERROR: GitHub CLI failed (exit {error.returncode}); operation did not complete.", file=sys.stderr)
        if error.stderr:
            print(error.stderr.strip(), file=sys.stderr)
        return 1
    except (ReleaseError, ValueError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
