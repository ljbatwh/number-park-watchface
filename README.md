# Number Park watchface

A Lua watchface for Xiaomi Smart Band 10 / Band 11 (Vela). It shows the time, today's system step count and an "-ity" number character that changes as steps grow (Primity → Squarity → Factority → Doublity → Googolity).

Band 11 uses the Band 10 package byte-for-byte (verified by comparing published Band 10 and Band 11 builds of the same face), so one `band10` build covers both.

## Build

Packages are compiled on GitHub Actions (Windows) with the [EasyFace](https://github.com/m0tral/EasyFace) Gen2 compiler. Every push to `main` produces a `.face` artifact. Rename to `.bin` if your installer needs it, then install with [AstroBox](https://github.com/AstralSightStudios).

Local project generation (no compile):

```
python3 tools/build.py
```

## Credits

The project layout, metadata patch and CI flow follow [sf-yuzifu/Monika](https://github.com/sf-yuzifu/Monika) (GPL-3.0). This repository is GPL-3.0 as well.
