#!/usr/bin/env python3
"""Keep dakota's CPU-arch conditionals in agreement with the arch axis.

`project.conf` declares the CPU-arch axis exactly once, under
`options.arch.values`. Every `arch == "<value>"` / `arch in [...]`
conditional in the project — including the ones inside the junction
`config.options` block of `elements/freedesktop-sdk.bst`, which are
evaluated in *this* project's option space — resolves against that axis.

BuildStream never warns about a conditional whose value can never be
selected, and it never warns about a variable that a sibling arch branch
defines and this one does not. Both failure modes are silent, so this
checker makes them fail closed:

  R1  no arch conditional may name a value outside options.arch.values;
  R2  project.conf's top-level `variables` arch switch must have a branch
      for every declared arch, and every branch must define the same
      variable names.

R2 is the rule that matters for growth: adding a third architecture then
fails here, at validate time, instead of failing open at build time on the
arch whose branch nobody remembered.
"""

from pathlib import Path
import re
import sys


ROOT = Path(".")
PROJECT_CONF = ROOT / "project.conf"

# Files whose arch conditionals resolve against this project's arch option.
SCAN_GLOBS = ("project.conf", "include/*.yml", "elements/**/*.bst")

EQUALITY = re.compile(r"""\barch\s*(?:==|!=)\s*['"](?P<value>[^'"]+)['"]""")
MEMBERSHIP = re.compile(r"""\barch\s+(?:not\s+in|in)\s*\[(?P<values>[^\]]*)\]""")
LIST_MEMBER = re.compile(r"""['"]([^'"]+)['"]""")


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip())


def block_lines(lines: list[str], start: int) -> list[tuple[int, str]]:
    """Return the (index, line) pairs indented deeper than lines[start]."""
    base = indent_of(lines[start])
    out = []
    for index in range(start + 1, len(lines)):
        line = lines[index]
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if indent_of(line) <= base:
            break
        out.append((index, line))
    return out


def find_key(lines: list[str], key: str, *, within: list[tuple[int, str]] | None = None):
    """Index of the first line declaring `key:` (optionally inside a block)."""
    candidates = within if within is not None else list(enumerate(lines))
    pattern = re.compile(rf"^\s*{re.escape(key)}:\s*(?:#.*)?$")
    for index, line in candidates:
        if pattern.match(line):
            return index
    return None


def parse_declared_arches(text: str, errors: list[str]) -> list[str]:
    lines = text.splitlines()
    options = find_key(lines, "options")
    if options is None:
        errors.append("project.conf: no top-level `options:` block")
        return []

    arch = find_key(lines, "arch", within=block_lines(lines, options))
    if arch is None:
        errors.append("project.conf: `options:` declares no `arch:` option")
        return []

    values = find_key(lines, "values", within=block_lines(lines, arch))
    if values is None:
        errors.append("project.conf: `options.arch` declares no `values:`")
        return []

    declared = []
    for _, line in block_lines(lines, values):
        item = line.strip()
        if item.startswith("- "):
            declared.append(item[2:].strip().strip("'\""))
    if not declared:
        errors.append("project.conf: `options.arch.values` is empty")
    return declared


def conditional_expression(line: str) -> str | None:
    """The expression of a BuildStream conditional line, else None.

    Conditionals are always a list item that opens a block: `- <expr>:`.
    Matching that shape keeps `arch != "NATIVE"` inside an embedded awk or
    shell fragment from being read as an option conditional.
    """
    stripped = line.strip()
    if not stripped.startswith("- "):
        return None
    stripped = re.sub(r"\s+#.*$", "", stripped).rstrip()
    if not stripped.endswith(":"):
        return None
    return stripped[2:-1].strip()


def conditional_arches(text: str) -> list[tuple[int, str]]:
    """Every arch value named by a conditional, as (line number, value)."""
    found = []
    for number, line in enumerate(text.splitlines(), start=1):
        expression = conditional_expression(line)
        if expression is None:
            continue
        for match in EQUALITY.finditer(expression):
            found.append((number, match.group("value")))
        for match in MEMBERSHIP.finditer(expression):
            for member in LIST_MEMBER.findall(match.group("values")):
                found.append((number, member))
    return found


def check_conditionals(declared: list[str], errors: list[str]) -> None:
    paths = []
    for glob in SCAN_GLOBS:
        paths.extend(sorted(ROOT.glob(glob)))

    allowed = set(declared)
    for path in paths:
        for number, value in conditional_arches(path.read_text()):
            if value not in allowed:
                errors.append(
                    f"{path}:{number}: conditional names arch {value!r}, which is "
                    f"not in project.conf options.arch.values "
                    f"({', '.join(declared)}) — the branch can never be selected"
                )


def parse_variables_switch(text: str, errors: list[str]) -> dict[str, set[str]]:
    """Map each arch branch of project.conf's `variables` switch to its keys."""
    lines = text.splitlines()
    variables = find_key(lines, "variables")
    if variables is None:
        errors.append("project.conf: no top-level `variables:` block")
        return {}

    switch = find_key(lines, r"(?)", within=block_lines(lines, variables))
    if switch is None:
        errors.append("project.conf: `variables:` has no `(?):` arch switch")
        return {}

    branches: dict[str, set[str]] = {}
    current = None
    current_indent = None
    for _, line in block_lines(lines, switch):
        expression = conditional_expression(line)
        header = EQUALITY.match(expression) if expression else None
        if header:
            current = header.group("value")
            current_indent = indent_of(line)
            if current in branches:
                errors.append(
                    f"project.conf: `variables` switch declares arch "
                    f"{current!r} more than once"
                )
            branches[current] = set()
            continue
        if current is None or current_indent is None:
            continue
        if indent_of(line) <= current_indent:
            current = None
            continue
        key = re.match(r"^\s*(?P<key>[\w.\-]+):", line)
        if key:
            branches[current].add(key.group("key"))
    return branches


def check_variables_switch(declared: list[str], errors: list[str], text: str) -> None:
    branches = parse_variables_switch(text, errors)
    if not branches:
        return

    for arch in declared:
        if arch not in branches:
            errors.append(
                f"project.conf: `variables` switch has no branch for declared arch "
                f"{arch!r} — every variable it defines would be unset there"
            )

    union: set[str] = set()
    for keys in branches.values():
        union |= keys
    for arch in sorted(branches):
        missing = union - branches[arch]
        if missing:
            errors.append(
                f"project.conf: `variables` branch {arch!r} does not define "
                f"{', '.join(sorted(missing))} — sibling arch branches do, so the "
                f"variable resolves inconsistently across the arch axis"
            )


def main() -> int:
    errors: list[str] = []
    if not PROJECT_CONF.exists():
        print(f"{PROJECT_CONF}: not found", file=sys.stderr)
        return 1

    text = PROJECT_CONF.read_text()
    declared = parse_declared_arches(text, errors)
    if declared:
        check_conditionals(declared, errors)
        check_variables_switch(declared, errors, text)

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print(f"arch axis checks passed ({', '.join(declared)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
