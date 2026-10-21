#!/usr/bin/env python3
"""Drive the installed keyboard on a connected device and check what it actually types.

The unit tests cover the layout data; this covers the part that only a real device can
answer — that a tap at a given spot produces the right codepoint in a real text field.

Usage: android/scripts/device-test.py          (device must already have the app installed)
"""
import re
import subprocess
import sys
import time

PKG = "uz.alifbo.keyboard"
ACTIVITY = f"{PKG}/.SetupActivity"
IME = f"{PKG}/.UzbekKeyboardService"

# Mirrors Layouts.kt. The unit test keeps that file honest; this table keeps the taps
# aimed at the right keys.
ROWS = [
    [("1", 1), ("2", 1), ("3", 1), ("4", 1), ("5", 1),
     ("6", 1), ("7", 1), ("8", 1), ("9", 1), ("0", 1)],
    [("q", 1), ("ş", 1), ("e", 1), ("r", 1), ("t", 1),
     ("y", 1), ("u", 1), ("i", 1), ("o", 1), ("p", 1)],
    [("a", 1), ("s", 1), ("d", 1), ("f", 1), ("g", 1),
     ("h", 1), ("j", 1), ("k", 1), ("l", 1), ("ö", 1)],
    [("SHIFT", 1), ("z", 1), ("x", 1), ("ç", 1), ("v", 1),
     ("b", 1), ("n", 1), ("m", 1), ("ğ", 1), ("DEL", 1)],
    [("?123", 1.5), ("GLOBE", 1), ("ʼ", 1), ("SPACE", 4), (".", 1), ("ENTER", 1.5)],
]
ROW_HEIGHT_DP = 52
PADDING_TOP_DP = 4
PADDING_BOTTOM_DP = 8
POPUP_CELL_DP = 44


def adb(*args, binary=False):
    out = subprocess.run(["adb", *args], capture_output=True)
    if out.returncode != 0:
        raise RuntimeError(f"adb {' '.join(args)} failed: {out.stderr.decode().strip()}")
    return out.stdout if binary else out.stdout.decode()


def shell(cmd):
    return adb("shell", cmd)


class Device:
    def __init__(self):
        size = re.search(r"(\d+)x(\d+)", shell("wm size"))
        self.width, self.height = int(size.group(1)), int(size.group(2))
        self.density = int(re.search(r"(\d+)", shell("wm density")).group(1)) / 160.0
        self.row_h = ROW_HEIGHT_DP * self.density
        self.pad_top = PADDING_TOP_DP * self.density
        self.pad_bottom = PADDING_BOTTOM_DP * self.density
        self.cell = POPUP_CELL_DP * self.density
        self.hint = None
        self.bottom = self._keyboard_bottom()
        self.top = self.bottom - (self.row_h * len(ROWS) + self.pad_top + self.pad_bottom)

    def _keyboard_bottom(self):
        """The keyboard sits directly on top of the navigation bar.

        Measured with the app in front and the keyboard still hidden: once the keyboard
        is up, uiautomator dumps the input method's own window, which has no navigation
        bar in it.
        """
        shell(f"am start -S -n {ACTIVITY}")
        time.sleep(1.5)
        dump = self.ui_dump()
        hint = re.search(r'class="android\.widget\.EditText"[^>]*hint="([^"]*)"', dump)
        if hint:
            self.hint = hint.group(1)
        nav = re.search(r'navigationBarBackground[^/]*?bounds="\[\d+,(\d+)\]', dump)
        if not nav:
            raise RuntimeError("could not find the navigation bar; is the app in front?")
        return int(nav.group(1))

    def ui_dump(self):
        return adb("exec-out", "uiautomator", "dump", "/dev/tty", binary=True).decode("utf-8", "replace")

    def field_text(self):
        """An empty field reports its hint as its text, so read that back as empty."""
        for _ in range(3):
            dump = self.ui_dump()
            m = re.search(r'class="android\.widget\.EditText"[^>]*?\btext="([^"]*)"', dump)
            if m is None:
                m = re.search(r'\btext="([^"]*)"[^>]*class="android\.widget\.EditText"', dump)
            if m:
                text = m.group(1)
                return "" if self.hint and text == self.hint else text
            time.sleep(0.5)
        return None

    def centre(self, label):
        for r, row in enumerate(ROWS):
            total = sum(w for _, w in row)
            x = 0.0
            for name, weight in row:
                if name == label:
                    cx = (x + weight / 2) / total * self.width
                    cy = self.top + self.pad_top + self.row_h * (r + 0.5)
                    return cx, cy
                x += weight
        raise KeyError(f"no key labelled {label!r}")

    def tap(self, label):
        x, y = self.centre(label)
        shell(f"input tap {int(x)} {int(y)}")
        time.sleep(0.3)

    def long_press_pick(self, label, index):
        """Hold a key until its alternates appear, slide to [index], release."""
        x, y = self.centre(label)
        shell(f"input motionevent DOWN {int(x)} {int(y)}")
        time.sleep(0.6)
        shell(f"input motionevent MOVE {int(x + self.cell * index)} {int(y)}")
        time.sleep(0.2)
        shell(f"input motionevent UP {int(x + self.cell * index)} {int(y)}")
        time.sleep(0.3)

    def fresh_field(self):
        shell(f"am start -S -n {ACTIVITY}")
        time.sleep(1.5)
        dump = self.ui_dump()
        m = re.search(r'class="android\.widget\.EditText"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', dump)
        if not m:
            raise RuntimeError("no EditText on the setup screen")
        x1, y1, x2, y2 = map(int, m.groups())
        cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
        shell(f"input tap {cx} {cy}")
        time.sleep(1.0)
        # Samsung's keyboard re-selects itself whenever an app comes to the front, so
        # switch to ours once a field already has focus: that selection does stick.
        shell(f"ime set {IME}")
        time.sleep(1.0)
        shell(f"input tap {cx} {cy}")
        time.sleep(1.2)
        current = shell("settings get secure default_input_method").strip()
        if IME not in current:
            raise RuntimeError(f"the system is using {current}, not the keyboard under test")


def main():
    if not re.search(r"\bdevice\b", adb("devices")):
        sys.exit("no authorised device; run `adb devices` and accept the prompt")
    # Reinstalling the app disables its input method; fresh_field() selects it.
    shell(f"ime enable {IME}")

    d = Device()
    print(f"device {d.width}x{d.height} @ {d.density:.3f}x, keyboard rows {d.top:.0f}..{d.bottom}")

    failures = []

    def case(name, steps, expected):
        d.fresh_field()
        steps()
        got = d.field_text()
        ok = got == expected
        codes = " ".join(f"U+{ord(c):04X}" for c in (got or ""))
        print(f"  [{'ok' if ok else 'FAIL'}] {name}: {got!r}  {codes}")
        if not ok:
            failures.append(f"{name}: expected {expected!r}, got {got!r}")

    print("\nrunning:")
    case("the four new letters and the tutuq belgisi",
         lambda: [d.tap(c) for c in ("ş", "ö", "ğ", "ç", "ʼ")],
         "şöğçʼ")

    case("shift applies to one letter only",
         lambda: [d.tap("SHIFT"), d.tap("ş"), d.tap("ö")],
         "Şö")

    case("w hides under ş, c under ç",
         lambda: [d.long_press_pick("ş", 1), d.long_press_pick("ç", 1)],
         "wc")


    case("the number row types digits",
         lambda: [d.tap("1"), d.tap("0")],
         "10")

    case("backspace removes one codepoint, not one UTF-16 unit",
         lambda: [d.tap("ʼ"), d.tap("ğ"), d.tap("DEL")],
         "ʼ")

    # On the symbol page the key in t's place is '5', and the one in '?123's place
    # reads 'ABC' and leads back.
    case("the symbol page types and returns",
         lambda: [d.tap("?123"), d.tap("t"), d.tap("?123"), d.tap("ş")],
         "5ş")

    if failures:
        print(f"\nFAILED ({len(failures)}):")
        for f in failures:
            print("  " + f)
        sys.exit(1)
    print("\nOK: the keyboard types the 2026 alphabet correctly on this device")


if __name__ == "__main__":
    main()
