# Patch management

Patches apply in **alphabetical filename order**. Numbers in filenames control application order.

## Lifecycle

```text
Add patch → Upstream-Status header → track upstream PR →
upstream merges → junction bump includes fix → drop patch
```

Every patch is maintenance debt. Drop as soon as it's upstream.

## Junction bumps

When bumping a junction: verify every patch in the relevant `patches/` directory still applies; update or drop any that target a `ref:` no longer in the new junction. Kernel patches (`patches/linux/`) apply against kernel source — verify against the new kernel version too.

## Required header

Every patch must have an `Upstream-Status:` header:

| Value | Meaning |
|---|---|
| `Submitted` | PR or MR opened upstream |
| `Accepted` | Upstream merged, waiting for junction bump |
| `Pending` | Not yet submitted |
| `Not-applicable` | Dakota-specific, will never go upstream |

Include upstream commit or PR link when backporting.

## Exit conditions

Document the exit condition in the patch header:

```text
# Exit: Drop when fdsdk bumps to X.Y
# Exit: Drop after GBM gnome-50 reaches commit abc123
```
