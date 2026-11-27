"""Tests for the live ISO build in files/live-iso/.

They cover build.py's own logic, the helpers it runs (fix-layout.py,
extract.py, mkcpio.py), and check that the shell and Python the ISO carries
still parse. None of them needs BuildStream, a container or root.
"""
from __future__ import annotations

import hashlib
import importlib.util
import io
import json
import os
import py_compile
import stat
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / "files/live-iso"
TAR = "application/vnd.oci.image.layer.v1.tar"
END = b"\0" * 1024


def load_build():
    """Import build.py without leaving a __pycache__ next to it: BuildStream
    imports that directory whole, so a stray file changes what gets built."""
    spec = importlib.util.spec_from_file_location("live_iso_build", TOOLS / "build.py")
    module = importlib.util.module_from_spec(spec)
    writes, sys.dont_write_bytecode = sys.dont_write_bytecode, True
    try:
        spec.loader.exec_module(module)
    finally:
        sys.dont_write_bytecode = writes
    return module


build = load_build()


def run(tool: str, *args: object, env: dict[str, str] | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(TOOLS / tool), *map(str, args)],
        capture_output=True, text=True, env={**os.environ, **(env or {})})


def sha(data: bytes) -> str:
    return "sha256:" + hashlib.sha256(data).hexdigest()


def layer(members: list[tuple[str, bytes | None]], complete: bool = True) -> bytes:
    """A tar with the given (name, content) members; content None is a directory."""
    data = io.BytesIO()
    with tarfile.open(fileobj=data, mode="w", format=tarfile.PAX_FORMAT) as tar:
        for name, content in members:
            info = tarfile.TarInfo(name)
            if content is None:
                info.type, info.mode = tarfile.DIRTYPE, 0o755
                tar.addfile(info)
            else:
                info.size = len(content)
                tar.addfile(info, io.BytesIO(content))
    raw = data.getvalue().rstrip(b"\0")
    raw += b"\0" * (-len(raw) % 512)
    return raw + END if complete else raw


def write_layout(path: Path, layers: list[bytes], media_type: str = TAR) -> None:
    blobs = path / "blobs/sha256"
    blobs.mkdir(parents=True)

    def put(data: bytes) -> str:
        digest = sha(data)
        (blobs / digest[7:]).write_bytes(data)
        return digest

    descriptors = [{"mediaType": media_type, "digest": put(raw), "size": len(raw)} for raw in layers]
    config = json.dumps({"rootfs": {"type": "layers", "diff_ids": [d["digest"] for d in descriptors]},
                         "history": [{"comment": "layer"} for _ in layers]}).encode()
    manifest = json.dumps({"schemaVersion": 2,
                           "config": {"mediaType": "application/vnd.oci.image.config.v1+json",
                                      "digest": put(config), "size": len(config)},
                           "layers": descriptors}).encode()
    index = {"schemaVersion": 2, "manifests": [{
        "mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": put(manifest),
        "size": len(manifest), "annotations": {"org.opencontainers.image.ref.name": "example.test/os:tag"}}]}
    (path / "index.json").write_text(json.dumps(index))
    (path / "oci-layout").write_text('{"imageLayoutVersion": "1.0.0"}')


def read_layout(path: Path) -> tuple[dict, dict, dict]:
    """Index entry, manifest and config, with every digest and size checked."""
    index = json.loads((path / "index.json").read_text())
    entry = index["manifests"][0]

    def get(descriptor: dict) -> bytes:
        data = (path / "blobs/sha256" / descriptor["digest"][7:]).read_bytes()
        assert sha(data) == descriptor["digest"], descriptor
        assert len(data) == descriptor["size"], descriptor
        return data

    manifest = json.loads(get(entry))
    config = json.loads(get(manifest["config"]))
    for descriptor in manifest["layers"]:
        get(descriptor)
    return entry, manifest, config


class FixLayoutTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.src = Path(self.tmp.name) / "src"
        self.dst = Path(self.tmp.name) / "dst"

    def test_truncated_layer_gets_end_marker_and_new_digests(self) -> None:
        truncated = layer([("usr", None), ("usr/file", b"data"), ("sys", None)], complete=False)
        write_layout(self.src, [truncated])
        result = run("fix-layout.py", self.src, self.dst)
        self.assertEqual(result.returncode, 0, result.stderr)
        entry, manifest, config = read_layout(self.dst)
        fixed = (self.dst / "blobs/sha256" / manifest["layers"][0]["digest"][7:]).read_bytes()
        self.assertEqual(fixed, truncated + END)
        # An uncompressed layer's diff ID is its own digest.
        self.assertEqual(config["rootfs"]["diff_ids"], [manifest["layers"][0]["digest"]])
        self.assertEqual(entry["annotations"]["org.opencontainers.image.ref.name"], "example.test/os:tag")
        with tarfile.open(fileobj=io.BytesIO(fixed)) as tar:
            self.assertEqual(tar.getnames(), ["usr", "usr/file", "sys"])

    def test_complete_layer_with_sys_is_left_as_it_is(self) -> None:
        write_layout(self.src, [layer([("usr", None), ("sys", None)])])
        before = read_layout(self.src)
        result = run("fix-layout.py", self.src, self.dst)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(read_layout(self.dst), before)
        # The manifest digest must stay the one the registry serves.
        self.assertEqual((self.dst / "index.json").read_bytes(), (self.src / "index.json").read_bytes())
        self.assertEqual(result.stdout, "")

    def test_missing_sys_directory_is_added_as_a_layer(self) -> None:
        write_layout(self.src, [layer([("usr", None), ("system", None)])])
        result = run("fix-layout.py", self.src, self.dst, env={"SOURCE_DATE_EPOCH": "1321009871"})
        self.assertEqual(result.returncode, 0, result.stderr)
        _, manifest, config = read_layout(self.dst)
        self.assertEqual(len(manifest["layers"]), 2)
        self.assertEqual(len(config["rootfs"]["diff_ids"]), 2)
        self.assertEqual(len(config["history"]), 2)
        added = (self.dst / "blobs/sha256" / manifest["layers"][1]["digest"][7:]).read_bytes()
        with tarfile.open(fileobj=io.BytesIO(added)) as tar:
            (member,) = tar.getmembers()
        self.assertEqual((member.name, member.isdir(), member.mode, member.mtime),
                         ("sys", True, 0o755, 1321009871))

    def test_output_is_the_same_for_the_same_input(self) -> None:
        write_layout(self.src, [layer([("usr", None)], complete=False)])
        other = Path(self.tmp.name) / "other"
        env = {"SOURCE_DATE_EPOCH": "1321009871"}
        self.assertEqual(run("fix-layout.py", self.src, self.dst, env=env).returncode, 0)
        self.assertEqual(run("fix-layout.py", self.src, other, env=env).returncode, 0)
        self.assertEqual((self.dst / "index.json").read_bytes(), (other / "index.json").read_bytes())

    def test_symlinked_blob_becomes_a_real_file(self) -> None:
        # BuildStream stages blobs as links into its store; the composefs
        # importer refuses links that leave the layout.
        write_layout(self.src, [layer([("usr", None), ("sys", None)])])
        blob = next(p for p in (self.src / "blobs/sha256").iterdir()
                    if p.read_bytes().endswith(END) and p.stat().st_size > 1024)
        store = Path(self.tmp.name) / "store"
        blob.rename(store)
        blob.symlink_to(store)
        self.assertEqual(run("fix-layout.py", self.src, self.dst).returncode, 0)
        copied = self.dst / "blobs/sha256" / blob.name
        self.assertFalse(copied.is_symlink())
        self.assertEqual(copied.read_bytes(), store.read_bytes())


def dump_line(path: str, mode: int, *, payload: str = "-", content: str = "-",
              mtime: str = "1321009871.0", size: int = 0) -> str:
    # composefs-dump(5): path size mode nlink uid gid rdev mtime payload content digest
    return f"{path} {size} {mode:o} 1 0 0 0 {mtime} {payload} {content} -\n"


class ExtractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        base = Path(self.tmp.name)
        self.objects = base / "objects"
        (self.objects / "ab").mkdir(parents=True)
        (self.objects / "ab/cdef").write_bytes(b"external content")
        self.dump = base / "dump"
        self.dest = base / "dest"
        self.dump.write_text("".join([
            dump_line("/", stat.S_IFDIR | 0o755),
            dump_line("/etc", stat.S_IFDIR | 0o755),
            dump_line("/etc/inline", stat.S_IFREG | 0o640, content="hello\\nworld", size=11),
            dump_line("/etc/external", stat.S_IFREG | 0o755, payload="ab/cdef", size=16),
            dump_line("/etc/link", stat.S_IFLNK | 0o777, payload="inline"),
            dump_line("/etc/with\\x20space", stat.S_IFREG | 0o644, content="x", size=1),
            "/etc/hard 0 @120000 1 0 0 0 0.0 /etc/inline - -\n",
            dump_line("/etc/private", stat.S_IFDIR | 0o700),
            dump_line("/etc/private/key", stat.S_IFREG | 0o600, content="secret", size=6),
            dump_line("/usr", stat.S_IFDIR | 0o755),
            dump_line("/usr/lib", stat.S_IFDIR | 0o755),
            dump_line("/usr/lib/modules", stat.S_IFDIR | 0o755),
            dump_line("/usr/lib/modules/7.3.3", stat.S_IFDIR | 0o755),
            dump_line("/usr/lib/modules/7.3.3/vmlinuz", stat.S_IFREG | 0o644, content="kernel", size=6),
            dump_line("/usr/lib/modules/7.3.3/other", stat.S_IFREG | 0o644, content="no", size=2),
            dump_line("/var", stat.S_IFDIR | 0o755),
        ]))

    def extract(self, *paths: str) -> subprocess.CompletedProcess:
        return run("extract.py", self.dump, self.objects, self.dest, *paths)

    def test_directory_is_taken_with_everything_below_it(self) -> None:
        result = self.extract("/etc")
        self.assertEqual(result.returncode, 0, result.stderr)
        etc = self.dest / "etc"
        self.assertEqual((etc / "inline").read_bytes(), b"hello\nworld")
        self.assertEqual(stat.S_IMODE((etc / "inline").stat().st_mode), 0o640)
        self.assertEqual((etc / "external").read_bytes(), b"external content")
        self.assertEqual(stat.S_IMODE((etc / "external").stat().st_mode), 0o755)
        self.assertEqual(os.readlink(etc / "link"), "inline")
        self.assertEqual((etc / "with space").read_bytes(), b"x")
        self.assertEqual((etc / "private/key").read_bytes(), b"secret")
        self.assertEqual(stat.S_IMODE((etc / "private").stat().st_mode), 0o700)
        self.assertEqual((etc / "inline").stat().st_mtime, 1321009871)
        self.assertEqual((etc / "private").stat().st_mtime, 1321009871)
        self.assertFalse((self.dest / "usr").exists())

    def test_hard_link_shares_the_inode(self) -> None:
        self.assertEqual(self.extract("/etc").returncode, 0)
        self.assertEqual((self.dest / "etc/hard").stat().st_ino, (self.dest / "etc/inline").stat().st_ino)

    def test_wildcard_selects_single_files(self) -> None:
        result = self.extract("/usr/lib/modules/*/vmlinuz")
        self.assertEqual(result.returncode, 0, result.stderr)
        modules = self.dest / "usr/lib/modules/7.3.3"
        self.assertEqual((modules / "vmlinuz").read_bytes(), b"kernel")
        self.assertFalse((modules / "other").exists())

    def test_nothing_matching_is_an_error(self) -> None:
        result = self.extract("/does/not/exist")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("nothing matched", result.stderr)


def parse_cpio(data: bytes) -> list[tuple[str, int, int, int, int, bytes]]:
    """(name, mode, uid, gid, mtime, content) for each newc entry."""
    entries, offset = [], 0
    while True:
        assert data[offset:offset + 6] == b"070701", offset
        fields = [int(data[offset + 6 + i * 8:offset + 14 + i * 8], 16) for i in range(13)]
        _, mode, uid, gid, _, mtime, size, *_, namesize, _ = fields
        name_start = offset + 110
        name = data[name_start:name_start + namesize - 1].decode()
        body = name_start + namesize
        body += -body % 4
        content = data[body:body + size]
        offset = body + size
        offset += -offset % 4
        if name == "TRAILER!!!":
            return entries
        entries.append((name, mode, uid, gid, mtime, content))


class MkcpioTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.src = Path(self.tmp.name) / "src"
        (self.src / "usr/lib").mkdir(parents=True)
        (self.src / "usr/lib/tool").write_bytes(b"#!/bin/sh\n")
        (self.src / "usr/lib/tool").chmod(0o700)
        (self.src / "usr/lib/data").write_bytes(b"abc")
        (self.src / "usr/lib/data").chmod(0o600)
        (self.src / "usr/link").symlink_to("lib/tool")

    def archive(self, name: str = "out.cpio") -> bytes:
        out = Path(self.tmp.name) / name
        result = run("mkcpio.py", self.src, out)
        self.assertEqual(result.returncode, 0, result.stderr)
        return out.read_bytes()

    def test_entries_are_sorted_root_owned_and_have_no_timestamp(self) -> None:
        entries = parse_cpio(self.archive())
        self.assertEqual([e[0] for e in entries],
                         ["usr", "usr/lib", "usr/lib/data", "usr/lib/tool", "usr/link"])
        for name, _, uid, gid, mtime, _ in entries:
            self.assertEqual((uid, gid, mtime), (0, 0, 0), name)

    def test_modes_are_normalised(self) -> None:
        by_name = {e[0]: e for e in parse_cpio(self.archive())}
        self.assertEqual(by_name["usr"][1], stat.S_IFDIR | 0o755)
        self.assertEqual(by_name["usr/lib/tool"][1], stat.S_IFREG | 0o755)
        self.assertEqual(by_name["usr/lib/data"][1], stat.S_IFREG | 0o644)
        self.assertEqual(by_name["usr/link"][1], stat.S_IFLNK | 0o777)
        self.assertEqual(by_name["usr/link"][5], b"lib/tool")
        self.assertEqual(by_name["usr/lib/data"][5], b"abc")

    def test_archive_is_padded_to_512_bytes(self) -> None:
        self.assertEqual(len(self.archive()) % 512, 0)

    def test_same_tree_gives_the_same_archive(self) -> None:
        first = self.archive("a.cpio")
        os.utime(self.src / "usr/lib/data", (1, 1))
        (self.src / "usr/lib/data").chmod(0o640)
        self.assertEqual(self.archive("b.cpio"), first)

    def test_unsupported_file_type_is_an_error(self) -> None:
        os.mkfifo(self.src / "fifo")
        result = run("mkcpio.py", self.src, Path(self.tmp.name) / "out.cpio")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsupported file type", result.stderr)


class BuildTests(unittest.TestCase):
    def test_esp_stays_within_what_boots_from_optical_media(self) -> None:
        self.assertEqual(build.ESP_MAX_MB, 256)
        # 249 MiB of boot files still fit; one more does not.
        self.assertEqual(build.esp_megabytes(249 * 1024 + 1023), 256)
        self.assertGreater(build.esp_megabytes(250 * 1024), build.ESP_MAX_MB)

    def test_apparent_size_counts_hard_links_once(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp, "tree")
            (root / "sub").mkdir(parents=True)
            (root / "sub/file").write_bytes(b"x" * 5000)
            before = build.apparent_kb(root)
            os.link(root / "sub/file", root / "sub/again")
            (root / "link").symlink_to("sub/file")
            du = subprocess.run(["du", "-sk", "--apparent-size", str(root)], capture_output=True, text=True)
            self.assertEqual(build.apparent_kb(root), int(du.stdout.split()[0]))
            self.assertLess(build.apparent_kb(root) - before, 4)

    def test_kernel_arguments_follow_the_architecture(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "20-b.toml").write_text('kargs = ["quiet"]\n')
            Path(tmp, "10-a.toml").write_text('kargs = ["rhgb", "a=1"]\nmatch-architectures = ["x86_64"]\n')
            Path(tmp, "30-arm.toml").write_text('kargs = ["arm"]\nmatch-architectures = ["aarch64"]\n')
            Path(tmp, "ignored.conf").write_text("not toml")
            self.assertEqual(build.kernel_arguments(Path(tmp), "x86_64"), ["rhgb", "a=1", "quiet"])
            self.assertEqual(build.kernel_arguments(Path(tmp), "aarch64"), ["quiet", "arm"])
            self.assertEqual(build.kernel_arguments(Path(tmp, "missing"), "x86_64"), [])

    def test_loader_entry(self) -> None:
        entry = build.loader_entry("Bluefin", "51", "EFI/Linux/bootc_composefs-abc", "abc", ["quiet"])
        lines = entry.splitlines()
        self.assertEqual(lines[:5], ["title Bluefin Live", "version 51", "linux /EFI/Linux/bootc_composefs-abc/vmlinuz",
                                     "initrd /EFI/Linux/bootc_composefs-abc/initrd",
                                     "initrd /EFI/Linux/bootc_composefs-abc/live.cpio"])
        options = lines[5].split()
        self.assertEqual(options[:5], ["options", "root=LABEL=dakota-live", "rootfstype=btrfs", "ro", "dakota.live"])
        self.assertIn("systemd.mask=boot.automount", options)
        # A swap file on the live filesystem would stop the installer.
        self.assertIn("systemd.mask=var-swap-swapfile.swap", options)
        self.assertIn("systemd.mask=bluefin-swapfile-init.service", options)
        # Optional digest: the seed has no fs-verity.
        self.assertEqual(options[-2:], ["quiet", "composefs.digest=?v1-sha512-12:abc"])

    def test_origin_file_and_boot_image(self) -> None:
        text = build.origin_file("ghcr.io/a/b:c", "d1", "sha256:m")
        self.assertIn("container-image-reference = ostree-unverified-image:docker://ghcr.io/a/b:c\n", text)
        self.assertIn("[boot]\nboot_type = bls\ndigest = d1\n", text)
        self.assertTrue(text.endswith("[image]\nmanifest_digest = sha256:m\n"))
        self.assertEqual(build.boot_image("Pulled\nBoot image: 4912ab\nDone\n"), "4912ab")
        with self.assertRaises(build.BuildFailed):
            build.boot_image("nothing useful")

    def test_layout_reference(self) -> None:
        index = {"manifests": [{"annotations": {"org.opencontainers.image.ref.name": "ghcr.io/a/b:c"}}]}
        self.assertEqual(build.layout_reference(index), "ghcr.io/a/b:c")
        self.assertEqual(build.layout_reference({"manifests": [{}]}), "")

    def test_wheel_and_automatic_login(self) -> None:
        group = "root:x:0:\nwheel:x:10:\nusers:x:100:a\n"
        self.assertEqual(build.with_wheel_member(group, "live"), "root:x:0:\nwheel:x:10:live\nusers:x:100:a\n")
        self.assertEqual(build.with_wheel_member("wheel:x:10:a,b\n", "live"), "wheel:x:10:a,b,live\n")
        self.assertEqual(build.with_wheel_member("wheel:x:10:live\n", "live"), "wheel:x:10:live\n")
        self.assertEqual(build.with_automatic_login("[daemon]\nWaylandEnable=true\n", "live"),
                         "[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=live\nWaylandEnable=true\n")
        kept = "[daemon]\nAutomaticLogin=someone\n"
        self.assertEqual(build.with_automatic_login(kept, "live"), kept)
        self.assertIn("[daemon]\nAutomaticLoginEnable=True", build.with_automatic_login("[security]\n", "live"))

    def test_live_session_lays_the_tree_over_the_image(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            etc, var, tree = Path(tmp, "etc"), Path(tmp, "var"), Path(tmp, "tree")
            etc.mkdir()
            var.mkdir()
            (etc / "passwd").write_text("root:x:0:0::/root:/bin/bash\n")
            (etc / "group").write_text("root:x:0:\nwheel:x:10:\n")
            (etc / "shadow").write_text("root:!::\n")
            (etc / "shadow").chmod(0)
            (etc / "replaced").write_text("from the image")
            (tree / "etc/systemd").mkdir(parents=True)
            (tree / "etc/systemd/unit.service").write_text("[Unit]\n")
            (tree / "etc/replaced").symlink_to("/dev/null")
            (tree / "var/opt/installer").mkdir(parents=True)
            (tree / "var/opt/installer/daemon.py").write_text("#!/usr/bin/python3\n")
            (tree / "var/opt/installer/daemon.py").chmod(0o755)
            for _ in range(2):  # a second run changes nothing
                build.live_session(etc, var, tree)
            self.assertEqual((etc / "passwd").read_text().count("live:x:900:900:"), 1)
            self.assertIn("wheel:x:10:live\n", (etc / "group").read_text())
            self.assertEqual(stat.S_IMODE((etc / "shadow").stat().st_mode), 0)
            (etc / "shadow").chmod(0o600)
            self.assertIn("live::20000:", (etc / "shadow").read_text())
            self.assertFalse((etc / "gshadow").exists())
            self.assertEqual(os.readlink(etc / "replaced"), "/dev/null")
            self.assertEqual(stat.S_IMODE((var / "opt/installer/daemon.py").stat().st_mode), 0o755)
            self.assertIn("AutomaticLogin=live", (etc / "gdm/custom.conf").read_text())


class SourceTests(unittest.TestCase):
    def test_shell_scripts_parse(self) -> None:
        # The initramfs has no Python, so this one stays a shell script.
        result = subprocess.run(["bash", "-n", str(TOOLS / "initrd/sprout")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_python_sources_compile(self) -> None:
        sources = sorted(TOOLS.rglob("*.py"))
        self.assertTrue(sources)
        with tempfile.TemporaryDirectory() as tmp:
            for source in sources:
                with self.subTest(source=source.name):
                    py_compile.compile(str(source), cfile=str(Path(tmp) / "out.pyc"), doraise=True)


if __name__ == "__main__":
    unittest.main()
