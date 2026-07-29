#!/usr/bin/env python3
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


MAX_SKILL_BYTES = 20_000
MAX_SKILL_LINES = 400
LEGACY_ROUTERS = {
    "docs/skills/README.md",
    "docs/skills/INDEX.md",
    ".github/copilot-instructions.md",
}
STALE_ARTIFACT_NAMES = {
    "CHANGELOG.md",
    "CHANGES.md",
    "IMPROVEMENTS.md",
    "NOTES.md",
    "PLAN.md",
    "SESSION.md",
    "TODO.md",
}
STALE_HEADING_TITLES = {
    "changelog",
    "changes",
    "history",
    "improvements",
    "notes",
    "plan",
    "retrospective",
    "session notes",
    "status snapshot",
    "todo",
}
SKILL_ROOT = Path("docs/skills")
SKILL_ROUTER = SKILL_ROOT / "index.md"
MARKDOWN_SUFFIX = ".md"
SYNCED_MARKDOWN_TEMPLATES = {
    Path(".github/PULL_REQUEST_TEMPLATE.md"),
}


def run_git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "git command failed"
        raise RuntimeError(message)
    return result.stdout


def repo_root() -> Path:
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=Path.cwd(),
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "not inside a git repository")
    return Path(result.stdout.strip())


def tracked_markdown_files(root: Path) -> list[Path]:
    output = run_git(root, "ls-files", "-z", "--", f"*{MARKDOWN_SUFFIX}")
    return [Path(item) for item in output.split("\0") if item]


def is_fenced_line(line: str) -> tuple[bool, str, int]:
    match = re.match(r"^(\s*)(`{3,}|~{3,})", line)
    if not match:
        return False, "", 0
    fence = match.group(2)[0]
    return True, fence, len(match.group(2))


def parse_frontmatter(text: str) -> tuple[dict[str, str], int]:
    if not text.startswith("---\n"):
        return {}, 0
    end = text.find("\n---\n", 4)
    if end == -1:
        return {}, 0
    body = text[4:end].splitlines()
    fields: dict[str, str] = {}
    for line in body:
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        fields[key.strip()] = value.strip()
    return fields, end + len("\n---\n")


def line_contains_banned_text(line: str) -> list[str]:
    errors: list[str] = []
    if re.search(r"docs/skills/(?!index\.md\b)[A-Za-z0-9][^/\s]*\.md", line):
        errors.append("legacy router path")
    for name in STALE_ARTIFACT_NAMES:
        if name in line:
            errors.append(f"stale planning/history artifact name: {name}")
    if "copilot-instructions.md" in line:
        errors.append("client-specific instruction string: .github/copilot-instructions.md")
    return errors


def line_contains_banned_heading(line: str) -> list[str]:
    match = re.match(r"^#{1,6}\s+(.+?)\s*$", line)
    if not match:
        return []
    heading = re.sub(r"\s+", " ", match.group(1)).casefold()
    if heading in STALE_HEADING_TITLES:
        return [f"stale planning/history heading: {match.group(1)}"]
    return []


def is_skill_tree_path(file_path: Path) -> bool:
    return file_path.parts[:2] == ("docs", "skills") and file_path.name == "SKILL.md"


def is_skill_router_path(file_path: Path) -> bool:
    return file_path == SKILL_ROUTER


def is_canonical_skill_path(file_path: Path) -> bool:
    return is_skill_tree_path(file_path) and len(file_path.parts) == 4


def skips_contract_text_rules(file_path: Path) -> bool:
    return file_path.parts[:2] == ("docs", "superpowers")


def skips_heading_rules(file_path: Path) -> bool:
    return (
        file_path.parts[:3] == ("files", "hive", "agent-policies")
        or file_path in SYNCED_MARKDOWN_TEMPLATES
    )


def validate_relative_link(root: Path, file_path: Path, target: str) -> list[str]:
    stripped = target.split("#", 1)[0].split("?", 1)[0].strip()
    if not stripped or re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", stripped):
        return []
    if stripped.startswith("/"):
        return []
    if stripped in LEGACY_ROUTERS:
        return [f"{file_path}: legacy router path: {stripped}"]
    if not stripped.endswith(MARKDOWN_SUFFIX) and not stripped.endswith("/"):
        return []

    resolved = (file_path.parent / stripped).resolve()
    try:
        resolved.relative_to(root.resolve())
    except ValueError:
        return [f"{file_path}: broken relative markdown link: {target}"]
    if resolved.is_dir():
        resolved = resolved / "README.md"
    if not resolved.exists():
        return [f"{file_path}: broken relative markdown link: {target}"]
    return []


def validate_markdown_file(root: Path, file_path: Path) -> list[str]:
    errors: list[str] = []
    text = (root / file_path).read_text()

    if file_path.as_posix() in LEGACY_ROUTERS:
        errors.append(f"{file_path}: legacy router path: {file_path.as_posix()}")

    if file_path.parts[:2] == ("docs", "skills") and not (
        is_canonical_skill_path(file_path) or is_skill_router_path(file_path)
    ):
        errors.append(
            f"{file_path}: skill modules must live at docs/skills/<topic>/SKILL.md"
        )

    if is_skill_tree_path(file_path):
        if len(text.encode()) > MAX_SKILL_BYTES:
            errors.append(
                f"{file_path}: skill module exceeds size budget of {MAX_SKILL_BYTES} bytes"
            )
        if len(text.splitlines()) > MAX_SKILL_LINES:
            errors.append(
                f"{file_path}: skill module exceeds size budget of {MAX_SKILL_LINES} lines"
            )

        frontmatter, frontmatter_end = parse_frontmatter(text)
        if not frontmatter or "name" not in frontmatter or "description" not in frontmatter:
            errors.append(f"{file_path}: missing frontmatter name/description")
        scan_text = text[frontmatter_end:] if frontmatter_end else text
    else:
        scan_text = text

    in_fence = False
    fence_char = ""
    fence_len = 0
    h1_count = 0
    previous_heading = 0
    enforce_text_rules = not skips_contract_text_rules(file_path)
    enforce_heading_rules = not skips_heading_rules(file_path)
    link_pattern = re.compile(r"(?<!\!)\[[^\]]+\]\(([^)]+)\)")
    heading_pattern = re.compile(r"^(#{1,6})\s+\S")

    for line_number, raw_line in enumerate(scan_text.splitlines(), start=1):
        line = raw_line.rstrip("\n")
        fence_open, char, length = is_fenced_line(line)
        if fence_open:
            if not in_fence:
                in_fence = True
                fence_char = char
                fence_len = length
            elif char == fence_char and length >= fence_len:
                in_fence = False
                fence_char = ""
                fence_len = 0
            continue
        if in_fence:
            continue

        if enforce_text_rules:
            errors.extend(
                f"{file_path}:{line_number}: {message}"
                for message in line_contains_banned_text(line)
            )

        if enforce_heading_rules:
            errors.extend(
                f"{file_path}:{line_number}: {message}"
                for message in line_contains_banned_heading(line)
            )

        for target in link_pattern.findall(line):
            errors.extend(validate_relative_link(root, file_path, target))

        heading = heading_pattern.match(line)
        if heading and enforce_heading_rules:
            level = len(heading.group(1))
            if level == 1:
                h1_count += 1
                if h1_count > 1:
                    errors.append(f"{file_path}:{line_number}: at most one H1")
            if previous_heading and level > previous_heading + 1:
                errors.append(
                    f"{file_path}:{line_number}: sequential heading levels broken ({previous_heading} -> {level})"
                )
            previous_heading = level

    if is_skill_tree_path(file_path) and h1_count != 1:
        errors.append(f"{file_path}: expected exactly one H1")

    return errors


def main() -> int:
    try:
        root = repo_root()
        errors: list[str] = []
        for file_path in tracked_markdown_files(root):
            errors.extend(validate_markdown_file(root, file_path))
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print("docs contract check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
