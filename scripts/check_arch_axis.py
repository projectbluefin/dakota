#!/usr/bin/env python3
"""check_arch_axis.py — keep dakota's CPU-arch axis fail-closed.

``project.conf`` declares exactly one CPU-arch axis::

    options:
      arch:
        type: arch
        values:
          - aarch64
          - x86_64

Every ``arch == "<value>"`` conditional in the project — in ``project.conf``
itself, in ``include/*.yml`` and in ``elements/**/*.bst`` — is resolved against
*that* option, including the ones inside junction ``config.options`` blocks
(junction options are evaluated in the parent project's option space).

Two failure modes are possible and neither is reported by BuildStream, because
a conditional whose value is never selected simply never fires:

  A. A conditional names an arch that is not in ``values``. The branch is
     unreachable dead configuration. It looks like support and is not.
  B. ``project.conf``'s ``variables`` arch switch defines a variable on some
     arch branches but not all of them, or omits a declared arch entirely.
     ``%{that-variable}`` then fails to resolve — or silently resolves to an
     inherited value — only on the arch that was forgotten.

Both fail *open*: the drift is invisible until somebody builds the arch that
was missed. This gate makes them fail closed at validate time.

Usage::

    python3 scripts/check_arch_axis.py
    python3 scripts/check_arch_axis.py --root /path/to/checkout
"""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys

# `arch == 'x86_64'` / `arch == "x86_64"`, as written in BuildStream `(?)`
# conditional keys. Whitespace around `==` is not significant to BuildStream.
ARCH_CONDITIONAL_RE = re.compile(r"""\barch\s*==\s*['"](?P<value>[^'"]+)['"]""")

SCAN_GLOBS = ("project.conf", "include/*.yml", "elements/**/*.bst")


def declared_arch_values(project_conf: str) -> list[str]:
    """Return the value list of the ``arch`` option in ``project.conf``.

    Hand-parsed rather than loaded with PyYAML: this gate runs in the CI
    validate job before any Python dependency is installed, and BuildStream
    project files carry custom ``(?)``/``(@)`` keys that a plain YAML load
    would not interpret the way BuildStream does anyway.
    """
    lines = project_conf.splitlines()

    option_indent = None
    in_values = None
    values: list[str] = []

    for raw in lines:
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())

        if option_indent is None:
            if re.match(r"^\s*arch:\s*$", line):
                option_indent = indent
            continue

        # Dedent past the `arch:` block ends the search.
        if indent <= option_indent:
            break

        if in_values is None:
            if re.match(r"^\s*values:\s*$", line):
                in_values = indent
            continue

        if indent <= in_values:
            break

        item = re.match(r"^\s*-\s*(?P<value>\S+)\s*$", line)
        if item:
            values.append(item.group("value").strip("'\""))

    if option_indent is None or in_values is None:
        raise ValueError(
            "could not locate options.arch.values in project.conf — "
            "check_arch_axis.py must be updated alongside that declaration"
        )
    return values


def variables_arch_branches(project_conf: str) -> dict[str, set[str]]:
    """Map each arch named in ``project.conf``'s top-level ``variables`` switch
    to the set of variable names that branch defines.

    Only the ``variables:`` block at column 0 is considered; that is the block
    that establishes project-wide arch identity.
    """
    lines = project_conf.splitlines()

    in_variables = False
    branches: dict[str, set[str]] = {}
    current: str | None = None
    branch_indent: int | None = None

    for raw in lines:
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())

        if not in_variables:
            if line == "variables:":
                in_variables = True
            continue

        if indent == 0:
            break

        match = ARCH_CONDITIONAL_RE.search(line)
        if match and line.rstrip().endswith(":"):
            current = match.group("value")
            branch_indent = indent
            branches.setdefault(current, set())
            continue

        if current is None or branch_indent is None:
            continue

        if indent <= branch_indent:
            # Left this arch branch (sibling branch or end of the switch).
            current = None
            branch_indent = None
            continue

        key = re.match(r"^\s*(?P<name>[A-Za-z0-9_.\-]+):", line)
        if key:
            branches[current].add(key.group("name"))

    return branches


def scan_conditionals(root: Path) -> list[tuple[Path, int, str]]:
    """Return every ``arch == "<value>"`` occurrence as (path, lineno, value)."""
    found: list[tuple[Path, int, str]] = []
    seen: set[Path] = set()

    for pattern in SCAN_GLOBS:
        for path in sorted(root.glob(pattern)):
            if not path.is_file() or path in seen:
                continue
            seen.add(path)
            text = path.read_text(encoding="utf-8", errors="replace")
            for lineno, line in enumerate(text.splitlines(), start=1):
                if line.lstrip().startswith("#"):
                    continue
                for match in ARCH_CONDITIONAL_RE.finditer(line):
                    found.append(
                        (path.relative_to(root), lineno, match.group("value"))
                    )
    return found


def check(root: Path) -> list[str]:
    errors: list[str] = []

    project_conf_path = root / "project.conf"
    project_conf = project_conf_path.read_text(encoding="utf-8")

    declared = declared_arch_values(project_conf)
    declared_set = set(declared)

    # A. No conditional may name an arch the axis does not declare.
    for path, lineno, value in scan_conditionals(root):
        if value not in declared_set:
            errors.append(
                f"{path}:{lineno}: unreachable conditional `arch == \"{value}\"` — "
                f"project.conf declares options.arch.values = {declared}. "
                "Either add the arch to the axis or delete the branch."
            )

    # B. The project-wide variables switch must cover every declared arch and
    #    define the same variable names on each of them.
    branches = variables_arch_branches(project_conf)
    reachable = {arch: names for arch, names in branches.items() if arch in declared_set}

    missing_branches = [arch for arch in declared if arch not in branches]
    if branches and missing_branches:
        errors.append(
            "project.conf: variables arch switch has no branch for "
            f"{missing_branches} — every declared arch must state its values "
            "explicitly rather than inheriting them by omission."
        )

    if len(reachable) > 1:
        union: set[str] = set()
        for names in reachable.values():
            union |= names
        for arch in sorted(reachable):
            gaps = sorted(union - reachable[arch])
            if gaps:
                errors.append(
                    f"project.conf: variables arch branch `{arch}` does not define "
                    f"{gaps}, but another arch branch does. A variable defined on "
                    "some arches and not others fails only on the arch that was "
                    "forgotten."
                )

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        default=str(Path(__file__).resolve().parent.parent),
        help="project root containing project.conf (default: repository root)",
    )
    args = parser.parse_args(argv)

    errors = check(Path(args.root))
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("arch axis checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
