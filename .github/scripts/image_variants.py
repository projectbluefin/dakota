#!/usr/bin/env python3
"""Derive GitHub Actions matrices from .github/image-variants.json.

`.github/image-variants.json` is the single declaration of the dakota image
variant set (issue #1434). This module projects that declaration into the
per-role `strategy.matrix.include` payloads consumed by publish.yml, and
validates that the declaration itself is internally consistent.

Usage:
    image_variants.py --role publish        # matrix JSON on stdout
    image_variants.py --check               # validate the declaration only
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

DECLARATION = Path(".github/image-variants.json")

# Derived role -> the publish.yml job whose matrix it governs.
CONSUMERS = {
    "publish": "publish-image",
    "sbom": "publish-sbom",
    "tag_testing": "promote",
}


class DeclarationError(Exception):
    """The variant declaration is malformed or internally inconsistent."""


def load(path: Path = DECLARATION) -> dict:
    try:
        return json.loads(path.read_text())
    except FileNotFoundError as exc:
        raise DeclarationError(f"{path} is missing") from exc
    except json.JSONDecodeError as exc:
        raise DeclarationError(f"{path} is not valid JSON: {exc}") from exc


def validate(declaration: dict) -> list[str]:
    """Return every consistency error found in the declaration."""
    errors: list[str] = []

    roles = declaration.get("roles")
    variants = declaration.get("variants")
    if not isinstance(roles, dict) or not roles:
        return ["image-variants.json must define a non-empty 'roles' object"]
    if not isinstance(variants, list) or not variants:
        return ["image-variants.json must define a non-empty 'variants' list"]

    for name, spec in roles.items():
        if not isinstance(spec.get("fields"), list) or not spec["fields"]:
            errors.append(f"role '{name}' must declare a non-empty 'fields' list")
        if not isinstance(spec.get("derived"), bool):
            errors.append(f"role '{name}' must declare a boolean 'derived'")
        if not spec.get("consumer"):
            errors.append(f"role '{name}' must name its 'consumer' workflow")

    seen_variants: set[str] = set()
    seen_images: set[str] = set()
    for entry in variants:
        variant = entry.get("variant")
        if not variant:
            errors.append("every variant must declare a 'variant' name")
            continue
        if variant in seen_variants:
            errors.append(f"variant '{variant}' is declared more than once")
        seen_variants.add(variant)

        image = entry.get("image")
        if not image:
            errors.append(f"variant '{variant}' must declare its published 'image'")
        elif image in seen_images:
            errors.append(f"image '{image}' is claimed by more than one variant")
        else:
            seen_images.add(image)

        memberships = entry.get("roles")
        if not isinstance(memberships, dict):
            errors.append(f"variant '{variant}' must declare a 'roles' object")
            continue

        # Membership is explicit in both directions: no role may be silently
        # omitted, and no variant may claim a role that does not exist.
        for role in roles:
            if role not in memberships:
                errors.append(
                    f"variant '{variant}' does not declare membership for role "
                    f"'{role}' — participation must be explicit, so state it or "
                    f'use {{"excluded": "<reason>"}}'
                )
        for role in memberships:
            if role not in roles:
                errors.append(
                    f"variant '{variant}' declares unknown role '{role}'"
                )

        for role, membership in memberships.items():
            if not isinstance(membership, dict):
                errors.append(
                    f"variant '{variant}' role '{role}' must be an object"
                )
                continue
            if "excluded" in membership and not str(membership["excluded"]).strip():
                errors.append(
                    f"variant '{variant}' is excluded from role '{role}' without a reason"
                )

    return errors


def matrix_for(declaration: dict, role: str) -> list[dict]:
    """Project the declaration into one role's matrix `include` entries."""
    roles = declaration.get("roles", {})
    if role not in roles:
        raise DeclarationError(f"unknown role '{role}'")

    fields = roles[role]["fields"]
    include: list[dict] = []
    for entry in declaration["variants"]:
        membership = entry.get("roles", {}).get(role)
        if membership is None or "excluded" in membership:
            continue

        # Role-local overrides (e.g. per-role `continue`) win over the
        # variant-level metadata they shadow.
        source = {**entry, **membership}
        include.append(
            {field: source[field] for field in fields if field in source}
        )
    return include


def _scalar(raw: str):
    """Coerce a YAML scalar. Quoting is significant: 'true' is a string."""
    raw = raw.strip()
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "'\"":
        return raw[1:-1]
    if raw == "true":
        return True
    if raw == "false":
        return False
    return raw


def parse_workflow_matrix(workflow: str, job: str) -> list[dict] | None:
    """Extract a job's inline `matrix.include` entries from workflow YAML text.

    Deliberately dependency-free: the blocks are a flat list of scalar
    key/value pairs, and the validation gate must not require PyYAML to be
    present on the runner.
    """
    job_match = re.search(
        rf"^  {re.escape(job)}:$\n(?P<body>(?:^(?:    .*)?$\n)*)",
        workflow,
        re.M,
    )
    if not job_match:
        return None

    body = job_match.group("body")
    include_match = re.search(r"^(?P<indent> +)include:[ \t]*$\n", body, re.M)
    if not include_match:
        return None

    base = len(include_match.group("indent"))
    entries: list[dict] = []
    for line in body[include_match.end():].splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())
        if indent <= base:
            break

        stripped = line.strip()
        if stripped.startswith("- "):
            entries.append({})
            stripped = stripped[2:]
        if not entries or ":" not in stripped:
            continue
        key, _, value = stripped.partition(":")
        entries[-1][key.strip()] = _scalar(value)

    return entries


def check_workflow_drift(declaration: dict, workflow: str, consumers: dict) -> list[str]:
    """Verify each inline matrix still equals what the declaration derives.

    Until publish.yml can consume the declaration directly, this is the gate
    that keeps the restated copies from drifting away from it.
    """
    errors: list[str] = []
    for role, job in consumers.items():
        inline = parse_workflow_matrix(workflow, job)
        if inline is None:
            errors.append(f"could not parse the '{job}' matrix in publish.yml")
            continue
        expected = matrix_for(declaration, role)
        if inline != expected:
            errors.append(
                f"job '{job}' has drifted from .github/image-variants.json "
                f"(role '{role}').\n  workflow:    {json.dumps(inline)}\n"
                f"  declaration: {json.dumps(expected)}"
            )
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--role", help="emit the matrix include list for this role")
    parser.add_argument(
        "--check",
        action="store_true",
        help="validate the declaration and its agreement with publish.yml",
    )
    parser.add_argument(
        "--file", type=Path, default=DECLARATION, help="path to image-variants.json"
    )
    parser.add_argument(
        "--workflow",
        type=Path,
        default=Path(".github/workflows/publish.yml"),
        help="publish workflow checked for drift by --check",
    )
    args = parser.parse_args(argv)

    if not args.role and not args.check:
        parser.error("one of --role or --check is required")

    try:
        declaration = load(args.file)
    except DeclarationError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    errors = validate(declaration)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    if args.role:
        try:
            print(json.dumps(matrix_for(declaration, args.role)))
        except DeclarationError as exc:
            print(str(exc), file=sys.stderr)
            return 1
        return 0

    drift = check_workflow_drift(declaration, args.workflow.read_text(), CONSUMERS)
    if drift:
        for error in drift:
            print(error, file=sys.stderr)
        return 1

    print(
        f"image-variants.json declares {len(declaration['variants'])} variants; "
        f"{len(CONSUMERS)} publish.yml matrices agree"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
