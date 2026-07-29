#!/usr/bin/env python3
from pathlib import Path
import sys

execute = Path('.github/workflows/execute-release.yml').read_text()
rollback = Path('.github/workflows/rollback-stable.yml').read_text()
errors = []

if 'resolve-stable-source-digests:' not in execute:
    errors.append('execute-release must resolve stable source digests before reconciliation')
if 'source_digests: ${{ steps.resolve.outputs.source_digests }}' not in execute:
    errors.append('execute-release must expose source_digests from the stable source resolver job')
if '"dakota":{"required":true}' not in execute:
    errors.append('execute-release must treat dakota as the required stable variant')
if '"dakota-nvidia":{"required":false}' not in execute:
    errors.append('execute-release must keep dakota-nvidia optional in recovery planning')
if '"dakota-gaming":{"required":false}' not in execute:
    errors.append('execute-release must keep dakota-gaming optional in recovery planning')
if 'SOURCE_DIGESTS_JSON: ${{ needs.resolve-stable-source-digests.outputs.source_digests }}' not in execute:
    errors.append('execute-release reconciliation must consume source_digests from the resolver job')
if 'known_manifest_absence()' not in execute:
    errors.append('execute-release must classify known manifest absence explicitly before skipping optional variants')
if 'manifest unknown' not in execute:
    errors.append('execute-release must match manifest-unknown errors before treating an optional variant as absent')
if '[ "${required}" != "true" ] && [ "${status}" -eq 2 ] && known_manifest_absence "${inspect_output}"' not in execute:
    errors.append('execute-release must only skip optional variants for classified manifest-not-found responses')
if 'skopeo inspect failed for ${ref} (attempt ${attempt}/3, exit ${status}); retrying in 10s.' not in execute:
    errors.append('execute-release must retry source digest inspection before skipping or failing')
if 'Optional stable variant ${ref} is genuinely absent after ${attempt} attempts; recovery will skip it.' not in execute:
    errors.append('execute-release must report classified optional absences after retries')
if 'restore_all_snapshots()' not in execute:
    errors.append('execute-release reconciliation must restore the full snapshotted stable set on failure')
if 'promoted_digests["${image}"]="$(inspect_digest "${image}" "${BUILD_SHA}")"' in execute:
    errors.append('execute-release reconciliation must not require every BUILD_SHA source digest')
if 'restore_pair "${image}"' in execute:
    errors.append('execute-release reconciliation must not restore only one image on failure')
if 'inspect_optional_source_digest()' in execute:
    errors.append('execute-release must not treat every source inspect failure as optional absence')

if 'restore_all_snapshots()' not in rollback:
    errors.append('rollback-stable must restore the full snapshotted stable set on failure')
if 'restore_pair "${image}"' in rollback:
    errors.append('rollback-stable must not restore only the current image on failure')

if errors:
    for err in errors:
        print(err, file=sys.stderr)
    sys.exit(1)

print('release recovery workflows look sane')
