#!/usr/bin/env python3
"""Check that every generated desktop layout really carries the letters in src/*.json.

Parses the artifacts in dist/ back into {position: [level0..level4]} and diffs them
against the source JSON, so a build is only "done" when the files say so.
"""
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
LEVELS = ["base", "shift", "ctrl", "altgr", "shift+altgr"]
ALPHABET = "abdefghijklmnopqrstuvxyzöğşç"
TUTUQ = "ʼ"
# Everything a US keyboard can type. A layout that silently drops one of these is worse
# than no layout: people only find out when they reach for ? and nothing comes out.
PUNCTUATION = "`1234567890-=~!@#$%^&*()_+[]{}\\|;:'\",.<>/? "

# KLFC position -> macOS virtual key code
MAC = {"A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7, "C": 8, "V": 9,
       "Iso": 10, "B": 11, "Q": 12, "W": 13, "E": 14, "R": 15, "Y": 16, "T": 17,
       "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "+": 24, "9": 25, "7": 26,
       "-": 27, "8": 28, "0": 29, "]": 30, "O": 31, "U": 32, "[": 33, "I": 34, "P": 35,
       "L": 37, "J": 38, "'": 39, "K": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "N": 45,
       "M": 46, ".": 47, "Space": 49, "~": 50, "KP_Dec": 65}

# KLFC position -> XKB key name
XKB = {"~": "TLDE", "-": "AE11", "+": "AE12", "[": "AD11", "]": "AD12", "\\": "BKSL",
       ";": "AC10", "'": "AC11", ",": "AB08", ".": "AB09", "/": "AB10",
       "Iso": "LSGT", "Space": "SPCE"}
for i, c in enumerate("1234567890"):
    XKB[c] = "AE%02d" % (i + 1)
for i, c in enumerate("QWERTYUIOP"):
    XKB[c] = "AD%02d" % (i + 1)
for i, c in enumerate("ASDFGHJKL"):
    XKB[c] = "AC%02d" % (i + 1)
for i, c in enumerate("ZXCVBNM"):
    XKB[c] = "AB%02d" % (i + 1)

# KLFC position -> KLC virtual key column
KLC = {"~": "OEM_3", "-": "OEM_MINUS", "+": "OEM_PLUS", "[": "OEM_4", "]": "OEM_6",
       "\\": "OEM_5", ";": "OEM_1", "'": "OEM_7", ",": "OEM_COMMA", ".": "OEM_PERIOD",
       "/": "OEM_2", "Iso": "OEM_102", "Space": "SPACE", "KP_Dec": "DECIMAL"}
for c in "1234567890QWERTYUIOPASDFGHJKLZXCVBNM":
    KLC[c] = c

failures = []


def check(variant, fmt, pos, level, want, got):
    if want != got:
        failures.append(f"{variant}/{fmt}: key {pos!r} level {LEVELS[level]}: "
                        f"expected {want!r}, got {got!r}")


def unesc(s):
    return re.sub(r"&#x?([0-9A-Fa-f]+);",
                  lambda m: chr(int(m.group(1), 16 if "x" in m.group(0) else 10)), s)


def read_keylayout(path):
    """-> {maplevel: {keycode: output}} for the five non-command key maps."""
    text = path.read_text(encoding="utf-8")
    maps = {}
    for m in re.finditer(r'<keyMap index="(\d+)"[^>]*>(.*?)</keyMap>', text, re.S):
        idx = int(m.group(1))
        keys = {}
        for k in re.finditer(r'<key code="(\d+)"\s+output="(.*?)"\s*/>', m.group(2)):
            keys[int(k.group(1))] = unesc(k.group(2))
        maps[idx] = keys
    return maps


def read_xkb(path):
    """-> {keyname: [level0..levelN]} with level names resolved to characters."""
    text = path.read_text(encoding="utf-8")
    out = {}
    for m in re.finditer(r'key\s+<(\w+)>\s*\{(.*?)\};', text, re.S):
        syms = re.search(r'\[(.*?)\]', m.group(2), re.S)
        if not syms:
            continue
        out[m.group(1)] = [s.strip() for s in syms.group(1).split(",")]
    return out


def keysym_to_char(name):
    if name in ("NoSymbol", "VoidSymbol", ""):
        return ""
    m = re.fullmatch(r"U([0-9A-Fa-f]{4,6})", name)
    if m:
        return chr(int(m.group(1), 16))
    named = {"space": " ", "grave": "`", "asciitilde": "~", "exclam": "!", "at": "@",
             "numbersign": "#", "dollar": "$", "percent": "%", "asciicircum": "^",
             "ampersand": "&", "asterisk": "*", "parenleft": "(", "parenright": ")",
             "minus": "-", "underscore": "_", "equal": "=", "plus": "+",
             "bracketleft": "[", "braceleft": "{", "bracketright": "]", "braceright": "}",
             "backslash": "\\", "bar": "|", "semicolon": ";", "colon": ":",
             "apostrophe": "'", "quotedbl": '"', "comma": ",", "less": "<",
             "period": ".", "greater": ">", "slash": "/", "question": "?",
             "endash": "–", "emdash": "—", "guillemotleft": "«",
             "guillemotright": "»", "rightsinglequotemark": "’",
             "scedilla": "ş", "Scedilla": "Ş", "ccedilla": "ç",
             "Ccedilla": "Ç", "odiaeresis": "ö", "Odiaeresis": "Ö",
             "gbreve": "ğ", "Gbreve": "Ğ"}
    if name in named:
        return named[name]
    if len(name) == 1:
        return name
    return None  # unknown -> reported


def read_klc(path):
    """-> {vk: [level0..level4]} from the LAYOUT section."""
    raw = path.read_bytes()
    text = raw.decode("utf-16" if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8")
    out = {}
    in_layout = False
    for line in text.splitlines():
        if line.startswith("LAYOUT"):
            in_layout = True
            continue
        if in_layout and (line.startswith("KEYNAME") or line.startswith("DESCRIPTIONS")):
            break
        if not in_layout or not line.strip() or line.lstrip().startswith("//"):
            continue
        cols = line.split("//")[0].split()
        if len(cols) < 4:
            continue
        vk = cols[1]
        vals = []
        for c in cols[3:8]:
            if c == "-1":
                vals.append("")
            elif len(c) == 1:
                vals.append(c)
            else:
                vals.append(chr(int(c.rstrip("@"), 16)))
        out[vk] = vals + [""] * (5 - len(vals))
    return out


for src in sorted((ROOT / "src").glob("uz-*.json")):
    variant = src.stem
    spec = json.loads(src.read_text(encoding="utf-8"))
    keys = {k["pos"]: k["letters"] for k in spec["keys"]}

    kl = read_keylayout(ROOT / "dist/macos/Uzbek2026.bundle/Contents/Resources" / f"{variant}.keylayout")
    xk = read_xkb(next((ROOT / "dist/linux" / variant / "symbols").iterdir()))
    kc = read_klc(ROOT / "dist/windows" / variant / f"{variant}.klc")

    for pos, letters in keys.items():
        for lvl, want in enumerate(letters):
            if not want or len(want) != 1 or ord(want) < 0x20:
                continue  # control codes / empties are format-specific filler
            if pos in MAC:
                check(variant, "keylayout", pos, lvl, want, kl.get(lvl, {}).get(MAC[pos], ""))
            if pos in XKB and XKB[pos] in xk:
                syms = xk[XKB[pos]]
                got = keysym_to_char(syms[lvl]) if lvl < len(syms) else ""
                if got is None:
                    failures.append(f"{variant}/xkb: key {pos!r} level {LEVELS[lvl]}: "
                                    f"unknown keysym {syms[lvl]!r}")
                else:
                    check(variant, "xkb", pos, lvl, want, got)
            if pos in KLC and KLC[pos] in kc:
                check(variant, "klc", pos, lvl, want, kc[KLC[pos]][lvl])

    # every alphabet letter plus the tutuq belgisi must be typeable somewhere
    produced = {c for ls in keys.values() for c in ls if c}
    for ch in ALPHABET + ALPHABET.upper() + TUTUQ:
        if ch not in produced:
            failures.append(f"{variant}: alphabet character {ch!r} (U+{ord(ch):04X}) is unreachable")

    # A layout that silently loses a punctuation mark is worse than no layout: people
    # only notice when they reach for ? or @ and nothing comes out.
    for ch in PUNCTUATION:
        if ch not in produced:
            failures.append(f"{variant}: ASCII character {ch!r} (U+{ord(ch):04X}) is unreachable")

    print(f"checked {variant}: {len(keys)} keys across keylayout, klc, xkb")

# Validate the keylayout structure against Apple's own DTD. libxml2 has no XML 1.1
# support, and XML 1.0 rejects the control-character references that Apple's layouts and
# ours both use for Escape and the function keys, so neutralise those first and validate
# what is left: the element structure, which is what the DTD describes.
DTD = pathlib.Path("/System/Library/DTDs/KeyboardLayout.dtd")
if DTD.exists() and shutil.which("xmllint"):
    for kl in sorted((ROOT / "dist/macos/Uzbek2026.bundle/Contents/Resources").glob("*.keylayout")):
        text = kl.read_text(encoding="utf-8")
        text = text.replace('version="1.1"', 'version="1.0"')
        text = re.sub(r"&#x?0*(?:[0-9]|1[0-9]|2[0-9]|3[01]);", "?", text)
        with tempfile.NamedTemporaryFile("w", suffix=".keylayout", delete=False) as fh:
            fh.write(text)
            tmp = fh.name
        proc = subprocess.run(["xmllint", "--noout", "--valid", tmp],
                              capture_output=True, text=True)
        os.unlink(tmp)
        if proc.returncode != 0:
            failures.append(f"{kl.name}: fails Apple's KeyboardLayout.dtd:\n    "
                            + proc.stderr.strip().replace("\n", "\n    "))
        else:
            print(f"checked {kl.stem}: valid against Apple's KeyboardLayout.dtd")

if failures:
    print(f"\nFAILED ({len(failures)}):")
    for f in failures:
        print("  " + f)
    sys.exit(1)
print("\nOK: all generated desktop layouts match src/")
