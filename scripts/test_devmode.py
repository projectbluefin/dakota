#!/usr/bin/env python3
"""Offline tests of the shipped virtualization setup; never touch the host firewall."""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "dakota_devmode", ROOT / "files/just-overrides/devmode.py"
)
devmode = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = devmode
SPEC.loader.exec_module(devmode)


def network_xml(bridge="virbr0", mode="nat", zone=None):
    zone_attr = f" zone='{zone}'" if zone is not None else ""
    return (
        f"<network><name>default</name><uuid>9d5e493e-94a9-4005-bab6-393c52edbb98</uuid><forward mode='{mode}'/>"
        f"<bridge name='{bridge}'{zone_attr}/></network>"
    )


class FakeHost:
    def __init__(self):
        self.xml = network_xml()
        self.saved_xml = None
        self.networks = "default\n"
        self.zones = {False: "lax libvirt custom", True: "lax libvirt custom"}
        self.bindings = {False: "", True: ""}
        self.calls = []
        self.failure = None
        self.ignore_writes = False
        self.write_failures = {False: 0, True: 0}
        self.vmm_installed = True
        self.vmm_scope = "system"
        self.guests = ""
        self.remove_failures = {False: 0, True: 0}
        self.ignore_removals = False
        self.extra_interfaces = {False: {}, True: {}}

    def run(self, *args, capture=False, env=None):
        self.calls.append(args)
        status, output = 0, ""
        if self.failure and self.failure[0] in args:
            status = self.failure[1]
        elif args == ("sudo", "-v"):
            pass
        elif args[:3] == ("sudo", "-n", "/usr/bin/python3"):
            workers = {
                "_firewall-setup": devmode.setup_virtualization_firewall,
                "_firewall-cleanup": devmode.cleanup_virtualization_firewall,
            }
            with devmode.firewall_receipt_lock():
                workers[args[-1]]()
        elif args[:5] == ("sudo", "-n", "timeout", "15s", "firewall-cmd"):
            permanent = "--permanent" in args
            if "--state" in args:
                output = "running\n"
            elif "--get-zones" in args:
                output = self.zones[permanent]
            elif args[-1].startswith("--get-zone-of-interface="):
                output = self.bindings[permanent]
                # firewalld 2.5.1 uses cmd.fail('no zone'), which exits 2.
                status = 0 if output else 2
            elif args[-1] == "--list-interfaces":
                zone = next(a.split("=", 1)[1] for a in args if a.startswith("--zone="))
                if self.bindings[permanent] == zone:
                    output = devmode.ET.fromstring(self.xml).find("bridge").get("name")
                output += " " + self.extra_interfaces[permanent].get(zone, "")
            elif args[-1].startswith("--add-interface="):
                if "--zone=libvirt" not in args:
                    raise AssertionError(args)
                status = self.write_failures[permanent]
                if not status and not self.ignore_writes:
                    self.bindings[permanent] = "libvirt"
            elif args[-1].startswith("--remove-interface="):
                if "--zone=libvirt" not in args:
                    raise AssertionError(args)
                status = self.remove_failures[permanent]
                if not status and not self.ignore_removals:
                    self.bindings[permanent] = ""
            else:
                raise AssertionError(args)
        elif args[:5] == ("sudo", "-n", "timeout", "15s", "virsh"):
            if args[5:8] != ("--readonly", "--connect", "qemu:///system"):
                raise AssertionError(args)
            if args[8:] == ("net-list", "--all", "--persistent", "--name"):
                output = self.networks
            elif args[8:] == ("net-dumpxml", "default"):
                output = self.xml
            elif args[8:] == ("net-dumpxml", "--inactive", "default"):
                output = self.saved_xml if self.saved_xml is not None else self.xml
            elif args[8:] == ("list", "--name"):
                output = self.guests
            else:
                raise AssertionError(args)
        elif args[:3] == ("sudo", "-n", "systemctl"):
            if args[3] not in ("enable", "start", "disable", "stop"):
                raise AssertionError(args)
        elif args[:2] == ("flatpak", "list"):
            if self.vmm_installed and args[2] == f"--{self.vmm_scope}":
                output = devmode.VMM_APP_ID
        elif args[:2] == ("loginctl", "show-session"):
            output = "yes\n"
        elif args[:2] != ("flatpak", "install"):
            raise AssertionError(args)
        return subprocess.CompletedProcess(args, status, output)

    @property
    def writes(self):
        return [args for args in self.calls if any(a.startswith("--add-interface=") for a in args)]


class VirtualizationFirewallTests(unittest.TestCase):
    def setUp(self):
        self.directory = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.receipt = self.directory / "firewall.json"
        self.boot_id = self.directory / "boot_id"
        self.boot_id.write_text("313b4be7-ccad-4c00-9225-a056f2fe29a0\n")
        self.enterContext(patch.object(devmode, "FIREWALL_RECEIPT", self.receipt))
        self.enterContext(patch.object(devmode, "BOOT_ID", self.boot_id))
        self.network_sysfs = self.directory / "net"
        self.enterContext(patch.object(devmode, "NETWORK_SYSFS", self.network_sysfs))
        self.host = FakeHost()
        self.enterContext(patch.dict(os.environ))
        os.environ.pop("XDG_SESSION_ID", None)
        self.output = io.StringIO()
        self.enterContext(patch.object(devmode, "run", side_effect=self.host.run))
        self.enterContext(patch.object(
            devmode, "virtualization_operation_lock",
            side_effect=lambda: devmode.firewall_receipt_lock("operation.lock"),
        ))
        self.enterContext(contextlib.redirect_stdout(self.output))

    def test_unbound_bridge_is_assigned_now_and_permanently(self):
        devmode.setup_virtualization_firewall()
        self.assertEqual(self.host.bindings, {False: "libvirt", True: "libvirt"})
        self.assertEqual(len(self.host.writes), 2)
        self.assertIn("--permanent", self.host.writes[0])
        self.assertNotIn("--permanent", self.host.writes[1])
        self.assertIn("verified now and permanently", self.output.getvalue())
        # Only read-only network calls and scoped additions: no net-start,
        # restart, reload, runtime-to-permanent or firewall policy rewrites.
        self.assertEqual(self.host.calls[0][-1], "--state")

    def test_bridge_name_is_discovered_not_hard_coded(self):
        self.host.xml = network_xml("virbr7")
        devmode.setup_virtualization_firewall()
        self.assertTrue(all(args[-1] == "--add-interface=virbr7" for args in self.host.writes))

    def test_runtime_only_libvirt_assignment_is_persisted(self):
        self.host.bindings[False] = "libvirt"
        devmode.setup_virtualization_firewall()
        self.assertEqual(len(self.host.writes), 1)
        self.assertIn("--permanent", self.host.writes[0])

    def test_permanent_only_assignment_is_applied_immediately(self):
        self.host.bindings[True] = "libvirt"
        devmode.setup_virtualization_firewall()
        self.assertEqual(len(self.host.writes), 1)
        self.assertNotIn("--permanent", self.host.writes[0])

    def test_rerun_is_idempotent(self):
        devmode.setup_virtualization_firewall()
        self.host.calls.clear()
        devmode.setup_virtualization_firewall()
        self.assertEqual(self.host.writes, [])

    def test_explicit_libvirt_zone_is_supported(self):
        self.host.xml = network_xml(zone="libvirt")
        devmode.setup_virtualization_firewall()
        self.assertEqual(len(self.host.writes), 2)

    def test_custom_xml_is_not_rewritten(self):
        for xml in (network_xml(zone="custom"), network_xml(mode="bridge"), network_xml(mode="route")):
            with self.subTest(xml=xml):
                self.host.xml = xml
                devmode.setup_virtualization_firewall()
                self.assertEqual(self.host.writes, [])
        self.assertIn("not changed or verified", self.output.getvalue())

    def test_no_persistent_default_network_is_not_created(self):
        self.host.networks = "my-custom-network\n"
        devmode.setup_virtualization_firewall()
        self.assertEqual(len(self.host.calls), 2)
        self.assertIn("not changed or verified", self.output.getvalue())

    def test_conflicting_zone_in_either_scope_prevents_all_writes(self):
        for permanent in (False, True):
            with self.subTest(permanent=permanent):
                self.host.bindings = {False: "", True: ""}
                self.host.bindings[permanent] = "custom"
                with self.assertRaisesRegex(devmode.SetupError, "leaving custom policy unchanged"):
                    devmode.setup_virtualization_firewall()
                self.assertEqual(self.host.writes, [])

    def test_missing_zone_in_either_scope_prevents_all_writes(self):
        for permanent in (False, True):
            with self.subTest(permanent=permanent):
                self.host.zones = {False: "lax libvirt", True: "lax libvirt"}
                self.host.zones[permanent] = "lax"
                with self.assertRaisesRegex(devmode.SetupError, "zone is missing"):
                    devmode.setup_virtualization_firewall()
                self.assertEqual(self.host.writes, [])

    def test_pending_bridge_or_zone_change_is_not_overridden(self):
        for xml in (network_xml("virbr1"), network_xml(zone="custom"), network_xml(mode="route")):
            with self.subTest(xml=xml):
                self.host.saved_xml = xml
                with self.assertRaisesRegex(devmode.SetupError, "live and saved"):
                    devmode.setup_virtualization_firewall()
                self.assertEqual(self.host.writes, [])

    def test_malformed_xml_or_missing_bridge_fails_before_writes(self):
        for xml in ("<network>", "<network/>", "<network><name>default</name><forward mode='nat'/></network>", network_xml(""), network_xml("bad/name")):
            with self.subTest(xml=xml):
                self.host.xml = xml
                with self.assertRaises(devmode.SetupError):
                    devmode.setup_virtualization_firewall()
                self.assertEqual(self.host.writes, [])

    def test_firewall_not_running_or_failed_is_not_silently_enabled(self):
        for status in (251, 252):
            with self.subTest(status=status):
                self.host.calls.clear()
                self.host.failure = ("--state", status)
                with self.assertRaises(devmode.SetupError):
                    devmode.setup_virtualization_firewall()
                self.assertEqual(len(self.host.calls), 1)

    def test_no_zone_exit_2_does_not_break_fresh_setup(self):
        # Match the observed host state: live assignment exists, saved one does not.
        self.host.bindings[False] = "libvirt"
        devmode.setup_virtualization_firewall()
        self.assertEqual(self.host.bindings[True], "libvirt")
        self.assertFalse(any(
            arg.startswith("--get-zone-of-interface=")
            for args in self.host.calls for arg in args
        ))

    def test_listing_errors_are_not_treated_as_unbound(self):
        for status in (1, 2, 36, 124, 253):
            with self.subTest(status=status):
                self.host.failure = ("--list-interfaces", status)
                with self.assertRaises(devmode.SetupError):
                    devmode.setup_virtualization_firewall()
                self.assertEqual(self.host.writes, [])

    def test_network_query_failure_does_not_skip_firewall_setup(self):
        self.host.failure = ("net-list", 1)
        with self.assertRaises(devmode.SetupError):
            devmode.setup_virtualization_firewall()
        self.assertEqual(self.host.writes, [])

    def test_successful_write_exit_code_is_not_sufficient(self):
        self.host.ignore_writes = True
        with self.assertRaisesRegex(devmode.SetupError, "did not persist"):
            devmode.setup_virtualization_firewall()
        self.assertNotIn("verified now and permanently", self.output.getvalue())

    def test_partial_failure_can_be_retried(self):
        self.host.write_failures[False] = 253
        with self.assertRaises(devmode.SetupError):
            devmode.setup_virtualization_firewall()
        self.assertEqual(self.host.bindings, {False: "", True: "libvirt"})
        self.assertNotIn("verified now and permanently", self.output.getvalue())
        self.host.write_failures[False] = 0
        self.host.calls.clear()
        devmode.setup_virtualization_firewall()
        self.assertEqual(self.host.bindings, {False: "libvirt", True: "libvirt"})
        self.assertEqual(len(self.host.writes), 1)
        self.assertNotIn("--permanent", self.host.writes[0])

    def setup_with_confirmation(self, confirmed=True):
        states = {
            name: devmode.UnitState(name, "loaded", "enabled", "active")
            for name in devmode.BOOT_UNITS
        }
        with patch.object(devmode, "confirm", return_value=confirmed), patch.object(
            devmode, "virtualization_preflight"
        ), patch.object(devmode, "unit_states", return_value=states):
            devmode.setup_virtualization()

    def test_setup_checks_firewall_even_when_vmm_is_already_installed(self):
        self.setup_with_confirmation()
        self.assertEqual(len(self.host.writes), 2)
        self.assertIn("No reboot is required", self.output.getvalue())

    def test_firewall_failure_blocks_install_and_success_message(self):
        self.host.vmm_installed = False
        self.host.failure = ("--add-interface=virbr0", 253)
        with self.assertRaisesRegex(devmode.SetupError, "Virtualization setup incomplete"):
            self.setup_with_confirmation()
        self.assertFalse(any(args[0] == "flatpak" for args in self.host.calls))
        self.assertNotIn("No reboot is required", self.output.getvalue())

    def test_cancel_does_not_touch_services_networks_or_firewall(self):
        self.setup_with_confirmation(confirmed=False)
        self.assertEqual(self.host.calls, [])
        self.assertFalse(self.receipt.exists())
        self.assertIn("Virtualization setup skipped; no changes were made.", self.output.getvalue())

    def setup_main(self):
        errors = io.StringIO()
        with patch.object(sys, "argv", ["devmode.py", "setup"]), patch.object(
            sys.stdin, "isatty", return_value=True
        ), patch.object(self.output, "isatty", return_value=True), contextlib.redirect_stderr(errors):
            status = devmode.main()
        return status, errors.getvalue()

    def test_setup_opt_out_exits_zero_without_running_setup(self):
        # #1624: the CLI's exit status propagates through ujust and devmode.
        for gum_status in (1, 130, -2):
            with self.subTest(gum_status=gum_status):
                self.output.seek(0)
                self.output.truncate()
                with patch.object(
                    devmode, "run", return_value=subprocess.CompletedProcess(
                        ["gum", "confirm"], gum_status, ""
                    )
                ) as commands, patch.object(devmode, "virtualization_preflight") as preflight:
                    status, errors = self.setup_main()
                self.assertEqual(status, 0)
                self.assertEqual(errors, "")
                preflight.assert_not_called()
                self.assertEqual(commands.call_count, 1)
                self.assertEqual(commands.call_args.args[:2], ("gum", "confirm"))
                self.assertIn("setup skipped", self.output.getvalue())
                self.assertNotIn("libvirt is responding", self.output.getvalue())
                self.assertFalse(self.receipt.exists())

    def test_confirmation_tool_failure_still_exits_nonzero(self):
        for gum_status in (2, 127):
            with self.subTest(gum_status=gum_status), patch.object(
                devmode, "run", return_value=subprocess.CompletedProcess(
                    ["gum", "confirm"], gum_status, ""
                )
            ) as commands, patch.object(devmode, "virtualization_preflight") as preflight:
                status, errors = self.setup_main()
                self.assertEqual(status, 1)
                self.assertIn("Could not display the confirmation", errors)
                preflight.assert_not_called()
                self.assertEqual(commands.call_count, 1)
                self.assertFalse(self.receipt.exists())

    def test_confirmed_setup_failure_still_exits_nonzero(self):
        with patch.object(devmode, "confirm", return_value=True), patch.object(
            devmode, "virtualization_preflight", side_effect=devmode.SetupError("missing unit")
        ):
            status, errors = self.setup_main()
        self.assertEqual(status, 1)
        self.assertIn("Virtualization setup incomplete: missing unit", errors)
        self.assertNotIn("setup skipped", self.output.getvalue())
        self.assertEqual(self.host.calls, [])

    def removals(self):
        return [args for args in self.host.calls if any(a.startswith("--remove-interface=") for a in args)]

    def unit_states(self, enabled=True):
        return {
            name: devmode.UnitState(
                name, "loaded", "enabled" if enabled else "disabled",
                "active" if enabled else "inactive",
            ) for name in devmode.BOOT_UNITS
        }

    def disable(self, enabled=True, confirmed=True):
        with patch.object(devmode, "confirm", return_value=confirmed), patch.object(
            devmode, "unit_states", return_value=self.unit_states(False)
        ), patch.object(devmode, "virtualization_preflight", return_value=self.unit_states(enabled)):
            devmode.disable_virtualization(self.unit_states(enabled))

    def test_setup_disable_setup_cycle_removes_only_recorded_additions(self):
        devmode.setup_virtualization_firewall()
        receipt = devmode.load_firewall_receipt()
        self.assertEqual((receipt["permanent"], receipt["runtime"]), ("owned", "owned"))
        self.disable()
        self.assertEqual(self.host.bindings, {False: "", True: ""})
        self.assertFalse(self.receipt.exists())
        self.assertEqual(len(self.removals()), 2)
        devmode.setup_virtualization_firewall()
        self.assertEqual(self.host.bindings, {False: "libvirt", True: "libvirt"})
        self.assertEqual(devmode.load_firewall_receipt()["permanent"], "owned")

    def test_disable_preserves_preexisting_runtime_binding(self):
        self.host.bindings[False] = "libvirt"
        devmode.setup_virtualization_firewall()
        self.disable()
        self.assertEqual(self.host.bindings, {False: "libvirt", True: ""})
        self.assertEqual(len(self.removals()), 1)
        self.assertIn("--permanent", self.removals()[0])

    def test_existing_permanent_policy_keeps_its_runtime_assignment(self):
        self.host.bindings[True] = "libvirt"
        devmode.setup_virtualization_firewall()
        self.disable()
        self.assertEqual(self.host.bindings, {False: "libvirt", True: "libvirt"})
        self.assertEqual(self.removals(), [])
        self.assertFalse(self.receipt.exists())

    def test_legacy_or_admin_bindings_are_never_adopted(self):
        self.host.bindings = {False: "libvirt", True: "libvirt"}
        devmode.setup_virtualization_firewall()
        self.assertFalse(self.receipt.exists())
        self.disable()
        self.assertEqual(self.removals(), [])
        self.assertEqual(self.host.bindings, {False: "libvirt", True: "libvirt"})

    def test_rerun_retains_original_ownership(self):
        self.host.bindings[False] = "libvirt"
        devmode.setup_virtualization_firewall()
        first = devmode.load_firewall_receipt()
        devmode.setup_virtualization_firewall()
        self.assertEqual(devmode.load_firewall_receipt(), first)
        self.disable()
        self.assertEqual(self.host.bindings, {False: "libvirt", True: ""})

    def test_active_guests_prevent_disable_and_cleanup(self):
        devmode.setup_virtualization_firewall()
        self.host.calls.clear()
        self.host.guests = "linux2024\n"
        for action in (self.disable, devmode.cleanup_virtualization_firewall):
            with self.assertRaisesRegex(devmode.SetupError, "Active guests"):
                action()
        self.assertEqual(self.removals(), [])
        self.assertFalse(any("systemctl" in args for args in self.host.calls))
        self.assertTrue(self.receipt.exists())

    def test_unknown_guest_state_prevents_cleanup_even_if_units_disabled(self):
        devmode.setup_virtualization_firewall()
        self.host.calls.clear()
        self.host.failure = ("list", 1)
        with self.assertRaisesRegex(devmode.SetupError, "Cannot verify active guests"):
            self.disable(enabled=False)
        self.assertEqual(self.removals(), [])
        self.assertFalse(any("systemctl" in args for args in self.host.calls))
        self.assertTrue(self.receipt.exists())

    def test_cancel_disable_preserves_services_and_receipt(self):
        devmode.setup_virtualization_firewall()
        self.host.calls.clear()
        self.disable(confirmed=False)
        self.assertEqual(self.host.calls, [])
        self.assertTrue(self.receipt.exists())

    def test_firewall_failure_leaves_management_available_for_retry(self):
        devmode.setup_virtualization_firewall()
        self.host.calls.clear()
        self.host.remove_failures[False] = 253
        with self.assertRaisesRegex(devmode.SetupError, "partially applied"):
            self.disable()
        self.assertFalse(any("systemctl" in args for args in self.host.calls))
        self.assertEqual(self.host.bindings, {False: "libvirt", True: ""})
        self.assertEqual(devmode.load_firewall_receipt()["runtime"], "owned")
        self.host.remove_failures[False] = 0
        self.disable()
        self.assertFalse(self.receipt.exists())

    def test_cleanup_precedes_service_stop_and_preserves_helpers(self):
        devmode.setup_virtualization_firewall()
        self.host.calls.clear()
        self.disable()
        stop = next(args for args in self.host.calls if "systemctl" in args and "stop" in args)
        self.assertTrue(all(helper not in stop for helper in devmode.HELPERS))
        last_remove = max(self.host.calls.index(args) for args in self.removals())
        self.assertLess(last_remove, self.host.calls.index(stop))
        self.assertFalse(any("net-destroy" in args or "net-undefine" in args for args in self.host.calls))

    def test_already_disabled_without_receipt_is_noop(self):
        self.disable(enabled=False)
        self.assertEqual(self.host.calls, [])

    def test_disabled_units_do_not_silently_skip_pending_cleanup(self):
        devmode.setup_virtualization_firewall()
        self.host.calls.clear()
        # Boot enablement can already be disabled while libvirt still answers.
        states = self.unit_states(False)
        states["virtqemud.socket"] = devmode.UnitState("virtqemud.socket", "loaded", "disabled", "active")
        with patch.object(devmode, "confirm", return_value=True), patch.object(
            devmode, "unit_states", return_value=self.unit_states(False)
        ), patch.object(devmode, "virtualization_preflight", return_value=states):
            devmode.disable_virtualization(states)
        self.assertEqual(len(self.removals()), 2)
        self.assertFalse(self.receipt.exists())

    def test_new_boot_runtime_binding_is_not_claimed_by_old_receipt(self):
        devmode.setup_virtualization_firewall()
        self.boot_id.write_text("7234f31f-4a9e-4dba-a618-de3121ecde87\n")
        self.disable()
        self.assertEqual(self.host.bindings, {False: "libvirt", True: ""})
        self.assertEqual(len(self.removals()), 1)

    def test_changed_zone_is_preserved_and_ownership_relinquished(self):
        devmode.setup_virtualization_firewall()
        self.host.bindings[False] = "custom"
        self.disable()
        self.assertEqual(self.host.bindings, {False: "custom", True: ""})
        self.assertFalse(self.receipt.exists())

    def test_changed_network_uuid_blocks_cleanup(self):
        devmode.setup_virtualization_firewall()
        self.host.xml = self.host.xml.replace("9d5e493e-94a9-4005-bab6-393c52edbb98", "bf1fc9d4-80e0-4ab2-abd8-5bb279de85ad")
        with self.assertRaisesRegex(devmode.SetupError, "recorded default network changed"):
            self.disable()
        self.assertEqual(self.removals(), [])
        self.assertTrue(self.receipt.exists())

    def test_missing_network_blocks_cleanup_instead_of_guessing(self):
        devmode.setup_virtualization_firewall()
        self.host.networks = ""
        with self.assertRaisesRegex(devmode.SetupError, "recorded default network changed"):
            self.disable()
        self.assertEqual(self.removals(), [])
        self.assertTrue(self.receipt.exists())

    def test_removal_verification_failure_keeps_receipt(self):
        devmode.setup_virtualization_firewall()
        self.host.ignore_removals = True
        with self.assertRaisesRegex(devmode.SetupError, "not removed"):
            self.disable()
        self.assertEqual(devmode.load_firewall_receipt()["permanent"], "owned")

    def test_removed_binding_with_stale_receipt_is_safe_to_retry(self):
        devmode.setup_virtualization_firewall()
        self.host.bindings = {False: "", True: ""}
        self.disable()
        self.assertEqual(self.removals(), [])
        self.assertFalse(self.receipt.exists())

    def test_uncertain_interrupted_addition_is_not_adopted_or_removed(self):
        devmode.setup_virtualization_firewall()
        receipt = devmode.load_firewall_receipt()
        receipt["permanent"] = "pending"
        devmode.save_firewall_receipt(receipt)
        for action in (devmode.setup_virtualization_firewall, self.disable):
            with self.assertRaisesRegex(devmode.SetupError, "uncertain ownership"):
                action()
        self.assertEqual(self.removals(), [])
        self.assertTrue(self.receipt.exists())

    def test_failed_addition_can_be_cleaned_without_ever_claiming_it(self):
        self.host.write_failures[False] = 253
        with self.assertRaises(devmode.SetupError):
            devmode.setup_virtualization_firewall()
        self.disable()
        self.assertEqual(self.host.bindings, {False: "", True: ""})
        self.assertEqual(len(self.removals()), 1)
        self.assertFalse(self.receipt.exists())

    def test_corrupt_receipt_blocks_firewall_changes(self):
        self.receipt.write_text('{"version": 999}')
        for action in (devmode.setup_virtualization_firewall, devmode.cleanup_virtualization_firewall):
            with self.assertRaisesRegex(devmode.SetupError, "Invalid firewall receipt"):
                action()
        self.assertEqual(self.host.calls, [])

    def test_receipt_is_private_and_atomic_replacement_leaves_no_temporary_file(self):
        devmode.setup_virtualization_firewall()
        self.assertEqual(self.receipt.stat().st_mode & 0o777, 0o600)
        self.assertFalse(list(self.directory.glob(".firewall-*")))

    def test_untrusted_receipt_and_symlink_are_rejected(self):
        self.receipt.write_text('{}')
        self.receipt.chmod(0o666)
        with self.assertRaisesRegex(devmode.SetupError, "Untrusted"):
            devmode.load_firewall_receipt()
        self.receipt.unlink()
        self.receipt.symlink_to(self.boot_id)
        with self.assertRaises(OSError):
            devmode.load_firewall_receipt()

    def test_receipt_failure_happens_before_firewall_addition(self):
        with patch.object(devmode, "save_firewall_receipt", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                devmode.setup_virtualization_firewall()
        self.assertEqual(self.host.writes, [])

    def test_firewall_actions_are_serialized(self):
        with devmode.firewall_receipt_lock():
            with self.assertRaisesRegex(devmode.SetupError, "Another virtualization"):
                with devmode.firewall_receipt_lock():
                    self.fail("A second writer acquired the lock")

    def test_interrupted_receipt_update_after_removal_is_retryable(self):
        devmode.setup_virtualization_firewall()
        with patch.object(devmode, "save_firewall_receipt", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                devmode.cleanup_virtualization_firewall()
        self.assertEqual(self.host.bindings, {False: "libvirt", True: ""})
        self.assertEqual(devmode.load_firewall_receipt()["permanent"], "owned")
        self.host.calls.clear()
        self.disable()
        self.assertEqual(len(self.removals()), 1)
        self.assertNotIn("--permanent", self.removals()[0])
        self.assertFalse(self.receipt.exists())

    def test_recording_ownership_failure_leaves_ambiguous_intent_not_false_ownership(self):
        real_save = devmode.save_firewall_receipt
        def fail_after_add(receipt):
            if receipt["permanent"] == "owned":
                raise OSError("disk full")
            real_save(receipt)
        with patch.object(devmode, "save_firewall_receipt", side_effect=fail_after_add):
            with self.assertRaises(OSError):
                devmode.setup_virtualization_firewall()
        self.assertEqual(devmode.load_firewall_receipt()["permanent"], "pending")
        self.assertEqual(self.host.bindings[True], "libvirt")
        with self.assertRaisesRegex(devmode.SetupError, "uncertain ownership"):
            self.disable()
        self.assertEqual(self.removals(), [])

    def test_setup_relinquishes_observed_custom_policy(self):
        devmode.setup_virtualization_firewall()
        self.host.bindings[True] = "custom"
        with self.assertRaisesRegex(devmode.SetupError, "leaving custom policy"):
            devmode.setup_virtualization_firewall()
        self.assertEqual(devmode.load_firewall_receipt()["permanent"], "none")
        self.host.bindings[True] = "libvirt"  # administrator moves it back
        self.disable()
        self.assertEqual(self.host.bindings, {False: "libvirt", True: "libvirt"})
        self.assertEqual(self.removals(), [])

    def test_service_stop_failure_can_be_retried_after_cleanup(self):
        devmode.setup_virtualization_firewall()
        self.host.failure = ("stop", 1)
        with self.assertRaisesRegex(devmode.SetupError, "partially applied"):
            self.disable()
        self.assertFalse(self.receipt.exists())
        self.assertEqual(self.host.bindings, {False: "", True: ""})
        self.host.calls.clear()
        self.host.failure = None
        self.disable()
        self.assertEqual(self.removals(), [])
        self.assertIn("Local management activation disabled", self.output.getvalue())

    def test_firewall_failure_during_cleanup_retains_receipt_and_services(self):
        devmode.setup_virtualization_firewall()
        for flag in ("--state", "--list-interfaces"):
            with self.subTest(flag=flag):
                self.host.calls.clear()
                self.host.failure = (flag, 253)
                with self.assertRaises(devmode.SetupError):
                    self.disable()
                self.assertEqual(self.removals(), [])
                self.assertFalse(any("systemctl" in args for args in self.host.calls))
                self.assertTrue(self.receipt.exists())

    def test_private_worker_reports_state_io_failure_without_traceback(self):
        with patch.object(sys, "argv", ["devmode.py", "_firewall-cleanup"]), patch.object(
            devmode.os, "geteuid", return_value=0
        ), patch.object(devmode, "firewall_receipt_lock", side_effect=OSError("read-only")), contextlib.redirect_stderr(io.StringIO()) as errors:
            self.assertEqual(devmode.main(), 1)
        self.assertIn("Firewall operation incomplete", errors.getvalue())
        self.assertNotIn("Traceback", errors.getvalue())

    def test_duplicate_zone_membership_blocks_setup_and_cleanup(self):
        devmode.setup_virtualization_firewall()
        self.host.calls.clear()
        self.host.extra_interfaces[True]["lax"] = "virbr0"
        for action in (devmode.setup_virtualization_firewall, self.disable):
            with self.assertRaisesRegex(devmode.SetupError, "multiple permanent firewall zones"):
                action()
        self.assertEqual(self.host.writes, [])
        self.assertEqual(self.removals(), [])
        self.assertTrue(self.receipt.exists())

    def test_other_interfaces_are_preserved(self):
        self.host.extra_interfaces = {
            False: {"libvirt": "virbr01 virbr7", "custom": "br-admin"},
            True: {"libvirt": "virbr01 virbr7", "custom": "br-admin"},
        }
        devmode.setup_virtualization_firewall()
        self.disable()
        self.assertTrue(all(args[-1] == "--remove-interface=virbr0" for args in self.removals()))
        self.assertEqual(self.host.extra_interfaces[True]["libvirt"], "virbr01 virbr7")

    def test_oversized_receipt_is_rejected(self):
        devmode.setup_virtualization_firewall()
        with self.receipt.open("a") as stream:
            stream.write(" " * 16384)
        with self.assertRaisesRegex(devmode.SetupError, "Invalid firewall receipt"):
            devmode.load_firewall_receipt()

    def test_attached_bridge_ports_block_cleanup_even_without_system_guests(self):
        devmode.setup_virtualization_firewall()
        ports = self.network_sysfs / "virbr0" / "brif"
        ports.mkdir(parents=True)
        (ports / "vnet-session-guest").touch()
        self.host.calls.clear()
        with self.assertRaisesRegex(devmode.SetupError, "still has attached interfaces"):
            self.disable()
        self.assertEqual(self.removals(), [])
        self.assertFalse(any("systemctl" in args for args in self.host.calls))
        self.assertTrue(self.receipt.exists())

    def test_private_worker_requires_root(self):
        for action in ("_firewall-cleanup", "_firewall-setup", "_operation-lock"):
            with patch.object(sys, "argv", ["devmode.py", action]), patch.object(
                devmode.os, "geteuid", return_value=1000
            ), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(devmode.main(), 1)
        self.assertEqual(self.host.calls, [])

    def test_setup_cannot_interleave_after_disable_firewall_cleanup(self):
        devmode.setup_virtualization_firewall()
        self.host.calls.clear()
        original_run = self.host.run
        def interleave(*args, **kwargs):
            if args[:4] == ("sudo", "-n", "systemctl", "disable"):
                before = len(self.host.writes)
                with self.assertRaisesRegex(devmode.SetupError, "Another virtualization"):
                    self.setup_with_confirmation()
                self.assertEqual(len(self.host.writes), before)
            return original_run(*args, **kwargs)
        with patch.object(devmode, "run", side_effect=interleave):
            self.disable()
        self.assertEqual(self.host.bindings, {False: "", True: ""})
        self.assertFalse(self.receipt.exists())
        self.assertIn("Local management activation disabled", self.output.getvalue())

    def test_disable_cannot_interleave_during_setup_services_or_flatpak(self):
        self.host.vmm_installed = False
        original_run = self.host.run
        attempts = []
        def interleave(*args, **kwargs):
            if "systemctl" in args or args[0] == "flatpak":
                attempts.append(args)
                with self.assertRaisesRegex(devmode.SetupError, "Another virtualization"):
                    self.disable()
            return original_run(*args, **kwargs)
        with patch.object(devmode, "run", side_effect=interleave):
            self.setup_with_confirmation()
        # Both setup's checked inventory and the shared installer's inventory
        # must stay under the lock, as must the actual install transaction.
        self.assertEqual(len(attempts), 7)  # enable, start, four inventories, install
        self.assertEqual(self.removals(), [])
        self.assertEqual(self.host.bindings, {False: "libvirt", True: "libvirt"})

    def test_remote_setup_keeps_authentication_and_install_inside_lock(self):
        self.host.vmm_installed = False
        original_run = self.host.run
        protected = []

        def inspect(*args, **kwargs):
            if args[0] == "loginctl" or args[:2] == ("flatpak", "install"):
                protected.append(args)
                self.assertEqual(self.host.bindings, {False: "libvirt", True: "libvirt"})
                with self.assertRaisesRegex(devmode.SetupError, "Another virtualization"):
                    with devmode.firewall_receipt_lock("operation.lock"):
                        self.fail("authentication or install ran outside lock")
            return original_run(*args, **kwargs)

        with patch.dict(os.environ, {"XDG_SESSION_ID": "remote-test"}), patch.object(
            sys.stdin, "isatty", return_value=True
        ), patch.object(self.output, "isatty", return_value=True), patch.object(
            devmode, "run", side_effect=inspect
        ):
            self.setup_with_confirmation()
        self.assertEqual(protected, [
            ("loginctl", "show-session", "remote-test", "-p", "Remote", "--value"),
            ("flatpak", "install", "--system", "flathub", devmode.VMM_APP_ID),
        ])
        self.assertIn("Flatpak will ask for your password", self.output.getvalue())
        self.assertIn("No reboot is required", self.output.getvalue())

    def test_flatpak_failure_releases_lock_and_keeps_firewall_retryable(self):
        self.host.vmm_installed = False
        for status in (1, 126, 130):
            with self.subTest(status=status):
                self.output.seek(0)
                self.output.truncate()
                self.host.failure = ("install", status)
                with patch.object(sys.stdin, "isatty", return_value=True), patch.object(
                    self.output, "isatty", return_value=True
                ), self.assertRaisesRegex(devmode.SetupError, "Virtualization setup incomplete"):
                    self.setup_with_confirmation()
                self.assertNotIn("No reboot is required", self.output.getvalue())
                self.assertEqual(self.host.bindings, {False: "libvirt", True: "libvirt"})
                self.assertEqual(devmode.load_firewall_receipt()["permanent"], "owned")
                with devmode.firewall_receipt_lock("operation.lock"):
                    pass
                self.host.failure = None
                self.host.calls.clear()
                self.setup_with_confirmation()
                self.assertEqual(self.host.writes, [])
                self.assertIn("No reboot is required", self.output.getvalue())

    def test_interrupted_flatpak_prompt_releases_lock_without_claiming_success(self):
        self.host.vmm_installed = False
        original_run = self.host.run

        def interrupt(*args, **kwargs):
            if args[:2] == ("flatpak", "install"):
                raise KeyboardInterrupt
            return original_run(*args, **kwargs)

        with patch.object(devmode, "run", side_effect=interrupt), patch.object(
            devmode, "confirm", return_value=True
        ), patch.object(devmode, "virtualization_preflight"), patch.object(
            devmode, "unit_states", return_value=self.unit_states()
        ):
            status, errors = self.setup_main()
        self.assertEqual(status, 130)
        self.assertIn("Interrupted", errors)
        self.assertNotIn("No reboot is required", self.output.getvalue())
        self.assertTrue(self.receipt.exists())
        with devmode.firewall_receipt_lock("operation.lock"):
            pass

    def test_user_installed_vmm_is_preserved_while_firewall_is_repaired(self):
        self.host.vmm_scope = "user"
        self.setup_with_confirmation()
        self.assertEqual(len(self.host.writes), 2)
        self.assertFalse(any(args[:2] == ("flatpak", "install") for args in self.host.calls))
        self.assertIn("already installed", self.output.getvalue())

    def test_flatpak_cli_stays_unprivileged_and_does_not_take_virtualization_lock(self):
        self.host.vmm_installed = False
        with patch.object(sys, "argv", ["devmode.py", "flatpak-install", devmode.VMM_APP_ID]), patch.object(
            sys.stdin, "isatty", return_value=False
        ), patch.object(devmode, "virtualization_operation_lock") as lock:
            self.assertEqual(devmode.main(), 0)
        lock.assert_not_called()
        self.assertFalse(self.receipt.exists())
        self.assertEqual(self.host.calls, [
            ("flatpak", "list", "--system", "--app", "--columns=application"),
            ("flatpak", "list", "--user", "--app", "--columns=application"),
            ("flatpak", "install", "--system", "--assumeyes", "flathub", devmode.VMM_APP_ID),
        ])

    def test_operation_lock_is_released_after_failure(self):
        self.host.failure = ("start", 1)
        with self.assertRaises(devmode.SetupError):
            self.setup_with_confirmation()
        with devmode.firewall_receipt_lock("operation.lock"):
            pass

    def test_cancel_does_not_acquire_operation_lock(self):
        with patch.object(devmode, "virtualization_operation_lock") as lock:
            self.setup_with_confirmation(confirmed=False)
            self.disable(confirmed=False)
            lock.assert_not_called()
        self.assertEqual(self.host.calls, [])

    def test_setup_preflight_is_rechecked_under_lock(self):
        calls = []
        def preflight():
            calls.append(True)
            if len(calls) == 2:
                with self.assertRaisesRegex(devmode.SetupError, "Another virtualization"):
                    with devmode.firewall_receipt_lock("operation.lock"):
                        self.fail("preflight ran outside lock")
                raise devmode.SetupError("configuration changed during confirmation")
        with patch.object(devmode, "confirm", return_value=True), patch.object(
            devmode, "virtualization_preflight", side_effect=preflight
        ), self.assertRaisesRegex(devmode.SetupError, "configuration changed"):
            devmode.setup_virtualization()
        self.assertEqual(len(calls), 2)
        self.assertEqual(self.host.calls, [("sudo", "-v")])

    def test_disable_preflight_is_rechecked_under_lock(self):
        def preflight():
            with self.assertRaisesRegex(devmode.SetupError, "Another virtualization"):
                with devmode.firewall_receipt_lock("operation.lock"):
                    self.fail("preflight ran outside lock")
            raise devmode.SetupError("configuration changed during confirmation")
        with patch.object(devmode, "confirm", return_value=True), patch.object(
            devmode, "virtualization_preflight", side_effect=preflight
        ), self.assertRaisesRegex(devmode.SetupError, "configuration changed"):
            devmode.disable_virtualization(self.unit_states())
        self.assertEqual(self.host.calls, [("sudo", "-v")])

    def assert_recovery(self, message):
        self.assertIn(f"sudo cat {self.receipt}", message)
        self.assertIn("virsh --readonly --connect qemu:///system net-dumpxml --inactive default", message)
        self.assertIn("sudo firewall-cmd --zone=libvirt --list-interfaces", message)
        self.assertIn("sudo firewall-cmd --permanent --zone=libvirt --list-interfaces", message)
        self.assertIn("Do not delete the record", message)
        self.assertNotIn("--remove-interface", message)

    def test_missing_receipt_explains_legacy_policy_and_readonly_inspection(self):
        self.host.bindings = {False: "libvirt", True: "libvirt"}
        devmode.cleanup_virtualization_firewall()
        self.assertIn("older setup versions", self.output.getvalue())
        self.assert_recovery(self.output.getvalue())
        self.assertEqual(self.host.calls, [])

    def test_corrupt_receipt_reports_readonly_recovery_without_changes(self):
        self.receipt.write_text("invalid")
        with self.assertRaises(devmode.SetupError) as raised:
            devmode.cleanup_virtualization_firewall()
        self.assert_recovery(str(raised.exception))
        self.assertEqual(self.host.calls, [])
        self.assertEqual(self.receipt.read_text(), "invalid")

    def test_ambiguous_receipt_reports_readonly_recovery_without_changes(self):
        devmode.setup_virtualization_firewall()
        receipt = devmode.load_firewall_receipt()
        receipt["permanent"] = "pending"
        devmode.save_firewall_receipt(receipt)
        before = self.receipt.read_bytes()
        self.host.calls.clear()
        for action in (devmode.setup_virtualization_firewall, devmode.cleanup_virtualization_firewall):
            with self.assertRaises(devmode.SetupError) as raised:
                action()
            self.assert_recovery(str(raised.exception))
        self.assertEqual(self.receipt.read_bytes(), before)
        self.assertEqual(self.host.writes, [])
        self.assertEqual(self.removals(), [])


class OperationLockProcessTests(unittest.TestCase):
    """Exercise the pipe protocol with real children, never sudo or host services."""

    def setUp(self):
        self.directory = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.receipt = self.directory / "firewall.json"
        self.enterContext(patch.object(devmode, "FIREWALL_RECEIPT", self.receipt))
        self.real_popen = subprocess.Popen
        self.children = []

    def launch(self, args, **kwargs):
        self.assertEqual(args[:3], ["sudo", "-n", "/usr/bin/python3"])
        self.assertEqual(args[-1], "_operation-lock")
        code = (
            "from scripts.test_devmode import devmode; from pathlib import Path; "
            f"devmode.FIREWALL_RECEIPT = Path({str(self.receipt)!r}); "
            "devmode.operation_lock_worker()"
        )
        child = self.real_popen([sys.executable, "-B", "-c", code], cwd=ROOT, **kwargs)
        self.children.append(child)
        return child

    def test_lock_is_held_until_parent_closes_pipe(self):
        with patch.object(devmode.subprocess, "Popen", side_effect=self.launch):
            with devmode.virtualization_operation_lock():
                with self.assertRaisesRegex(devmode.SetupError, "Another virtualization"):
                    with devmode.firewall_receipt_lock("operation.lock"):
                        self.fail("child did not hold lock")
            with devmode.firewall_receipt_lock("operation.lock"):
                pass
        self.assertEqual(self.children[0].returncode, 0)
        self.assertTrue(self.children[0].stdout.closed)

    def test_exception_releases_child_and_lock(self):
        with patch.object(devmode.subprocess, "Popen", side_effect=self.launch):
            with self.assertRaisesRegex(devmode.SetupError, "test failure"):
                with devmode.virtualization_operation_lock():
                    raise devmode.SetupError("test failure")
            with devmode.firewall_receipt_lock("operation.lock"):
                pass
        self.assertEqual(self.children[0].returncode, 0)

    def test_failed_child_start_never_enters_transition(self):
        with patch.object(devmode.subprocess, "Popen", side_effect=OSError("unavailable")):
            with self.assertRaisesRegex(devmode.SetupError, "Could not start"):
                with devmode.virtualization_operation_lock():
                    self.fail("transition ran without lock")

    def test_child_refusal_never_enters_transition(self):
        def refuse(args, **kwargs):
            return self.real_popen([sys.executable, "-c", "raise SystemExit(1)"], **kwargs)
        with patch.object(devmode.subprocess, "Popen", side_effect=refuse):
            with self.assertRaisesRegex(devmode.SetupError, "Could not acquire"):
                with devmode.virtualization_operation_lock():
                    self.fail("transition ran without lock")

    def test_unexpected_child_exit_prevents_success(self):
        with patch.object(devmode.subprocess, "Popen", side_effect=self.launch):
            with self.assertRaisesRegex(devmode.SetupError, "exited unexpectedly"):
                with devmode.virtualization_operation_lock():
                    self.children[0].terminate()
                    self.children[0].wait(timeout=5)


if __name__ == "__main__":
    unittest.main()
