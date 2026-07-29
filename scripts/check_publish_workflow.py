#!/usr/bin/env python3
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import textwrap


ROOT = Path(".")
PUBLISH = ROOT / ".github/workflows/publish.yml"
BUILD = ROOT / ".github/workflows/build.yml"
CI_CONFIG_ACTION = ROOT / ".github/actions/generate-bst-ci-config/action.yml"


def extract_composite_shell(action: str) -> str | None:
    run_indent = None
    shell_lines = []
    for line in action.splitlines(keepends=True):
        if run_indent is None:
            match = re.match(r"^(?P<indent> *)run: \|\s*$", line)
            if match:
                run_indent = len(match.group("indent"))
            continue

        if line.strip() and len(line) - len(line.lstrip()) <= run_indent:
            break
        shell_lines.append(line)

    if run_indent is None:
        return None
    return textwrap.dedent("".join(shell_lines))


def run_generator(shell: str, *, remote: bool, push: bool, credentials: bool):
    with tempfile.TemporaryDirectory() as tempdir:
        workspace = Path(tempdir)
        env = os.environ.copy()
        env.update(
            {
                "GITHUB_WORKSPACE": str(workspace),
                "ENABLE_REMOTE_EXECUTION": str(remote).lower(),
                "ENABLE_PUSH": str(push).lower(),
                "CASD_CLIENT_CERT": "test certificate" if credentials else "",
                "CASD_CLIENT_KEY": "test private key" if credentials else "",
            }
        )
        result = subprocess.run(
            ["bash", "-c", shell],
            cwd=workspace,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )
        config_path = workspace / "buildstream-ci.conf"
        config = config_path.read_text() if config_path.exists() else ""
        return result, config


def check_generated_configs(shell: str, errors: list[str]) -> None:
    syntax = subprocess.run(
        ["bash", "-n"], input=shell, text=True, capture_output=True, check=False
    )
    if syntax.returncode:
        errors.append(f"generate-bst-ci-config shell is invalid: {syntax.stderr.strip()}")
        return

    remote_result, remote_config = run_generator(
        shell, remote=True, push=True, credentials=True
    )
    if remote_result.returncode:
        errors.append(
            "remote BuildStream config generation failed: "
            + (remote_result.stderr.strip() or remote_result.stdout.strip())
        )
    else:
        required = {
            "remote-execution:": "remote-execution block",
            "  execution-service:": "execution service",
            "  action-cache-service:": "action-cache service",
            "  max-jobs: 8": "build.max-jobs: 8",
            "cache:\n  cache-buildtrees: never\n  storage-service:": "top-level cache storage service",
        }
        for token, description in required.items():
            if token not in remote_config:
                errors.append(f"remote config is missing {description}")
        if len(re.findall(r"^  storage-service:", remote_config, re.M)) != 2:
            errors.append("remote config must contain top-level and RE storage services")
        if remote_config.count("push: true") < 3:
            errors.append("remote config must publish artifacts, sources, and action-cache results")

    fetch_result, fetch_config = run_generator(
        shell, remote=False, push=False, credentials=True
    )
    if fetch_result.returncode:
        errors.append(
            "fetch-only BuildStream config generation failed: "
            + (fetch_result.stderr.strip() or fetch_result.stdout.strip())
        )
    else:
        if "remote-execution:" in fetch_config:
            errors.append("fetch-only config must not contain remote-execution")
        if re.search(r"^  storage-service:", fetch_config, re.M):
            errors.append("fetch-only config must not use top-level remote storage")
        if "  max-jobs: 1" not in fetch_config:
            errors.append("fetch-only/local config must retain build.max-jobs: 1")
        if "push: true" in fetch_config:
            errors.append("fetch-only config must keep every cache read-only")

    missing_result, _ = run_generator(
        shell, remote=True, push=True, credentials=False
    )
    if missing_result.returncode == 0:
        errors.append("remote config generation must fail when mTLS credentials are missing")


def check_build_workflow(build: str, errors: list[str]) -> None:
    required = {
        "max-parallel: 4": "four-way variant concurrency",
        'enable-remote-execution: "true"': "fail-closed remote execution",
        'enable-push: "true"': "automatic artifact publication",
        'grep -Fq "Remote Execution Configuration"': "runtime RE evidence check",
    }
    for token, description in required.items():
        if token not in build:
            errors.append(f"build workflow is missing {description}")

    forbidden = {
        "Pull prebuilt artifacts from remote CAS": "explicit CAS pre-pull",
        "Push OCI artifact to remote CAS": "standalone artifact push",
        "buildstream-push.conf": "legacy push-only config",
    }
    for token, description in forbidden.items():
        if token in build:
            errors.append(f"build workflow still contains {description}")


def check_publish_workflow(publish: str, errors: list[str]) -> None:
    sbom_match = re.search(r"publish-sbom:\n(?P<body>.*?)(?:\n\S|\Z)", publish, re.S)
    if not sbom_match:
        errors.append("could not find publish-sbom job in .github/workflows/publish.yml")
    else:
        sbom_body = sbom_match.group("body")
        default_continue = re.search(
            r"- variant: default\n"
            r"\s+element: oci/bluefin\.bst\n"
            r"\s+image_suffix: ''\n"
            r"\s+sbom_filename: dakota\.spdx\.json\n"
            r"\s+continue: true",
            sbom_body,
        )
        if not default_continue:
            errors.append("publish-sbom default variant must stay continue-on-error")
        if "continue-on-error: ${{ matrix.continue }}" not in sbom_body:
            errors.append("publish-sbom job must wire continue-on-error to the matrix")

    if publish.count("enable-remote-execution: 'false'") < 2:
        errors.append("publish export and SBOM jobs must remain local/fetch-only")
    if publish.count("enable-push: 'false'") < 2:
        errors.append("publish export and SBOM jobs must keep remote caches read-only")


def main() -> int:
    errors: list[str] = []
    publish = PUBLISH.read_text()
    build = BUILD.read_text()
    action = CI_CONFIG_ACTION.read_text()

    shell = extract_composite_shell(action)
    if shell is None:
        errors.append("could not find composite action shell in generate-bst-ci-config")
    else:
        check_generated_configs(shell, errors)

    check_build_workflow(build, errors)
    check_publish_workflow(publish, errors)

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print("build, publish, and BuildStream CI configuration checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
