# ChairLift migration fixtures

- `chairlift-brew` is an offline Bash test double. It operates only under the
  test's temporary prefix and never delegates to real Homebrew.
- `common-brew-preinstall` is an unmodified, test-only snapshot of
  `projectbluefin/common` at `5cb020bf868d5502cceb9ecd11ff859dd3a6c6e3`, path
  `system_files/shared/usr/libexec/brew-preinstall` (Apache-2.0 upstream).
  It supplies the `--external-chairlift` API merged in common #1100.
  It is not installed in the image and is not a downstream source patch.
  When advancing Dakota's common pin, refresh this snapshot and its reference
  from the same committed revision. The BST install guard rejects common
  without `external-chairlift-v1`.

The suite redirects the fixture's filesystem constants inside a temporary copy
and runs it against the mock Brew. These tests do not establish that live cask
hooks, GNOME launchers, or polkit work. Fresh-install, migration, offline failure,
and rollback boot tests remain required before deployment.
