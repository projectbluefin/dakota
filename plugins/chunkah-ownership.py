"""Chunkah component ownership for an exact normal BuildStream compose artifact.

The companion stages the already-built compose layer, never replays its
integration commands.  Component claims come from the compose inputs while the
exact layer artifact determines which paths survived composition.  This keeps
basis correctness separate from final-image byte identity: OCI finalization
snapshots the actual integrated root later.
"""

import json
import os
from pathlib import PurePosixPath

from buildstream import Element, ElementError
from buildstream.storage.directory import FileType


_INTERVAL_HINTS = (
    ("bluefin/", "weekly"), ("gnome/gnome-shell", "weekly"),
    ("gnome/mutter", "weekly"), ("gnome/gdm", "weekly"),
    ("gnome/nautilus", "weekly"), ("gnome/", "monthly"),
    ("freedesktop-sdk", "monthly"),
)
_INTEGRATION_OWNER = {
    "component": "dakota.integration",
    "producer": "dakota:integration",
    "interval": "monthly",
}


def _interval(component):
    for prefix, interval in _INTERVAL_HINTS:
        if prefix in component:
            return interval
    return "monthly"


def _relative_path(path):
    normalized = str(PurePosixPath(path))
    if path.startswith("/") or normalized == "." or any(part in ("", ".", "..") for part in normalized.split("/")):
        raise ElementError("BuildStream returned an unsafe staged path: {!r}".format(path))
    return normalized


def _file_type(info):
    if info.file_type == FileType.DIRECTORY:
        return "directory"
    if info.file_type == FileType.REGULAR_FILE:
        return "file"
    if info.file_type == FileType.SYMLINK:
        return "symlink"
    # Special files are not xattr candidates, but recording their type makes
    # structural validation fail closed rather than overlooking them.
    return str(info.file_type)


def _structure(directory):
    """Return path/type identity without conflating it with final bytes.

    A BuildStream cache key can name non-reproducible realizations of the same
    logical artifact.  Ownership depends on surviving paths and types, not on
    incidental bytes.  The OCI finalizer separately records complete bytes,
    metadata, xattrs, and hardlink topology from the actual root it packages.
    """
    return {
        path: _file_type(directory.stat(path, follow_symlinks=False))
        for path in sorted(_relative_path(item) for item in directory.list_relative_paths())
    }


class ChunkahOwnershipElement(Element):
    """Generate Chunkah metadata from an exact compose layer and its inputs."""

    BST_MIN_VERSION = "2.5"
    BST_STRICT_REBUILD = True
    BST_FORBID_RDEPENDS = True
    BST_FORBID_SOURCES = True
    BST_RUN_COMMANDS = False

    def configure(self, node):
        node.validate_keys([
            "metadata-path", "layer-dependency", "provenance-dependencies",
            "metadata-dependencies", "inherit-from-components",
        ])
        self.metadata_path = _relative_path(node.get_str("metadata-path", default="ownership/basis.json"))
        self.layer_name = node.get_str("layer-dependency")
        self.provenance_names = set(node.get_str_list("provenance-dependencies"))
        self.metadata_names = set(node.get_str_list("metadata-dependencies"))
        self.inherit_from = set(node.get_str_list("inherit-from-components"))
        if not self.layer_name or not self.provenance_names:
            raise ElementError("chunkah-ownership requires a layer-dependency and provenance-dependencies")
        if len(self.metadata_names) != len(self.inherit_from):
            raise ElementError("metadata-dependencies and inherit-from-components must have equal lengths")
        selected = self.provenance_names | self.metadata_names
        if self.layer_name in selected or self.provenance_names & self.metadata_names:
            raise ElementError("chunkah-ownership dependency roles must not overlap")

    def preflight(self):
        names = {dep.name for dep in self.dependencies(recurse=False)}
        configured = {self.layer_name} | self.provenance_names | self.metadata_names
        unknown = configured - names
        if unknown:
            raise ElementError("chunkah-ownership dependencies not declared: {}".format(sorted(unknown)))

    def get_unique_key(self):
        return {
            "metadata-path": self.metadata_path,
            "layer-dependency": self.layer_name,
            "provenance-dependencies": sorted(self.provenance_names),
            "metadata-dependencies": sorted(self.metadata_names),
            "inherit-from-components": sorted(self.inherit_from),
        }

    def configure_sandbox(self, sandbox):
        pass

    def stage(self, sandbox):
        direct = list(self.dependencies(recurse=False))
        layers = [dep for dep in direct if dep.name == self.layer_name]
        provenance_roots = [dep for dep in direct if dep.name in self.provenance_names]
        metadata = [dep for dep in direct if dep.name in self.metadata_names]
        if len(layers) != 1 or len(provenance_roots) != len(self.provenance_names) or len(metadata) != len(self.metadata_names):
            raise ElementError("chunkah-ownership selected dependency set is incomplete")

        self._layer = layers[0]
        # This is the same deterministic input order core compose used.  These
        # dependencies are inspected for claims only; they are never restaged
        # as a second independently integrated root.
        self._provenance = list(self.dependencies(selection=provenance_roots))
        self._metadata = metadata
        with self.timed_activity("Staging exact compose layer", silent_nested=True):
            self.stage_dependency_artifacts(sandbox, selection=layers, path="ownership-layer")
        for index, dep in enumerate(metadata):
            dep.stage_artifact(sandbox, path="ownership-inputs/{}".format(index))

    def _claims(self):
        claims = {}
        component_producers = {}
        for dep in self._provenance:
            component = dep.name
            producer = "{}:{}".format(dep.project_name, dep.name)
            previous = component_producers.setdefault(component, producer)
            if previous != producer:
                raise ElementError(
                    "ambiguous component {!r} is produced by both {!r} and {!r}".format(component, previous, producer)
                )
            claim = {"component": component, "producer": producer, "interval": _interval(component)}
            # Core compose stages in this order; the last ordinary file claim
            # is the overlap winner.  Final layer structure below excludes
            # removed/filtered paths and non-file directory merges.
            for path in dep.compute_manifest(include=[], exclude=[], orphans=True):
                claims[_relative_path(path)] = claim
        return claims

    def _inherit_claims(self, basedir, claims):
        replacements = {}
        for index, dep in enumerate(self._metadata):
            metadata_dir = basedir.open_directory("ownership-inputs/{}".format(index), create=False)
            try:
                with metadata_dir.open_file(self.metadata_path, mode="r") as source:
                    document = json.load(source)
            except (OSError, ValueError, json.JSONDecodeError) as error:
                raise ElementError("cannot read ownership companion {}: {}".format(dep.name, error))
            if document.get("schema") != 3 or not isinstance(document.get("entries"), list):
                raise ElementError("invalid ownership companion {}".format(dep.name))
            for entry in document["entries"]:
                if not isinstance(entry, dict):
                    raise ElementError("invalid ownership entry in {}".format(dep.name))
                path = _relative_path(entry.get("path", "").lstrip("/"))
                component, producer, interval = entry.get("component"), entry.get("producer"), entry.get("interval")
                if not all(isinstance(value, str) and value for value in (component, producer, interval)):
                    raise ElementError("invalid ownership entry in {}".format(dep.name))
                claim = {"component": component, "producer": producer, "interval": interval}
                if path in replacements and replacements[path] != claim:
                    raise ElementError("conflicting inherited owner for {}".format(path))
                replacements[path] = claim
        for path, claim in list(claims.items()):
            if claim["component"] in self.inherit_from and path in replacements:
                claims[path] = replacements[path]
        return claims

    def assemble(self, sandbox):
        basedir = sandbox.get_virtual_directory()
        layer = basedir.open_directory("ownership-layer", create=False)
        structure = _structure(layer)
        claims = self._inherit_claims(basedir, self._claims())

        entries = []
        for path, file_type in structure.items():
            if file_type not in ("file", "symlink"):
                continue
            claim = claims.get(path, _INTEGRATION_OWNER)
            entries.append({"path": "/" + path, **claim})

        payload = {
            "schema": 3,
            "layer_artifact": self._layer.get_artifact_name(),
            "structure": structure,
            "entries": entries,
        }
        artifact = basedir.open_directory("buildstream/ownership-output", create=True)
        parent = str(PurePosixPath(self.metadata_path).parent)
        if parent != ".":
            artifact.open_directory(parent, create=True)
        with artifact.open_file(self.metadata_path, mode="w") as metadata:
            metadata.write(json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n")
        return os.path.join(os.sep, "buildstream", "ownership-output")


def setup():
    return ChunkahOwnershipElement
