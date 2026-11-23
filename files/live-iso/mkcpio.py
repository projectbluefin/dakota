#!/usr/bin/env python3
"""Write a reproducible newc cpio archive of a directory tree.

usage: mkcpio.py SOURCE_DIR OUTPUT

Everything is owned by root with a zero timestamp, and entries are sorted,
so the same input always gives the same archive.
"""
import os
import stat
import sys


def header(ino, mode, nlink, size, name):
    name_b = name.encode() + b'\0'
    fields = [ino, mode, 0, 0, nlink, 0, size, 0, 0, 0, 0, len(name_b), 0]
    head = b'070701' + b''.join(b'%08X' % v for v in fields) + name_b
    return head + b'\0' * (-len(head) % 4)


def main():
    src, out = sys.argv[1:3]
    entries = []
    for root, dirs, files in os.walk(src):
        dirs.sort()
        for name in sorted(dirs + files):
            full = os.path.join(root, name)
            entries.append(os.path.relpath(full, src))
    entries.sort()
    with open(out, 'wb') as f:
        for ino, rel in enumerate(entries, start=1):
            full = os.path.join(src, rel)
            st = os.lstat(full)
            if stat.S_ISLNK(st.st_mode):
                data = os.readlink(full).encode()
                mode = stat.S_IFLNK | 0o777
            elif stat.S_ISDIR(st.st_mode):
                data = b''
                mode = stat.S_IFDIR | 0o755
            elif stat.S_ISREG(st.st_mode):
                with open(full, 'rb') as g:
                    data = g.read()
                mode = stat.S_IFREG | (0o755 if st.st_mode & 0o111 else 0o644)
            else:
                sys.exit(f'{rel}: unsupported file type')
            nlink = 2 if stat.S_ISDIR(st.st_mode) else 1
            f.write(header(ino, mode, nlink, len(data), rel))
            f.write(data + b'\0' * (-len(data) % 4))
        f.write(header(0, 0, 1, 0, 'TRAILER!!!'))
        f.write(b'\0' * (-f.tell() % 512))


if __name__ == '__main__':
    main()
