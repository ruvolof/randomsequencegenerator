# Trademark and Branding Policy

**Version 2.0 — effective 2026-08-17**

The source code in this repository is licensed under the Apache License, version
2.0 (see [`LICENSE`](LICENSE)). That license governs the code, and nothing in
this document takes away any right it grants you.

This document covers something the Apache License deliberately does *not* cover:
the project's **name and identity**.

## Relationship to the Apache License

This policy does not add a condition to the license — it describes rights the
license never granted in the first place. **Section 6** of the Apache License
says so directly:

> *"This License does not grant permission to use the trade names, trademarks,
> service marks, or product names of the Licensor, except as required for
> reasonable and customary use in describing the origin of the Work."*

So the split below is the license's own default, spelled out. The code grant in
sections 2 and 3 — copyright and patents — is unaffected, and you always retain
it in full.

Two related obligations already live in the license itself, and this policy does
not extend them: **section 4(b)** requires modified files to carry prominent
notices of change, and **section 4(d)** requires the [`NOTICE`](NOTICE) file's
attribution text to travel with redistributions.

## What is reserved

The following are **not** licensed under the Apache License and remain the
property of Francesco Ruvolo, all rights reserved:

**1. Names and marks**

- The app name **"Random Sequence Generator"**
- The publisher name **"Werebug"** and any logo or wordmark using it
- Any name confusingly similar to the above

**2. Copyrighted branding assets**

- The app icon and logo in their published form
- Store listing screenshots, feature graphics, promotional images, and
  marketing copy authored for this project
- Any other visual branding whose purpose is to identify the official release

**3. Application namespace**

- The application identifier `com.werebug.randomsequencegenerator`, used as the
  Android application id and the iOS bundle id, and any identifier under the
  `com.werebug.` namespace

## What you may do

Under the Apache License, without asking anyone:

- Clone, read, audit, study, and modify this source code
- Build the app from source **for your own use**, including with the original
  name and icon intact — a personal build is not a distribution, and you should
  not have to patch the repo just to run it
- Redistribute the source code, in whole or in part, under the Apache License,
  keeping the `LICENSE` and [`NOTICE`](NOTICE) files with it
- Fork the project and distribute your fork **under a different name, icon, and
  application identifier**, with attribution to this project and a clear
  statement that it is an independent, unofficial fork not associated with
  Francesco Ruvolo

Additionally, **nominative use is expressly permitted**: you may use the name
"Random Sequence Generator" truthfully to refer to this project — in
documentation, changelogs, articles, reviews, comparisons, package descriptions,
or a statement such as *"MyFork is a fork of Random Sequence Generator"* — as
long as you do not imply sponsorship, endorsement, or official status.

## What requires prior written permission

- Publishing a build of this software, modified or not, to any app store,
  website, package repository, or other distribution channel using the name
  "Random Sequence Generator", the project's icon, or branding confusingly
  similar to either
- Using "Random Sequence Generator" in a store listing title, developer name,
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
| Notices | Keep `LICENSE` and `NOTICE`, and mark the files you changed (Apache §4(b), §4(d)) |

## Why this split exists

This project uses an open source license so the code stays transparent,
auditable, and reusable.

The project's *identity* is reserved for a different reason: so that a user
searching an app store for "Random Sequence Generator" lands on a build the
author stands behind, rather than a re-upload carrying ads, trackers, or
malicious code under the same name and icon. Reserving the name protects users,
not the code.

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
revoke any Apache License rights already granted for code you have received.

Versions of this project released before 2026-08-17 were licensed under the GNU
General Public License, version 3. That grant is irrevocable for the code as it
stood then: anyone holding a copy received under the GPL keeps every right it
gave them.

---

## Notice to include elsewhere

The following notice should appear in `README.md`:

> Licensed under the Apache License, Version 2.0. See [`LICENSE`](LICENSE) for
> the full text and [`NOTICE`](NOTICE) for the attribution that travels with
> redistributions.
>
> The name "Random Sequence Generator", the app icon, and the project's other
> branding are not covered by that license — section 6 of the Apache License
> grants no trademark rights. They are reserved under
> [`TRADEMARK.md`](TRADEMARK.md).
