---
name: dakota-image
description: Ghost Lab exact-SHA builds, artifact inspection, OCI layer assembly, and container GUI verification for Dakota; distinguish these from boot and OTA evidence.
metadata:
  verified-sources:
    - https://argo-workflows.readthedocs.io/en/latest/cli/argo_submit/
---

# Dakota Image Integration

## When to Use

- Building or inspecting a Dakota candidate on Ghost Lab
- Modifying layer composition under `elements/oci/layers/`
- Changing post-install integration in `elements/oci/bluefin.bst`
- Verifying a candidate's container GUI or evaluating boot/OTA evidence
- Enforcing the installer boundary between Dakota and live installer tools

## When NOT to Use

- Source package changes → also load `dakota-packaging`
- GNOME Shell extension packaging → also load `dakota-extensions`
- GitHub Actions export or publication changes → load `dakota-ci`

## Core Process

1. **Compose layers** with `kind: compose`; build dependencies define their contents.
2. **Order post-install integration**: `systemd-sysusers --root /layer`, schema compilation, `dconf update /layer/etc/dconf/db`, then `ldconfig -r /layer` LAST before `build-oci`. Every library change must precede the linker-cache update.
3. **Build and inspect on Ghost Lab** using the procedure below. Local `just check-publish-workflow` and `just test-render-card` are permitted non-BST checks. Run the BST graph portion of `just validate` on the lab, not the workstation.
4. **Exercise the exact candidate** through Ghost Lab's current Dakota container GUI path. Check the changed behavior in its active GNOME session, with logs and visual evidence. A container GUI result proves only that surface; it does not prove hardware boot, a VM boot, or transactional OTA.
5. **Report evidence boundaries**: record source SHA, workflow identity, image digest, candidate tag, and the runtime surface actually exercised. For a separately provisioned bootc target, read [`references/local-ota.md`](references/local-ota.md); no supported Dakota boot/OTA path is implied by the container GUI lane.

## Ghost Lab procedure

All BuildStream operations run inside Ghost Lab workloads launched or accessed with Argo/kubectl: builds, graph `show`, the BST portion of validation, shells, and artifact checkout. The workstation is only the submission/monitoring client. Do not run local `just bst`, `just build`, `just validate`, or export recipes that invoke BST. Do not SSH to cluster nodes or mutate GitOps-managed templates with live apply/patch; workflow changes belong in `projectbluefin/lab`.

1. Read the deployed inputs before submitting:

   ```bash
   kubectl -n argo get workflowtemplate dakota-build-pipeline -o yaml
   ```

   Compare with `projectbluefin/lab`'s `Justfile` and `argo/workflow-templates/dakota-build-pipeline.yaml`. The supported build inputs are `repo`, `ref`, `commit-sha`, `image-tag`, `registry`, and `variants`. Admission already enforces remote execution; there is no caller `build-mode` parameter.

2. Choose a pushed ref, its exact full Git SHA, and a unique candidate tag. `ref` must make the commit reachable from the selected repository. Use `variants=default` for the plain image; `all` requests the configured matrix. The lab's `just run-bst-build` accepts ref/repo/variants/SHA but leaves `image-tag` at `testing`, so use direct submission for isolated feature validation:

   ```bash
   REF=feat/example
   SHA=<full-pushed-git-sha>
   TAG=candidate-example-<short-sha>
   argo submit --from workflowtemplate/dakota-build-pipeline -n argo \
     -p repo=https://github.com/projectbluefin/dakota.git \
     -p ref="$REF" -p commit-sha="$SHA" -p image-tag="$TAG" \
     -p registry=192.168.1.102:30500 -p variants=default --watch
   ```

   Never overwrite `:testing` for candidate validation. Capture the generated workflow name; inspect its logs and resolved source SHA before attributing results to the candidate.

3. Perform any additional graph or artifact inspection in the lab build workload, using its source checkout and configured BST environment via kubectl. If that workload is no longer available, use a lab-owned workflow for the operation rather than falling back to workstation BST. A successful build is not proof that the final OCI compose retained the library, typelib, or loader cache.

4. Use the published candidate tag/digest explicitly for GUI QA. The lab's candidate-selectable container entrypoint is:

   ```bash
   # In the projectbluefin/lab checkout:
   just run-dakota-container-qa "$TAG" dakota
   ```

   Its container smoke results are not visual proof. Verify the same candidate in the active lab GNOME container GUI session and exercise the changed controls. Do not substitute a default-tag QA run or an already-running old image.

The [official Argo submit reference](https://argo-workflows.readthedocs.io/en/latest/cli/argo_submit/) documents `--from`, repeated `-p` inputs, namespace selection, and `--watch`.

## Invariants

- **Layer kind**: `kind: compose`, not `kind: stack`, for filesystem layers.
- **Linker cache**: `ldconfig -r /layer` runs after all library updates and before `build-oci`.
- **Installer separation**: Installer-specific Flatpaks/setup tools are purged via `files/firstboot/`; installer UI changes belong in `projectbluefin/bootc-installer`.
- **Evidence before assertion**: Build, container GUI, VM boot, hardware boot, and OTA are distinct claims; report only the path actually exercised.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Graph checks or checkout are not builds, so local BST is fine." | Every BST operation belongs on Ghost Lab. |
| "The recipe accepts an exact SHA, so it is safe for a candidate." | `run-bst-build` still defaults the published image tag to `testing`. |
| "The library built, so the layer is fine." | Compose filters and runtime loading still require inspection and behavioral proof. |
| "The container desktop works, so Dakota boots and upgrades." | Container GUI evidence proves neither boot nor OTA. |

## Red Flags

- Workstation BST execution, including `show` or artifact checkout
- Candidate publication to a shared testing tag
- A stale `build-mode` input or bypass of lab admission
- `kind: stack` in OCI filesystem layers or library writes after `ldconfig`
- Runtime claims based on an old image, file presence alone, or another verification surface

## Verification

- Source SHA and isolated candidate tag match the submitted workflow and published digest
- Graph and artifact inspections ran on Ghost Lab
- Final OCI includes required runtime libraries, typelibs, and linker-cache entries
- Changed behavior was exercised in the candidate's active container GNOME session
- Boot/OTA claims, if any, have separate target, reboot, and runtime evidence

## References

- [`docs/oci-assembly.md`](../../../docs/oci-assembly.md)
- [`references/local-ota.md`](references/local-ota.md)
- [`elements/oci/`](../../../elements/oci/)
- [`files/firstboot/`](../../../files/firstboot/)
