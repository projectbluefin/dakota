#!/usr/bin/python3
"""Install daemon for the Bluefin Dakota live session.

The running live filesystem (btrfs seed plus zram) is moved onto the
target disk, encrypted unless the user turns that off, so the live session
becomes the installed system without a restart. The installer application (ui/installer.py) drives it
over D-Bus.

Only an administrator in an active local session, or root, may call it. It
keeps running after the install, on a system that by then has real
accounts, and it can erase disks and holds the recovery key.

An install has two parts. Preparing the disk can fail without harm and be
tried again. Once the session starts to move, a failure leaves the live
filesystem spread over two devices, and only a restart from the install
media recovers.
"""
import fcntl
import grp
import json
import os
import pwd
import re
import secrets
import struct
import subprocess
import sys
import threading
import time
import traceback

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

import disks

BUS = 'org.gnome.Installer1'
OBJ = '/org/gnome/Installer'
ADMIN_GROUP = 'wheel'
CERT = '/usr/lib/dakota/secure-boot/dakota-secure-boot.der'
MOK_PASSWORD = 'dakota'
WORK = '/run/dakota-installer'
STATE = f'{WORK}/state.json'
MAPPING = 'root'
CLEANUP_MARKER = '/etc/dakota-live-cleanup-pending'
AUTOSTART = '/etc/xdg/autostart/org.projectbluefin.Installer.desktop'
LIVE_FS = '/var'  # writable mount of the live btrfs; /sysroot is read-only
FS_IOC_ENABLE_VERITY = 0x40806685
NO_TPM = ("This computer has no TPM 2.0 security chip, or it is turned off "
          "in the firmware setup. Disk encryption needs it.")
STOPPED = ('The installer stopped unexpectedly. Restart from the install '
           'media to try again.')

# %s is the root partition. The partition label would not do: another disk
# can carry a partition with the same label.
RESEAL_UNIT = """[Unit]
Description=Seal disk encryption to the Secure Boot state
ConditionSecurity=uefi-secureboot
ConditionPathExists=/etc/dakota-tpm-reseal-pending
After=tpm2.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemd-cryptenroll --unlock-tpm2-device=auto --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 %s
ExecStartPost=/usr/bin/rm -f /etc/dakota-tpm-reseal-pending

[Install]
WantedBy=multi-user.target
"""


class Denied(dbus.DBusException):
    _dbus_error_name = 'org.freedesktop.DBus.Error.AccessDenied'


class Refused(dbus.DBusException):
    _dbus_error_name = 'org.projectbluefin.Installer.Refused'


def log(message):
    print(message, file=sys.stderr, flush=True)


def run(*args, **kwargs):
    r = subprocess.run(args, capture_output=True, text=True, **kwargs)
    if r.returncode != 0:
        output = (r.stderr or r.stdout).strip()
        log(f"{' '.join(args)}: exit {r.returncode}\n{output}")
        lines = output.splitlines() or ['failed']
        # The last line is often a follow-on message; prefer the failure.
        failed = [l for l in lines if 'ailed' in l or 'rror' in l]
        raise RuntimeError(f"{args[0]}: {(failed or lines)[-1]}")
    return r.stdout


def quiet(*args, **kwargs):
    """Run a command whose failure does not matter."""
    return subprocess.run(args, capture_output=True, text=True, **kwargs)


def os_release():
    out = {}
    with open('/usr/lib/os-release') as f:
        for line in f:
            k, sep, v = line.strip().partition('=')
            if sep:
                out[k] = v.strip('"')
    return out


def has_tpm2():
    try:
        with open('/sys/class/tpm/tpm0/tpm_version_major') as f:
            return f.read().strip() == '2'
    except OSError:
        return False


def live_esp():
    """Mount point of the install media's ESP, mounting it if needed.

    systemd-boot records the partition it was started from, which also
    covers optical media, where the ESP is a partition of a loop device.
    """
    # An automount point counts as a mount even when nothing can be mounted
    # there, so ask for the filesystem.
    if quiet('findmnt', '-n', '-t', 'vfat', '/boot').returncode == 0:
        return '/boot'
    target = f'{WORK}/live-esp'
    if os.path.ismount(target):
        return target
    var = ('/sys/firmware/efi/efivars/'
           'LoaderDevicePartUUID-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f')
    with open(var, 'rb') as f:
        uuid = f.read()[4:].decode('utf-16-le').strip('\0').lower()
    os.makedirs(target, exist_ok=True)
    run('mount', '-o', 'ro', f'/dev/disk/by-partuuid/{uuid}', target)
    return target


def release_media(devices):
    """Let go of the install media once nothing is read from it any more.

    An optical disc is used through a loop device that systemd attached
    (systemd-loop@.service). It would stay attached, and the disc locked in
    the drive, until the next restart.
    """
    quiet('umount', f'{WORK}/live-esp')
    for dev in devices:
        parent = quiet('lsblk', '-no', 'PKNAME', dev).stdout.strip()
        if not parent.startswith('loop'):
            continue
        try:
            with open(f'/sys/block/{parent}/loop/backing_file') as f:
                backing = f.read().strip()
            unit = subprocess.run(
                ['systemd-escape', '--template=systemd-loop@.service',
                 '--path', backing], capture_output=True, text=True,
                check=True).stdout.strip()
            quiet('systemctl', 'stop', unit)
        except (OSError, subprocess.CalledProcessError):
            pass
        if os.path.exists(f'/sys/block/{parent}/loop/backing_file'):
            quiet('losetup', '-d', f'/dev/{parent}')


def secure_boot_enabled():
    r = quiet('mokutil', '--sb-state')
    return 'SecureBoot enabled' in r.stdout + r.stderr


def key_enrolled():
    r = quiet('mokutil', '--ignore-keyring', '--test-key', CERT)
    return 'already enrolled' in r.stdout + r.stderr


def fs_devices():
    """Return {path: used_bytes} for the live filesystem's devices."""
    out = run('btrfs', 'filesystem', 'show', '--raw', LIVE_FS)
    return {m.group(2): int(m.group(1))
            for m in re.finditer(r'used (\d+) path (\S+)', out)}


def swap_files():
    """The swap files in use. Swap on a device is not one of them."""
    with open('/proc/swaps') as f:
        entries = [line.split() for line in f.read().splitlines()[1:]]
    return [entry[0] for entry in entries if entry[1] == 'file']


def devices_in_use():
    """Kernel names of the devices the session runs from."""
    paths = list(fs_devices())
    paths += quiet('findmnt', '-no', 'SOURCE', live_esp()).stdout.split()
    names = set()
    for path in paths:
        names.update(quiet('lsblk', '-no', 'KNAME', path).stdout.split())
        names.add(os.path.basename(path))
    return names


def installable_disks():
    return disks.describe(disks.lsblk(), devices_in_use(), disks.candidates())


def new_recovery_key():
    # The alphabet systemd uses for recovery keys (modhex): the same keys
    # on every keyboard layout.
    groups = [''.join(secrets.choice('cbdefghijklnrtuv') for _ in range(8))
              for _ in range(8)]
    return '-'.join(groups)


def strip_autologin():
    conf = '/etc/gdm/custom.conf'
    if not os.path.exists(conf):
        return
    with open(conf) as f:
        lines = [l for l in f
                 if not l.startswith(('AutomaticLogin', 'InitialSetupEnable'))]
    with open(conf, 'w') as f:
        f.writelines(lines)


def enable_unit(name, text):
    with open(f'/etc/systemd/system/{name}', 'w') as f:
        f.write(text)
    wants = '/etc/systemd/system/multi-user.target.wants'
    os.makedirs(wants, exist_ok=True)
    link = os.path.join(wants, name)
    if not os.path.lexists(link):
        os.symlink(f'../{name}', link)


def release_disk(disk):
    """Take the disk out of use and make the kernel forget its partitions.

    The desktop mounts a partition when the user opens it in Files. And
    systemd-repart cannot create a partition while the kernel still has an
    old one under the same number, so the old table goes first: wipefs
    makes the kernel read the now empty disk again, which also fails
    cleanly when something still uses a partition.
    """
    def unmount(devices):
        for device in devices:
            unmount(device.get('children', []))
            for mountpoint in device.get('mountpoints') or []:
                if mountpoint == '[SWAP]':
                    run('swapoff', device['path'])
                elif mountpoint:
                    run('umount', mountpoint)
    tree = json.loads(run('lsblk', '--json', '--output', 'PATH,MOUNTPOINTS',
                          disk))
    unmount(tree['blockdevices'])
    run('wipefs', '--all', '--quiet', disk)
    run('udevadm', 'settle')
    left = run('lsblk', '-ln', '-o', 'PATH', disk).split()[1:]
    if left:
        raise RuntimeError(f'{", ".join(left)} is still in use')


def close_mapping():
    """Close a LUKS mapping left by an install that did not get to the move."""
    if not os.path.exists(f'/dev/mapper/{MAPPING}'):
        return
    if f'/dev/mapper/{MAPPING}' in fs_devices():
        raise RuntimeError('The session already runs from an installed disk.')
    run('/usr/bin/systemd-cryptsetup', 'detach', MAPPING)


class Installer(dbus.service.Object):
    def __init__(self, bus, loop):
        super().__init__(bus, OBJ)
        self._bus = bus
        self._loop = loop
        self._lock = threading.Lock()
        self._state = 'idle'
        self._step = ''
        self._fraction = 0.0
        self._key = ''
        self._mok_queued = False
        self._message = ''  # the error of a failed install, or a warning
        self._restore()

    # -- state ------------------------------------------------------------
    def _save(self):
        """Keep the outcome where a restarted daemon finds it.

        The recovery key is shown at the end of the install, in another
        session than the one that started it. Without this a daemon crash
        in between would lose the only copy.
        """
        os.makedirs(WORK, exist_ok=True)
        fd = os.open(f'{STATE}.new', os.O_WRONLY | os.O_CREAT | os.O_TRUNC,
                     0o600)
        with os.fdopen(fd, 'w') as f:
            json.dump({'state': self._state, 'key': self._key,
                       'mok_queued': self._mok_queued,
                       'message': self._message}, f)
        os.replace(f'{STATE}.new', STATE)

    def _restore(self):
        try:
            with open(STATE) as f:
                saved = json.load(f)
        except (OSError, ValueError):
            return
        self._state = saved['state']
        self._key = saved['key']
        self._mok_queued = saved['mok_queued']
        self._message = saved['message']
        if self._state == 'preparing':
            self._state, self._key = 'idle', ''
        elif self._state == 'installing':
            self._state, self._message = 'failed', STOPPED
        log(f'restarted; the install is {self._state}')
        self._save()

    def _authorize(self, sender):
        uid = self._bus.get_unix_user(sender)
        if uid == 0:
            return
        try:
            user = pwd.getpwuid(uid)
            admin = grp.getgrnam(ADMIN_GROUP).gr_gid
            is_admin = admin in os.getgrouplist(user.pw_name, user.pw_gid)
        except KeyError:
            is_admin = False
        state = quiet('loginctl', 'show-user', str(uid),
                      '--property=State', '--value').stdout.strip()
        if not is_admin or state != 'active':
            log(f'refused a call from uid {uid}')
            raise Denied('Only an administrator in the active session may '
                         'use the installer.')

    # -- signals ----------------------------------------------------------
    @dbus.service.signal(BUS, signature='')
    def InstallationFinished(self):
        pass

    @dbus.service.signal(BUS, signature='sb')
    def InstallationFailed(self, message, can_retry):
        pass

    @dbus.service.signal(BUS, signature='sd')
    def Progress(self, step, fraction):
        pass

    def _progress(self, step, fraction):
        if step != self._step:
            log(step)
        self._step, self._fraction = step, float(fraction)
        GLib.idle_add(lambda: self.Progress(step, float(fraction)) and False)

    # -- methods ----------------------------------------------------------
    @dbus.service.method(BUS, in_signature='', out_signature='s',
                         sender_keyword='sender')
    def GetEncryptionBlocker(self, sender=None):
        """Why the disk cannot be encrypted on this computer, or ''."""
        self._authorize(sender)
        return '' if has_tpm2() else NO_TPM

    @dbus.service.method(BUS, in_signature='', out_signature='a(sssstbs)',
                         sender_keyword='sender')
    def GetDisks(self, sender=None):
        self._authorize(sender)
        return dbus.Array(
            [(d.name, d.ident, d.model, d.transport, dbus.UInt64(d.size),
              d.has_data, d.problem) for d in installable_disks()],
            signature='(sssstbs)')

    @dbus.service.method(BUS, in_signature='', out_signature='bb',
                         sender_keyword='sender')
    def GetSecureBootState(self, sender=None):
        self._authorize(sender)
        return secure_boot_enabled(), key_enrolled()

    @dbus.service.method(BUS, in_signature='', out_signature='ssdsbs',
                         sender_keyword='sender')
    def GetStatus(self, sender=None):
        """state, step, fraction, recovery key, MOK enrolment queued, message.

        The state is idle, preparing, installing, finished or failed. The
        key is only given out once the install has finished, and is empty
        for a disk that is not encrypted.
        """
        self._authorize(sender)
        key = self._key if self._state == 'finished' else ''
        return (self._state, self._step, self._fraction, key,
                self._mok_queued, self._message)

    @dbus.service.method(BUS, in_signature='ssa{sv}', out_signature='',
                         sender_keyword='sender')
    def Install(self, device, ident, options, sender=None):
        """Erase the disk `device` and install on it.

        `ident` is the identity GetDisks gave for it, so a disk that took
        over the name since then is not erased in its place. The options
        are `encrypt` and `secure-boot`, both on unless given as false.
        """
        self._authorize(sender)
        with self._lock:
            if self._state != 'idle':
                raise Refused('An installation is already running.')
            encrypt = bool(options.get('encrypt', True))
            if encrypt and not has_tpm2():
                raise Refused(NO_TPM)
            try:
                disk = disks.choose(installable_disks(), str(device),
                                    str(ident))
            except disks.Refused as refusal:
                raise Refused(str(refusal))
            # An unsigned image carries no key to enrol.
            want_sb = (bool(options.get('secure-boot', True))
                       and os.path.exists(CERT))
            self._state = 'preparing'
            self._message = ''
            self._key = new_recovery_key() if encrypt else ''
            self._mok_queued = want_sb and not key_enrolled()
            self._save()
        log(f'installing on {disk.name} ({disk.model}, {disk.size} bytes), '
            f'{"encrypted" if encrypt else "not encrypted"}')
        threading.Thread(target=self._install, daemon=True,
                         args=(f'/dev/{disk.name}', encrypt, want_sb)).start()

    @dbus.service.method(BUS, in_signature='', out_signature='',
                         sender_keyword='sender')
    def HandOver(self, sender=None):
        """End the live session so GDM runs initial setup for the real account.

        Refused until the session is moving to the disk: an account made
        before that would be on a system that may never be installed.
        """
        self._authorize(sender)
        if self._state not in ('installing', 'finished'):
            raise Refused('The installation has not started.')
        strip_autologin()
        # GDM refuses initial setup once any session has started this boot
        try:
            os.unlink('/run/gdm/gdm.ran-initial-setup')
        except FileNotFoundError:
            pass
        subprocess.Popen(['loginctl', 'terminate-user', 'live'])

    @dbus.service.method(BUS, in_signature='', out_signature='',
                         sender_keyword='sender')
    def Acknowledge(self, sender=None):
        """The user has seen the result and the recovery key: forget it and stop."""
        self._authorize(sender)
        if self._state != 'finished':
            raise Refused('The installation has not finished.')
        for path in (AUTOSTART, STATE):
            try:
                os.unlink(path)
            except FileNotFoundError:
                pass
        self._key = ''
        log('acknowledged; stopping')
        # After the reply is on its way.
        GLib.timeout_add(500, self._loop.quit)

    @dbus.service.method(BUS, in_signature='', out_signature='',
                         sender_keyword='sender')
    def Restart(self, sender=None):
        self._authorize(sender)
        if self._state in ('preparing', 'installing'):
            raise Refused('The installation is still running.')
        subprocess.Popen(['systemctl', 'reboot'])

    # -- the install ------------------------------------------------------
    def _install(self, disk, encrypt, want_sb):
        try:
            esp, root, target = self._prepare(disk, encrypt)
        except Exception as e:  # report every failure to the UI
            self._failed(e, can_retry=True)
            return
        try:
            self._state = 'installing'
            self._save()
            self._move(esp, root, target, want_sb)
        except Exception as e:
            self._failed(e, can_retry=False)
            return
        self._state = 'finished'
        self._save()
        log('finished')
        GLib.idle_add(lambda: self.InstallationFinished() and False)

    def _failed(self, error, can_retry):
        traceback.print_exc()
        message = str(error) or type(error).__name__
        if can_retry:
            # Nothing of the session is on the disk yet.
            try:
                close_mapping()
            except Exception:
                traceback.print_exc()
            self._state, self._key = 'idle', ''
        else:
            message += '. Restart from the install media to try again.'
            self._state, self._message = 'failed', message
        self._step, self._fraction = '', 0.0
        self._save()
        log(f'failed: {message}')
        GLib.idle_add(
            lambda: self.InstallationFailed(message, can_retry) and False)

    def _prepare(self, disk, encrypt):
        """Partition the disk, and encrypt and unlock it. Safe to repeat.

        Returns the ESP, the root partition and the device the filesystem
        goes on: the unlocked mapping, or the root partition itself when
        the disk is not encrypted.
        """
        self._progress('Preparing the disk', 0.02)
        # btrfs cannot remove a device that holds an active swap file, and
        # the session moves by removing the devices it runs from.
        for path in swap_files():
            run('swapoff', path)
        os.makedirs(f'{WORK}/repart.d', exist_ok=True)
        close_mapping()
        release_disk(disk)
        quiet('systemctl', 'stop', 'flatpak-preinstall.service')
        with open(f'{WORK}/repart.d/10-esp.conf', 'w') as f:
            f.write('[Partition]\nType=esp\nFormat=vfat\nSizeMinBytes=2G\n'
                    f'SizeMaxBytes=2G\nCopyFiles={live_esp()}:/\n')
        with open(f'{WORK}/repart.d/50-root.conf', 'w') as f:
            f.write(disks.root_partition(encrypt))
        repart = ['systemd-repart', '--dry-run=no', '--empty=force',
                  f'--definitions={WORK}/repart.d', '--no-pager']
        if encrypt:
            # With Secure Boot off the policy would change when it is turned
            # on, so bind to no PCR now and let the reseal unit bind to PCR 7
            # later.
            pcrs = '7' if secure_boot_enabled() else ''
            keyfile = f'{WORK}/key'
            fd = os.open(keyfile, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            try:
                os.write(fd, self._key.encode())
                os.close(fd)
                run(*repart, f'--key-file={keyfile}', '--tpm2-device=auto',
                    f'--tpm2-pcrs={pcrs}', disk)
            finally:
                os.unlink(keyfile)
        else:
            run(*repart, disk)
        run('udevadm', 'settle')
        parts = run('lsblk', '-ln', '-o', 'PATH', disk).split()[1:]
        if len(parts) != 2:
            raise RuntimeError(f'expected two partitions on {disk}, '
                               f'found {len(parts)}')
        esp, root = parts
        # systemd-repart flags a root partition to be grown at boot, also
        # with GrowFileSystem=no. The filesystem fills it already, and on
        # an unencrypted root systemd-growfs-root.service would fail on
        # every boot: / is the composefs image, which cannot be grown.
        run('sfdisk', '--part-attrs', disk, '2', '')
        run('udevadm', 'settle')
        if not encrypt:
            return esp, root, root

        self._progress('Unlocking the new disk with the security chip', 0.12)
        run('/usr/bin/systemd-cryptsetup', 'attach', MAPPING, root, '-',
            'tpm2-device=auto,headless=1')
        return esp, root, f'/dev/mapper/{MAPPING}'

    def _move(self, esp, root, target, want_sb):
        self._progress('Moving this session to your disk', 0.15)
        before = fs_devices()
        run('btrfs', 'device', 'add', '-f', target, LIVE_FS)
        zram = [d for d in before if 'zram' in d]
        seed = [d for d in before if 'zram' not in d]
        for d in zram:
            run('btrfs', 'device', 'remove', d, LIVE_FS)
        for d in seed:
            total = max(before[d], 1)
            p = subprocess.Popen(['btrfs', 'device', 'remove', d, LIVE_FS],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                 text=True)
            while p.poll() is None:
                time.sleep(2)
                try:
                    left = fs_devices().get(d, 0)
                except RuntimeError:
                    continue
                done = 1 - min(left / total, 1)
                self._progress('Moving this session to your disk',
                               0.17 + 0.60 * done)
            if p.returncode != 0:
                raise RuntimeError('btrfs: ' + p.stderr.read().strip())
        run('btrfs', 'filesystem', 'label', LIVE_FS, 'root')
        for d in zram:
            try:
                with open(f'/sys/block/{os.path.basename(d)}/reset', 'w') as f:
                    f.write('1')
            except OSError:
                pass

        self._progress('Protecting system files', 0.78)
        os.makedirs(f'{WORK}/fs', exist_ok=True)
        run('mount', target, f'{WORK}/fs')
        try:
            repo = f'{WORK}/fs/composefs'
            objects = [os.path.join(d, name)
                       for d, _, files in os.walk(repo) for name in files]
            arg = struct.pack('IIIIQIIQ88x', 1, 2, 4096, 0, 0, 0, 0, 0)
            for n, p in enumerate(objects):
                if os.path.islink(p) or not os.path.isfile(p):
                    continue
                f = os.open(p, os.O_RDONLY)
                try:
                    fcntl.ioctl(f, FS_IOC_ENABLE_VERITY, arg)
                except FileExistsError:
                    pass
                finally:
                    os.close(f)
                if n % 4000 == 0:
                    self._progress('Protecting system files',
                                   0.78 + 0.12 * n / len(objects))
            run('bootc', 'internals', 'cfs', '--repo', repo,
                '--require-verity', 'fsck')
        finally:
            quiet('umount', f'{WORK}/fs')

        self._progress('Setting up startup', 0.92)
        with open('/proc/cmdline') as f:
            cmdline = f.read().split()
        digest = next(a for a in cmdline if a.startswith('composefs.digest='))
        digest = digest.split('=', 1)[1].lstrip('?')
        kargs = [a for a in cmdline
                 if not a.startswith(('initrd=', 'systemd.mask=', 'root=',
                                      'rootfstype=', 'rootflags=',
                                      'composefs.digest=', 'BOOT_IMAGE='))
                 and a not in ('dakota.live', 'ro', 'rw')]
        kargs.insert(0, 'rw')
        kargs.append(f'composefs.digest={digest}')
        os.makedirs(f'{WORK}/esp', exist_ok=True)
        run('mount', esp, f'{WORK}/esp')
        try:
            e = f'{WORK}/esp'
            bootdir = next(d for d in os.listdir(f'{e}/EFI/Linux')
                           if d.startswith('bootc_composefs-'))
            for junk in (f'{e}/loader/entries/dakota-live.conf',
                         f'{e}/EFI/Linux/{bootdir}/live.cpio',
                         f'{e}/Enroll Dakota Secure Boot key.cer'):
                if os.path.exists(junk):
                    os.unlink(junk)
            rel = os_release()
            os_id = rel.get('ID', 'bluefin').replace('-', '_')
            version = rel.get('VERSION_ID', '0')
            entry = f'{e}/loader/entries/bootc_{os_id}-{version}-0.conf'
            with open(entry, 'w') as f:
                f.write(f'title {rel.get("NAME", "Bluefin")}\n'
                        f'version {version}\n'
                        f'linux /EFI/Linux/{bootdir}/vmlinuz\n'
                        f'initrd /EFI/Linux/{bootdir}/initrd\n'
                        f'options {" ".join(kargs)}\n'
                        f'sort-key bootc-{os_id.replace("_", "-")}-0\n')
        finally:
            quiet('umount', f'{WORK}/esp')

        self._progress('Finishing', 0.96)
        # The installed system must not log the live user in or start the
        # installer: dakota-live-cleanup.service removes them on its first
        # boot. This comes before the steps below, which may fail without
        # making the install any less complete.
        open(CLEANUP_MARKER, 'w').close()
        strip_autologin()
        if target != root and not secure_boot_enabled():
            partuuid = run('lsblk', '-dno', 'PARTUUID', root).strip()
            open('/etc/dakota-tpm-reseal-pending', 'w').close()
            enable_unit('dakota-tpm-reseal.service',
                        RESEAL_UNIT % f'/dev/disk/by-partuuid/{partuuid}')
        os.sync()
        release_media(seed)
        if want_sb and not key_enrolled():
            r = quiet('mokutil', '--ignore-keyring', '--import', CERT,
                      input=f'{MOK_PASSWORD}\n{MOK_PASSWORD}\n')
            if r.returncode == 0:
                quiet('mokutil', '--timeout', '-1')
            else:
                # The system is installed and boots; only the key is missing.
                log(f'mokutil --import: {(r.stderr or r.stdout).strip()}')
                self._mok_queued = False
                self._message = ("Bluefin's Secure Boot key could not be "
                                 'queued for enrolment. Run "ujust '
                                 'enroll-secure-boot-key" after the restart.')
        self._progress('Done', 1.0)


if __name__ == '__main__':
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    dbus.mainloop.glib.threads_init()
    system_bus = dbus.SystemBus()
    main_loop = GLib.MainLoop()
    name = dbus.service.BusName(BUS, system_bus)
    Installer(system_bus, main_loop)
    main_loop.run()
