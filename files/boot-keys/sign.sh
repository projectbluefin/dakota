#!/usr/bin/env bash
# Sign kernel modules and EFI binaries with the Dakota Secure Boot key.
# Runs inside the signing elements, which stage files/boot-keys as their
# source, so the key and certificate paths are relative to the build root.
#
# Usage: sign.sh modules <modules-root>
#        sign.sh efi <input.efi> <output.efi>
set -euo pipefail

key=private/secure-boot.key
cert=modules/linux-module-cert.crt

if [ ! -s "$key" ]; then
    echo "FATAL: no signing key at $key; CI writes it from DAKOTA_SECURE_BOOT_KEY" >&2
    exit 1
fi
if [ ! -s "$cert" ]; then
    echo "FATAL: no certificate at $cert; generate one with just secure-boot-keygen" >&2
    exit 1
fi

# A key that does not match the certificate compiled into the kernel and
# enrolled as the MOK yields binaries that fail verification; fail the
# build instead.
if [ "$(openssl pkey -in "$key" -pubout)" != "$(openssl x509 -in "$cert" -pubkey -noout)" ]; then
    echo "FATAL: signing key does not match $cert" >&2
    exit 1
fi

sign_modules() {
    local root="$1" count=0 mod ko
    openssl x509 -in "$cert" -outform DER -out signing-cert.der
    # Compressed modules are decompressed, signed, and recompressed the way
    # kbuild's modules_install compresses them.
    while IFS= read -r -d '' mod; do
        ko="${mod%.zst}"
        if [ "$ko" != "$mod" ]; then
            zstd -d -q --rm "$mod"
        fi
        sign-file sha512 "$key" signing-cert.der "$ko"
        if [ "$ko" != "$mod" ]; then
            zstd -T0 -q --rm "$ko"
        fi
        count=$((count + 1))
    done < <(find "$root" -type f \( -name '*.ko' -o -name '*.ko.zst' \) -print0)

    if [ "$count" -eq 0 ]; then
        echo "FATAL: no kernel modules found under $root" >&2
        exit 1
    fi
    echo "Signed $count kernel modules"
}

# Authenticode signatures carry a signing time. sbsign always stamps the
# current time, so every CI run would produce a different vmlinuz and users
# would download the kernel modules layer on every update. systemd-sbsign
# takes the time from SOURCE_DATE_EPOCH instead. Pin it to the
# certificate's notBefore rather than BuildStream's 2011 epoch: the
# kernel's PKCS#7 verifier rejects signing times outside the certificate's
# validity window.
sign_efi() {
    local input="$1" output="$2" epoch
    epoch="$(date -u -d "$(openssl x509 -in "$cert" -noout -startdate | cut -d= -f2)" +%s)"
    SOURCE_DATE_EPOCH="$epoch" /usr/lib/systemd/systemd-sbsign sign \
        --private-key="$key" --certificate="$cert" --output="$output" "$input"
    sbverify --cert "$cert" "$output"
}

case "${1:-}" in
    modules) sign_modules "$2" ;;
    efi) sign_efi "$2" "$3" ;;
    *)
        echo "usage: sign.sh modules <root> | sign.sh efi <in> <out>" >&2
        exit 2
        ;;
esac
