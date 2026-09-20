#!/usr/bin/python3
"""Developer-tool management; firewall receipts authorize only our own cleanup."""

import fcntl
import json
import os
import re
import select
import stat
import subprocess
import sys
import tempfile
import uuid
import xml.etree.ElementTree as ET
from contextlib import contextmanager
from dataclasses import dataclass, replace
from pathlib import Path

BREW = "/home/linuxbrew/.linuxbrew/bin/brew"
VMM_APP_ID = "org.virt_manager.virt-manager"
FIREWALL_RECEIPT = Path("/var/lib/dakota/virtualization/firewall.json")
BOOT_ID = Path("/proc/sys/kernel/random/boot_id")
NETWORK_SYSFS = Path("/sys/class/net")
FIREWALL = ("sudo", "-n", "timeout", "15s", "firewall-cmd")
VIRSH = (
    "sudo", "-n", "timeout", "15s", "virsh", "--readonly",
    "--connect", "qemu:///system",
)
FIREWALL_SCOPES = {"permanent": ("--permanent",), "runtime": ()}
DRIVERS = (
    "qemu",
    "interface",
    "network",
    "nodedev",
    "nwfilter",
    "secret",
    "storage",
    "proxy",
)
SERVICES = tuple(f"virt{driver}d.service" for driver in DRIVERS)
# Never use virt*.socket globs: those would include remote TCP/TLS listeners.
SOCKETS = tuple(
    f"virt{driver}d{suffix}.socket"
    for driver in DRIVERS
    for suffix in ("", "-ro", "-admin")
)
HELPERS = (
    "virtlogd.socket",
    "virtlogd-admin.socket",
    "virtlockd.socket",
    "virtlockd-admin.socket",
)
BOOT_UNITS = SERVICES + SOCKETS + HELPERS
FOREIGN_UNITS = (
    "libvirtd.service",
    *(f"libvirtd{suffix}.socket" for suffix in ("", "-ro", "-admin", "-tcp", "-tls")),
    "virtproxyd-tcp.socket",
    "virtproxyd-tls.socket",
    "virtvboxd.service",
    "virtvboxd.socket",
    "libvirt-guests.service",
)


class SetupError(Exception):
    """A failed operation that should be reported without a traceback."""


def run(
    *args: str, capture: bool = False, env: dict[str, str] | None = None
) -> subprocess.CompletedProcess:
    """Run argument vectors only. Never interpolate a selection into a shell command."""
    try:
        return subprocess.run(
            args,
            text=True,
            stdout=subprocess.PIPE if capture else None,
            env=env,
            check=False,
        )
    except OSError as error:
        raise SetupError(f"Could not run {args[0]}: {error}") from error


def checked(*args: str, capture: bool = False) -> str:
    result = run(*args, capture=capture)
    if result.returncode:
        raise SetupError(
            f"{args[0]} {args[1]} failed with exit code {result.returncode}."
        )
    return result.stdout or ""


def choose(header: str, options: list[str], *, multiple: bool = False) -> list[str]:
    flags = ["--no-limit", "--selected="] if multiple else []
    result = run("gum", "choose", *flags, f"--header={header}", *options, capture=True)
    if result.returncode in (1, 130, -2):  # Escape or Ctrl-C: no selection, no action.
        return []
    if result.returncode:
        raise SetupError("Could not display the menu.")
    selected = result.stdout.splitlines()
    selected = [item for item in selected if item]
    if any(item not in options for item in selected) or (
        not multiple and len(selected) > 1
    ):
        raise SetupError("Unknown menu selection; nothing was changed.")
    return list(dict.fromkeys(selected))


def confirm(prompt: str) -> bool:
    result = run("gum", "confirm", "--default=false", prompt)
    if result.returncode not in (0, 1, 130, -2):
        raise SetupError("Could not display the confirmation; nothing was changed.")
    return result.returncode == 0


@dataclass(frozen=True)
class App:
    name: str
    package: str
    manager: str
    scope: str = ""

    @property
    def label(self) -> str:
        source = "Homebrew" if self.manager == "brew" else f"Flatpak, {self.scope}"
        return f"{self.name} ({source})"


# Only these known developer apps are eligible for removal. Fonts, CLI tools,
# image packages and unrelated applications are deliberately outside this catalog.
APPS = (
    App("Visual Studio Code", "ublue-os/tap/visual-studio-code-linux", "brew"),
    App(
        "Visual Studio Code Insiders",
        "ublue-os/tap/visual-studio-code-linux@insiders",
        "brew",
    ),
    App("VSCodium", "ublue-os/tap/vscodium-linux", "brew"),
    App("Antigravity IDE", "ublue-os/tap/antigravity-ide-linux", "brew"),
    App("Zed", "ublue-os/tap/zed-linux", "brew"),
    App("JetBrains Toolbox", "ublue-os/tap/jetbrains-toolbox-linux", "brew"),
    App("GNOME Builder", "org.gnome.Builder", "flatpak"),
    App("Clapgrep", "de.leopoldluley.Clapgrep", "flatpak"),
    App("Embellish", "io.github.getnf.embellish", "flatpak"),
    App("Podman Desktop", "io.podman_desktop.PodmanDesktop", "flatpak"),
    App("Dev Toolbox", "me.iepure.devtoolbox", "flatpak"),
    App("Virtual Machine Manager", VMM_APP_ID, "flatpak"),
)


def installed_apps() -> list[App]:
    apps = []
    if os.access(BREW, os.X_OK):
        casks = set(
            checked(
                BREW, "list", "--cask", "--full-name", "-1", capture=True
            ).splitlines()
        )
        apps.extend(
            app for app in APPS if app.manager == "brew" and app.package in casks
        )
    for scope in ("system", "user"):
        packages = set(
            checked(
                "flatpak",
                "list",
                f"--{scope}",
                "--app",
                "--columns=application",
                capture=True,
            ).splitlines()
        )
        apps.extend(
            replace(app, scope=scope)
            for app in APPS
            if app.manager == "flatpak" and app.package in packages
        )
    return apps


def uninstall_apps() -> None:
    try:
        inventory = {app.label: app for app in installed_apps()}
    except SetupError as error:
        raise SetupError(
            f"Could not inspect installed apps; nothing will be removed. {error}"
        ) from error
    if not inventory:
        print("No supported developer apps are installed. Nothing to uninstall.")
        return
    print("Choose apps with x, then Enter. Nothing is preselected; Escape cancels.")
    print(
        "System Flatpaks are shared by every user. Close selected apps before removing them."
    )
    selections = choose(
        "Uninstall selected developer apps", list(inventory), multiple=True
    )
    if not selections:
        return
    for label in selections:
        print(f"Remove: {label}")
    print(
        "User data, fonts, VM definitions and disks are kept. No zap or data cleanup is performed."
    )
    print("Removing JetBrains Toolbox does not uninstall the IDEs it manages.")
    print("This does not disable libvirt or remove image-owned QEMU/libvirt.")
    if not confirm("Uninstall only these selected apps?"):
        return
    failed = []
    for label in selections:
        app = inventory[label]
        try:
            if app.manager == "brew":
                result = run(
                    BREW,
                    "uninstall",
                    "--cask",
                    app.package,
                    env={**os.environ, "HOMEBREW_NO_AUTOREMOVE": "1"},
                )
            else:
                result = run(
                    "flatpak",
                    "uninstall",
                    f"--{app.scope}",
                    "--app",
                    "--assumeyes",
                    "--no-related",
                    app.package,
                )
            if result.returncode:
                failed.append(label)
        except SetupError as error:
            print(error, file=sys.stderr)
            failed.append(label)
    if failed:
        raise SetupError(
            "Could not uninstall: "
            + ", ".join(failed)
            + ". Other selections were attempted. Retry with: ujust uninstall-dev-apps"
        )
    print("Selected apps uninstalled; user data was kept.")


@dataclass(frozen=True)
class UnitState:
    name: str
    load: str
    boot: str
    active: str

    @property
    def enabled(self) -> bool:
        # Treat nonstandard enablement as configured, not as safe to ignore.
        return self.boot not in (
            "",
            "disabled",
            "masked",
            "masked-runtime",
            "not-found",
        )

    @property
    def running(self) -> bool:
        # Transitional states must not be mistaken for an inactive service.
        return self.active not in ("inactive", "failed")


def unit_states(units: tuple[str, ...]) -> dict[str, UnitState]:
    output = checked(
        "systemctl",
        "show",
        "--property=Id,LoadState,UnitFileState,ActiveState",
        *units,
        capture=True,
    )
    states = {}
    for block in output.strip().split("\n\n"):
        fields = dict(line.split("=", 1) for line in block.splitlines() if "=" in line)
        if not all(
            key in fields for key in ("Id", "LoadState", "UnitFileState", "ActiveState")
        ):
            raise SetupError(
                "Incomplete systemd state; refusing to change virtualization."
            )
        states[fields["Id"]] = UnitState(
            fields["Id"],
            fields["LoadState"],
            fields["UnitFileState"],
            fields["ActiveState"],
        )
    if set(states) != set(units):
        raise SetupError(
            "Could not inspect every requested unit; refusing to change virtualization."
        )
    return states


def virtualization_preflight() -> dict[str, UnitState]:
    states = unit_states(BOOT_UNITS)
    for state in states.values():
        if state.load != "loaded":
            raise SetupError(
                f"{state.name} is {state.load}. Missing or masked units must be resolved manually; "
                "nothing was changed."
            )
    # Do not silently migrate or reconfigure somebody's existing deployment.
    for state in unit_states(FOREIGN_UNITS).values():
        if state.enabled or state.running:
            raise SetupError(
                f"{state.name} is active or enabled. Manage this existing libvirt setup manually; "
                "nothing was changed."
            )
    return states


def default_nat_network(xml: str) -> tuple[str, str] | None:
    """Return bridge and UUID only for the standard-zone default NAT network."""
    try:
        network = ET.fromstring(xml)
    except ET.ParseError as error:
        raise SetupError("Could not parse the default libvirt network XML.") from error
    if network.tag != "network" or network.findtext("name") != "default":
        raise SetupError("Unexpected default libvirt network XML.")
    forward = network.find("forward")
    bridge = network.find("bridge")
    if forward is None or forward.get("mode") != "nat":
        return None
    if bridge is None:
        raise SetupError("The default NAT network has no bridge.")
    if bridge.get("zone", "libvirt") != "libvirt":
        return None
    name = bridge.get("name", "")
    if not re.fullmatch(r"[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,14}", name):
        raise SetupError("The default NAT network has no usable bridge name.")
    try:
        network_uuid = str(uuid.UUID(network.findtext("uuid", "")))
    except ValueError as error:
        raise SetupError("The default NAT network has no valid UUID.") from error
    return name, network_uuid


def current_default_nat() -> tuple[str, str] | None:
    networks = checked(
        *VIRSH, "net-list", "--all", "--persistent", "--name", capture=True
    ).splitlines()
    if "default" not in networks:
        return None
    live = default_nat_network(checked(*VIRSH, "net-dumpxml", "default", capture=True))
    saved = default_nat_network(
        checked(*VIRSH, "net-dumpxml", "--inactive", "default", capture=True)
    )
    if live != saved:
        raise SetupError(
            "The default network's live and saved bridge/zone settings differ; "
            "resolve the pending network changes manually before retrying."
        )
    return live


@contextmanager
def firewall_receipt_lock(name: str = "firewall.lock"):
    """Root-owned locks serialize operations and receipt updates independently."""
    directory = FIREWALL_RECEIPT.parent
    directory.mkdir(parents=True, exist_ok=True, mode=0o755)
    info = directory.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.geteuid() or info.st_mode & 0o022:
        raise SetupError("Untrusted virtualization firewall state directory.")
    fd = os.open(directory / name, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid() or info.st_mode & 0o022:
            raise SetupError("Untrusted virtualization firewall lock.")
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise SetupError("Another virtualization operation is running; wait for it to finish and retry.") from error
        yield
    finally:
        os.close(fd)


def operation_lock_worker() -> None:
    """Hold the machine-wide lock until the unprivileged parent's pipe closes."""
    with firewall_receipt_lock("operation.lock"):
        print("virtualization-lock-ready", flush=True)
        sys.stdin.read()


@contextmanager
def virtualization_operation_lock():
    # Keep the menu and user Flatpak inventory unprivileged. Only this small
    # lock holder runs as root; EOF releases its lock even if the parent exits.
    try:
        process = subprocess.Popen(
            ["sudo", "-n", "/usr/bin/python3", str(Path(__file__).resolve()), "_operation-lock"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True,
        )
    except OSError as error:
        raise SetupError(f"Could not start virtualization operation lock: {error}") from error
    try:
        ready, _, _ = select.select([process.stdout], [], [], 15)
        if not ready or process.stdout.readline() != "virtualization-lock-ready\n":
            raise SetupError("Could not acquire virtualization operation lock; check the diagnostic above and retry.")
        yield
        if process.poll() is not None:
            raise SetupError("Virtualization operation lock exited unexpectedly; verify current state before retrying.")
    finally:
        process.stdin.close()
        process.stdin = None
        try:
            process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate()


def firewall_recovery() -> str:
    """Read-only evidence, not permission to erase or adopt uncertain policy."""
    return (
        f"\nOwnership record: {FIREWALL_RECEIPT}\n"
        "Read-only inspection commands (a missing record is not proof of ownership):\n"
        f"  sudo cat {FIREWALL_RECEIPT}\n"
        "  sudo virsh --readonly --connect qemu:///system net-dumpxml --inactive default\n"
        "  sudo firewall-cmd --zone=libvirt --list-interfaces\n"
        "  sudo firewall-cmd --permanent --zone=libvirt --list-interfaces\n"
        "Keep the record and existing rules until an administrator has reviewed their ownership. "
        "Do not delete the record to force a retry."
    )


def load_firewall_receipt() -> dict | None:
    try:
        fd = os.open(FIREWALL_RECEIPT, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except FileNotFoundError:
        return None
    with os.fdopen(fd) as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid() or info.st_mode & 0o022:
            raise SetupError("Untrusted virtualization firewall receipt." + firewall_recovery())
        try:
            if info.st_size > 16384:
                raise ValueError("oversized receipt")
            receipt = json.loads(stream.read(16384))
            if not isinstance(receipt, dict) or set(receipt) != {
                "version", "bridge", "uuid", "boot_id", "permanent", "runtime"
            }:
                raise ValueError("unexpected receipt fields")
            if type(receipt["version"]) is not int or receipt["version"] != 1 or not re.fullmatch(
                r"[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,14}", receipt["bridge"]
            ):
                raise ValueError("unexpected receipt version or bridge")
            uuid.UUID(receipt["uuid"])
            uuid.UUID(receipt["boot_id"])
            if any(receipt[scope] not in ("none", "pending", "owned") for scope in FIREWALL_SCOPES):
                raise ValueError("unexpected ownership status")
        except (ValueError, TypeError, AttributeError) as error:
            raise SetupError("Invalid firewall receipt; refusing automatic changes." + firewall_recovery()) from error
    # A new boot's runtime binding belongs to libvirt/firewalld, not this helper.
    boot_id = BOOT_ID.read_text().strip()
    if receipt["boot_id"] != boot_id:
        receipt["runtime"] = "none"
        receipt["boot_id"] = boot_id
    return receipt


def save_firewall_receipt(receipt: dict) -> None:
    """Atomic, durable receipt update inside the root-owned locked directory."""
    if all(receipt[scope] == "none" for scope in FIREWALL_SCOPES):
        FIREWALL_RECEIPT.unlink(missing_ok=True)
    else:
        fd, name = tempfile.mkstemp(prefix=".firewall-", dir=FIREWALL_RECEIPT.parent)
        try:
            with os.fdopen(fd, "w") as stream:
                json.dump(receipt, stream)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(name, FIREWALL_RECEIPT)
        finally:
            Path(name).unlink(missing_ok=True)
    fd = os.open(FIREWALL_RECEIPT.parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def firewall_bindings(bridge: str) -> dict[str, str]:
    bindings = {}
    for scope, flags in FIREWALL_SCOPES.items():
        zones = checked(*FIREWALL, *flags, "--get-zones", capture=True).split()
        if "libvirt" not in zones:
            raise SetupError("The libvirt firewall zone is missing; check the image/firewalld configuration.")
        bindings[scope] = ""
        # --get-zone-of-interface exits 2 for 'no zone' AND CLI errors.
        # Successful listings avoid interpreting an error as an unbound bridge.
        for zone in zones:
            interfaces = checked(
                *FIREWALL, *flags, f"--zone={zone}", "--list-interfaces", capture=True
            ).split()
            if bridge in interfaces:
                if bindings[scope]:
                    raise SetupError(f"{bridge} appears in multiple {scope} firewall zones; refusing changes.")
                bindings[scope] = zone
    return bindings


def setup_virtualization_firewall() -> None:
    """Root worker, called with the receipt lock held."""
    receipt = load_firewall_receipt()
    checked(*FIREWALL, "--state", capture=True)
    network = current_default_nat()
    if network is None:
        if receipt:
            raise SetupError("The recorded default network changed." + firewall_recovery())
        print("No standard default NAT network; custom networking was not changed or verified.")
        return
    bridge, network_uuid = network
    if receipt and (receipt["bridge"], receipt["uuid"]) != network:
        raise SetupError("The recorded default network changed." + firewall_recovery())
    if receipt is None:
        receipt = {
            "version": 1, "bridge": bridge, "uuid": network_uuid,
            "boot_id": BOOT_ID.read_text().strip(), "permanent": "none", "runtime": "none",
        }
    bindings = firewall_bindings(bridge)
    for scope, zone in bindings.items():
        if zone not in ("", "libvirt"):
            # Once an administrator changes a binding, never reclaim it from
            # a stale receipt if they later move it back to libvirt themselves.
            receipt[scope] = "none"
            save_firewall_receipt(receipt)
            raise SetupError(
                f"{bridge} already belongs to firewall zone {zone}; "
                "leaving custom policy unchanged. Review it manually before retrying."
            )
        if zone and receipt[scope] == "pending":
            raise SetupError(
                "An interrupted firewall addition has uncertain ownership; "
                "Existing bindings were not adopted." + firewall_recovery()
            )
    # Persist intent BEFORE adding, then ownership only AFTER verification.
    # A crash in between is ambiguous, never permission to delete somebody's rule.
    for scope, flags in FIREWALL_SCOPES.items():
        if not bindings[scope]:
            receipt[scope] = "pending"
            save_firewall_receipt(receipt)
            checked(*FIREWALL, *flags, "--zone=libvirt", f"--add-interface={bridge}")
            interfaces = checked(
                *FIREWALL, *flags, "--zone=libvirt", "--list-interfaces", capture=True
            ).split()
            if bridge not in interfaces:
                raise SetupError(f"The libvirt firewall zone binding for {bridge} did not persist.")
            receipt[scope] = "owned"
            save_firewall_receipt(receipt)
    for flags in FIREWALL_SCOPES.values():
        interfaces = checked(
            *FIREWALL, *flags, "--zone=libvirt", "--list-interfaces", capture=True
        ).split()
        if bridge not in interfaces:
            raise SetupError(f"The libvirt firewall zone binding for {bridge} did not persist.")
    save_firewall_receipt(receipt)
    print(f"Default NAT bridge {bridge}: libvirt firewall zone verified now and permanently.")


def cleanup_virtualization_firewall() -> None:
    """Root worker; never infer ownership from a bridge name or zone alone."""
    receipt = load_firewall_receipt()
    if receipt is None:
        print(
            "No helper-owned firewall bindings recorded; existing bindings were kept. "
            "Bindings added manually or by older setup versions cannot safely be removed automatically."
            + firewall_recovery()
        )
        return
    require_no_active_guests()
    checked(*FIREWALL, "--state", capture=True)
    network = current_default_nat()
    if network != (receipt["bridge"], receipt["uuid"]):
        raise SetupError("The recorded default network changed." + firewall_recovery())
    bridge = receipt["bridge"]
    # Session VMs or other users of this bridge may not appear in the system
    # connection's guest list. Do not disrupt their networking either.
    ports = NETWORK_SYSFS / bridge / "brif"
    if ports.is_dir() and any(ports.iterdir()):
        raise SetupError(
            f"{bridge} still has attached interfaces; refusing firewall cleanup. "
            "Stop other bridge users and retry disable."
        )
    bindings = firewall_bindings(bridge)
    if any(receipt[scope] == "pending" and zone == "libvirt" for scope, zone in bindings.items()):
        raise SetupError("An interrupted firewall addition has uncertain ownership." + firewall_recovery())
    # Runtime is normally libvirt-owned and is kept when it predates setup.
    # Do not remove a runtime rule backed by pre-existing permanent policy.
    if receipt["permanent"] == "none" and bindings["permanent"]:
        receipt["runtime"] = "none"
    for scope, flags in FIREWALL_SCOPES.items():
        if receipt[scope] == "owned" and bindings[scope] == "libvirt":
            checked(*FIREWALL, *flags, "--zone=libvirt", f"--remove-interface={bridge}")
            interfaces = checked(
                *FIREWALL, *flags, "--zone=libvirt", "--list-interfaces", capture=True
            ).split()
            if bridge in interfaces:
                raise SetupError(f"The {scope} firewall binding for {bridge} was not removed; retry disable.")
        elif receipt[scope] != "none" and bindings[scope]:
            print(f"Kept changed {scope} firewall policy for {bridge}; it is no longer helper-owned.")
        receipt[scope] = "none"
        save_firewall_receipt(receipt)
    print("Helper-owned firewall bindings removed; pre-existing and custom policy was kept.")


def firewall_action(action: str) -> None:
    # Use system Python, including when testing an uninstalled draft. The root
    # worker owns receipts; the ordinary user process never writes them.
    checked("sudo", "-n", "/usr/bin/python3", str(Path(__file__).resolve()), f"_firewall-{action}")


def require_no_active_guests() -> None:
    try:
        guests = checked(*VIRSH, "list", "--name", capture=True)
    except SetupError as error:
        raise SetupError(
            "Cannot verify active guests; no firewall cleanup or deactivation was attempted. "
            "Inspect with: sudo systemctl status virtqemud.socket virtnetworkd.socket\n"
            "Restore local libvirt management access and retry ujust manage-virtualization. "
            "Starting libvirt can autostart configured guests; do not restart it blindly."
        ) from error
    if guests.strip():
        raise SetupError(
            f"Active guests prevent disabling virtualization:\n{guests.strip()}\n"
            "Shut them down yourself, then retry ujust manage-virtualization."
        )


def setup_virtualization() -> None:
    print(
        "Virtualization setup installs Virtual Machine Manager and activates its system libvirt backend together."
    )
    print(
        "This is a persistent, machine-wide change requiring administrator authorization."
    )
    print(
        "Remote TCP/TLS listeners stay disabled. Existing guest/network/pool autostart settings are respected."
    )
    print(
        "The default NAT bridge will be assigned to the libvirt firewall zone now and permanently. "
        "Custom network zones are not replaced; firewalld must be running."
    )
    if not confirm("Install VMM, enable local libvirt and configure its default NAT firewall?"):
        print("Virtualization setup skipped; no changes were made.")
        return
    try:
        virtualization_preflight()
        checked("sudo", "-v")
        with virtualization_operation_lock():
            # State may have changed while confirmation/authorization was pending.
            virtualization_preflight()
            # Verify the backend before installing the GUI, not just the package download.
            checked("sudo", "-n", "systemctl", "enable", *BOOT_UNITS)
            checked("sudo", "-n", "systemctl", "start", *SOCKETS, *HELPERS)
            states = unit_states(BOOT_UNITS)
            if any(state.boot != "enabled" for state in states.values()):
                raise SetupError("Some units were not persistently enabled.")
            if any(states[unit].active != "active" for unit in SOCKETS + HELPERS):
                raise SetupError("Some local sockets did not start.")
            checked(
                "sudo",
                "-n",
                "timeout",
                "15s",
                "virsh",
                "--readonly",
                "--connect",
                "qemu:///system",
                "list",
                "--name",
                capture=True,
            )
            firewall_action("setup")
            for scope in ("system", "user"):
                installed = checked(
                    "flatpak",
                    "list",
                    f"--{scope}",
                    "--app",
                    "--columns=application",
                    capture=True,
                ).splitlines()
                if VMM_APP_ID in installed:
                    print(
                        "Virtual Machine Manager is already installed; leaving it unchanged."
                    )
                    break
            else:
                checked(
                    "flatpak", "install", "--system", "--assumeyes", "flathub", VMM_APP_ID
                )
    except SetupError as error:
        raise SetupError(
            f"Virtualization setup incomplete: {error} Some changes may remain. "
            "Retry with: ujust setup-virtualization"
        ) from error
    print(
        "Virtual Machine Manager is installed and system libvirt is responding. No reboot is required."
    )


def disable_virtualization(states: dict[str, UnitState]) -> None:
    if not FIREWALL_RECEIPT.exists() and not any(
        state.enabled for state in states.values()
    ) and not any(states[unit].running for unit in SERVICES + SOCKETS):
        print("Local activation is already disabled and no firewall cleanup is pending.")
        return
    print(
        "Close VM managers first. Disabling affects every user and prevents normal VM autostart next boot."
    )
    print(
        "VM definitions, disks, installed apps and autostart preferences are kept; no guest is shut down."
    )
    print(
        "Logging/locking helpers are not stopped, because stopping them can disrupt guests."
    )
    print(
        "Only firewall bindings recorded as added by this helper are removed. "
        "Pre-existing and custom network policy is kept."
    )
    if not confirm("Check for active guests, clean up owned firewall bindings, then disable libvirt?"):
        return
    checked("sudo", "-v")
    # Never stop virtlogd or virtlockd: guests outside this connection, or started
    # concurrently after the check, may still need them. Only stop management units.
    try:
        with virtualization_operation_lock():
            virtualization_preflight()
            require_no_active_guests()
            # Clean up while the management sockets still permit guest/network
            # checks. On failure leave them available for a safe, verified retry.
            firewall_action("cleanup")
            checked("sudo", "-n", "systemctl", "disable", *BOOT_UNITS)
            checked("sudo", "-n", "systemctl", "stop", *SOCKETS, *SERVICES)
            states = unit_states(BOOT_UNITS)
            if any(state.enabled for state in states.values()) or any(
                states[unit].running for unit in SERVICES + SOCKETS
            ):
                raise SetupError("Some units remain enabled or active.")
    except SetupError as error:
        raise SetupError(
            f"Deactivation may be partially applied: {error} Inspect ujust manage-virtualization."
        ) from error
    print("Local management activation disabled. VM data and applications were kept.")
    print(
        "Logging/locking helpers may remain active until reboot. Administrators can still start units manually."
    )


def virtualization() -> None:
    states = unit_states(BOOT_UNITS)
    print(f"{'Unit':28} {'Load':12} {'Boot':12} Now")
    for state in states.values():
        print(f"{state.name:28} {state.load:12} {state.boot:12} {state.active}")
    print(
        "Setup installs VMM, starts local sockets now, and enables the drivers at boot for configured autostart objects."
    )
    print(
        "It does not create VMs, networks or storage pools, or change authentication."
    )
    selection = choose(
        "Manage system virtualization",
        [
            "Set up or repair virtualization (VMM + libvirt)",
            "Disable local activation",
            "Back",
        ],
    )
    if not selection or selection[0] == "Back":
        return
    if selection[0] == "Set up or repair virtualization (VMM + libvirt)":
        setup_virtualization()
    else:
        disable_virtualization(virtualization_preflight())


def menu() -> None:
    print(
        "Dakota developer setup: rerunning this command does not automatically turn anything off."
    )
    print(
        "Apps and virtualization are managed separately; there is no image switch or global enabled marker."
    )
    try:
        print(f"Installed supported developer apps: {len(installed_apps())}")
    except SetupError as error:
        print(f"Installed app inventory is unavailable: {error}", file=sys.stderr)
    try:
        state = unit_states(("virtqemud.socket",))["virtqemud.socket"]
        print(
            f"QEMU management socket: {state.load}, boot={state.boot or 'unavailable'}, now={state.active}."
        )
        print("Other units may differ; use Manage virtualization for full state.")
    except SetupError as error:
        print(f"System virtualization status is unavailable: {error}", file=sys.stderr)
    selection = choose(
        "Manage developer tools",
        [
            "Add or retry developer tools",
            "Manage virtualization",
            "Uninstall selected developer apps",
            "Exit",
        ],
    )
    if not selection or selection[0] == "Exit":
        return
    if selection[0] == "Add or retry developer tools":
        checked("ujust", "install-dev-tools")
    elif selection[0] == "Manage virtualization":
        virtualization()
    else:
        uninstall_apps()


def main() -> int:
    # Private sudo entry points; no interactive menu or Flatpak action runs as root.
    workers = {
        "_firewall-setup": setup_virtualization_firewall,
        "_firewall-cleanup": cleanup_virtualization_firewall,
    }
    if len(sys.argv) == 2 and sys.argv[1] == "_operation-lock":
        if os.geteuid() != 0:
            print("Virtualization locking requires administrator authorization.", file=sys.stderr)
            return 1
        try:
            operation_lock_worker()
        except (SetupError, OSError) as error:
            print(f"Virtualization lock unavailable: {error}", file=sys.stderr)
            return 1
        return 0
    if len(sys.argv) == 2 and sys.argv[1] in workers:
        if os.geteuid() != 0:
            print("Firewall ownership operations require administrator authorization.", file=sys.stderr)
            return 1
        try:
            with firewall_receipt_lock():
                workers[sys.argv[1]]()
        except (SetupError, OSError) as error:
            print(f"Firewall operation incomplete: {error}", file=sys.stderr)
            return 1
        return 0
    actions = {
        "menu": menu,
        "virtualization": virtualization,
        "setup": setup_virtualization,
        "uninstall": uninstall_apps,
    }
    if len(sys.argv) > 2 or (len(sys.argv) == 2 and sys.argv[1] not in actions):
        print(
            "Usage: dakota-devmode [menu|virtualization|setup|uninstall]",
            file=sys.stderr,
        )
        return 2
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        print(
            "Run ujust devmode in a terminal to manage developer tools.",
            file=sys.stderr,
        )
        return 1
    try:
        actions[sys.argv[1] if len(sys.argv) == 2 else "menu"]()
    except SetupError as error:
        print(error, file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print(
            "\nInterrupted. Any operations already completed are kept; check current state before retrying.",
            file=sys.stderr,
        )
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
