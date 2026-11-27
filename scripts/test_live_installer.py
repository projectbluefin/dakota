"""Tests for the parts of the live installer that decide what gets erased or
removed (files/live-iso/installer/), and for the checks around the ISO build.

None of them needs D-Bus, a disk, QEMU or root.
"""
from __future__ import annotations

import importlib.util
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def load(path: str):
    """Import a file that is not on the module path (or is not named like a module)."""
    name = Path(path).stem.replace("-", "_")
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    # No __pycache__ next to the sources: BuildStream imports those
    # directories whole, so a stray file there changes what gets built.
    writes, sys.dont_write_bytecode = sys.dont_write_bytecode, True
    try:
        spec.loader.exec_module(module)
    finally:
        sys.dont_write_bytecode = writes
    return module


disks = load("files/live-iso/installer/disks.py")
cleanup = load("files/live-iso/installer/cleanup.py")
check_seed = load("files/live-iso/check-seed.py")
smoke = load("scripts/iso_smoke_boot.py")

GB = 1024**3
DATA = ROOT / "scripts/testdata/live-installer"


def disk(name: str, **fields) -> dict:
    return {"name": name, "type": "disk", "size": 500 * GB, "ro": False, "model": "Example SSD",
            "serial": f"serial-{name}", "wwn": None, "tran": "nvme", "pttype": None, "fstype": None, **fields}


def offer(tree: list[dict], in_use: set[str] = frozenset(), skip: set[str] = frozenset()) -> list:
    """describe() with every disk of the tree partitionable, except `skip`."""
    partitionable = {d["name"]: n for n, d in enumerate(tree, 1) if d["name"] not in skip}
    return disks.describe(tree, set(in_use), partitionable)


class Recorded(unittest.TestCase):
    """What lsblk and systemd-repart print in a live session (systemd 262,
    util-linux 2.41) for disks in known states: the files in testdata.

    sda, sdb and vda are blank, vda without a serial number. sdc has an
    empty GPT, sdd an empty MBR, sde a GPT with one unformatted partition,
    sdf ext4 on the whole disk. sdg is 4 GiB. sdh is the install media,
    read-only, with the live filesystem's second device on zram0.
    """

    def setUp(self) -> None:
        tree = json.loads((DATA / "lsblk.json").read_text())["blockdevices"]
        self.partitionable = disks.parse_candidates((DATA / "candidates.jsonseq").read_text())
        self.disks = {d.name: d for d in disks.describe(tree, {"sdh2", "zram0"}, self.partitionable)}

    def test_candidates(self) -> None:
        self.assertEqual(set(self.partitionable), {"sda", "sdb", "sdc", "sdd", "sde", "sdf", "sdg", "vda"})
        self.assertEqual(self.partitionable["vda"], 9)

    def test_the_install_media_and_its_memory_device_are_left_out(self) -> None:
        self.assertEqual(sorted(self.disks), ["sda", "sdb", "sdc", "sdd", "sde", "sdf", "sdg", "vda"])

    def test_a_disk_without_partitions_is_empty_whatever_its_table(self) -> None:
        empty = {name for name, d in self.disks.items() if not d.has_data}
        self.assertEqual(empty, {"sda", "sdb", "sdc", "sdd", "sdg", "vda"})

    def test_a_partition_or_a_bare_filesystem_is_data(self) -> None:
        self.assertTrue(self.disks["sde"].has_data)
        self.assertTrue(self.disks["sdf"].has_data)

    def test_only_the_small_disk_has_a_problem(self) -> None:
        self.assertEqual({name: d.problem for name, d in self.disks.items() if d.problem},
                         {"sdg": "This disk is too small. Bluefin needs at least 10 GB."})

    def test_a_disk_without_a_serial_number_still_has_an_identity(self) -> None:
        self.assertEqual(self.disks["vda"].ident, "9|||21474836480")
        self.assertEqual(self.disks["sda"].ident, "10|QM00001|QEMU HARDDISK|42949672960")


class Describe(unittest.TestCase):
    def names(self, tree: list[dict], in_use: set[str] = frozenset(), skip: set[str] = frozenset()) -> list[str]:
        return [d.name for d in offer(tree, in_use, skip)]

    def test_whole_disks_are_offered(self) -> None:
        self.assertEqual(self.names([disk("nvme0n1"), disk("sda")]), ["nvme0n1", "sda"])

    def test_install_media_is_left_out(self) -> None:
        stick = disk("sdb", children=[{"name": "sdb1"}, {"name": "sdb2"}])
        self.assertEqual(self.names([disk("sda"), stick], {"sdb2", "zram0"}), ["sda"])

    def test_installed_disk_is_left_out_through_its_mapping(self) -> None:
        installed = disk("sda", children=[{"name": "sda1"}, {"name": "sda2", "children": [{"name": "root"}]}])
        self.assertEqual(self.names([installed], {"root", "dm-0"}), [])

    def test_everything_that_is_not_a_disk_is_left_out(self) -> None:
        tree = [disk("sr0", type="rom"), disk("loop0", type="loop"), disk("sda")]
        self.assertEqual(self.names(tree), ["sda"])

    def test_what_systemd_repart_cannot_partition_is_left_out(self) -> None:
        boot_area = disk("mmcblk0boot0", size=4 * 1024**2, ro=True)
        tree = [disk("zram0"), disk("dm-0", size=8 * GB), boot_area, disk("sda")]
        self.assertEqual(self.names(tree, skip={"zram0", "dm-0", "mmcblk0boot0"}), ["sda"])

    def test_a_drive_with_nothing_in_it_is_left_out(self) -> None:
        self.assertEqual(self.names([disk("sdb", size=0), disk("sdc", size=None), disk("sda")]), ["sda"])

    def test_small_and_read_only_disks_are_shown_and_cannot_be_chosen(self) -> None:
        small, locked = offer([disk("sda", size=8 * GB), disk("sdb", ro=True)], skip={"sdb"})
        self.assertIn("too small", small.problem)
        self.assertIn("read-only", locked.problem)

    def test_the_size_limit_is_the_one_the_message_names(self) -> None:
        sold_as_10_gb, below = offer([disk("sda", size=10 * 1000**3), disk("sdb", size=10 * 1000**3 - 1)])
        self.assertEqual(sold_as_10_gb.problem, "")
        self.assertIn("at least 10 GB", below.problem)

    def test_old_lsblk_booleans(self) -> None:
        self.assertEqual(offer([disk("sda", ro="0")])[0].problem, "")
        self.assertIn("read-only", offer([disk("sda", ro="1")])[0].problem)

    def test_partitions_and_filesystems_count_as_data(self) -> None:
        cases = {"blank": disk("sda"), "empty table": disk("sda", pttype="gpt"),
                 "bare filesystem": disk("sda", fstype="crypto_LUKS"),
                 "partitions": disk("sda", pttype="gpt", children=[{"name": "sda1"}])}
        found = {label: offer([tree])[0].has_data for label, tree in cases.items()}
        self.assertEqual(found, {"blank": False, "empty table": False, "bare filesystem": True, "partitions": True})


class Candidates(unittest.TestCase):
    def test_records_are_split_on_the_separator_or_on_lines(self) -> None:
        one = '{"node":"/dev/nvme0n1","diskseq":3,"sizeBytes":1}'
        two = '{"node":"/dev/sda","diskseq":7}'
        expected = {"nvme0n1": 3, "sda": 7}
        self.assertEqual(disks.parse_candidates(f"\x1e{one}\n\x1e{two}\n"), expected)
        self.assertEqual(disks.parse_candidates(f"{one}\n{two}\n"), expected)
        self.assertEqual(disks.parse_candidates(""), {})


class Choose(unittest.TestCase):
    def setUp(self) -> None:
        self.tree = [disk("sda"), disk("sdb", size=8 * GB)]
        self.offered = offer(self.tree)

    def test_the_confirmed_disk_is_returned(self) -> None:
        self.assertEqual(disks.choose(self.offered, "sda", self.offered[0].ident).name, "sda")

    def test_another_disk_under_the_same_name_is_refused(self) -> None:
        with self.assertRaisesRegex(disks.Refused, "changed"):
            disks.choose(offer([disk("sda", serial="another")]), "sda", self.offered[0].ident)

    def test_an_identical_disk_attached_later_is_refused(self) -> None:
        later = disks.describe([disk("sda")], set(), {"sda": 99})
        self.assertNotEqual(later[0].ident, self.offered[0].ident)
        with self.assertRaisesRegex(disks.Refused, "changed"):
            disks.choose(later, "sda", self.offered[0].ident)

    def test_a_name_that_is_not_offered_is_refused(self) -> None:
        for name in ("sda1", "zram0", "../sda", ""):
            with self.assertRaises(disks.Refused):
                disks.choose(self.offered, name, self.offered[0].ident)

    def test_a_disk_with_a_problem_is_refused(self) -> None:
        with self.assertRaisesRegex(disks.Refused, "too small"):
            disks.choose(self.offered, "sdb", self.offered[1].ident)


class RootPartition(unittest.TestCase):
    def test_encrypted_root_opens_with_the_key_file_and_the_tpm(self) -> None:
        self.assertIn("Encrypt=key-file+tpm2\n", disks.root_partition(True))

    def test_unencrypted_root_differs_only_in_the_encryption(self) -> None:
        plain = disks.root_partition(False)
        self.assertNotIn("Encrypt", plain)
        self.assertEqual(plain + "Encrypt=key-file+tpm2\n", disks.root_partition(True))
        self.assertIn("Type=root\n", plain)


class Cleanup(unittest.TestCase):
    def test_only_plain_paths_below_etc_and_var_are_removed(self) -> None:
        allowed = ["/etc/xdg/autostart/org.projectbluefin.Installer.desktop", "/var/home/live"]
        refused = ["/usr/bin/bash", "/etc/../usr/bin/bash", "/var/opt/../../usr", "etc/passwd", "/etc", "/etc//x", ""]
        self.assertEqual([p for p in allowed + refused if cleanup.removable(p)], allowed)


class CheckSeed(unittest.TestCase):
    SUPER = "label\t\t\tdakota-live\ntotal_bytes\t\t5181014016\nbytes_used\t\t4830248960\nnodesize\t\t16384\n"

    def test_superblock_fields(self) -> None:
        self.assertEqual(check_seed.superblock(self.SUPER),
                         {"total_bytes": 5181014016, "bytes_used": 4830248960, "nodesize": 16384})

    def test_a_tight_image_passes(self) -> None:
        self.assertEqual(check_seed.unused_problem(check_seed.superblock(self.SUPER)), "")

    def test_a_stray_chunk_fails(self) -> None:
        fields = {"total_bytes": 4830248960 + 335 * 1024**2 + GB, "bytes_used": 4830248960}
        self.assertIn("nothing uses", check_seed.unused_problem(fields))


class SmokeBoot(unittest.TestCase):
    def test_guest_has_no_network(self) -> None:
        command = smoke.command(Path("x.iso"), "usb", "code.fd", Path("vars.fd"), Path("serial.log"))
        self.assertEqual(command[command.index("-nic") + 1], "none")

    def test_failed_units_are_read_from_the_console(self) -> None:
        console = f"noise\n{smoke.FAILED_UNITS}\nfoo.service loaded failed failed Foo\nbar.mount loaded failed\n{smoke.END}\n{smoke.PASSED}\n"
        self.assertEqual(smoke.failed_units(console), ["foo.service", "bar.mount"])
        self.assertEqual(smoke.failed_units(f"{smoke.FAILED_UNITS}\n{smoke.END}\n"), [])
        self.assertEqual(smoke.failed_units("no report"), [])


if __name__ == "__main__":
    unittest.main()
