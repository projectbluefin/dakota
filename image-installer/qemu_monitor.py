"""Shared QEMU monitor helpers, used by both e2e unlock scripts.

luks-unlock.py and plymouth-prompt.py both drive the QEMU monitor the same
way: a plain UNIX stream socket carrying HMP (Human Monitor Protocol)
commands. This module holds that logic once, so the two scripts cannot drift
apart. It stays stdlib-only, by the scripts' convention, and needs no socket
package of its own.
"""

import socket
import time


def run_hmp_command(sock_path, command, *, settle=0.0, connect_timeout=10.0,
                    recv_timeout=1.0, prompt=None, drain_before=False):
    """Send one HMP command to the QEMU monitor and read its reply.

    A monitor socket is a plain stream socket, so this needs nothing beyond
    the standard library.

    sock_path — path to the QEMU monitor UNIX socket.
    command — the HMP command line, sent without its trailing newline.
    settle — seconds to wait after sending, before reading, so QEMU can
        begin its reply first.
    connect_timeout — socket timeout while connecting, in seconds.
    recv_timeout — socket timeout while reading, in seconds.
    prompt — if a byte string, reading stops as soon as it appears in the
        reply. QEMU prints "(qemu)" after each command, so b"(qemu)" makes
        this return only once a synchronous command such as screendump is
        finished.
    drain_before — if true, read until prompt first, before sending, to clear
        any prompt QEMU already printed while idle.

    Returns the decoded reply. A closed socket ends the read; a read timeout
    ends it too, leaving whatever was already gathered.
    """
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(connect_timeout)
        client.connect(sock_path)
        if drain_before and prompt is not None:
            seen = b""
            while prompt not in seen:
                seen += client.recv(4096) or prompt
        client.sendall(command.encode() + b"\n")
        if settle:
            time.sleep(settle)
        client.settimeout(recv_timeout)
        chunks = []
        seen = b""
        try:
            while True:
                chunk = client.recv(4096)
                if not chunk:
                    break
                chunks.append(chunk)
                seen += chunk
                if prompt is not None and prompt in seen:
                    break
        except (socket.timeout, TimeoutError):
            pass
    return b"".join(chunks).decode(errors="replace")
