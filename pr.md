## What problem are you solving?

Publish Smoke has failed on every run since 2026-09-18 (#1305). Publish itself succeeds; Smoke then fails to resolve `ghcr.io/projectbluefin/dakota:<sha>` for a SHA that was never pushed.

## Cause

Smoke is the second hop of a `workflow_run` chain: Build → Publish → Smoke. Publish reads the built commit from its own `github.event.workflow_run.head_sha` (the Build run). But by the time it reaches Smoke, `github.event.workflow_run.head_sha` is the *Publish* run's head — and for a `workflow_run`-triggered run that is the default-branch tip at trigger time, not the commit that was built.

The two only coincide for a `testing` push nothing has moved past. Every `next`-stream Publish (back since #1590 on 09-18) breaks it. Example from this morning: Publish run 35434468946 built and promoted `953bd508` (`chore(next): restore next-stream junctions…`); Smoke asked for `b71fac57` (the `testing` tip) and got `cannot resolve digest`.

## Fix

Publish already writes the SHA it published into the `digest-default` artifact. `wait-for-images` now downloads that artifact first, reads `.sha`, uses it for both `resolve-image-digest` verifications, and exports it as a job output that the `smoke` matrix uses for the image tag. If the artifact has no usable SHA the job fails loudly rather than guessing.

## Testing

- `actionlint` (v1.7.12) clean on the modified workflow
- `python3 scripts/check_publish_workflow.py` and `scripts.test_check_publish_workflow` pass
- Can only be exercised for real by the next Publish on `testing`/`next` after merge; the failure mode it fixes is reproducible from any recent Publish Smoke run (compare Publish's `setup` `sha` output with Smoke's `wait-for-images` log).

Closes #1305

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01VXwvRu29c2MkwftzkgAHcC
