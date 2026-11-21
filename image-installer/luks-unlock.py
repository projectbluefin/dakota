#!/usr/bin/env python3
"""
Automate LUKS passphrase entry for a VM booting with Plymouth.

Vendored from projectbluefin/iso (src/luks-unlock.py, Apache-2.0) so Utah's
end-to-end test does not depend on a checkout of that repository. One change:
the QEMU monitor is driven through a plain UNIX socket rather than socat,
which is not packaged for this platform and cannot be installed here.

Plymouth renders the passphrase prompt on the EFI framebuffer (not the serial
console), so we cannot detect it via serial output.  Instead we detect the
Plymouth prompt by analysing QEMU screendumps (PPM files):

  - Plymouth passphrase prompt is a static, nearly all-black screen.
  - We wait for the screendump MD5 hash to stabilise (stop changing) after
    the framebuffer has first shown any non-zero content (OVMF/boot rendered).
  - Then inject keystrokes via virsh send-key (libvirt) or QEMU HMP sendkey.

Usage:
  libvirt mode:  luks-unlock.py libvirt <vm-name> <passphrase> <mac-address>
  qemu mode:     luks-unlock.py qemu    <monitor-sock> <passphrase> <serial-log>

Exit codes:
  0 — passphrase sent and boot succeeded (display re-stabilised after unlock)
  1 — error (timed out, passphrase prompt never appeared, etc.)
  2 — passphrase sent but boot resulted in emergency shell (issue #270 reproduced)
"""

import hashlib
import os
import socket
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qemu_monitor import run_hmp_command


# ── Shared constants ──────────────────────────────────────────────────────────

POLL_INTERVAL = 3        # seconds between screenshot polls
PLYMOUTH_WAIT = 10       # seconds to wait after display goes blank before sending keys
PROMPT_DEADLINE = 300    # seconds to wait for Plymouth to take over
BOOT_DEADLINE = 900      # seconds to wait for successful boot after passphrase

# Headless QEMU (-display none) often keeps the framebuffer all-black after
# LUKS unlock while GRUB2 and Plymouth run.  If the screen hash has not
# changed within this many seconds of the passphrase being sent, we assume
# the passphrase was accepted and the system is booting silently.
DARK_SCREEN_OVERRIDE_S = 90


# ── Libvirt helpers ───────────────────────────────────────────────────────────

def virsh_screenshot_size(vm: str, path: str) -> int:
    r = subprocess.run(["virsh", "screenshot", vm, path], capture_output=True)
    if r.returncode != 0:
        return 0
    try:
        return os.path.getsize(path)
    except OSError:
        return 0


def virsh_send_passphrase(vm: str, passphrase: str):
    key_map = {
        c: f"KEY_{c.upper()}" for c in "abcdefghijklmnopqrstuvwxyz"
    }
    key_map.update({str(i): f"KEY_{i}" for i in range(10)})
    key_map["-"] = "KEY_MINUS"
    key_map["_"] = "KEY_MINUS"
    key_map[" "] = "KEY_SPACE"

    for ch in passphrase:
        key = key_map.get(ch)
        if key is None:
            print(f"[luks-unlock] WARNING: no key mapping for {ch!r}", file=sys.stderr)
            continue
        subprocess.run(
            ["virsh", "send-key", vm, "--codeset", "linux", key],
            capture_output=True,
        )
        time.sleep(0.08)
    subprocess.run(
        ["virsh", "send-key", vm, "--codeset", "linux", "KEY_ENTER"],
        capture_output=True,
    )


def virsh_dhcp_ip(mac: str) -> str:
    r = subprocess.run(
        ["virsh", "net-dhcp-leases", "default"],
        capture_output=True, text=True,
    )
    for line in r.stdout.splitlines():
        if mac.lower() in line.lower():
            for part in line.split():
                if "/" in part and "." in part:
                    return part.split("/")[0]
    return ""


# ── QEMU monitor helpers ──────────────────────────────────────────────────────

def qemu_screendump(sock: str, path: str) -> tuple:
    """Return (brightness, md5_hash) for the screendump, or (-1, '') on error.

    PPM files are always the same byte length regardless of content, so we
    analyse pixel values rather than file size.

    brightness — average sampled pixel value (0-255).
      QEMU uninitialized: all zeros → 0.0
      OVMF/bootloader:   dim text on black → typically 0.5–5
      Plymouth prompt:   nearly all-black → typically 0.5–2, STABLE
      GDM/GNOME:         colourful UI → typically higher

    md5_hash — MD5 of the full PPM file.  Used to detect when the display
      has stopped changing (Plymouth is waiting for passphrase input).
    """
    try:
        run_hmp_command(sock, f"screendump {path}", settle=0.5)
    except OSError:
        return -1, ""
    # Brief pause so QEMU can finish writing the PPM before we read it
    time.sleep(0.5)
    try:
        data = open(path, "rb").read()
    except OSError:
        return -1, ""
    md5 = hashlib.md5(data).hexdigest()
    # Parse PPM header: "P6\n<W> <H>\n255\n"
    try:
        header_end = data.index(b"255\n") + 4
    except ValueError:
        return -1, ""
    pixel_data = data[header_end:]
    if not pixel_data:
        return -1, ""
    # Sample every 100th byte for speed (each pixel = 3 bytes R,G,B)
    sampled = pixel_data[::100]
    return sum(sampled) / len(sampled), md5


def qemu_send_passphrase(sock: str, passphrase: str):
    # QEMU HMP sendkey takes individual key names (one per invocation).
    # Keys are sent one character at a time with a small delay.
    key_map = {c: c for c in "abcdefghijklmnopqrstuvwxyz0123456789"}
    key_map["-"] = "minus"
    key_map["_"] = "shift-minus"
    key_map[" "] = "spc"

    def _sendkey(key: str):
        run_hmp_command(sock, f"sendkey {key}", settle=0.05)

    for ch in passphrase:
        key = key_map.get(ch)
        if key is None:
            print(f"[luks-unlock] WARNING: no key mapping for {ch!r}", file=sys.stderr)
            continue
        _sendkey(key)
        time.sleep(0.1)
    _sendkey("ret")


def qemu_check_serial(serial_log: str) -> str:
    """Return 'plymouth', 'gdm', 'emergency', or '' if no marker yet.

    Checks for systemd unit messages that appear on the serial console when the
    installed system has console=ttyS0 in its kernel cmdline.
    Falls back gracefully to '' when serial output is absent.
    """
    import re
    try:
        raw = open(serial_log, errors="replace").read()
    except OSError:
        return ""
    # Strip ANSI escape codes and collapse whitespace so that systemd status
    # lines like "  OK  ] Started \n<ESC>gdm.service\n<ESC>- GNOME Display…"
    # become searchable as a single string.
    content = re.sub(r'\x1b\[[0-9;]*[A-Za-z]', '', raw)
    content_flat = ' '.join(content.split())
    if "emergency mode" in content or "emergency shell" in content:
        return "emergency"
    # systemd serial output (ANSI-stripped, whitespace-collapsed):
    #   "OK ] Started gdm.service - GNOME Display Manager."
    if "Started gnome-initial-setup" in content_flat:
        return "gnome-initial-setup"
    if "Started gdm.service" in content_flat or "Started GNOME Display Manager" in content_flat:
        return "gdm"
    # Plymouth passphrase prompt — no ANSI codes, plain text on serial.
    if "Please enter passphrase for disk" in raw:
        return "plymouth"
    return ""


# ── Mode implementations ──────────────────────────────────────────────────────

def run_libvirt(vm: str, passphrase: str, mac: str):
    snap = "/tmp/luks-unlock-snap.png"
    seen_content = False

    print(f"[luks-unlock] libvirt mode — watching {vm} for Plymouth takeover...", flush=True)
    deadline = time.time() + PROMPT_DEADLINE

    while time.time() < deadline:
        size = virsh_screenshot_size(vm, snap)
        print(f"[luks-unlock] screenshot: {size}B", flush=True)

        if not seen_content and size > 4096:
            seen_content = True
            print("[luks-unlock] Boot content visible (OVMF/bootloader)", flush=True)

        if seen_content and size <= 4096:
            print(
                f"[luks-unlock] Plymouth has the display — waiting {PLYMOUTH_WAIT}s...",
                flush=True,
            )
            time.sleep(PLYMOUTH_WAIT)
            print("[luks-unlock] Sending passphrase via virsh send-key...", flush=True)
            virsh_send_passphrase(vm, passphrase)
            print("[luks-unlock] Passphrase sent — waiting for boot...", flush=True)
            break

        time.sleep(POLL_INTERVAL)
    else:
        print("[luks-unlock] ERROR: Plymouth takeover never detected", file=sys.stderr)
        sys.exit(1)

    deadline = time.time() + BOOT_DEADLINE
    while time.time() < deadline:
        ip = virsh_dhcp_ip(mac)
        if ip:
            print(f"[luks-unlock] RESULT: boot succeeded — guest IP {ip}", flush=True)
            sys.exit(0)
        time.sleep(5)

    print("[luks-unlock] WARNING: passphrase sent but no DHCP lease within timeout", file=sys.stderr)
    sys.exit(2)


def ssh_reachable(port: int, timeout: int = 5) -> bool:
    """Return True if sshd on localhost:port is accepting TCP connections.

    Checks TCP reachability only — does not require auth or a configured user.
    An SSH banner in the response means the daemon is up and the system booted.
    """
    import socket
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=timeout) as s:
            banner = s.recv(64)
            return banner.startswith(b"SSH-")
    except OSError:
        return False


def run_qemu(monitor_sock: str, passphrase: str, serial_log: str, ssh_port: int = 0):
    snap = "/tmp/luks-unlock-snap.ppm"

    # Plymouth detection strategy
    # ----------------------------
    # QEMU with -display none renders very dim (brightness 0–5 for all phases).
    # We cannot distinguish OVMF from Plymouth by absolute brightness, so we use
    # two criteria instead:
    #
    #   1. had_content: at least one poll returned brightness > 0.5, meaning the
    #      VM has started rendering something (rules out the all-zeros framebuffer
    #      right after QEMU starts).
    #
    #   2. hash stability: the screendump MD5 has not changed for STABLE_POLLS
    #      consecutive polls.  Plymouth passphrase prompt is a static screen
    #      (no animation) so it stabilises quickly; OVMF and early boot are
    #      actively changing.
    CONTENT_THRESHOLD = 0.5   # any non-zero rendering
    STABLE_POLLS      = 2     # consecutive identical-hash polls → Plymouth waiting
                              # (≥ 6 s at POLL_INTERVAL=3)

    print(f"[luks-unlock] qemu mode — watching monitor {monitor_sock}...", flush=True)
    deadline = time.time() + PROMPT_DEADLINE

    had_content = False
    stable_count = 0
    prev_hash = ""

    while time.time() < deadline:
        # Primary path: detect Plymouth passphrase prompt via serial log.
        # With console=tty0 console=ttyS0 in the BLS entry, Plymouth writes
        # the prompt to serial.  Input still comes from tty0, so sendkey works.
        serial_result = qemu_check_serial(serial_log)
        if serial_result == "plymouth":
            print("[luks-unlock] Plymouth passphrase prompt detected via serial", flush=True)
            brightness, md5 = qemu_screendump(monitor_sock, snap)
            prev_hash = md5  # anchor passphrase_hash so post-passphrase screen_changed is accurate
            try:
                import shutil
                shutil.copy2(snap, "/tmp/luks-screenshot-plymouth.ppm")
            except OSError:
                pass
            print(f"[luks-unlock] Waiting {PLYMOUTH_WAIT}s for Plymouth to settle...", flush=True)
            time.sleep(PLYMOUTH_WAIT)
            print("[luks-unlock] Sending passphrase via QEMU monitor sendkey...", flush=True)
            qemu_send_passphrase(monitor_sock, passphrase)
            print("[luks-unlock] Passphrase sent — watching for boot...", flush=True)
            break

        brightness, md5 = qemu_screendump(monitor_sock, snap)
        print(f"[luks-unlock] screendump brightness={brightness:.2f} hash={md5[:8]}", flush=True)

        if brightness < 0:
            # Failed to read/parse screendump — socket not ready yet
            stable_count = 0
            time.sleep(POLL_INTERVAL)
            continue

        if not had_content and brightness > CONTENT_THRESHOLD:
            had_content = True
            print(f"[luks-unlock] VM is rendering (brightness {brightness:.2f})", flush=True)

        # Track hash stability only after the framebuffer has any content
        if had_content:
            if md5 == prev_hash:
                stable_count += 1
            else:
                stable_count = 0
            prev_hash = md5

        # Fallback: detect Plymouth via framebuffer stability (no serial console)
        if had_content and stable_count >= STABLE_POLLS:
            print(
                f"[luks-unlock] Plymouth prompt stable"
                f" (brightness={brightness:.2f}, {stable_count} identical polls)",
                flush=True,
            )
            # Save a copy of the Plymouth screendump for CI diagnostics
            try:
                import shutil
                shutil.copy2(snap, "/tmp/luks-screenshot-plymouth.ppm")
            except OSError:
                pass
            print(f"[luks-unlock] Waiting {PLYMOUTH_WAIT}s for Plymouth to settle...", flush=True)
            time.sleep(PLYMOUTH_WAIT)
            print("[luks-unlock] Sending passphrase via QEMU monitor sendkey...", flush=True)
            qemu_send_passphrase(monitor_sock, passphrase)
            print("[luks-unlock] Passphrase sent — watching for boot...", flush=True)
            break

        time.sleep(POLL_INTERVAL)
    else:
        print("[luks-unlock] ERROR: Plymouth takeover never detected", file=sys.stderr)
        sys.exit(1)

    # After passphrase: watch for the screen to change from Plymouth (passphrase
    # accepted → Plymouth clears → boot continues) and check serial for emergency
    # shell (still useful for catching issue #270 even without ttyS0).
    deadline = time.time() + BOOT_DEADLINE
    passphrase_time = time.time()
    passphrase_hash = prev_hash  # Plymouth hash at time of passphrase send
    screen_changed = False
    gnome_stable_count = 0

    while time.time() < deadline:
        result = qemu_check_serial(serial_log)
        if result == "emergency":
            print("[luks-unlock] RESULT: emergency shell — issue #270 reproduced", flush=True)
            sys.exit(2)

        # SSH success path: if caller provided a port, test TCP reachability to
        # detect sshd banner — no auth needed, just "daemon is up = boot done".
        # Wins reliably when the installed system starts sshd but lacks
        # console=ttyS0 (so no serial markers reach the log).
        if ssh_port and ssh_reachable(ssh_port):
            print(f"[luks-unlock] RESULT: boot succeeded (sshd banner on port {ssh_port})",
                  flush=True)
            try:
                import shutil
                qemu_screendump(monitor_sock, snap)
                shutil.copy2(snap, "/tmp/luks-screenshot-final.ppm")
            except OSError:
                pass
            sys.exit(0)

        # Dark-screen override: headless QEMU (-display none) often keeps the
        # framebuffer all-black during GRUB2 + Plymouth even after a successful
        # LUKS unlock.  The passphrase_hash == post-passphrase hash so
        # screen_changed never flips and the brightness check never runs.
        #
        # When the screen stays dark for DARK_SCREEN_OVERRIDE_S seconds:
        #   - With SSH port: do nothing. We just keep looping and polling SSH.
        #   - Without SSH port: exit 0 now.  If the passphrase was wrong Plymouth
        #     would have re-prompted; silence = passphrase accepted = boot proceeding.
        elapsed_since_passphrase = time.time() - passphrase_time
        if not screen_changed and elapsed_since_passphrase > DARK_SCREEN_OVERRIDE_S:
            if not ssh_port:
                print(
                    f"[luks-unlock] Dark-screen override: screen unchanged for "
                    f"{int(elapsed_since_passphrase)}s and no SSH port configured — assuming boot succeeded",
                    flush=True,
                )
                sys.exit(0)


        brightness, md5 = qemu_screendump(monitor_sock, snap)
        print(f"[luks-unlock] post-passphrase brightness={brightness:.2f} hash={md5[:8]}",
              flush=True)

        if md5 != passphrase_hash and not screen_changed:
            screen_changed = True
            print(
                "[luks-unlock] Screen changed after passphrase"
                " — LUKS accepted, boot proceeding",
                flush=True,
            )

        # Primary success path: serial log confirms gnome-initial-setup or GDM.
        # gnome-initial-setup fires after GDM — screenshot taken immediately.
        # If only GDM is seen, wait 30s as a fallback in case g-i-s is slow.
        if result == "gnome-initial-setup":
            print("[luks-unlock] gnome-initial-setup started (serial confirmed) — taking screenshot", flush=True)
            brightness, md5 = qemu_screendump(monitor_sock, snap)
            print(f"[luks-unlock] RESULT: boot succeeded (g-i-s confirmed via serial, brightness={brightness:.2f})", flush=True)
        elif result == "gdm":
            print(
                "[luks-unlock] GDM started — waiting 30s for gnome-initial-setup...",
                flush=True,
            )
            time.sleep(30)
            brightness, md5 = qemu_screendump(monitor_sock, snap)
            print(
                f"[luks-unlock] RESULT: boot succeeded"
                f" (GDM confirmed via serial, brightness={brightness:.2f})",
                flush=True,
            )
        if result in ("gnome-initial-setup", "gdm"):
            try:
                import shutil
                shutil.copy2(snap, "/tmp/luks-screenshot-final.ppm")
            except OSError:
                pass
            sys.exit(0)

        # Fallback: no serial console (console=ttyS0 absent).  Use framebuffer
        # brightness to distinguish GDM (~2.4) from emergency shell (~1.0).
        # Only trigger once the screen has re-stabilised after the initial
        # post-passphrase animation.  GDM re-renders continuously (cursor
        # blink, animations), so we cannot require many consecutive identical
        # frames — 1 stable poll is sufficient to confirm the screen settled.
        GNOME_THRESHOLD    = 1.8
        GNOME_STABLE_POLLS = 1   # 1 stable poll is enough; GDM keeps rendering
        if md5 == prev_hash:
            gnome_stable_count += 1
        else:
            gnome_stable_count = 0

        # With an SSH port the sshd banner above is the verdict. Plymouth's
        # graphical splash after the unlock is a dark frame whose spinner can
        # repeat between two polls, which this heuristic would call an
        # emergency shell; an emergency boot is still caught on serial.
        if not ssh_port and screen_changed and gnome_stable_count >= GNOME_STABLE_POLLS:
            if brightness > GNOME_THRESHOLD:
                print(
                    f"[luks-unlock] RESULT: boot succeeded"
                    f" (framebuffer stable {gnome_stable_count} polls,"
                    f" brightness={brightness:.2f})",
                    flush=True,
                )
            else:
                print(
                    f"[luks-unlock] RESULT: emergency shell suspected"
                    f" (framebuffer stable but dark, brightness={brightness:.2f})",
                    flush=True,
                )
            try:
                import shutil
                shutil.copy2(snap, "/tmp/luks-screenshot-final.ppm")
            except OSError:
                pass
            sys.exit(0 if brightness > GNOME_THRESHOLD else 2)

        prev_hash = md5
        time.sleep(5)

    print("[luks-unlock] WARNING: passphrase sent but boot did not complete within timeout",
          file=sys.stderr)
    sys.exit(2)


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    mode = sys.argv[1]

    if mode == "libvirt":
        if len(sys.argv) < 5:
            print("Usage: luks-unlock.py libvirt <vm> <passphrase> <mac>", file=sys.stderr)
            sys.exit(1)
        run_libvirt(sys.argv[2], sys.argv[3], sys.argv[4])

    elif mode == "qemu":
        if len(sys.argv) < 5:
            print("Usage: luks-unlock.py qemu <monitor-sock> <passphrase> <serial-log> [ssh-port]",
                  file=sys.stderr)
            sys.exit(1)
        ssh_port = int(sys.argv[5]) if len(sys.argv) >= 6 else 0
        run_qemu(sys.argv[2], sys.argv[3], sys.argv[4], ssh_port=ssh_port)

    else:
        print(f"Unknown mode: {mode!r}. Use 'libvirt' or 'qemu'.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
