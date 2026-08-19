---
name: dakota-image
description: OCI layer assembly, boot testing, installer boundaries, VM work, and local OTA verification for Dakota images.
---

# Dakota image integration

Use this skill when filesystem content crosses from BuildStream artifacts into
OCI layers or when validating an installed/booted image.

## OCI assembly

- Filesystem-producing layer elements use `kind: compose`. A `stack` artifact is
  empty and must not be staged as `/layer`.
- Read the full compose chain under `elements/oci/layers/` before changing
  include/exclude filters.
- Integration commands run after dependencies are staged; avoid silently
  overwriting files from earlier layers.
- Keep development/debug domains out of runtime composition unless required.
- Run `ldconfig -r /layer` at the location required by
  [`docs/oci-assembly.md`](../../../docs/oci-assembly.md).

## Verification ladder

1. `just validate` — graph and patch correctness.
2. Build the narrowest affected element or image variant.
3. `just lint` — bootc container structure after export.
4. `just boot-test` for automated boot evidence, or `just boot-fast` for focused
   interactive diagnosis.
5. Use hardware OTA testing only when the change requires hardware evidence;
   follow [`references/local-ota.md`](references/local-ota.md).

Do not require the most expensive step when a narrower check fully exercises a
non-image change. Do not claim a boot result that was not actually run.

## Installer boundary

| Responsibility | Repository |
|---|---|
| Installed OCI image and firstboot cleanup | `projectbluefin/dakota` |
| Live ISO and installer bundling | `projectbluefin/dakota-iso` |
| GTK installer | `projectbluefin/bootc-installer` |
| Installer backend | `tuna-os/fisherman` |

The installed system must remove installer-only Flatpaks during first boot.
Changes to installer UI or disk-install behavior belong in the owning upstream
repository; Dakota owns the resulting installed image.

## References

- [`docs/oci-assembly.md`](../../../docs/oci-assembly.md)
- [`references/local-ota.md`](references/local-ota.md)
- [`elements/oci/`](../../../elements/oci/)
- [`files/firstboot/`](../../../files/firstboot/)
