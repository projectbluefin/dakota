#!/usr/bin/env python3
"""Make an OCI layout importable by the composefs tools.

usage: fix-layout.py SOURCE_LAYOUT DEST_LAYOUT

The base layer BuildStream's oci-builder writes is an uncompressed tar with
no end-of-archive marker (two zero blocks). Most tools accept that; the
composefs importer stops with "Unexpected EOF in splitstream". This writes a
copy of the layout in which such layers get the marker, and updates the
digests that depend on them. Layers that are already complete are hard linked
where the filesystem allows, and the files in the image are unchanged either way.

The layers also carry no /sys directory, which the published image gets
when it is re-chunked. systemd cannot switch from the initramfs into a root
without one, so a layer holding only that directory is added when no layer
has it.
"""
import hashlib
import io
import json
import os
import shutil
import sys
import tarfile

TAR = 'application/vnd.oci.image.layer.v1.tar'
END = b'\0' * 1024


def blob(layout, digest):
    algo, value = digest.split(':', 1)
    return os.path.join(layout, 'blobs', algo, value)


def write_json(layout, obj):
    data = json.dumps(obj, separators=(',', ':')).encode()
    digest = 'sha256:' + hashlib.sha256(data).hexdigest()
    with open(blob(layout, digest), 'wb') as f:
        f.write(data)
    return digest, len(data)


def complete(path):
    size = os.path.getsize(path)
    if size < len(END):
        return False
    with open(path, 'rb') as f:
        f.seek(-len(END), os.SEEK_END)
        return f.read() == END


def has_top_level(path, name):
    with tarfile.open(path) as tar:
        for member in tar:
            if member.name.lstrip('./').rstrip('/') == name:
                return True
    return False


def directory_layer(name, mode, mtime):
    data = io.BytesIO()
    with tarfile.open(fileobj=data, mode='w', format=tarfile.PAX_FORMAT) as tar:
        info = tarfile.TarInfo(name)
        info.type, info.mode, info.mtime = tarfile.DIRTYPE, mode, mtime
        tar.addfile(info)
    return data.getvalue()


def main():
    src, dst = sys.argv[1:3]
    os.makedirs(os.path.join(dst, 'blobs', 'sha256'))
    with open(os.path.join(src, 'oci-layout'), 'rb') as f, \
            open(os.path.join(dst, 'oci-layout'), 'wb') as g:
        g.write(f.read())
    with open(os.path.join(src, 'index.json')) as f:
        index = json.load(f)
    original = json.loads(json.dumps(index))
    for entry in index['manifests']:
        with open(blob(src, entry['digest'])) as f:
            manifest = json.load(f)
        with open(blob(src, manifest['config']['digest'])) as f:
            config = json.load(f)
        changed = False
        for i, layer in enumerate(manifest['layers']):
            source = blob(src, layer['digest'])
            if layer['mediaType'] != TAR or complete(source):
                # The importer refuses links that leave the layout.
                try:
                    os.link(source, blob(dst, layer['digest']))
                except OSError:
                    shutil.copyfile(source, blob(dst, layer['digest']))
                continue
            h = hashlib.sha256()
            tmp = os.path.join(dst, 'blobs', 'sha256', 'incoming')
            with open(source, 'rb') as f, open(tmp, 'wb') as g:
                while chunk := f.read(8 << 20):
                    h.update(chunk)
                    g.write(chunk)
                h.update(END)
                g.write(END)
            digest = 'sha256:' + h.hexdigest()
            os.rename(tmp, blob(dst, digest))
            changed = True
            print(f'layer {i}: added the end-of-archive marker, '
                  f'{layer["digest"][7:19]} -> {digest[7:19]}')
            # An uncompressed layer's diff_id is its own digest.
            config['rootfs']['diff_ids'][i] = digest
            layer['digest'] = digest
            layer['size'] += len(END)
        if not any(has_top_level(blob(dst, layer['digest']), 'sys')
                   for layer in manifest['layers']):
            mtime = int(os.environ.get('SOURCE_DATE_EPOCH', '0'))
            data = directory_layer('sys', 0o755, mtime)
            digest = 'sha256:' + hashlib.sha256(data).hexdigest()
            with open(blob(dst, digest), 'wb') as f:
                f.write(data)
            manifest['layers'].append(
                {'mediaType': TAR, 'digest': digest, 'size': len(data)})
            config['rootfs']['diff_ids'].append(digest)
            if 'history' in config:
                config['history'].append({'created_by': 'live ISO: add /sys'})
            print('added a layer with the /sys directory')
            changed = True
        if not changed:
            # Keep the manifest byte for byte, so its digest stays the one
            # the registry serves.
            for digest in (entry['digest'], manifest['config']['digest']):
                shutil.copyfile(blob(src, digest), blob(dst, digest))
            continue
        manifest['config']['digest'], manifest['config']['size'] = \
            write_json(dst, config)
        entry['digest'], entry['size'] = write_json(dst, manifest)
    if index == original:
        shutil.copyfile(os.path.join(src, 'index.json'),
                        os.path.join(dst, 'index.json'))
        return
    with open(os.path.join(dst, 'index.json'), 'w') as f:
        json.dump(index, f, separators=(',', ':'))


if __name__ == '__main__':
    main()
