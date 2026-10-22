Özbek klaviaturasi — qisqa qöllanma
===================================

> Bu qöllanmaning özi 2026-yilgi yangi alifboda yozilgan. Texnik atamalar (AltGr, Shift,
> layout, driver, MSKLC, APK, Xcode, adb) tarjima qilinmagan — ular hamma joyda şu nom
> bilan yuritiladi.

Nima özgardi
------------

2026-yil 21-oktabrda imzolangan qonunga köra tört harf birikmasi bitta harfga aylandi:

| Eski | Yangi |
|------|-------|
| Sh sh | **Ş ş** |
| Ch ch | **Ç ç** |
| Oʻ oʻ | **Ö ö** |
| Gʻ gʻ | **Ğ ğ** |

Alifbo endi **28 harf va bitta tutuq belgisi (ʼ)**. `c` va `w` alifboda yöq.

Qaysi klavişda nima
-------------------

```
 ~   1 2 3 4 5 6 7 8 9 0 - =
      q ş e r t y u i o p ö ğ
       a s d f g h j k l ; ʼ
        z x ç v b n m , . /
```

- `ş` — eski `w` klavişi
- `ç` — eski `c` klavişi
- `ö` — eski `[` klavişi
- `ğ` — eski `]` klavişi
- `ʼ` (tutuq belgisi) — eski `'` klavişi

Katta harf uçun odatdagidek `Shift`.

### w, c, [, ], ' qayerda qoldi

Ular **AltGr** (öng `Alt`; Mac'da `Option`) bilan çiqadi:

| Bosiş | Natija |
|-------|--------|
| `AltGr` + `w` | w |
| `AltGr` + `c` | c |
| `AltGr` + `[` | [ |
| `AltGr` + `]` | ] |
| `AltGr` + `'` | ' (oddiy apostrof) |

Agar inglizça köp yozsangiz yoki kod yozsangiz, **`uz-altgr`** variantini oling: unda
QWERTY umuman özgarmaydi, yangi harflar esa `AltGr` + `s`, `c`, `o`, `g` da turadi.

Örnatiş
-------

### Bitta buyruq bilan (macOS yoki Linux)

```sh
curl -fsSL https://raw.githubusercontent.com/botirakhmedov/klfc_uzbek/main/install.sh | sh
```

Skript pipe'dan öqilgani uçun hech narsa söray olmaydi — sozlamalar environment orqali
beriladi:

```sh
curl -fsSL .../install.sh | VARIANT=uz-altgr sh     # ikkinçi variant
curl -fsSL .../install.sh | ACTION=uninstall sh     # öçiriş
```

macOS'da bundle `~/Library/Keyboard Layouts` ga köçiriladi, Linux'da esa XKB skripti
`sudo` bilan işga tuşiriladi. Windows bu yölga kirmaydi — u yerda `.klc` ni MSKLC bilan
yiğiş kerak, pastda yozilgan.

Quyidagilar — şu işning qölda bajariliş yöli.

### macOS

```sh
./dist/macos/install.sh
```

Söng **tizimdan çiqib, qayta kiring** — macOS yangi layout'ni faqat login paytida
öqiydi. Keyin: *System Settings → Keyboard → Text Input → Input Sources → + → Others*
dan tanlang.

Öçiriş: `./dist/macos/uninstall.sh`

### Windows

`dist/windows/uz-qserty/uz-qserty.klc` — bu layout'ning özi emas, **MSKLC uçun manba
fayl**. [MSKLC](https://www.microsoft.com/en-us/download/details.aspx?id=102134) da
oçing, *Project → Build DLL and Setup Package* qiling, söng çiqqan installer'ni işga
tuşiring.

Şu papkada AHK skript va PKL varianti ham bor — ular hech narsa örnatmay işlaydi,
**lekin** ikkalasi ham tugma bosişini *qaytadan yuboradi*, şuning uçun ayrim dasturlar
buni matn emas, yorliq (shortcut) deb qabul qiladi. Kundalik iş uçun MSKLC driver'ini
işlating.

### Linux

```sh
sudo ./dist/linux/uz-qserty/install-system.sh
```

Söng tizim sozlamalaridan klaviaturani tanlang. Ubuntu, Debian va Fedora'da sinab
körilgan.

### Android

```sh
cd android && ./gradlew :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Ilovani oçib, ikki qadamni bajaring: klaviaturani yoqiş va tanlaş.

Telefonda `w` va `c` — `ş` va `ç` ni **bosib turganda** çiqadi. Raqamlar yuqori qatorda.

### iOS

`ios/UzbekKeyboard.xcodeproj` ni Xcode'da oçing, ikkala target'ga öz signing team'ingizni
qöying va telefonga yuklang. Söng: *Settings → General → Keyboard → Keyboards → Add New
Keyboard*.

Köp beriladigan savollar
------------------------

**`?` işlamayapti, Telegram yorliqlar oynasini oçyapti.**
Bu layout muammosi emas. Telegram Desktop'da böş xabar maydonida `Shift+?` — yorliqlar
oynasining özi. Oldida harf bölsa `?` oddiy yoziladi. Ingliz layout'ida ham xuddi şunday.

**Tutuq belgisi qaysi belgi?**
`ʼ` — Unicode'da `U+02BC`. Bu apostrof (`'`) ham, qöştirnoq (`'`) ham emas; u **harf**
hisoblanadi, şuning uçun qidiruv va saralaş töğri işlaydi.

**Eski hujjatlarim nima böladi?**
Qonunga köra amaldagi hujjatlar, milliy valyuta va qimmatli qoğozlar özgartirilmaydi.

**`ng` nima böldi?**
Alifboda alohida birlik emas, lekin sözlarda oldingidek yoziladi: *tong*, *keng*.
