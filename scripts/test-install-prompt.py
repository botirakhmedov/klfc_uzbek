#!/usr/bin/env python3
"""Check that install.sh asks which layout to install, and honours the answer.

The question is the one part of the installer that plain `sh install.sh` cannot
exercise: it is only asked when a terminal is attached, and it is read from /dev/tty
rather than stdin, because piping the script into sh puts the script itself on stdin.
So the test gives it a pseudo-terminal and types into that.

Run from the repository root. On Linux the installer needs root, so run it as root or
with sudo available; it uninstalls again afterwards.
"""
import fcntl
import os
import pty
import re
import select
import subprocess
import sys
import tempfile
import termios
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TIMEOUT = 180


def run_with_tty(answers, env_extra=None):
    """Run install.sh attached to a pty, type `answers`, return what it printed."""
    env = dict(os.environ)
    env.pop("VARIANT", None)
    env.pop("ACTION", None)
    env.update(env_extra or {})

    primary, secondary = pty.openpty()

    def attach_terminal():
        """Make the pty the child's controlling terminal, so /dev/tty resolves to it.

        A new session alone is not enough on Linux: without TIOCSCTTY the child has no
        controlling terminal and opening /dev/tty fails.
        """
        os.setsid()
        fcntl.ioctl(secondary, termios.TIOCSCTTY, 0)

    process = subprocess.Popen(
        ["sh", os.path.join(ROOT, "install.sh")],
        stdin=secondary, stdout=secondary, stderr=secondary,
        env=env, cwd=ROOT, close_fds=True, preexec_fn=attach_terminal,
    )
    os.close(secondary)

    output = bytearray()
    pending = list(answers)
    deadline = time.time() + TIMEOUT
    try:
        while True:
            if time.time() > deadline:
                process.kill()
                raise TimeoutError("install.sh did not finish in time")
            readable, _, _ = select.select([primary], [], [], 0.5)
            if readable:
                try:
                    chunk = os.read(primary, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                output += chunk
                # Answer each prompt as it appears.
                if pending and b"Choose 1 or 2" in output.split(b"\n")[-1]:
                    os.write(primary, pending.pop(0).encode() + b"\n")
            elif process.poll() is not None:
                break
    finally:
        os.close(primary)
        process.wait(timeout=10)

    return process.returncode, output.decode("utf-8", "replace")


def check(name, answers, expect, env_extra=None):
    code, text = run_with_tty(answers, env_extra)
    clean = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", text)
    ok = code == 0 and all(fragment in clean for fragment in expect)
    print(f"  [{'ok' if ok else 'FAIL'}] {name}")
    if not ok:
        print(f"    exit={code}")
        for fragment in expect:
            if fragment not in clean:
                print(f"    missing: {fragment!r}")
        print("    ---- output ----")
        for line in clean.splitlines():
            print("    " + line)
    return ok


def uninstall(variant):
    env = dict(os.environ, ACTION="uninstall", VARIANT=variant)
    subprocess.run(["sh", os.path.join(ROOT, "install.sh")],
                   env=env, cwd=ROOT, capture_output=True)


def main():
    linux = sys.platform.startswith("linux")
    home = None
    env_extra = {}
    if not linux:
        # Keep a macOS run out of the real keyboard layouts directory.
        home = tempfile.mkdtemp()
        env_extra["HOME"] = home

    installed_marker = "uzaltgr" if linux else "Uzbek (2026) AltGr"
    default_marker = "uzqserty" if linux else "Uzbek (2026) QŞERTY"

    print("running:")
    results = [
        check("the question is asked, and lists both layouts",
              ["1"], ["Which layout do you want?", "uz-qserty", "uz-altgr"], env_extra),
        check("answering 2 installs uz-altgr",
              ["2"], [installed_marker, "+ s  ->  ş"], env_extra),
        check("pressing enter takes the default",
              [""], [default_marker, "the w key  ->  ş"], env_extra),
        check("a wrong answer is asked again",
              ["9", "1"], ["Please answer 1 or 2", default_marker], env_extra),
    ]

    for variant in ("uz-qserty", "uz-altgr"):
        uninstall(variant)
    if home:
        subprocess.run(["rm", "-rf", home])

    if not all(results):
        sys.exit(f"\n{results.count(False)} check(s) failed")
    print("\nOK: install.sh asks which layout to install and honours the answer")


if __name__ == "__main__":
    main()
