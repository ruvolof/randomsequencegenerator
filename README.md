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

## Privacy

The app collects nothing. The published policy is at
<https://werebug.com/privacy-policy/random-sequence-generator.html>; its source
is [`docs/privacy-policy.md`](docs/privacy-policy.md).

## License

Licensed under the Apache License, Version 2.0. See [`LICENSE`](LICENSE) for the
full text and [`NOTICE`](NOTICE) for the attribution that travels with
redistributions.

Releases before 2026-08-17 were licensed under the GNU General Public License,
version 3. That grant stands for the code as it was: anyone who received a copy
under the GPL keeps every right it gave them.

The name "Random Sequence Generator", the app icon, and the project's other
branding are not covered by that license — section 6 of the Apache License
grants no trademark rights. They are reserved under
[`TRADEMARK.md`](TRADEMARK.md).

You are free to fork this project and publish your own build — just give it a
different name, icon, and application identifier, and make clear that it is not
the official release. [`TRADEMARK.md`](TRADEMARK.md) has the full checklist.
