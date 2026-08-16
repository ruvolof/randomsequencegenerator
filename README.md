# Random Sequence Generator

A small, offline randomness toolkit for Android and iOS: random sequences, coin flips, and dice.

Built with Flutter. No network access, no analytics, no ads.

## Features

**Sequences** — generate a random string in any of six modes:

| Mode | What it draws from                                                          |
| --- |-----------------------------------------------------------------------------|
| Binary | `0` and `1`                                                                 |
| Hexadecimal | `0`–`9`, `a`–`f`                                                            |
| Character classes | set of pre-defined classes (lowercase, uppercase, digits...)                |
| Manual | whatever character pool you type                                            |
| UUID | a version 4 UUID                                                            |
| Mask | a user-defined template, where each placeholder is filled from its own pool |

**Toss** — flip a coin, or roll a d4, d6, d8, d10, d12, or d20.

Everything runs locally on the device.

String sequences can be stored, retrieved and shared with other devices.

## License

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License, version 3, as published by the Free
Software Foundation. See [`LICENSE`](LICENSE) for the full text.

The name "Random Sequence Generator", the app icon, and the project's other
branding are not covered by that license. They are reserved under the
supplementary terms in [`TRADEMARK.md`](TRADEMARK.md), as permitted by GPLv3
section 7.

You are free to fork this project and publish your own build — just give it a
different name, icon, and application identifier, and make clear that it is not
the official release. [`TRADEMARK.md`](TRADEMARK.md) has the full checklist.
