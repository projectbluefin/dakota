#!/usr/bin/env python3
"""End-to-end test of Dakota's experimental image-based installer, with screenshots.

  raw_e2e.py --raw medium.raw --work DIR --candidate IMAGE@sha256:... --ssh-key KEY

Vendored from projectbluefin/utah iso/raw/raw_e2e.py (482c400d) and adapted to
Dakota: systemd-boot instead of GRUB, the "Dakota Live" entry, Plymouth's bgrt
theme (no watermark), AppArmor instead of SELinux, no runuser.

Stages (every screenshot is listed in DIR/screenshots/manifest.json):
  1. Boot the raw disk image as live media (read-only virtio disk,
     systemd-boot's default "Dakota Live" entry: ro dakota.live plus the
     live-only initrd, tmpfs overlays over /, /etc and /var).
  2. Install with the real OS-Installer window (--install gui): language,
     welcome, keyboard, disk, encryption with a passphrase, confirmation,
     summary, progress, completion. With --install script the same
     install.sh runs over SSH instead, which exercises the installed disk
     independently of the GUI driver.
  3. Boot the installed disk alone: Plymouth LUKS prompt, unlock,
     gnome-initial-setup (user creation), GNOME desktop, a terminal with
     `bootc status`.
  4. `bootc switch` to the candidate digest, reboot, unlock, log in at GDM:
     desktop + `bootc status`. Then `bootc rollback` and the same again.
     With --flatpaks (the medium's baked app list), every installed boot
     checks the baked apps are there; after the first boot one is removed
     (--remove-flatpak) and must stay removed through switch and rollback.

DIR/evidence/results.json records each stage (STAGES) as pass, fail or not
run with its duration, plus the LSM state, fs-verity facts and failed units
for every boot.

Input is what a user at the machine would give: a QEMU USB tablet clicks at a
widget's on-screen position and QEMU `sendkey` types. AT-SPI (atspi_drive.py,
run in the guest session) only observes: which page shows, what is sensitive,
and where a widget is inside its window. Buttons are pressed through their
AT-SPI "click" action. GTK 4 reports positions relative to the window, so the
harness maximizes it first: a maximized window spans the screen width and starts
right under the top bar, which turns window coordinates into screen coordinates.

Uses qemu_monitor.py and luks-unlock.py from this directory.
"""

import argparse
import json
import os
import re
import shlex
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPTS = HERE
sys.path.insert(0, str(SCRIPTS))
from qemu_monitor import run_hmp_command  # noqa: E402

DISTRO = "Dakota"
LIVE_KARG = "dakota.live"
READY_MARKER = "DAKOTA_LIVE_READY"
INSTALL_SCRIPT = "/usr/share/dakota/os-installer/scripts/install.sh"
INSTALL_LOG = "/run/dakota-install.log"
PIN = "dakotaluks2026"
USER_FULL = "Dakota Tester"
USER = "tester"
PASSWORD = "dakotatest2026"
INSTALLER_APP = "installer"   # AT-SPI app name of com.github.p3732.os_installer
GIS_APP = "initial-setup"
TARGET_DISK = "/dev/vdb"
SCREEN_W, SCREEN_H = 1920, 1080
TOP_BAR = 32                  # GNOME Shell top bar at scale 1: top of the work area
ABS_MAX = 0x7FFF              # QEMU absolute pointer axis range

SSH_OPTS = ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
            "-o", "LogLevel=ERROR", "-o", "ConnectTimeout=5",
            "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=8"]

# What every boot records next to its failed units: the LSM state (Dakota
# runs AppArmor; its systemd is built -SELINUX) and fs-verity on the composefs
# repository (ext4 'V' attribute on objects; kernel messages).
BOOT_FACTS = ("cat /sys/kernel/security/lsm; echo; "
              "printf 'apparmor enabled: '; cat /sys/module/apparmor/parameters/enabled 2>/dev/null || echo n/a; "
              "aa-status 2>/dev/null | sed -n '1,4p'; "
              "printf 'selinux: '; getenforce 2>/dev/null || echo n/a; echo ---; "
              "tr ' ' '\\n' </proc/cmdline | grep -E '^(composefs|root|rd.luks)'; "
              "find /sysroot/composefs/objects -type f 2>/dev/null | head -n 400 | xargs -r lsattr 2>/dev/null "
              "| awk '{v += ($1 ~ /V/); n++} END {printf \"composefs objects with fs-verity: %d of %d sampled\\n\", v, n}'; "
              "journalctl -k -b --no-pager | grep -ciE 'verity.*(corrupt|error|fail)|FILE CORRUPTED' "
              "| sed 's/^/kernel fs-verity errors: /'; echo ---; "
              "systemctl --failed --no-legend --plain")

# The stages results.json reports, in order.
STAGES = ("live boot", "install", "first boot unlock", "initial setup",
          "first boot desktop", "bootc switch", "bootc rollback")


def parse_failed_units(text):
    """Unit names from `systemctl --failed --no-legend --plain` output."""
    units = []
    for line in (text or "").splitlines():
        words = line.replace("\u25cf", " ").split()
        if words and "." in words[0]:
            units.append(words[0])
    return units


class Results:
    """Per-stage pass/fail with durations, and what every boot looked like."""

    def __init__(self, install, clock=time.monotonic):
        self.install = install
        self.clock = clock
        self.stages = {}
        self.boots = {}
        self.flatpaks = {}
        self.current = None
        self.started = None
        self.error = None

    def begin(self, stage):
        if stage not in STAGES:
            raise ValueError(f"unknown stage {stage!r}")
        self.finish()
        self.current, self.started = stage, self.clock()

    def finish(self, error=None):
        """Close the running stage: failed if error is set, else passed."""
        if self.current is None:
            if error is not None and self.error is None:
                self.error = str(error)
            return
        self.stages[self.current] = {"status": "fail" if error is not None else "pass",
                                     "seconds": round(self.clock() - self.started)}
        if error is not None:
            self.error = str(error)
        self.current = None

    def boot(self, phase, lsm, verity, failed_units):
        self.boots[phase] = {"lsm": lsm, "verity": verity, "failed_units": failed_units}

    def flatpak(self, phase, installed, problems):
        self.flatpaks[phase] = {"apps": len(installed), "problems": problems}

    def as_dict(self, timings=None):
        stages = [{"stage": s, **self.stages.get(s, {"status": "not run", "seconds": None})} for s in STAGES]
        passed = self.error is None and all(s["status"] == "pass" for s in stages)
        return {"result": "pass" if passed else "fail", "error": self.error, "install": self.install,
                "stages": stages, "boots": self.boots, "flatpaks": self.flatpaks,
                "timings": dict(timings or {})}


def flatpak_problems(baked, installed, removed=None):
    """What is wrong with the installed system's Flatpaks.

    baked: apps the medium carries (bake-flatpaks.sh); removed: the app the
    user removed before bootc switch, which must stay removed. Every other
    baked app must still be there.
    """
    installed = set(installed)
    problems = [f"missing {app}" for app in sorted(set(baked) - installed) if app != removed]
    if removed and removed in installed:
        problems.append(f"{removed} came back after it was removed")
    return problems


class Fail(Exception):
    pass


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def find_firmware():
    pairs = [("/usr/share/OVMF/OVMF_CODE_4M.fd", "/usr/share/OVMF/OVMF_VARS_4M.fd"),
             ("/usr/share/edk2/ovmf/OVMF_CODE.fd", "/usr/share/edk2/ovmf/OVMF_VARS.fd"),
             ("/usr/share/OVMF/OVMF_CODE.fd", "/usr/share/OVMF/OVMF_VARS.fd")]
    for code, var in pairs:
        if os.path.exists(code) and os.path.exists(var):
            return code, var
    raise Fail("OVMF firmware not found")


class Harness:
    def __init__(self, args):
        self.args = args
        self.work = Path(args.work).resolve()
        self.shots = self.work / "screenshots"
        self.evidence = self.work / "evidence"
        self.debug = self.work / "debug"
        for d in (self.shots, self.evidence, self.debug):
            d.mkdir(parents=True, exist_ok=True)
        self.manifest = []
        self.vm = None
        self.mon_sock = None
        self.qmp_sock = None
        self.serial = None
        self.ssh_port = None
        self.code, self.vars_src = find_firmware()
        self.baseline_digest = None
        self.candidate_digest = args.candidate.split("@", 1)[1] if "@" in args.candidate else None
        self.timings = {}
        self.results = Results(args.install)

    # ---- QEMU ---------------------------------------------------------------
    def start_vm(self, name, drives, vars_file, ssh_port):
        self.mon_sock = str(self.work / f"{name}-monitor.sock")
        self.qmp_sock = str(self.work / f"{name}-qmp.sock")
        self.serial = self.work / f"{name}-serial.log"
        self.ssh_port = ssh_port
        cmd = ["qemu-system-x86_64", "-name", name, "-machine", "q35", "-m", str(self.args.ram),
               "-smp", str(self.args.cpus),
               "-drive", f"if=pflash,format=raw,readonly=on,file={self.code}",
               "-drive", f"if=pflash,format=raw,file={vars_file}",
               "-netdev", f"user,id=n0,hostfwd=tcp:127.0.0.1:{ssh_port}-:22",
               "-device", "virtio-net-pci,netdev=n0",
               "-vga", "none", "-device", "VGA,xres=1920,yres=1080",
               # Absolute pointer: clicks land at exact screen coordinates.
               "-device", "qemu-xhci", "-device", "usb-tablet",
               "-display", "none", "-serial", f"file:{self.serial}",
               "-monitor", f"unix:{self.mon_sock},server,nowait",
               "-qmp", f"unix:{self.qmp_sock},server=on,wait=off"]
        cmd += ["-accel", "kvm", "-cpu", "host"] if os.access("/dev/kvm", os.W_OK) else ["-accel", "tcg"]
        for d in drives:
            cmd += ["-drive", d["drive"], "-device", d["device"]]
        log(f"starting VM {name}: {' '.join(shlex.quote(c) for c in cmd)}")
        self.vm = subprocess.Popen(cmd, stdout=open(self.work / f"{name}-qemu.log", "w"), stderr=subprocess.STDOUT)
        for _ in range(50):
            if os.path.exists(self.mon_sock) and os.path.exists(self.qmp_sock):
                break
            time.sleep(0.2)

    def stop_vm(self, graceful_cmd=None):
        if self.vm is None:
            return
        if graceful_cmd:
            try:
                graceful_cmd()
            except Exception as e:  # noqa: BLE001
                log(f"graceful stop failed: {e}")
            try:
                self.vm.wait(timeout=180)
            except subprocess.TimeoutExpired:
                log("VM did not power off in time; killing")
        if self.vm.poll() is None:
            self.vm.kill()
            self.vm.wait()
        self.vm = None

    def mon(self, command):
        return run_hmp_command(self.mon_sock, command, settle=0.1, prompt=b"(qemu)", recv_timeout=5)

    def qmp(self, *commands):
        """Run QMP commands on a fresh connection; returns their replies."""
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(10)
            s.connect(self.qmp_sock)
            f = s.makefile("rwb", buffering=0)

            def reply():
                while True:
                    line = f.readline()
                    if not line:
                        raise Fail("QMP connection closed")
                    msg = json.loads(line)
                    if "return" in msg or "error" in msg:
                        return msg

            f.readline()  # greeting
            f.write(b'{"execute": "qmp_capabilities"}\n')
            reply()
            out = []
            for c in commands:
                f.write(json.dumps(c).encode() + b"\n")
                r = reply()
                if "error" in r:
                    raise Fail(f"QMP {c['execute']}: {r['error']}")
                out.append(r)
            return out

    def click_at(self, x, y):
        x = max(0, min(SCREEN_W - 1, int(x)))
        y = max(0, min(SCREEN_H - 1, int(y)))
        ev = lambda events: {"execute": "input-send-event", "arguments": {"events": events}}  # noqa: E731
        self.qmp(ev([{"type": "abs", "data": {"axis": "x", "value": round(x * ABS_MAX / (SCREEN_W - 1))}},
                     {"type": "abs", "data": {"axis": "y", "value": round(y * ABS_MAX / (SCREEN_H - 1))}}]))
        time.sleep(0.4)
        self.qmp(ev([{"type": "btn", "data": {"down": True, "button": "left"}}]))
        time.sleep(0.1)
        self.qmp(ev([{"type": "btn", "data": {"down": False, "button": "left"}}]))
        time.sleep(0.5)

    def key(self, k):
        self.mon(f"sendkey {k}")
        time.sleep(0.08)

    def type(self, text, enter=False):
        for ch in text:
            if ch.isdigit() or ("a" <= ch <= "z"):
                k = ch
            elif "A" <= ch <= "Z":
                k = f"shift-{ch.lower()}"
            else:
                k = {" ": "spc", "-": "minus", ".": "dot", "_": "shift-minus", "/": "slash"}[ch]
            self.key(k)
        if enter:
            self.key("ret")

    def screendump(self, path):
        ppm = path.with_suffix(".ppm")
        ppm.unlink(missing_ok=True)
        self.mon(f"screendump {ppm}")
        for _ in range(20):
            if ppm.exists() and ppm.stat().st_size > 0:
                break
            time.sleep(0.3)
        time.sleep(0.5)
        return ppm

    def to_png(self, ppm, png):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(ppm), str(png)], check=True)
        ppm.unlink(missing_ok=True)

    def shot(self, label, proves, retake_until_drawn=False):
        png = self.shots / f"{label}.png"
        for attempt in range(12 if retake_until_drawn else 1):
            ppm = self.screendump(png)
            if not retake_until_drawn or drawn(ppm):
                break
            log(f"  {label}: frame not drawn yet ({attempt + 1}/12)")
            self.key("shift")
            time.sleep(5)
        self.to_png(ppm, png)
        self.manifest.append({"file": png.name, "stage": label, "proves": proves})
        self.write_manifest()
        log(f"  screenshot {png.name}: {proves}")
        return png

    def debug_shot(self, label):
        """Diagnostic frame outside the stage table (debug/)."""
        try:
            png = self.debug / f"{label}.png"
            self.to_png(self.screendump(png), png)
        except Exception as e:  # noqa: BLE001
            log(f"  debug shot {label} failed: {e}")

    def write_manifest(self):
        (self.shots / "manifest.json").write_text(json.dumps(self.manifest, indent=2) + "\n")

    def wait_serial(self, needle, timeout):
        end = time.time() + timeout
        while time.time() < end:
            if self.vm.poll() is not None:
                raise Fail(f"VM exited while waiting for {needle!r} on serial")
            if self.serial.exists() and needle.encode() in self.serial.read_bytes():
                return
            time.sleep(3)
        raise Fail(f"serial never showed {needle!r} within {timeout}s")

    # ---- SSH ----------------------------------------------------------------
    def ssh(self, user, command, check=True, timeout=600, password=None):
        base = (["sshpass", "-p", password, "ssh"] if password else ["ssh", "-i", self.args.ssh_key])
        cmd = base + SSH_OPTS + ["-p", str(self.ssh_port), f"{user}@127.0.0.1", command]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        if check and r.returncode != 0:
            raise Fail(f"ssh {user}: {command!r} failed ({r.returncode}): {r.stderr.strip()[-2000:]}")
        return r.stdout

    def scp_to(self, user, src, dst, password=None):
        base = (["sshpass", "-p", password, "scp"] if password else ["scp", "-i", self.args.ssh_key])
        subprocess.run(base + SSH_OPTS + ["-P", str(self.ssh_port), str(src), f"{user}@127.0.0.1:{dst}"], check=True)

    def scp_from(self, user, src, dst, password=None):
        base = (["sshpass", "-p", password, "scp"] if password else ["scp", "-i", self.args.ssh_key])
        subprocess.run(base + SSH_OPTS + ["-P", str(self.ssh_port), f"{user}@127.0.0.1:{src}", str(dst)], check=True)

    def wait_ssh(self, user, timeout, password=None):
        end = time.time() + timeout
        while time.time() < end:
            if self.vm.poll() is not None:
                raise Fail("VM exited while waiting for SSH")
            try:
                self.ssh(user, "true", timeout=20, password=password)
                return
            except (Fail, subprocess.TimeoutExpired):
                time.sleep(5)
        raise Fail(f"SSH as {user} not reachable within {timeout}s")

    def collect_journal(self, tag):
        """Best-effort guest journal for diagnosis (live user via sudo, or root)."""
        for user, pw, cmd in (("liveuser", "live", "sudo journalctl -b --no-pager -o short-monotonic"),
                              ("root", None, "journalctl -b --no-pager -o short-monotonic")):
            try:
                out = self.ssh(user, cmd, timeout=120, password=pw)
                self.save(f"journal-{tag}.txt", out)
                return
            except Exception:  # noqa: BLE001
                continue

    def save(self, name, text):
        (self.evidence / name).write_text(text)

    # ---- AT-SPI observation + pointer/keyboard input -------------------------
    def atspi(self, runner, *argv):
        # `|| true`: a miss (exit 2/3) still prints its JSON error, which callers handle.
        out = runner("python3 /var/tmp/atspi_drive.py " + " ".join(shlex.quote(a) for a in argv) + " || true")
        try:
            return json.loads(out) if out.strip() else None
        except json.JSONDecodeError:
            raise Fail(f"atspi {argv}: unparsable output {out[:500]!r}")

    def snapshot(self, runner, app):
        try:
            nodes = self.atspi(runner, "snapshot", app)
        except (Fail, subprocess.TimeoutExpired):
            return []
        return nodes if isinstance(nodes, list) else []

    def poll(self, runner, app, predicate, timeout):
        end = time.time() + timeout
        while True:
            nodes = self.snapshot(runner, app)
            if nodes and predicate(nodes):
                return nodes
            if time.time() >= end:
                return None
            time.sleep(2)

    def wait_for(self, runner, app, predicate, what, timeout=300):
        nodes = self.poll(runner, app, predicate, timeout)
        if nodes is not None:
            return nodes
        self.save(f"atspi-timeout-{slug(what)}.json", json.dumps(self.snapshot(runner, app), indent=1))
        self.shot(f"fail-{slug(what)}", f"FAILURE: {what} never appeared")
        raise Fail(f"{what} never appeared in {app}")

    def to_screen(self, nodes, node):
        frame = top_frame(nodes)
        if frame is None or not node.get("ext"):
            raise Fail(f"no window extents for {node.get('role')} {node.get('name')!r}")
        fx, fy, fw, fh = frame["ext"]
        x, y, w, h = node["ext"]
        if fw >= SCREEN_W - 2:
            # Fullscreen covers the screen; maximized starts under the top bar.
            ox, oy = 0, (0 if fh >= SCREEN_H - 2 else TOP_BAR)
        else:
            # Mutter centers new windows in the work area (fallback; logged).
            ox, oy = (SCREEN_W - fw) // 2, TOP_BAR + (SCREEN_H - TOP_BAR - fh) // 2
            log(f"  window {fw}x{fh} not maximized; assuming it is centered")
        return ox + (x - fx) + w // 2, oy + (y - fy) + h // 2

    def click_node(self, nodes, node):
        x, y = self.to_screen(nodes, node)
        log(f"  click {node['role']} {node['name'] or node['text'][:30]!r} at ({x}, {y}) ext={node['ext']}")
        self.click_at(x, y)

    def maximize(self, runner, app):
        """Maximize the app's window so window coordinates map to the screen."""
        nodes = []
        for attempt in range(4):
            nodes = self.snapshot(runner, app)
            frame = top_frame(nodes)
            if frame is not None and frame["ext"][2] >= SCREEN_W - 2:
                log(f"  {app} window maximized: frame ext={frame['ext']}")
                return nodes
            log(f"  {app} frame ext={frame and frame['ext']}; maximizing (attempt {attempt + 1})")
            if attempt % 2 == 0 and has_name(nodes, "Maximize", sensitive=True):
                self.atspi(runner, "act", app, "Maximize")
            else:
                self.atspi(runner, "frame-action", app, "window.toggle-maximized")
            time.sleep(3)
        self.save(f"atspi-maximize-{slug(app)}.json", json.dumps(nodes, indent=1))
        log(f"  {app} window could not be maximized; clicks use the centered-window fallback")
        return nodes

    def click_until(self, runner, app, pick, done, what, tries=3, settle=20):
        """Click the node pick(nodes) returns until done(nodes) holds."""
        for attempt in range(tries):
            nodes = self.snapshot(runner, app)
            node = pick(nodes)
            if node is None:
                self.save(f"atspi-missing-{slug(what)}.json", json.dumps(nodes, indent=1))
                raise Fail(f"{what}: nothing to click")
            self.click_node(nodes, node)
            got = self.poll(runner, app, done, settle)
            if got is not None:
                return got
            self.debug_shot(f"miss-{slug(what)}-{attempt}")
            self.save(f"atspi-miss-{slug(what)}-{attempt}.json", json.dumps(self.snapshot(runner, app), indent=1))
        self.shot(f"fail-{slug(what)}", f"FAILURE: clicking never reached {what}")
        raise Fail(f"clicking never reached {what}")

    def press(self, runner, app, name, done, what, timeout=120):
        """Press a button by its AT-SPI click action (pointer if it has none)."""
        for attempt in range(3):
            res = self.atspi(runner, "act", app, name)
            if not res or "error" in res:
                log(f"  press {name!r}: {res}")
                time.sleep(3)
                continue
            if res["how"] == "none":
                nodes = self.snapshot(runner, app)
                node = next((n for n in nodes if n["path"] == res["path"]), None)
                if node is not None:
                    self.click_node(nodes, node)
            got = self.poll(runner, app, done, 30 if attempt < 2 else timeout)
            if got is not None:
                return got
            self.debug_shot(f"press-miss-{slug(what)}-{attempt}")
        self.save(f"atspi-timeout-{slug(what)}.json", json.dumps(self.snapshot(runner, app), indent=1))
        self.shot(f"fail-{slug(what)}", f"FAILURE: pressing {name!r} never reached {what}")
        raise Fail(f"pressing {name!r} never reached {what}")

    def fill(self, runner, app, node, text, clear=True):
        """Click an entry, then type into it."""
        nodes = self.snapshot(runner, app)
        node = next((n for n in nodes if n["path"] == node["path"]), node)
        self.click_node(nodes, node)
        time.sleep(1)
        if clear:
            self.key("ctrl-a")
            self.key("backspace")
        self.type(text)
        time.sleep(1)

    def record_boot(self, phase, user, password=None):
        """LSM state, fs-verity facts and failed units of the running boot, into results.json."""
        prefix = "" if user == "root" else "sudo "
        out = self.ssh(user, f"{prefix}sh -c {shlex.quote(BOOT_FACTS)}", password=password, check=False)
        self.save(f"boot-facts-{slug(phase)}.txt", out)
        lsm, _, rest = out.partition("---")
        verity, _, failed = rest.partition("---")
        self.results.boot(phase, " | ".join(l.strip() for l in lsm.strip().splitlines() if l.strip()) or "unknown",
                          " | ".join(l.strip() for l in verity.strip().splitlines() if l.strip()),
                          parse_failed_units(failed))

    # ---- Stages -------------------------------------------------------------
    def live(self):
        log("=== Stage 1: live boot of the raw disk image ===")
        self.results.begin("live boot")
        target = self.work / "install.qcow2"
        target.unlink(missing_ok=True)
        subprocess.run(["qemu-img", "create", "-q", "-f", "qcow2", str(target), self.args.target_size], check=True)
        self.vars_live = self.work / "vars-live.fd"
        shutil.copy(self.vars_src, self.vars_live)
        self.start_vm("live", [
            {"drive": f"file={self.args.raw},format=raw,if=none,id=medium,readonly=on",
             "device": "virtio-blk-pci,drive=medium,bootindex=1"},
            {"drive": f"file={target},format=qcow2,if=none,id=target",
             "device": "virtio-blk-pci,drive=target"},
        ], self.vars_live, self.args.ssh_port)
        self.shot_boot_menu()
        self.wait_serial(READY_MARKER, 1200)
        live_pw = "live"
        self.wait_ssh("liveuser", 300, password=live_pw)
        runner = lambda c: self.ssh("liveuser", "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus; " + c, password=live_pw)  # noqa: E731
        self.live_runner = runner
        facts = self.ssh("liveuser", "cat /proc/cmdline; echo; findmnt -no FSTYPE,SOURCE,OPTIONS /sysroot; findmnt -no FSTYPE,SOURCE,OPTIONS /; "
                         "findmnt -no FSTYPE,SOURCE,OPTIONS /etc; findmnt -no FSTYPE,SOURCE,OPTIONS /var; "
                         "lsblk -o NAME,SIZE,RO,TYPE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINTS; systemctl --failed --no-legend; "
                         "sudo bootctl list --no-pager 2>&1 | head -40; sudo bootc status || true",
                         password=live_pw, check=False)
        self.save("live-facts.txt", facts)
        self.record_boot("live", "liveuser", password=live_pw)
        if LIVE_KARG not in facts.split("\n", 1)[0]:
            raise Fail(f"live VM did not boot the {LIVE_KARG} entry")
        self.scp_to("liveuser", HERE / "atspi_drive.py", "/var/tmp/atspi_drive.py", password=live_pw)
        end = time.time() + 300
        while time.time() < end and "gnome-shell" not in self.ssh("liveuser", "pgrep -a -u liveuser gnome-shell || true", password=live_pw):
            time.sleep(5)
        time.sleep(10)
        self.shot("01-live-session", f"Raw disk image booted as live media ({LIVE_KARG}, tmpfs overlays over /, /etc, /var): GNOME session for the live user", True)

    def shot_boot_menu(self):
        # loader.conf's timeout keeps systemd-boot's menu up for a few seconds;
        # catch it to show the live entry is the default.
        end = time.time() + 90
        probe = self.debug / "boot-menu-probe.png"
        while time.time() < end:
            time.sleep(1)
            ppm = self.screendump(probe)
            if "Dakota Live" in ocr(ppm):
                ppm.unlink(missing_ok=True)
                self.shot("00-boot-menu", "Firmware -> systemd-boot on the medium; the 'Dakota Live' Type #1 entry is the default")
                return
        probe.with_suffix(".ppm").unlink(missing_ok=True)
        log("  systemd-boot menu not captured")

    def installer(self):
        log("=== Stage 2: OS-Installer GUI ===")
        self.results.begin("install")
        r, app = self.live_runner, INSTALLER_APP
        nodes = self.wait_for(r, app, lambda n: has_text(n, "English"), "language page", 240)
        self.save("atspi-language.json", json.dumps(nodes, indent=1))
        # GNOME Shell opens the overview at login, above the autostarted window.
        self.key("esc")
        time.sleep(3)
        self.maximize(r, app)
        time.sleep(2)
        self.shot("02-installer-language", "OS-Installer autostarted in the live session: language page")

        nodes = self.click_until(r, app, lambda n: row_containing(n, "English (United States)"),
                                 lambda n: has_text(n, "copying this live system"), "welcome page")
        self.shot("03-installer-welcome", "Welcome page with the Dakota logo and config text")
        if not has_name(nodes, "Continue"):
            raise Fail("the click picked another language than English (welcome page has no 'Continue')")

        self.press(r, app, "Continue", lambda n: has_text(n, "Test the Keyboard Layout Here"), "keyboard page")
        self.shot("04-installer-keyboard", "Keyboard layout page")

        nodes = self.press(r, app, "Continue", lambda n: has_text(n, TARGET_DISK), "disk page")
        self.save("atspi-disk.json", json.dumps(nodes, indent=1))
        self.shot("05-installer-disk", f"Disk selection: the empty 48 GB target {TARGET_DISK} is offered; the 24 GB live medium is too small to pick")

        nodes = self.click_until(r, app, lambda n: row_containing(n, TARGET_DISK),
                                 lambda n: has_name(n, "Encrypt Files"), "encryption page")
        self.save("atspi-encrypt.json", json.dumps(nodes, indent=1))
        self.enable_encryption(r, app)
        self.shot("06-installer-encryption", "Encryption enabled with a passphrase (LUKS2 via systemd-repart Encrypt=key-file)")

        self.press(r, app, "Continue", lambda n: has_text(n, "This will delete all data on"), "confirmation page")
        self.shot("07-installer-confirm", "Confirmation: the target disk will be erased")
        nodes = self.press(r, app, "Confirm", lambda n: not has_text(n, "This will delete all data on"), "page after confirmation")
        start = time.time()
        if has_name(nodes, "Confirm") and not install_finished(nodes):
            self.shot("08-installer-summary", "Summary page; the install script is already running in the background")
            nodes = self.press(r, app, "Confirm", lambda n: has_name(n, "Confirm") is False or install_finished(n), "install page")
        if not install_finished(nodes):
            time.sleep(5)
            self.shot("09-installer-progress", "Install running: block copy of the live medium onto the target")
        nodes = self.wait_for(r, app, install_finished, "install result", 3600)
        self.timings["gui-install-seconds-after-confirm"] = int(time.time() - start)
        self.grab_install_log()
        if has_text(nodes, "Error During Installation"):
            self.shot("10-installer-failed", "FAILURE: OS-Installer reported an error")
            self.atspi(r, "frame-action", app, "win.show-terminal")
            time.sleep(3)
            self.shot("11-installer-log", "Install script output at the failure")
            raise Fail("installer failed")
        log(f"  installer finished {self.timings['gui-install-seconds-after-confirm']}s after confirmation")
        self.shot("10-installer-done", "Installation complete page")
        res = self.atspi(r, "frame-action", app, "win.show-terminal")
        if res and "error" not in res:
            time.sleep(3)
            self.shot("11-installer-log", "OS-Installer's terminal view: repart block copy into LUKS2, UUID regeneration, live entry removed, timings")
        else:
            log(f"  terminal view not opened: {res}")
        self.after_install()

    def enable_encryption(self, r, app):
        res = self.atspi(r, "act", app, "Encrypt Files")
        log(f"  Encrypt Files: {res}")
        pin_ready = lambda n: has_name(n, "Encryption PIN", sensitive=True)  # noqa: E731
        if not (res and res.get("how", "none") != "none" and self.poll(r, app, pin_ready, 10)):
            self.click_until(r, app, lambda n: named(n, "Encrypt Files"), pin_ready, "encryption switch")
        for label in ("Encryption PIN", "Confirm PIN"):
            nodes = self.snapshot(r, app)
            node = named(nodes, label, sensitive=True)
            if node is None:
                self.save("atspi-encrypt-missing.json", json.dumps(nodes, indent=1))
                raise Fail(f"no sensitive {label!r} entry")
            self.fill(r, app, node, PIN)
        nodes = self.snapshot(r, app)
        self.save("atspi-encrypt-filled.json", json.dumps(nodes, indent=1))
        lengths = [len(n["text"]) for n in nodes if n["role"] in ("password text", "text", "entry") and n["text"]]
        log(f"  entry text lengths after typing: {lengths}")
        if lengths and lengths.count(len(PIN)) < 2:
            self.debug_shot("encryption-typed")
            raise Fail(f"passphrase entries hold {lengths}, expected two of length {len(PIN)}")

    def script_install(self):
        """Run the same install.sh over SSH (no GUI), for --install script."""
        log("=== Stage 2 (script): install.sh over SSH ===")
        self.results.begin("install")
        start = time.time()
        out = self.ssh("liveuser", f"sudo OSI_DEVICE_PATH={TARGET_DISK} OSI_DEVICE_IS_PARTITION=0 OSI_USE_ENCRYPTION=1 "
                       f"OSI_ENCRYPTION_PIN={PIN} {INSTALL_SCRIPT} 2>&1",
                       password="live", timeout=3600, check=False)
        self.timings["script-install-seconds"] = int(time.time() - start)
        self.save("dakota-install.log", out)
        if f"{DISTRO} installed to" not in out:
            raise Fail("install.sh failed (evidence/dakota-install.log)")
        self.after_install()

    def after_install(self):
        facts = self.ssh("liveuser", "sudo efibootmgr -v; lsblk -o NAME,SIZE,TYPE,FSTYPE,UUID,PARTTYPENAME,PARTLABEL", password="live", check=False)
        self.save("live-after-install.txt", facts)
        self.stop_vm(lambda: self.ssh("liveuser", "sudo systemctl poweroff --no-block", password="live", check=False))

    def grab_install_log(self):
        # The script writes it as root (it re-executes through sudo).
        out = self.ssh("liveuser", f"sudo cat {INSTALL_LOG}", password="live", check=False)
        if out:
            self.save("dakota-install.log", out)
        else:
            log(f"  no {INSTALL_LOG}")

    def wait_luks_prompt(self, phase, label, timeout=600):
        """Wait for Plymouth's graphical passphrase prompt and screenshot it.

        Dakota's Plymouth theme is bgrt (firmware logo, no watermark), so
        there is no watermark to match as on Utah. The prompt must be on
        screen (tesseract reads "passphrase"), and it must not be the text
        fallback: a console prompt comes with a screen of boot messages,
        Plymouth's graphical one with a few words."""
        end = time.time() + timeout
        probe = self.debug / f"prompt-probe-{slug(phase)}.png"
        while time.time() < end:
            if self.vm.poll() is not None:
                raise Fail(f"{phase}: VM exited before the passphrase prompt")
            ppm = self.screendump(probe)
            text = ocr(ppm)
            if re.search(r"pass ?phrase|password", text, re.I):
                words = len(text.split())
                png = self.shots / f"{label}.png"
                self.to_png(ppm, png)
                mode = "text console" if words > 60 else "graphical"
                self.manifest.append({"file": png.name, "stage": label,
                                      "proves": f"{phase}: Plymouth LUKS passphrase prompt ({mode}, {words} words on screen)"})
                self.write_manifest()
                log(f"  {phase}: passphrase prompt ({mode}, {words} words): {' '.join(text.split())[:160]!r}")
                if mode != "graphical":
                    raise Fail(f"{phase}: the passphrase prompt is the text console, not Plymouth's graphical splash")
                return
            ppm.unlink(missing_ok=True)
            time.sleep(3)
        self.shot(f"fail-no-prompt-{slug(phase)}", f"FAILURE: {phase}: no passphrase prompt within {timeout}s")
        raise Fail(f"{phase}: no passphrase prompt within {timeout}s")

    def installed_boot(self, phase, unlock_label):
        """Boot (or reboot) the installed disk: Plymouth prompt, unlock, graphical target."""
        self.wait_luks_prompt(phase, unlock_label)
        r = subprocess.run([sys.executable, str(SCRIPTS / "luks-unlock.py"), "qemu", self.mon_sock, PIN, str(self.serial),
                            str(self.ssh_port)], capture_output=True, text=True)
        self.save(f"unlock-{slug(phase)}.log", r.stdout + r.stderr)
        if r.returncode != 0:
            self.shot(f"fail-unlock-{slug(phase)}", f"FAILURE: {phase} unlock")
            raise Fail(f"{phase}: LUKS unlock failed ({r.returncode})")
        self.wait_ssh("root", 600)
        end = time.time() + 600
        while time.time() < end:
            if self.ssh("root", "systemctl is-active graphical.target", check=False).strip() == "active":
                break
            time.sleep(5)
        else:
            raise Fail(f"{phase}: graphical.target not reached")
        facts = self.ssh("root", "cat /proc/cmdline; echo; findmnt -no FSTYPE,SOURCE,OPTIONS /sysroot; findmnt -no FSTYPE,SOURCE,OPTIONS /; "
                         "findmnt -no FSTYPE,SOURCE,OPTIONS /etc; findmnt -no FSTYPE,SOURCE,OPTIONS /var; "
                         "lsblk -f; cat /etc/crypttab; bootctl list --no-pager 2>&1 | head -40; "
                         "systemctl is-active gdm.service graphical.target; systemctl --failed --no-legend; bootc status", check=False)
        self.save(f"facts-{slug(phase)}.txt", facts)
        self.record_boot(phase, "root")
        if LIVE_KARG in facts.split("\n", 1)[0]:
            raise Fail(f"{phase}: installed system booted with {LIVE_KARG}")
        self.scp_to("root", HERE / "atspi_drive.py", "/var/tmp/atspi_drive.py")
        self.scp_to("root", HERE / "vte_term.py", "/var/tmp/vte_term.py")
        self.ssh("root", "chmod 0755 /var/tmp/atspi_drive.py /var/tmp/vte_term.py")

    def user_runner(self, user):
        def run(command):
            uid = self.ssh("root", f"id -u {user}").strip()
            env = f"DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{uid}/bus XDG_RUNTIME_DIR=/run/user/{uid}"
            # Dakota has no runuser; root's sudo does the same here.
            return self.ssh("root", f"sudo -u {user} env {env} sh -c {shlex.quote(command)}")
        return run

    def initial_setup(self):
        log("=== Stage 3: gnome-initial-setup creates the user ===")
        # ps truncates long user names and comm is cut at 15 characters: match the
        # executable path and resolve the uid.
        find_gis = ("ps -eo uid=,args= | awk '{u=$1; $1=\"\"; if ($0 ~ /\\/gnome-initial-setup( |$)/) {print u; exit}}' "
                    "| xargs -r id -nu")
        gis_user = ""
        end = time.time() + 300
        while not gis_user and time.time() < end:
            gis_user = self.ssh("root", find_gis, check=False).strip()
            if not gis_user:
                time.sleep(5)
        if not gis_user:
            self.shot("fail-no-gis", "FAILURE: gnome-initial-setup never started")
            raise Fail("gnome-initial-setup did not start on first boot")
        log(f"  gnome-initial-setup runs as {gis_user}")
        r, app = self.user_runner(gis_user), GIS_APP
        self.wait_for(r, app, lambda n: has_name(n, "Next") or has_name(n, "~Start Using"), "initial setup window", 300)
        self.maximize(r, app)
        previous = None
        for step in range(20):
            nodes = self.snapshot(r, app)
            self.save(f"atspi-gis-{step:02d}.json", json.dumps(nodes, indent=1))
            page = page_title(nodes)
            log(f"  initial setup page {step}: {page!r}")
            entries = [n for n in nodes if n["role"] in ("text", "entry", "password text") and "editable" in n["states"]]
            pw = [n for n in entries if n["role"] == "password text"]
            txt = [n for n in entries if n["role"] != "password text"]
            if pw:
                for n in pw[:2]:
                    self.fill(r, app, n, PASSWORD)
            elif has_text(nodes, "Full Name") or has_name(nodes, "Full Name"):
                if txt:
                    self.fill(r, app, txt[0], USER_FULL)
                    time.sleep(1)
                if len(txt) > 1:
                    self.fill(r, app, txt[1], USER)
            time.sleep(1)
            self.shot(f"13-gis-{step:02d}-{slug(page)[:30]}", f"gnome-initial-setup on the installed system: {page}", True)
            nodes = self.snapshot(r, app)
            start_using = [n for n in nodes if norm(n["name"]).startswith("start using") and "sensitive" in n["states"]]
            if start_using:
                self.atspi(r, "act", app, start_using[0]["name"])
                break
            nxt = [n for n in nodes if norm(n["name"]) in ("next", "skip") and "sensitive" in n["states"]]
            if not nxt:
                self.save(f"atspi-gis-stuck-{step:02d}.json", json.dumps(nodes, indent=1))
                raise Fail(f"initial setup page {page!r}: no sensitive Next/Skip")
            sig = page_sig(nodes)
            self.press(r, app, nxt[0]["name"], lambda n, s=sig: page_sig(n) != s or has_name(n, "~Start Using"),
                       f"page after {page}", timeout=60)
            previous = page
        else:
            raise Fail(f"initial setup did not finish in 20 pages (last {previous!r})")
        self.wait_user_shell()

    def wait_user_shell(self):
        end = time.time() + 300
        while time.time() < end:
            if self.ssh("root", f"pgrep -u {USER} -x gnome-shell >/dev/null && echo up", check=False).strip() == "up":
                time.sleep(20)
                return
            time.sleep(5)
        self.shot("fail-no-session", f"FAILURE: no GNOME session for {USER}")
        raise Fail(f"no gnome-shell for {USER}")

    def gdm_login(self, phase, label):
        self.key("shift")
        time.sleep(3)
        self.shot(label, f"{phase}: GDM greeter offers the account created by gnome-initial-setup", True)
        self.key("ret")
        time.sleep(3)
        self.type(PASSWORD, enter=True)
        self.wait_user_shell()

    def close_overview(self):
        """Leave the overview GNOME Shell opens at login, checked through its D-Bus property.

        Run 44866213203: one Escape right after the first login (gnome-initial-setup's
        hand-off) left the overview up. Press Escape like a user until the Shell says
        it is closed; set the property only if keys never take."""
        r = self.user_runner(USER)
        prop = ("gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell "
                "--method org.freedesktop.DBus.Properties.{} org.gnome.Shell OverviewActive{}")
        for attempt in range(5):
            try:
                active = "true" in r(prop.format("Get", ""))
            except Fail as e:
                log(f"  OverviewActive unreadable: {e}")
                self.key("esc")
                time.sleep(3)
                return
            if not active:
                return
            if attempt < 4:
                self.key("esc")
            else:
                log("  overview still active after Escape; closing it through org.gnome.Shell")
                try:
                    r(prop.format("Set", " '<false>'"))
                except Fail as e:
                    log(f"  could not close the overview: {e}")
            time.sleep(3)

    def desktop_and_status(self, phase, prefix):
        # Close the overview (and Shell's first-login welcome dialog) over the desktop.
        self.close_overview()
        self.shot(f"{prefix}-desktop", f"{phase}: GNOME desktop for {USER}", True)
        status = self.ssh("root", "bootc status", check=False)
        status_json = self.ssh("root", "bootc status --json", check=False)
        self.save(f"bootc-status-{slug(phase)}.txt", status)
        self.save(f"bootc-status-{slug(phase)}.json", status_json)
        cmd = f"echo {PASSWORD} | sudo -S -p '' bootc status"
        unit = f"dakota-e2e-term-{prefix}"
        self.ssh("root", f"systemd-run --machine={USER}@.host --user --collect --unit={unit} "
                         f"python3 /var/tmp/vte_term.py 'bootc status' {shlex.quote(cmd)}", check=False)
        time.sleep(15)
        self.shot(f"{prefix}-bootc-status", f"{phase}: terminal on the desktop running `bootc status`", True)
        self.ssh("root", f"systemctl --machine={USER}@.host --user stop {unit}", check=False)
        try:
            return json.loads(status_json)["status"]["booted"]["image"]["imageDigest"]
        except (KeyError, TypeError, json.JSONDecodeError):
            raise Fail(f"{phase}: bootc status --json has no booted image digest")

    def reboot(self):
        self.ssh("root", "systemctl reboot --no-block", check=False)
        end = time.time() + 120
        while time.time() < end:
            try:
                self.ssh("root", "true", timeout=10)
                time.sleep(2)
            except (Fail, subprocess.TimeoutExpired):
                return
        raise Fail("installed system did not go down for reboot")

    def check_flatpaks(self, phase, removed=None):
        """The baked Flatpaks are all there, except the one the user removed."""
        if not self.args.flatpaks:
            return
        baked = [a for a in Path(self.args.flatpaks).read_text().split() if a]
        # flatpak-preinstall.service runs in the background on every boot and
        # has the network here: let it finish, so a removed app it would
        # reinstall is back before we look.
        end = time.time() + 900
        while time.time() < end:
            state = self.ssh("root", "systemctl show -P ActiveState flatpak-preinstall.service", check=False).strip()
            if state not in ("activating", "deactivating"):
                break
            time.sleep(10)
        installed = self.ssh("root", "flatpak list --system --app --columns=application", check=False).split()
        self.save(f"flatpaks-{slug(phase)}.txt", "\n".join(installed) + "\n\n" + self.ssh(
            "root", "journalctl -b -u flatpak-preinstall.service --no-pager -n 40", check=False))
        problems = flatpak_problems(baked, installed, removed)
        self.results.flatpak(phase, installed, problems)
        log(f"  {phase}: {len(installed)} Flatpak apps; problems: {problems or 'none'}")
        if problems:
            raise Fail(f"{phase}: Flatpaks: {'; '.join(problems)}")

    def remove_flatpak(self):
        """Remove one baked app the way a user would; it must stay removed."""
        if not self.args.flatpaks:
            return None
        baked = sorted(a for a in Path(self.args.flatpaks).read_text().split() if a)
        app = self.args.remove_flatpak if self.args.remove_flatpak in baked else baked[0]
        self.save("flatpak-remove.log", self.ssh("root", f"flatpak uninstall --system --noninteractive -y {shlex.quote(app)} 2>&1"))
        log(f"  removed Flatpak {app}")
        return app

    def installed(self):
        log("=== Stage 3: first boot of the installed disk ===")
        self.results.begin("first boot unlock")
        vars_installed = self.work / "vars-installed.fd"
        shutil.copy(self.vars_live, vars_installed)
        self.start_vm("installed", [
            {"drive": f"file={self.work / 'install.qcow2'},format=qcow2,if=none,id=target",
             "device": "virtio-blk-pci,drive=target,bootindex=1"},
        ], vars_installed, self.args.ssh_port + 1)
        self.installed_boot("first boot", "12-first-boot-luks-prompt")
        self.results.begin("initial setup")
        self.initial_setup()
        self.results.begin("first boot desktop")
        self.baseline_digest = self.desktop_and_status("first boot", "14-first-boot")
        self.check_flatpaks("first boot")
        removed = self.remove_flatpak()
        log(f"  baseline digest {self.baseline_digest}")

        log("=== Stage 4: bootc switch to the candidate digest ===")
        self.results.begin("bootc switch")
        start = time.time()
        out = self.ssh("root", f"bootc switch {shlex.quote(self.args.candidate)} 2>&1", timeout=3600, check=False)
        self.save("bootc-switch.log", out)
        self.timings["bootc-switch-seconds"] = int(time.time() - start)
        staged = (json.loads(self.ssh("root", "bootc status --json"))["status"].get("staged") or {})
        staged_digest = (staged.get("image") or {}).get("imageDigest")
        log(f"  staged: {staged_digest}")
        if not staged_digest:
            raise Fail("bootc switch staged nothing (evidence/bootc-switch.log)")
        self.reboot()
        self.installed_boot("after bootc switch", "20-switch-luks-prompt")
        self.gdm_login("after bootc switch", "21-switch-gdm")
        digest = self.desktop_and_status("after bootc switch", "22-switch")
        self.check_flatpaks("after bootc switch", removed)
        if self.candidate_digest and digest != self.candidate_digest:
            raise Fail(f"after switch booted {digest}, expected {self.candidate_digest}")

        log("=== Stage 5: bootc rollback ===")
        self.results.begin("bootc rollback")
        self.save("bootc-rollback.log", self.ssh("root", "bootc rollback 2>&1"))
        self.reboot()
        self.installed_boot("after bootc rollback", "30-rollback-luks-prompt")
        self.gdm_login("after bootc rollback", "31-rollback-gdm")
        digest = self.desktop_and_status("after bootc rollback", "32-rollback")
        self.check_flatpaks("after bootc rollback", removed)
        if digest != self.baseline_digest:
            raise Fail(f"after rollback booted {digest}, expected baseline {self.baseline_digest}")
        self.stop_vm(lambda: self.ssh("root", "systemctl poweroff --no-block", check=False))


def norm(text):
    return (text or "").replace("_", "").strip().lower()


def slug(text):
    return "".join(c if c.isalnum() else "-" for c in (text or "page").lower()).strip("-") or "page"


def has_text(nodes, text):
    t = text.lower()
    return any(t in (n["name"] + " " + n["text"]).lower() for n in nodes)


def has_name(nodes, name, sensitive=False):
    return named(nodes, name, sensitive) is not None


def named(nodes, name, sensitive=False):
    want = norm(name)
    for n in nodes:
        got = norm(n["name"])
        if (want[1:] in got if want.startswith("~") else got == want):
            if not sensitive or "sensitive" in n["states"]:
                return n
    return None


def row_containing(nodes, text):
    """The list row (or, failing that, the node) whose name/text contains text."""
    t = text.lower()
    by_path = {n["path"]: n for n in nodes}
    for n in nodes:
        if t not in f"{n['name']} {n['text']}".lower() or not n.get("ext"):
            continue
        parts = n["path"].split(".")
        while parts:
            cand = by_path.get(".".join(parts))
            if cand and cand["role"] in ("list item", "table row", "row") and cand.get("ext"):
                return cand
            parts.pop()
        return n
    return None


def top_frame(nodes):
    frames = [n for n in nodes if n["role"] in ("frame", "window", "dialog") and n.get("ext") and n["ext"][2] > 0]
    return max(frames, key=lambda n: n["ext"][2] * n["ext"][3]) if frames else None


def install_finished(nodes):
    return has_text(nodes, "Restart System") or has_text(nodes, "Error During Installation")


def page_sig(nodes):
    """What identifies a page: its showing headings and labels."""
    return frozenset((n["role"], n["name"] or n["text"]) for n in nodes if n["role"] in ("heading", "label"))


def page_title(nodes):
    for n in nodes:
        if n["role"] == "heading" and (n["name"] or n["text"]):
            return n["name"] or n["text"]
    labels = [n["name"] or n["text"] for n in nodes if n["role"] == "label" and (n["name"] or n["text"])]
    return labels[0] if labels else "page"


def ocr(ppm):
    """Text tesseract reads in a screendump ('' if it cannot)."""
    try:
        r = subprocess.run(["tesseract", str(ppm), "-", "--psm", "3"], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return r.stdout if r.returncode == 0 else ""


def drawn(ppm, min_colors=8):
    """True when a PPM screendump is more than a flat or near-flat frame."""
    try:
        data = ppm.read_bytes()
    except OSError:
        return False
    if not data.startswith(b"P6"):
        return False
    parts = data.split(b"\n", 3)
    try:
        w, h = map(int, parts[1].split())
        body = parts[3]
    except (ValueError, IndexError):
        return False
    step = max(1, (w * h) // 20000) * 3
    colors = {body[i:i + 3] for i in range(0, len(body) - 3, step)}
    return len(colors) >= min_colors


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--raw", required=True)
    ap.add_argument("--work", required=True)
    ap.add_argument("--candidate", required=True, help="image ref (prefer @sha256 digest) for bootc switch")
    ap.add_argument("--ssh-key", required=True, help="private key whose public half is root's authorized key on the image")
    ap.add_argument("--ssh-port", type=int, default=2240)
    ap.add_argument("--ram", type=int, default=6144)
    ap.add_argument("--cpus", type=int, default=4)
    ap.add_argument("--target-size", default="48G")
    ap.add_argument("--install", choices=("gui", "script"), default="gui")
    ap.add_argument("--flatpaks", help="apps baked into the medium (bake-flatpaks.sh flatpak-apps.txt)")
    ap.add_argument("--remove-flatpak", default="org.gnome.Calculator",
                    help="baked app to remove after first boot (default: first baked app if absent)")
    args = ap.parse_args()
    h = Harness(args)
    try:
        h.live()
        if args.install == "gui":
            h.installer()
        else:
            h.script_install()
        h.installed()
        h.results.finish()
        log("PASS: all stages")
        return 0
    except Exception as e:  # noqa: BLE001
        h.results.finish(e)
        log(f"FAIL: {e}")
        if h.vm is not None and h.vm.poll() is None:
            try:
                h.shot("fail-final", f"FAILURE state: {e}")
            except Exception:  # noqa: BLE001
                pass
            if h.serial is not None and h.serial.name.startswith("live"):
                h.grab_install_log()
            h.collect_journal("failure")
        return 1
    finally:
        h.write_manifest()
        h.save("timings.json", json.dumps(h.timings, indent=1) + "\n")
        h.save("results.json", json.dumps(h.results.as_dict(h.timings), indent=1) + "\n")
        if h.vm is not None and h.vm.poll() is None:
            h.vm.kill()


if __name__ == "__main__":
    sys.exit(main())
