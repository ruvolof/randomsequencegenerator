# MIGRATION.md — Android (Java, 2013) → Flutter

> **This file is the single source of truth for the migration.** It was written in a planning
> session on **2026-07-27** and is meant to be read cold at the start of the implementation
> session. It contains the complete specification of the legacy app, because **the legacy
> sources get deleted in step A1** and this document has to survive them.
>
> **Do not delete this file during step A1.** It stays at the repo root.
>
> Status: **planning complete, no code written yet.** Progress tracker at the bottom.

---

## 1. Context

`RandomSequenceGenerator` is the first Android app its author published — Java, Holo-era,
`compileSdk 19` / `minSdk 8`, AGP 2.2.2, Gradle 2.14.1. It has been removed from the Play
Store and untouched for years. It no longer builds on modern toolchains, targets an API
level Play would reject, and carries dead AdMob leftovers plus several real bugs.

**Goal:** a full rewrite in Flutter that preserves the functionality and the *immediate look*
of the original — four screens, dark `#333333` background, white text, the same controls in
the same arrangement — while modernizing the stack and fixing the known defects. Nothing from
the old codebase is carried over; it stays recoverable in git history.

### Decisions locked in (do not re-litigate)

| Decision | Value |
|---|---|
| Repo strategy | Replace in place at the repo root, branch `flutter_modernization` (already checked out) |
| Git | **The agent never runs git write commands.** The user handles all commits, branches, pushes. The agent may run read-only git (`status`, `log`, `show`, `ls-files`) |
| Platforms | Android now, iOS in a later session. Generate `ios/` but leave it unconfigured. **All code must be cross-platform** — no Android-only plugins or APIs |
| Visual | Same layout and flow, rendered with Material 3 dark |
| Bugs | Fix all of them (§4) |
| Localization | `flutter_localizations` + ARB, `en` only for now, fully wired so adding a locale is drop-in. **No hardcoded user-facing strings** |
| Storage | `shared_preferences` holding a JSON list — name, sequence, timestamp, mode. Stable ordering |
| Icon | Regenerate the original concept at high res via `flutter_launcher_icons` |
| Version | `3.0.0+300` (legacy was `2.2.2` / versionCode `222`, so `300` keeps Play upgrades valid) |
| applicationId | Stays `com.werebug.randomsequencegenerator` |

### Environment (verified 2026-07-27 on this machine)

| Item | Value |
|---|---|
| Flutter | 3.44.8 stable, Dart 3.12.2, at `/home/francesco/development/flutter` |
| Android SDK | 36.1.0-rc1, platform android-36, licenses accepted, JDK 21 (Android Studio JBR) |
| Devices | `emulator-5554` — sdk gphone64 x86_64, Android 16 / API 36; plus a `linux` desktop toolchain |
| Chrome | **not installed** — `flutter run -d chrome` is unavailable |
| Flutter Gradle defaults | `compileSdk=36`, `minSdk=24`, `targetSdk=36`, `ndkVersion=28.2.13676358` |
| Image tooling | Python 3 + Pillow 10.2.0, DejaVu Sans Mono at `/usr/share/fonts/truetype/dejavu/` (no ImageMagick/Inkscape/cairosvg) |
| Pub versions checked | `share_plus 13.3.0`, `shared_preferences 2.5.5`, `intl 0.20.3`, `flutter_launcher_icons 0.14.4`, `flutter_lints 6.0.0` |

`flutter run -d emulator-5554` is the real run command. `-d linux` will **not** work
(`--platforms=android,ios` produces no `linux/` folder). The emulator plus widget tests are
the feedback loop.

---

## 2. Legacy app specification

Package `com.werebug.randomsequencegenerator`, versionName `2.2.2`, versionCode `222`.
Six Java files: `RSGMain`, `ShowSaved`, `ShowSingle`, `LaunchCoin`, `SaveDialog`,
`ConfirmDeleteAllDialog`. No permissions (INTERNET / ACCESS_NETWORK_STATE were removed along
with AdMob in commits `ed90d87` and `b88cf35`). Theme `@android:style/Theme.Holo` on v11+.
Colors: background `#333333`, text `#FFFFFF`. No settings screen, no About/Help, no SQLite.

### 2.1 Character pools (verbatim — the non-alphabetical keyboard order is intentional)

```
BINARY  = "01"
HEX     = "0123456789ABCDEF"
DIGIT   = "0123456789"
LAZ     = "qwertyuiopasdfghjklzxcvbnm"
CAZ     = "QWERTYUIOPASDFGHJKLZXCVBNM"
SPECIAL = "$%&()=?@#<>_£[]*"
```

Class mode concatenates the checked sets **in the fixed order DIGIT → LAZ → CAZ → SPECIAL**,
regardless of the order the user ticked them. Manual mode uses the text field content
**verbatim** as the pool — no trim, no dedup; duplicates legitimately bias the output.

### 2.2 Screen: Main (`RSGMain`, title "Random Sequence Generator")

Dark, 15dp padding, scrollable. Top to bottom:

1. **Vertical radio group** — Binary (checked at startup), Hexadecimal, Class, Manual. Row
   height 34dp on phones, 50dp on `sw600dp`.
2. **Class block** (visible only in Class mode) — four checkboxes: `[0–9]`, `[a–z]`, `[A–Z]`
   across one row, `[$%&()=?@#<>_£[]*]` on a second row beneath the first.
3. **Manual field** (visible only in Manual mode) — one full-width text field, hint `abcd078[]`.
4. **Length row** — `Length` label on the left (`textAppearanceLarge` ≈ 22sp) + a numeric
   field on the right defaulting to `32`.
5. **Create button** — centered, 250dp wide (plus a 30dp margin on `sw600dp`).
6. **Three 40×40dp icon buttons**, hidden until the first successful generation, laid out on a
   row below Create: copy aligned to Create's *left* edge, save *centered*, share aligned to
   Create's *right* edge. Hidden again whenever the pool comes out empty.
7. **Result** — centered, 30sp, white, wraps freely. Empty state shows the hint
   `Click menu button to go to saved sequences`.

AppBar items: `Saved` → Saved Sequences, `Coin` → Launch Coin.

Legacy generation loop, for reference:
```java
chars_last_index = chars.length() - 1;
for (int i = selected_length; i > 0; i--)
    result += chars.charAt((int) Math.round(Math.random() * chars_last_index));
```

Copy → clipboard + toast `Copied to clipboard`. Send → `ACTION_SEND` chooser, `text/plain`.
Save → the "Save as…" dialog, then `getSharedPreferences("saved_sequences", MODE_PRIVATE)`
`.putString(name, sequence).commit()`.

### 2.3 Screen: Saved Sequences (`ShowSaved`, title "Saved Sequences")

A `ListView` of saved **names** (`simple_list_item_1`); empty state is a centered white
`No saved entries`. Order was `SharedPreferences.getAll()` HashMap iteration order —
effectively random, which we replace with a stable ordering.

- **Tap** a row → Show Sequences with that sequence.
- **Long-press** → context menu Delete / Copy / Send. Copy/Send act on the stored sequence;
  a missing key surfaced `There isn't any saved string which matches this key.`
- **AppBar `Delete all`** → if non-empty, an `Are you sure?` dialog with `Cancel` /
  `Yes, delete them!`; if empty, a toast `There are no saved entries.` instead.

### 2.4 Screen: Show Sequences (`ShowSingle`, title "Show Sequences")

Two 40×40dp icon buttons near the top (copy, share) — the legacy layout gave them 200dp side
margins tuned for tablets, which collide on a phone — above a scrollable, centered, 30sp
white display of the sequence.

### 2.5 Screen: Launch Coin (`LaunchCoin`, title "Launch Coin")

An area 280dp tall (360dp on `sw600dp`) showing the hint `Click on flip`, and a `Flip` button
centered beneath it. Constants `MINFLIP=10`, `MAXFLIP=30`, `SLEEP=200`ms.

On Flip: pick `flipnum` in 10..30 and decide the final `coin` (0 or 1) **up front**, then a
`CountDownTimer(flipnum * 200ms, 200ms)` toggles the displayed digit `0,1,0,1,…` every tick;
`onFinish` shows the decided value. On the first tick the digit turns white and huge — the
intent was a giant digit filling the block.

### 2.6 Dialogs

- **Save as…** — message `Save as…`, a text field (the legacy `save_as_dialog.xml` with hint
  `Enter a name` existed but was never inflated; we *do* show the hint), buttons `Cancel` / `Save`.
- **Are you sure?** — buttons `Cancel` / `Yes, delete them!`. No title.

### 2.7 All 36 legacy strings, verbatim (these become `app_en.arb` values)

Preserve the U+2013 en-dashes in the three range labels, the `£`, and the U+2026 `…`.

```
app_name                   RandomSequenceGenerator
title_activity_rsg_main    Random Sequence Generator
r_binary                   Binary
r_hexadecimal              Hexadecimal
r_class                    Class
r_manual                   Manual
range_digit                [0–9]
range_lowercase            [a–z]
range_uppercase            [A–Z]
range_special              [$%&()=?@#<>_£[]*]
manual_hint                abcd078[]
create                     Create
default_length             32
length                     Length
copy                       Copy
copied_to_cb               Copied to clipboard
send                       Send
save                       Save
cancel                     Cancel
save_as                    Save as…
saved                      Saved
save_hint                  Enter a name
goto_saved                 Click menu button to go to saved sequences
delete_all                 Delete all
title_activity_show_saved  Saved Sequences
no_saved                   No saved entries
are_you_sure               Are you sure?
yes_delete_them            Yes, delete them!
nothing_to_delete          There are no saved entries.
delete                     Delete
title_activity_show_single Show Sequences
string_notfound            There isn't any saved string which matches this key.
coin                       Coin
title_activity_launch_coin Launch Coin
flip                       Flip
click_on_flip              Click on flip
```

**New keys to add:** `length_invalid` (placeholders `min`, `max`), `name_required`,
`overwrite_title` ("Overwrite?"), `overwrite_message` (placeholder `name`), `replace`,
`entry_saved` (placeholder `name`), `empty_pool` ("Select at least one character set"),
`entry_deleted` (placeholder `name`), `all_entries_deleted`.

`empty_pool` covers both Class-with-nothing-checked and Manual-with-empty-field: hide the
three action buttons as the legacy did **and** show a SnackBar, so Create doesn't silently
do nothing.

### 2.8 Dimensions

`main_padding` 15dp · `img_button` 40dp · `create_button` 250dp · output text 30sp ·
`coin_view_height` 280dp (360dp on `sw600dp`) · `coin_text_size` 160dp · radio row 34dp
(50dp on `sw600dp`).

### 2.9 Icon

`app/src/main/res/drawable-{ldpi,mdpi,hdpi,xhdpi}/ic_launcher.png`, 36/48/72/96 px — a black
rounded square with white monospace `100101` (a binary string) centered. No vector source
exists in the repo; regenerate from the concept.

---

## 3. Reference: everything the legacy repo contained

Deleted in step A1 but recoverable from git history on this branch's parent:

```
app/src/main/java/com/werebug/randomsequencegenerator/{RSGMain,ShowSaved,ShowSingle,
                                    LaunchCoin,SaveDialog,ConfirmDeleteAllDialog}.java
app/src/main/res/layout/{activity_rsg_main,activity_show_saved,activity_show_single,
                         activity_launch_coin,save_as_dialog}.xml
app/src/main/res/layout-sw600dp/{activity_rsg_main,activity_launch_coin}.xml
app/src/main/res/values/{strings,colors,styles,dimens}.xml
app/src/main/res/values-v11/styles.xml   values-sw600dp/dimens.xml
app/src/main/res/menu/{activity_main,activity_show_saved,show_saved_conmenu}.xml
app/src/main/res/drawable-*/{ic_launcher,ic_menu_save,ic_menu_share,ic_menu_copy_holo_dark,
                             ic_action_search}.png
app/src/main/AndroidManifest.xml   app/build.gradle   app/lint.xml
build.gradle  settings.gradle  gradle/wrapper/  gradlew  gradlew.bat  import-summary.txt
.idea/  RandomSequenceGenerator.iml  .gitignore
```

Dead weight confirmed and *not* worth porting: `save_as_dialog.xml` (never inflated),
`ic_action_search.png` (never referenced), `activity_horizontal_margin` /
`activity_vertical_margin` dimens (never referenced), `proguard-rules.txt` (referenced by
`build.gradle` but absent), and the `xmlns:ads=…` namespace declaration still sitting on the
root element of all six layouts.

Italian/Spanish/French translations existed and were deleted in commit `258f050` (Jan 2013).
Their string names no longer match today's keys. Not restoring them now — the ARB pipeline
makes adding locales later a drop-in.

---

## 4. Bugs to fix (all confirmed present in the Java)

| # | Legacy defect | Fix |
|---|---|---|
| 1 | `Integer.parseInt` on an unvalidated `numberDecimal` field → crash on empty or `3.5` | `digitsOnly` formatter + `int.tryParse`, range 1–4096, inline error, Create disabled when invalid |
| 2 | `Math.round(Math.random()*lastIndex)` under-weights the first and last pool chars | `Random.nextInt(pool.length)` — uniform |
| 3 | Non-crypto RNG in what is effectively a password generator | `Random.secure()` |
| 4 | Delete hid a *recycled* ListView row instead of removing the model item — the row reappeared on scroll and an unrelated row vanished | Mutate the model, `notifyListeners()` |
| 5 | `getDimension()` returns px but single-arg `setTextSize()` reads sp → the digit rendered at ~480sp and clipped | `fontSize: 160` (Flutter logical px == dp) inside `FittedBox(fit: scaleDown)` |
| 6 | 200dp side margins pushed the buttons off narrow phones; NPE when the intent extra was missing | Centered row with a fixed gap; required non-nullable constructor arg |
| 7 | No rotation state preservation — the result and buttons were lost | State lives in `_MainScreenState`; Flutter keeps `State` across rebuilds, so this is free |
| 8 | Duplicate save name silently overwrote; empty name allowed | Overwrite confirmation dialog; blank name rejected inside the dialog |

Plus: the coin `CountDownTimer` captured `findViewById` and outlived `onDestroy`. The Flutter
controller cancels its timer in `dispose()` and the Flip button is disabled mid-flip.

---

## 5. Architecture

Plain `StatefulWidget` + small service classes + one `ChangeNotifier`. **No provider,
riverpod, or bloc** — exactly one piece of state crosses a screen boundary (the saved list);
everything else is local to a single screen's `State`.

The store is constructed in `main()`, passed into `RsgApp`, and exposed through a ~10-line
`InheritedNotifier<SavedStore>` (`SavedStoreScope`) — that is `ChangeNotifierProvider` minus
the dependency. **Not a global singleton**, so widget tests can inject a fake. Services take
an injectable `Random`, and the store takes an injectable `KeyValueStore`, so unit tests are
deterministic and need no plugin mocking at all.

```
lib/
  main.dart                          # WidgetsFlutterBinding, build SavedStore, load(), runApp
  app.dart                           # MaterialApp + theme + l10n delegates + SavedStoreScope
  l10n/app_en.arb                    # all 36 legacy strings + the ~9 new ones
  l10n/generated/                    # gen-l10n output, gitignored
  theme/app_theme.dart               # M3 dark scheme pinned to #333333 + component themes
  theme/dimens.dart                  # mainPadding 15, imgButton 40, createButton 250,
                                     #   outputText 30, coinText 160
  theme/breakpoints.dart             # isTablet(context) == shortestSide >= 600  (Android sw600dp)
  models/generation_mode.dart        # enum {binary, hexadecimal, charClass, manual}
  models/class_selection.dart        # immutable 4-bool value type + copyWith
  models/saved_entry.dart            # {name, sequence, createdAt, mode} + toJson/tryFromJson
  services/char_pools.dart           # the six verbatim constants
  services/sequence_generator.dart   # poolFor(...) + generate(...), injectable Random
  services/key_value_store.dart      # abstract seam + SharedPreferencesAsync impl
  services/saved_store.dart          # ChangeNotifier: load/upsert/deleteByName/deleteAll + codec
  services/coin_flip_controller.dart # ChangeNotifier + Timer.periodic state machine
  services/text_actions.dart         # copyToClipboard / shareText with SnackBar feedback
  state/saved_store_scope.dart       # InheritedNotifier<SavedStore>
  screens/main_screen.dart           # radios, class block, manual field, length, Create,
                                     #   3 actions, output          — bugs 1, 7, 8
  screens/saved_list_screen.dart     # list, empty state, long-press menu, Delete all — bug 4
  screens/show_sequence_screen.dart  # required entry arg, 2 centered buttons, scroll — bug 6
  screens/coin_screen.dart           # coin area, giant digit, Flip button           — bug 5
  widgets/save_as_dialog.dart        # -> Future<String?>, rejects blank names
  widgets/confirm_dialog.dart        # generic yes/no (delete-all, overwrite)
  widgets/length_field.dart          # numeric field + formatters + validation -> int?
  widgets/icon_action_button.dart    # 40dp IconButton with tooltip (also the a11y label
                                     #   the legacy ImageButtons never had)
  widgets/class_range_selector.dart  # 3-across + 1-below checkbox block
  widgets/result_display.dart        # centered 30px white SelectableText, hint when empty

test/
  services/{sequence_generator,saved_store,coin_flip_controller}_test.dart
  widgets/{main,saved_list,show_sequence,coin}_screen_test.dart
  support/fake_key_value_store.dart  # in-memory KeyValueStore
  support/pump_app.dart              # MaterialApp + l10n + theme + SavedStoreScope wrapper

assets/icon/app_icon.png             # 1024x1024 regenerated source
assets/icon/app_icon_foreground.png  # 1024x1024, ~60% width for the adaptive safe zone
tool/generate_icon.py                # Pillow script, checked in for reproducibility
```

### Dependencies and why

| Package | Why |
|---|---|
| `shared_preferences: ^2.5.5` | Decided storage. Cross-platform, no native config |
| `share_plus: ^13.3.0` | The only cross-platform share sheet; maps 1:1 to the legacy `ACTION_SEND` chooser |
| `flutter_localizations` + `intl: ^0.20.3` | The only officially supported ARB pipeline. **`intl` must match the SDK's pin** or gen-l10n breaks — this is the #1 failure mode |
| `flutter_lints: ^6.0.0` (dev) | The ruleset `flutter create` wires up |
| `flutter_launcher_icons: ^0.14.4` (dev) | Density + adaptive icon generation from one 1024px PNG |

No clipboard package — `Clipboard.setData` lives in `flutter/services.dart`.

`l10n.yaml` at the repo root: `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`,
`output-dir: lib/l10n/generated`, `output-localization-file: app_localizations.dart`,
`output-class: AppLocalizations`, `nullable-getter: false`,
`untranslated-messages-file: l10n_untranslated.txt`.

> The synthetic package was **removed** in this SDK and now hard-errors, so `output-dir` must
> be a real directory. `nullable-getter: false` gives `AppLocalizations.of(context).create`
> with no `!`. Gitignore `lib/l10n/generated/` and `l10n_untranslated.txt`.

---

## 6. Implementation sequence

### Checkpoint A — clean slate

1. **Delete from the working tree** (the user handles git; the agent only deletes files):
   ```
   app/  build/  .gradle/  gradle/  .idea/
   build.gradle  settings.gradle  gradlew  gradlew.bat
   local.properties  import-summary.txt  RandomSequenceGenerator.iml  .gitignore
   ```
   Keep `.git/` and **keep `MIGRATION.md`**. Delete *before* `flutter create` — it defaults to
   `--no-overwrite`, so a surviving legacy `.gitignore` or `local.properties` would silently
   persist and break things.

2. ```bash
   cd /home/francesco/MyCloud/Programming/StudioProjects/RandomSequenceGenerator
   /home/francesco/development/flutter/bin/flutter create \
     --project-name random_sequence_generator \
     --org com.werebug \
     --description "Random sequence and password generator" \
     --platforms=android,ios \
     --android-language kotlin \
     --template=app --empty .
   ```
   `--project-name` is **required** — the directory name `RandomSequenceGenerator` is not a
   valid Dart package name and `flutter create .` aborts without it. `--empty` skips the
   counter boilerplate.

3. **Reconcile the applicationId.** `flutter create` derives
   `com.werebug.random_sequence_generator`, which is wrong. There is no flag combination that
   yields both a `random_sequence_generator` Dart package and a `randomsequencegenerator`
   applicationId, so afterwards:
   - set `namespace` **and** `applicationId` in `android/app/build.gradle.kts` to
     `com.werebug.randomsequencegenerator`;
   - move `android/app/src/main/kotlin/com/werebug/random_sequence_generator/MainActivity.kt`
     to `.../com/werebug/randomsequencegenerator/MainActivity.kt`, fix its `package` line,
     delete the empty dir;
   - `grep -rn "random_sequence_generator" android/` must return nothing.
   - `ios/` keeps its generated bundle id; fix in the iOS session.

4. ✅ `flutter analyze` clean; `flutter run -d emulator-5554` launches an empty app.

### Checkpoint B — scaffolding

5. `pubspec.yaml` (`version: 3.0.0+300`, `generate: true`, deps from §5) and `l10n.yaml`;
   `flutter pub get`.
6. `lib/l10n/app_en.arb` — the 36 verbatim strings from §2.7 plus the new keys; `flutter gen-l10n`.
7. `lib/theme/{app_theme,dimens,breakpoints}.dart`.
8. `lib/app.dart` + `lib/main.dart` with a placeholder body.
9. **Android config** in `android/app/build.gradle.kts`:
   ```kotlin
   namespace = "com.werebug.randomsequencegenerator"
   compileSdk = flutter.compileSdkVersion        // 36
   defaultConfig {
       applicationId = "com.werebug.randomsequencegenerator"
       minSdk        = 24                        // literal, NOT flutter.minSdkVersion
       targetSdk     = flutter.targetSdkVersion  // 36
       versionCode   = flutter.versionCode       // 300, from pubspec
       versionName   = flutter.versionName       // "3.0.0"
   }
   ```
   `minSdk = 24` is Flutter 3.44's own floor — going lower is unsupported by the engine, and
   both plugins need ≥21 anyway. Pinned as a literal so a future SDK bump can't silently
   raise the floor.

   **Manifest:** `android:label="RandomSequenceGenerator"` (verbatim `app_name`),
   `android:icon="@mipmap/ic_launcher"`, and **`android:allowBackup="false"` — a deliberate
   change from the legacy `true`**, because the store holds generated secrets in plaintext and
   auto-backup would ship them to Google Drive. Add
   `android/app/src/main/res/xml/data_extraction_rules.xml` excluding `sharedpref` under both
   `<cloud-backup>` and `<device-transfer>`. Keep the template's `MainActivity` `configChanges`
   list — it's what makes rotation a rebuild rather than a recreate. `share_plus` needs no
   extra `<queries>` for the `ACTION_SEND` chooser.

   **Launch background:** replace `@android:color/white` in `drawable/launch_background.xml`,
   `drawable-v21/`, and the `values-night` variant with `#FF333333` to kill the white flash.

10. ✅ `flutter run` shows a `#333333` screen titled "Random Sequence Generator", no white flash.

### Checkpoint C — pure Dart core, test-first

11. `models/`, `char_pools.dart`, `sequence_generator.dart`.
12. `key_value_store.dart`, `saved_store.dart`, `saved_store_scope.dart`.
13. `coin_flip_controller.dart`.
14. All three unit test files + `test/support/fake_key_value_store.dart`.
15. ✅ `flutter test test/services/` green — **bugs 2, 3, 4 and the store half of 8 are
    provably fixed before a single line of UI exists.**

Details that bite:

- `SPECIAL` must be a Dart **raw string**: `r'$%&()=?@#<>_£[]*'`. Unescaped `$` is interpolation.
- `generate` iterates `pool.runes`, not code units, so an emoji pasted into Manual can't be
  split into lone surrogates. `£` (U+00A3) is BMP either way.
- `SavedStore.decode` returns `const []` for null / blank / `not json` / `{}` / `[1,2,3]` /
  `[{"name":"a"}]` rather than throwing.
- **Nothing to migrate from the legacy data.** The old app wrote a SharedPreferences *file*
  named `saved_sequences` with one key per entry name; Flutter's plugin reads a different
  file, so legacy data is invisible by construction. Storage key is `saved_entries_v1`,
  reserving room for a schema bump.
- Ordering: `createdAt` ascending, `name` as a deterministic tiebreak for same-millisecond
  saves. (The legacy order was HashMap iteration order — effectively random.)
- `upsert` replaces in place, preserving position; the **caller** confirms the overwrite first.
- `_commit` sorts, assigns, `notifyListeners()` optimistically, *then* awaits the write.
- Prefer `SharedPreferencesAsync` (the non-deprecated 2.5.x API, DataStore-backed on Android).
  If it misbehaves, the one-line fallback is `(await SharedPreferences.getInstance())` — the
  `KeyValueStore` seam means nothing above it changes.
- `CoinFlipController.flip()` is a no-op while already flipping; the first face renders
  immediately without waiting 200ms; `dispose()` cancels the timer and suppresses further
  notifications.

Sketch of the generator core:
```dart
static String poolFor({required GenerationMode mode,
                       required ClassSelection classes,
                       required String manualText}) => switch (mode) {
      GenerationMode.binary      => CharPools.binary,
      GenerationMode.hexadecimal => CharPools.hex,
      GenerationMode.manual      => manualText,        // verbatim: no trim, no dedup
      GenerationMode.charClass   => [
          if (classes.digits)    CharPools.digit,
          if (classes.lowercase) CharPools.lowercase,
          if (classes.uppercase) CharPools.uppercase,
          if (classes.special)   CharPools.special,
        ].join(),
    };

String generate({required String pool, required int length}) {
  if (pool.isEmpty || length <= 0) return '';
  final codePoints = pool.runes.toList(growable: false);
  final buf = StringBuffer();
  for (var i = 0; i < length; i++) {
    buf.writeCharCode(codePoints[_random.nextInt(codePoints.length)]);  // bugs 2 + 3
  }
  return buf.toString();
}
```

### Checkpoint D — screens

16. `widgets/` first (dialogs, length field, icon button, class selector, result display).
17. `main_screen.dart` — the biggest file; bugs 1, 7, 8.
18. `saved_list_screen.dart` (bug 4 UI), `show_sequence_screen.dart` (bug 6),
    `coin_screen.dart` (bug 5).
19. ✅ Manual pass on the emulator against the checklist in §8.

Layout fidelity:

- The three action buttons go in a `SizedBox(width: 250)` + `Row(spaceBetween)` directly under
  the equally-250dp Create button, so copy/save/share align with Create's left/center/right
  edges *by construction* — matching the legacy `RelativeLayout` alignment.
- Avoid `RadioListTile` (full-width, heavy padding, nothing like the legacy `wrap_content`
  rows). Use `Row(mainAxisSize: min)` of `Radio` + tappable `Text` inside a
  `SizedBox(height: isTablet ? 50 : 34)`.
- `ClassRangeSelector` is the **one** place that needs a `LayoutBuilder`: fall back to a `Wrap`
  when three labels can't fit across, rather than letting `[A–Z]` overflow.
- Show Sequences replaces the legacy 200dp side margins with a centered row + a ~48dp gap
  (bug 6, layout half).
- Everywhere else use `Breakpoints.isTablet(context)` for the only two real `sw600dp` deltas —
  coin area 280→360 and radio row 34→50. **Do not build two widget trees.** Use
  `MediaQuery.sizeOf(context)`, not `MediaQuery.of`.
- Root of Main is `SingleChildScrollView(padding: EdgeInsets.all(15))`.
- Output is a `SelectableText`, `TextAlign.center`, `fontSize: 30` — selectable is a small win
  over the legacy read-only `TextView`.
- Coin digit: `FittedBox(fit: BoxFit.scaleDown, child: Text(..., fontSize: 160, height: 1.0))`
  inside the fixed-height area, so it renders giant but can never overflow.
- Navigate with a typed `MaterialPageRoute(builder: (_) => ShowSequenceScreen(entry: entry))`,
  **not** named routes with `settings.arguments as String` — the untyped pattern is exactly
  what produced the legacy NPE. This makes `string_notfound` unreachable; keep the ARB key
  (spec says verbatim) or reuse it as the `tryFromJson` failure fallback.
- `if (!mounted) return;` after **every** `await` around a `BuildContext`;
  `use_build_context_synchronously` from `flutter_lints` will flag omissions.
- `shareText` should pass `sharePositionOrigin` from the render box — harmless on Android,
  saves work in the iPad session later.

Theming: `ColorScheme.fromSeed(seedColor: Color(0xFF33B5E5) /* the Holo accent the original
inherited */, brightness: Brightness.dark)`, then `copyWith` the neutral roles — **seeding
alone never lands on `#333333`**, it produces `#141218`-ish tonal surfaces. Override
`surface: #333333`, `onSurface: white`, the `surfaceContainer*` ramp (`#2B2B2B` … `#404040`),
`onSurfaceVariant: #CCCCCC`, `outline: #8A8A8A`. Set `surfaceTintColor: Colors.transparent`
and `scrolledUnderElevation: 0` on the AppBar so it doesn't lighten on scroll, and pin the
`dialogTheme` / `popupMenuTheme` backgrounds (M3 otherwise tints them). Radios and checkboxes
need **explicit white unselected fills** — M3's default `onSurfaceVariant` is too dim on
`#333333`; use `VisualDensity.compact` on the checkboxes to keep three across on a phone.
`Typography.whiteMountainView` for the text theme. Pass the same theme to both `theme:` and
`darkTheme:` with `themeMode: ThemeMode.dark` — the app is dark-only regardless of system setting.

### Checkpoint E — widget tests

20. `test/support/pump_app.dart` (supplies l10n delegates, the dark theme, and a
    `SavedStoreScope` over a fake-backed store), then the four screen test files.
21. ✅ `flutter test` fully green.

### Checkpoint F — icon and polish

22. `tool/generate_icon.py` with Pillow: 1024×1024 RGBA,
    `rounded_rectangle([0,0,1023,1023], radius=180, fill=black)`, DejaVu Sans Mono **Bold**,
    font size binary-searched so `draw.textbbox` width of `"100101"` lands at ~78% of 1024,
    centered via the bbox offsets (`textsize` was removed in Pillow 10). Second pass writes
    `app_icon_foreground.png` — same digits, transparent background, ~60% width, to survive
    the adaptive-icon 66% safe-zone circular mask.
23. `dart run flutter_launcher_icons` (`ios: false` for now — flip it in the iOS session).
24. `.gitignore` additions: `lib/l10n/generated/`, `l10n_untranslated.txt`.
25. Rotate every screen; check the tablet layout on a 600dp+ emulator profile.
26. ✅ `flutter build apk --release` succeeds; install and smoke-test.

---

## 7. Tests to write

**`sequence_generator_test.dart`** — pool composition per mode against the verbatim constants;
a table-driven test over all 16 `ClassSelection` combinations asserting DIGIT→LAZ→CAZ→SPECIAL
order; manual pool taken verbatim (`'  aab  '` stays `'  aab  '`); length honored at 1, 32,
4096; every output rune is in the pool; empty pool and non-positive length return `''` without
throwing; **uniformity regression for bug 2** — with `Random(42)` and the hex pool, generate
160 000 chars and assert each of the 16 symbols lands within ±4% of 10 000; surrogate pairs
(`'🙂🙃'`, length 10 → `runes.length == 10`, no lone surrogates).

**`saved_store_test.dart`** (against `FakeKeyValueStore`) — `decode` resilience against `null`,
`''`, `'   '`, `'not json'`, `'{}'`, `'[1,2,3]'`, `'[{"name":"a"}]'` → all `[]`, no throw;
JSON round-trip preserving `createdAt` to the millisecond and `mode`; overwrite keeps length 1
and position; **delete-the-middle-of-three leaves the right survivors (bug 4 — the test the
legacy code would fail)**; `deleteAll` persists `'[]'`; stable ordering including the
same-timestamp name tiebreak; `containsName`; `notifyListeners` fires exactly once per mutation.

**`coin_flip_controller_test.dart`** (with `fake_async`, available transitively via
`flutter_test`) — initial `face == null`; `flip()` renders face 0 immediately; tick count
always in `[10,30]` across several seeds; `0,1,0,1,…` alternation; final value matches the
up-front `nextInt(2)` decision; `flip()` mid-flip is a no-op; **after `dispose()`,
`async.pendingTimers` is empty and no post-dispose notification fires**.

**Widget tests** — Binary preselected with both conditional blocks absent; each radio reveals
the right block; length defaults to `32`; Create with defaults yields 32 chars all in `01` and
reveals the three buttons; **bug 1** — empty / `abc` / `0` / `4097` each show the error with
Create disabled, `64` clears it; **bug 7** — generate, resize `tester.view.physicalSize` to
landscape, the same result and buttons survive; Class with nothing checked shows `empty_pool`
and keeps the buttons hidden; copy records `Clipboard.setData` via the platform channel mock;
**bug 8** — saving `x` twice raises the overwrite dialog, Cancel keeps the first sequence and
Replace swaps it, blank names are rejected; AppBar items push the right screens; empty saved
list shows `No saved entries`; **bug 4** — long-press row 2 → Delete leaves rows 1 and 3
correctly labelled; `Delete all` on an empty list shows the SnackBar and **no dialog**;
**bug 6** — at 320×640 both Show Sequences buttons are fully inside the viewport
(`getRect(copy).left >= 0`, `getRect(share).right <= 320`); coin starts on `Click on flip`,
disables Flip while running, and re-enables after — drive with explicit
`tester.pump(Duration(milliseconds: 200))` in a loop, since **`pumpAndSettle` never terminates
on a periodic timer**; unmounting mid-flip must not trip "Timer still pending".

---

## 8. Verification

```bash
export PATH=/home/francesco/development/flutter/bin:$PATH
cd /home/francesco/MyCloud/Programming/StudioProjects/RandomSequenceGenerator

flutter pub get
flutter gen-l10n                                    # l10n_untranslated.txt should be empty
flutter analyze                                     # must be "No issues found!"
dart format --output=none --set-exit-if-changed .   # exit 0
flutter test
flutter run -d emulator-5554                        # THE run command on this machine
flutter build apk --release
```

Post-build assertions:
```bash
grep -rn "applicationId\|namespace" android/app/build.gradle.kts   # both com.werebug.randomsequencegenerator
grep -rn "random_sequence_generator" android/                      # no matches
aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk | head -3
#   -> package name='com.werebug.randomsequencegenerator' versionCode='300' versionName='3.0.0'
file android/app/src/main/res/mipmap-*/ic_launcher.png             # 48/72/96/144/192 px
grep -rnE "Text\('|Text\(\"" lib/screens lib/widgets | grep -v AppLocalizations
#   -> only the coin digit interpolation
```

Manual checklist on the emulator — one line per fixed bug:

| Steps | Expected |
|---|---|
| Clear Length; try `3.5`, `0`, `9999` | Inline error each time, Create disabled, **no crash** |
| Hex, length 4096, Create | No visible skew toward `0`/`F` |
| Save 3 entries, long-press the middle → Delete, scroll, leave and return | Middle gone permanently; the other two intact and correctly labelled |
| Coin → Flip, portrait and landscape, phone and tablet profile | Giant digit fully visible, never clipped |
| Saved → tap an entry on a 320dp-wide profile | Both icon buttons on screen and tappable |
| Generate, rotate to landscape and back | Same sequence, three buttons still visible |
| Save as `foo`; save a new sequence as `foo` | Overwrite dialog; Cancel keeps the old, Replace swaps it; blank name rejected |
| Class mode, uncheck everything, Create | `Select at least one character set`, buttons stay hidden |
| Share from Main, Saved long-press, and Show Sequences | Android share sheet with the correct plain text each time |
| Delete all on an empty list | `There are no saved entries.`, no dialog |
| Kill and relaunch | Saved list intact and in the same order |

---

## 9. Progress tracker

**Implementation complete — all six checkpoints landed on 2026-07-28.**

- [x] **A** — legacy files deleted, `flutter create` run, applicationId reconciled, empty app runs
- [x] **B** — pubspec, l10n.yaml, ARB, theme, app/main shells, Android config, launch background
- [x] **C** — models + services + store + coin controller, unit tests green
- [x] **D** — widgets + all four screens
- [x] **E** — widget tests green
- [x] **F** — icon regenerated, gitignore, tablet/rotation pass, release APK

Final state: 66 tests green, `flutter analyze` clean, `dart format` clean,
`app-release.apk` built and smoke-tested on `emulator-5554`
(`com.werebug.randomsequencegenerator`, versionCode 300, versionName 3.0.0,
minSdk 24, targetSdk 36).

### Deviations from the plan, and why

- **`intl` is pinned to `^0.20.2`, not `^0.20.3`.** `flutter_localizations` in
  Flutter 3.44.8 pins `intl 0.20.2` exactly, so `^0.20.3` fails to resolve. This
  is the failure mode §5 warned about; the constraint cannot go higher.
- **`fake_async` is a declared dev dependency.** It does reach the tests
  transitively through `flutter_test`, but `depend_on_referenced_packages`
  (from `flutter_lints`) requires it to be declared for `flutter analyze` to
  pass.
- **The launch background is a `@color/launch_background` resource, not an
  inline `#FF333333`.** There is no `values-night/launch_background.xml` in this
  template; the day variant used `@android:color/white` and the v21 variant used
  `?android:colorBackground`, which resolves to white under the light launch
  theme. Both `LaunchTheme` and `NormalTheme` now inherit
  `Theme.Black.NoTitleBar` in `values/` and `values-night/` alike, so the app is
  dark from the first frame regardless of the system setting.
- **The mode radio group uses `RadioGroup<GenerationMode>`.** Per-`Radio`
  `groupValue`/`onChanged` are deprecated in this SDK.
- **`string_notfound` is retained but unreachable**, as §6 anticipated: typed
  route arguments make the missing-extra case impossible.

### Open items deferred to later sessions

- **iOS**: `ios/` is generated but unconfigured. Set the bundle id to match, flip
  `flutter_launcher_icons: ios: true`, verify `share_plus` `sharePositionOrigin` on iPad.
- **Restoring it/es/fr**: the ARB pipeline makes this a drop-in; historical translations are in
  commit `258f050^` but their keys no longer match.
- **Android process-death restoration**: rotation is handled, but a killed-and-restored process
  loses the un-saved current result. If wanted, add `RestorationMixin` + `RestorableString` to
  `_MainScreenState` — not a reason to adopt a state framework.
