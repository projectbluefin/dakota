/*
 * fakecap-restore — physically write user.component xattrs from a
 * fakecap manifest to a target rootfs.
 *
 * Usage: fakecap-restore <manifest.tsv> <rootfs>
 *
 * Reads a TSV manifest (path\tcomponent\tinterval) and calls lsetxattr
 * on each file under <rootfs>.  Skips missing files silently.
 *
 * Physical xattr injection for BST images.
 * chunkah uses rustix raw syscalls for xattr reads (bypassing libc / LD_PRELOAD),
 * so xattrs must be physically applied before chunkah runs.
 * coreos/chunkah#113 is closed — the resolution is this overlay approach,
 * not a libc fallback. Used by `just chunkify` for local dev; CI uses
 * the bootc-build/chunka action (inject-xattrs.py) instead.
 *
 * Copyright (c) 2025  contributors
 * SPDX-License-Identifier: MIT
 */

#define _GNU_SOURCE
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/xattr.h>

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: fakecap-restore <manifest.tsv> <rootfs>\n");
        return 1;
    }
    const char *manifest_path = argv[1];
    const char *rootfs        = argv[2];

    FILE *f = fopen(manifest_path, "r");
    if (!f) {
        perror("fakecap-restore: open manifest");
        return 1;
    }

    size_t n_set = 0, n_skip = 0, n_err = 0;
    char line[8192];

    while (fgets(line, sizeof(line), f)) {
        /* strip newline */
        size_t len = strlen(line);
        if (len && line[len - 1] == '\n') line[--len] = '\0';

        if (!*line || *line == '#') continue;

        char *tab1 = strchr(line, '\t');
        if (!tab1) continue;
        *tab1 = '\0';
        const char *rel_path  = line;
        const char *component = tab1 + 1;

        char *tab2 = strchr(component, '\t');
        const char *interval = "weekly";
        if (tab2) { *tab2 = '\0'; interval = tab2 + 1; }

        char fullpath[8192];
        if (snprintf(fullpath, sizeof(fullpath), "%s%s", rootfs, rel_path)
                >= (int)sizeof(fullpath))
            continue;

        int r = lsetxattr(fullpath, "user.component",
                          component, strlen(component), 0);
        if (r < 0) {
            /* ENOENT: file absent in this image variant — expected, skip.
             * EPERM/ENOTSUP/EOPNOTSUPP: symlinks and some special files do
             * not support user.* xattrs on Linux — expected, skip. */
            if (errno == ENOENT   ||
                errno == EPERM    ||
                errno == ENOTSUP  ||
                errno == EOPNOTSUPP) { n_skip++; continue; }
            n_err++;
            continue;
        }

        lsetxattr(fullpath, "user.update-interval",
                  interval, strlen(interval), 0);
        n_set++;
    }
    fclose(f);

    fprintf(stderr,
            "fakecap-restore: %zu xattrs set, %zu files skipped, %zu errors\n",
            n_set, n_skip, n_err);
    return n_err > 0 ? 1 : 0;
}
