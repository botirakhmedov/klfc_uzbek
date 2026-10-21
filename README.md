Uzbek keyboard layouts for the 2026 alphabet
============================================

On 21 October 2026 the president signed the law that replaces the digraphs `Sh`, `Ch`,
`Oʻ` and `Gʻ` with the single letters **Ş**, **Ç**, **Ö** and **Ğ**. The alphabet is now
28 letters plus the tutuq belgisi `ʼ`, and `ng` is no longer counted as a unit of its own.
The law takes effect six months after publication.

**Uzbekçada:** [QOLLANMA.md](QOLLANMA.md) — örnatiş va işlatiş böyiça qisqa qöllanma.

No operating system ships an Uzbek Latin keyboard: macOS has only `uz-Arab` and
`uz-Cyrl`, and Windows and Linux are no better. This repository is that keyboard, for
every platform people actually type on.

| Platform | What you install | Status |
|----------|------------------|--------|
| macOS | `dist/macos/Uzbek2026.bundle` | built and checked against Apple's DTD |
| Windows | `dist/windows/<variant>/*.klc`, compiled with MSKLC | generated and checked |
| Linux | `dist/linux/<variant>/` (XKB) | generated and checked |
| Android | `android/` — a real input method, installable as an APK | tested on a Galaxy S24 Ultra |
| iOS | `ios/` — a keyboard extension, built with Xcode | unit and UI tested in the simulator |

Layouts
-------

Two desktop variants are generated from `src/`. Both put the tutuq belgisi `ʼ`
(U+02BC MODIFIER LETTER APOSTROPHE, not a quote mark) where you can reach it.

### `uz-qserty` — the default

`c` and `w` are not letters of the 2026 alphabet, which leaves their keys free, and `ç`
is literally `c` with a cedilla. So the new letters take the free keys and nothing that
is still a letter has to move.

```
 ~   1 2 3 4 5 6 7 8 9 0 - =
      q ş e r t y u i o p ö ğ
       a s d f g h j k l ; ʼ
        z x ç v b n m , . /
```

`AltGr` (right Alt; Option on macOS) gives back what moved: `AltGr+w` → `w`,
`AltGr+c` → `c`, `AltGr+[` → `[`, `AltGr+]` → `]`, `AltGr+'` → `'`.

### `uz-altgr` — for people who also type English and code

A US QWERTY layout with nothing moved at all. The new letters sit on `AltGr` under the
letter they are built from: `AltGr+s` → `ş`, `AltGr+c` → `ç`, `AltGr+o` → `ö`,
`AltGr+g` → `ğ`, `AltGr+'` → `ʼ`. Hold shift as well for the capitals.

### Phones

The phone keyboards use the same arrangement as `uz-qserty`, over ten columns with a
number row on top:

```
1 2 3 4 5 6 7 8 9 0
 q ş e r t y u i o p
 a s d f g h j k l ö
⇧ z x ç v b n m ğ ⌫
?123 🌐 ʼ ␣ . ⏎
```

`w` and `c` are a long press away on `ş` and `ç`, which is all it takes to type a URL.

Installing
----------

### macOS

```sh
./dist/macos/install.sh
```

Then log out and back in — macOS only reads new layout bundles at login — and add the
layout under *System Settings → Keyboard → Text Input → Input Sources → + → Others*.
`./dist/macos/uninstall.sh` removes it.

### Windows

The `.klc` file is source for Microsoft Keyboard Layout Creator; it is not itself a
layout. Open `dist/windows/uz-qserty/uz-qserty.klc` in
[MSKLC](https://www.microsoft.com/en-us/download/details.aspx?id=102134), then
*Project → Build DLL and Setup Package*, and run the installer it produces.

The same folder also holds an AutoHotkey script and a Portable Keyboard Layout folder.
Both work without installing anything, but both of them *replay* keystrokes rather than
being a real keyboard driver, so some applications read those keystrokes as shortcuts
instead of text. Use the compiled MSKLC layout for daily work.

### Linux

```sh
sudo ./dist/linux/uz-qserty/install-system.sh
```

Then pick the layout in your desktop's keyboard settings.

### Android

```sh
cd android && ./gradlew :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Open the app and follow its two steps, or enable it from the command line:

```sh
adb shell ime enable uz.alifbo.keyboard/.UzbekKeyboardService
adb shell ime set uz.alifbo.keyboard/.UzbekKeyboardService
```

### iOS

Open `ios/UzbekKeyboard.xcodeproj` in Xcode, set your signing team on both targets and
run it on your device. Then enable the keyboard under *Settings → General → Keyboard →
Keyboards → Add New Keyboard*. The project file is generated:

```sh
cd ios && xcodegen generate
```

Building and checking
---------------------

The desktop layouts are generated from `src/*.json` with
[KLFC](https://github.com/39aldo39/klfc), which `scripts/fetch-klfc.sh` downloads on
first use.

```sh
./scripts/build-desktop.sh        # src/*.json -> dist/
python3 scripts/verify-desktop.py # parse dist/ back and diff it against src/
```

The verifier reads each generated `.keylayout`, `.klc` and XKB symbols file, turns it
back into a key map and compares it with the source, then checks that every letter of
the alphabet and every ASCII character a US keyboard can type is still reachable. It
also validates the macOS layouts against `/System/Library/DTDs/KeyboardLayout.dtd`.

```sh
cd android && ./gradlew :app:testDebugUnitTest   # layout data
python3 android/scripts/device-test.py           # taps real keys on a connected phone
```

```sh
cd ios && xcodebuild -scheme UzbekKeyboard -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Two fixes on top of KLFC
------------------------

`scripts/package-macos.sh` corrects two things in what KLFC 1.5.7 emits for macOS:

* KLFC gives every layout the id `-1337`, which collides as soon as a bundle holds more
  than one.
* KLFC puts the `` ` `` key on virtual key code 10 and the ISO key on 50. Apple's own ABC
  layout is the other way round — 50 is `kVK_ANSI_Grave`, the key left of `1`, and 10 is
  `kVK_ISO_Section` — so with KLFC's order the `` ` `` key does nothing on the ANSI
  keyboards most people have.

Credits
-------

Keyboard layouts by Botir Akhmedov. Built with
[KLFC](https://github.com/39aldo39/klfc) by Aldo Gunsing. GPL-3.0, like KLFC.
