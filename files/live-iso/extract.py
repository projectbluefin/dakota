#!/usr/bin/env python3
"""Materialise paths from a composefs repository without mounting it.

Reads the dumpfile that `cfsctl oci dump` prints (composefs-dump(5)) and
copies the requested paths out of the repository's object store. The build
sandbox cannot mount, so this is how the live image gets the image's /etc,
/var and boot files.

usage: extract.py DUMPFILE OBJECTS_DIR DEST PATH...

Each PATH is an absolute path in the image; a directory is taken with
everything below it. Shell-style wildcards are allowed in PATH.
"""
import fnmatch
import os
import re
import shutil
import stat
import sys

_ESC = re.compile(rb'\\(x[0-9a-fA-F]{2}|.)')
_SIMPLE = {b'n': b'\n', b'r': b'\r', b't': b'\t', b'\\': b'\\', b'-': b'-'}


def unescape(field: bytes) -> bytes:
    def sub(m):
        e = m.group(1)
        if e[:1] == b'x':
            return bytes([int(e[1:], 16)])
        return _SIMPLE.get(e, e)
    return _ESC.sub(sub, field)


def optional(field: bytes) -> bytes:
    return b'' if field == b'-' else unescape(field)


def wanted(path: str, patterns) -> bool:
    for pat in patterns:
        if fnmatch.fnmatchcase(path, pat):
            return True
        # everything below a requested directory
        parts = path.split('/')
        for i in range(2, len(parts)):
            if fnmatch.fnmatchcase('/'.join(parts[:i]), pat):
                return True
    return False


def main():
    dump, objects, dest = sys.argv[1:4]
    patterns = [p.rstrip('/') for p in sys.argv[4:]]
    links, dirs, count = [], [], 0
    with open(dump, 'rb') as f:
        for line in f:
            fields = line.rstrip(b'\n').split(b' ')
            if len(fields) < 11:
                continue
            path = unescape(fields[0]).decode()
            if not wanted(path, patterns):
                continue
            target = dest + path
            os.makedirs(os.path.dirname(target), exist_ok=True)
            mode_field = fields[2]
            if mode_field.startswith(b'@'):
                links.append((target, dest + optional(fields[8]).decode()))
                continue
            mode = int(mode_field, 8)
            mtime = float(fields[7])
            payload, content = optional(fields[8]), fields[9]
            if stat.S_ISDIR(mode):
                os.makedirs(target, exist_ok=True)
                dirs.append((target, mode, mtime))
            elif stat.S_ISLNK(mode):
                os.symlink(payload, target)
                os.utime(target, (mtime, mtime), follow_symlinks=False)
            elif stat.S_ISREG(mode):
                if payload:
                    shutil.copyfile(os.path.join(objects, payload.decode()),
                                    target)
                else:
                    with open(target, 'wb') as out:
                        out.write(optional(content))
                os.chmod(target, stat.S_IMODE(mode))
                os.utime(target, (mtime, mtime))
            else:
                sys.exit(f'{path}: unsupported file type {mode:o}')
            count += 1
    for target, source in links:
        if os.path.exists(source):
            os.link(source, target)
            count += 1
        else:
            sys.exit(f'{target}: hard link target {source} was not extracted')
    for target, mode, mtime in reversed(dirs):
        os.chmod(target, stat.S_IMODE(mode))
        os.utime(target, (mtime, mtime))
    if count == 0:
        sys.exit(f'nothing matched {patterns}')
    print(f'extracted {count} entries for {" ".join(patterns)}')


if __name__ == '__main__':
    main()
