# Trademark and Branding Policy

**Version 1.0 — effective 2026-08-01**

The source code in this repository is licensed under the GNU General Public
License, version 3 (see [`LICENSE`](LICENSE)). That license governs the code,
and nothing in this document takes away any right the GPL grants you.

This document covers something the GPL deliberately does *not* cover: the
project's **name and identity**.

## Relationship to the GPL

This policy is a supplementary term under **GPLv3 section 7**, which expressly
permits the following additions to a GPL'd work:

- **7(b)** — requiring preservation of author attributions;
- **7(c)** — requiring that modified versions be marked as different from the
  original;
- **7(e)** — *"Declining to grant rights under trademark law for use of some
  trade names, trademarks, or service marks."*

Because GPLv3 anticipates exactly these terms, this policy is **not** a "further
restriction" under section 10 and does not conflict with the license. You always
retain the full GPLv3 grant over the code itself.

## What is reserved

The following are **not** licensed under the GPL and remain the property of
Francesco Ruvolo, all rights reserved:

**1. Names and marks**

- The app name **"Everything Random"**
- The publisher name **"Werebug"** and any logo or wordmark using it
- Any name confusingly similar to the above

**2. Copyrighted branding assets**

- The app icon and logo in their published form
- Store listing screenshots, feature graphics, promotional images, and
  marketing copy authored for this project
- Any other visual branding whose purpose is to identify the official release

**3. Application namespace**

- The Android application identifier `com.werebug.randomsequencegenerator`, the
  iOS bundle identifier `com.werebug.everythingrandom`, and any identifier under
  the `com.werebug.` namespace

## What you may do

Under the GPLv3, without asking anyone:

- Clone, read, audit, study, and modify this source code
- Build the app from source **for your own use**, including with the original
  name and icon intact — a personal build is not a distribution, and you should
  not have to patch the repo just to run it
- Redistribute the source code, in whole or in part, under the GPLv3
- Fork the project and distribute your fork **under a different name, icon, and
  application identifier**, with attribution to this project and a clear
  statement that it is an independent, unofficial fork not associated with
  Francesco Ruvolo

Additionally, **nominative use is expressly permitted**: you may use the name
"Everything Random" truthfully to refer to this project — in documentation,
changelogs, articles, reviews, comparisons, package descriptions, or a statement
such as *"MyFork is a fork of Everything Random"* — as long as you do not imply
sponsorship, endorsement, or official status.

## What requires prior written permission

- Publishing a build of this software, modified or not, to any app store,
  website, package repository, or other distribution channel using the name
  "Everything Random", the project's icon, or branding confusingly similar to
  either
- Using "Everything Random" in a store listing title, developer name,
  description, keywords, or other metadata in a way likely to cause confusion
  with the official release
- Using the reserved application identifier or the `com.werebug.` namespace in a
  distributed build
- Implying in any way that a fork is official, endorsed, or maintained by
  Francesco Ruvolo

## Rebranding checklist for forks

If you distribute a fork, change all of the following:

| What | Where |
| --- | --- |
| App display name | `android/app/src/main/AndroidManifest.xml` (`android:label`) |
| App display name | `ios/Runner/Info.plist` (`CFBundleDisplayName`) |
| Package name | `pubspec.yaml` (`name`, `description`) |
| Application identifier | `android/app/build.gradle.kts` (`applicationId`, `namespace`) |
| Bundle identifier | Xcode project / `ios/Runner.xcodeproj` |
| Icon | `assets/icon/` — replace the source images, then re-run `flutter pub run flutter_launcher_icons` |
| Attribution | Your README, stating the fork is unofficial and linking back here |

## Why this split exists

This project uses an open source license so the code stays transparent,
auditable, and reusable.

The project's *identity* is reserved for a different reason: so that a user
searching an app store for "Everything Random" lands on a build the author
stands behind, rather than a re-upload carrying ads, trackers, or malicious code
under the same name and icon. Reserving the name protects users, not the code.

## Reporting misuse

If you find a store listing, repository, or website using the reserved name or
branding in a way that violates this policy, please open an issue in this
repository or contact <ruvolof@gmail.com>.

If it is an **active store listing**, please also report it directly to the
platform. Their own impersonation and intellectual-property reporting forms are
usually a much faster route to takedown than contacting the author first:

- Google Play: <https://support.google.com/legal/troubleshooter/1114905>
- Apple App Store: <https://www.apple.com/legal/intellectual-property/>

## Changes

This policy may be updated. Changes apply going forward and do not retroactively
revoke any GPLv3 rights already granted for code you have received.

---

## Notice to include elsewhere

For the section 7 terms above to travel with the code, the following notice
should appear in `README.md`:

> This program is free software: you can redistribute it and/or modify it under
> the terms of the GNU General Public License, version 3, as published by the
> Free Software Foundation. See [`LICENSE`](LICENSE) for the full text.
>
> The name "Everything Random", the app icon, and the project's other branding
> are not covered by that license. They are reserved under the supplementary
> terms in [`TRADEMARK.md`](TRADEMARK.md), as permitted by GPLv3 section 7.
