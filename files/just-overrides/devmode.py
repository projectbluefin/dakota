#!/usr/bin/python3
"""Interactive Dakota developer-tool management, using installed state, not a marker."""

import os
import subprocess
import sys
from dataclasses import dataclass, replace

BREW = "/home/linuxbrew/.linuxbrew/bin/brew"
VMM_APP_ID = "org.virt_manager.virt-manager"
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
    if not confirm("Install VMM and enable local libvirt sockets/services?"):
        raise SetupError(
            "Virtualization setup canceled; no changes were made. Retry with: ujust setup-virtualization"
        )
    try:
        virtualization_preflight()
        checked("sudo", "-v")
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
    if not any(state.enabled for state in states.values()) and not any(
        states[unit].running for unit in SERVICES + SOCKETS
    ):
        print("Local activation is already disabled. No changes were made.")
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
    if not confirm("Check for active guests, then disable local libvirt activation?"):
        return
    checked("sudo", "-v")
    try:
        guests = checked(
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
    except SetupError as error:
        raise SetupError(
            "Cannot verify active guests; refusing to disable anything. Check libvirt and retry."
        ) from error
    if guests.strip():
        raise SetupError(
            f"Active guests prevent disabling virtualization:\n{guests.strip()}\n"
            "Shut them down yourself, then retry ujust manage-virtualization."
        )
    # Never stop virtlogd or virtlockd: guests outside this connection, or started
    # concurrently after the check, may still need them. Only stop management units.
    try:
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
