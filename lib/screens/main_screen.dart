import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/class_selection.dart';
import '../models/generation_mode.dart';
import '../models/mask_pattern.dart';
import '../models/saved_entry.dart';
import '../models/uuid_options.dart';
import '../services/sequence_generator.dart';
import '../services/text_actions.dart';
import '../state/saved_store_scope.dart';
import '../theme/dimens.dart';
import '../widgets/class_range_selector.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/icon_action_button.dart';
import '../widgets/length_field.dart';
import '../widgets/mask_field.dart';
import '../widgets/mask_legend.dart';
import '../widgets/mode_selector.dart';
import '../widgets/result_display.dart';
import '../widgets/save_as_dialog.dart';
import '../widgets/section_header.dart';
import '../widgets/uuid_options_selector.dart';
import 'coin_screen.dart';
import 'saved_list_screen.dart';

/// The generator screen.
///
/// All of its state lives here in [State], which Flutter keeps across the
/// rebuild a rotation triggers — so the result and the action buttons survive
/// it, which the legacy activity did not manage (bug 7).
class MainScreen extends StatefulWidget {
  const MainScreen({this.generator, super.key});

  /// Injectable so a widget test can make generation deterministic.
  final SequenceGenerator? generator;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final SequenceGenerator _generator =
      widget.generator ?? SequenceGenerator();

  final TextEditingController _manualController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _maskController = TextEditingController();

  GenerationMode _mode = GenerationMode.binary;
  ClassSelection _classes = ClassSelection.none;
  UuidOptions _uuidOptions = UuidOptions.defaults;
  bool _lengthTouched = false;
  bool _maskTouched = false;

  /// The sequence on screen and the mode that produced it, or null before the
  /// first successful generation.
  ///
  /// The two travel together because the result outlives a mode change: the
  /// radio can move after Create, and a save must still record where the
  /// sequence actually came from rather than whatever is selected by then.
  ({String text, GenerationMode mode})? _result;

  @override
  void initState() {
    super.initState();
    _lengthController.text = _defaultLength;
  }

  // The length the app starts with. A string because that is what the field
  // holds, and a plain const rather than an ARB key: a default is not
  // translatable content.
  static const String _defaultLength = '32';

  @override
  void dispose() {
    _manualController.dispose();
    _lengthController.dispose();
    _maskController.dispose();
    super.dispose();
  }

  int? get _length => LengthField.parse(_lengthController.text);

  bool get _lengthHasError => _lengthTouched && _length == null;

  MaskPattern get _maskPattern => MaskPattern.parse(_maskController.text);

  /// The modes without a length must not be held back by a stale unusable value
  /// left behind in the hidden field.
  bool get _canCreate => switch (_mode) {
    GenerationMode.uuid => true,
    GenerationMode.mask => _maskPattern.isValid,
    _ => _length != null,
  };

  /// Records [text] as the result, stamped with the mode generating it right
  /// now. Only [_create] calls this, so [_mode] is that mode by construction.
  void _setResult(String text) {
    setState(() => _result = (text: text, mode: _mode));
  }

  void _clearResult() {
    setState(() => _result = null);
  }

  void _create() {
    if (_mode == GenerationMode.uuid) {
      _setResult(_generator.generateUuid(_uuidOptions));
      return;
    }

    if (_mode == GenerationMode.mask) {
      final pattern = _maskPattern;
      // Create is disabled while the mask is unusable, and the field carries the
      // reason — so unlike the empty pool below there is nothing to announce.
      if (!pattern.isValid) return;
      _setResult(_generator.generateFromMask(pattern));
      return;
    }

    final length = _length;
    if (length == null) return;

    final pool = SequenceGenerator.poolFor(
      mode: _mode,
      classes: _classes,
      manualText: _manualController.text,
    );

    if (pool.isEmpty) {
      // The legacy app silently did nothing here and hid the buttons. Hide them
      // the same way, but say why.
      _clearResult();
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).emptyPool)),
        );
      return;
    }

    _setResult(_generator.generate(pool: pool, length: length));
  }

  Future<void> _save() async {
    final result = _result;
    // Unreachable: the Save button only exists while a result does.
    if (result == null) return;

    final l10n = AppLocalizations.of(context);
    final store = SavedStoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);

    final name = await showSaveAsDialog(context);
    if (name == null) return;
    if (!mounted) return;

    if (store.containsName(name)) {
      final replace = await showConfirmDialog(
        context: context,
        title: l10n.overwriteTitle,
        message: l10n.overwriteMessage(name),
        confirmLabel: l10n.replace,
      );
      if (!replace) return;
      if (!mounted) return;
    }

    final stored = await store.upsert(
      SavedEntry(
        name: name,
        sequence: result.text,
        createdAt: DateTime.now(),
        // The mode that generated this sequence, not the one selected now.
        mode: result.mode,
      ),
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(stored ? l10n.entrySaved(name) : l10n.changeNotStored),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = _result;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.titleActivityRsgMain),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SavedListScreen()),
            ),
            child: Text(l10n.saved),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const CoinScreen())),
            child: Text(l10n.coin),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Dimens.mainPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(l10n.sectionMode),
            const SizedBox(height: 8),
            ModeSelector(
              mode: _mode,
              onChanged: (mode) => setState(() => _mode = mode),
            ),
            const SizedBox(height: 20),
            SectionHeader(l10n.sectionOptions),
            const SizedBox(height: 8),
            _ModeOptions(
              mode: _mode,
              classes: _classes,
              onClassesChanged: (classes) => setState(() => _classes = classes),
              manualController: _manualController,
              uuidOptions: _uuidOptions,
              onUuidOptionsChanged: (options) =>
                  setState(() => _uuidOptions = options),
              maskController: _maskController,
              // Quiet until the user has typed, like the length field: an empty
              // mask on arrival is not a mistake yet.
              maskError: _maskTouched ? _maskPattern.error : null,
              onMaskChanged: () => setState(() => _maskTouched = true),
              lengthController: _lengthController,
              lengthHasError: _lengthHasError,
              onLengthChanged: () => setState(() => _lengthTouched = true),
            ),
            const SizedBox(height: 20),
            ResultDisplay(text: result?.text ?? ''),
          ],
        ),
      ),
      // Pinned to the bottom rather than sitting in the middle of the content:
      // the screen's primary action stays under the thumb, stays put while the
      // result scrolls, and rides above the keyboard in Manual mode.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Dimens.mainPadding),
          // heightFactor keeps the bar exactly as tall as the button. Without
          // it Center fills the whole Scaffold and leaves the body no height.
          child: Center(
            heightFactor: 1,
            child: SizedBox(
              // Same width as the action buttons above it, so copy, save and
              // share line up with Create's left edge, centre and right edge by
              // construction.
              width: Dimens.createButton,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pinned here above Create rather than in the scrolling body:
                  // the actions stay put while the result scrolls. Hidden until
                  // the first successful generation, and hidden again whenever
                  // the pool comes out empty — as in the legacy screen.
                  if (result != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconActionButton(
                          icon: Icons.content_copy,
                          label: l10n.copy,
                          onPressed: () =>
                              TextActions.copyToClipboard(context, result.text),
                        ),
                        IconActionButton(
                          icon: Icons.save,
                          label: l10n.save,
                          onPressed: _save,
                        ),
                        IconActionButton(
                          icon: Icons.share,
                          label: l10n.send,
                          onPressed: () =>
                              TextActions.shareText(context, result.text),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  ElevatedButton(
                    onPressed: _canCreate ? _create : null,
                    child: Text(l10n.create),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Everything under the Options heading: the controls belonging to [mode].
///
/// One exhaustive switch rather than the `if (_mode == …)` blocks this replaces.
/// The switch has no `default`, so a seventh [GenerationMode] will not compile
/// until its panel is written here — which is the point of gathering them.
///
/// The length row is part of a mode's options too, not a row of its own: Binary
/// and Hexadecimal have only it, UUID and Mask have none. No mode ends up with
/// an empty panel, so the heading above never sits over nothing.
class _ModeOptions extends StatelessWidget {
  const _ModeOptions({
    required this.mode,
    required this.classes,
    required this.onClassesChanged,
    required this.manualController,
    required this.uuidOptions,
    required this.onUuidOptionsChanged,
    required this.maskController,
    required this.maskError,
    required this.onMaskChanged,
    required this.lengthController,
    required this.lengthHasError,
    required this.onLengthChanged,
  });

  final GenerationMode mode;

  final ClassSelection classes;
  final ValueChanged<ClassSelection> onClassesChanged;

  final TextEditingController manualController;

  final UuidOptions uuidOptions;
  final ValueChanged<UuidOptions> onUuidOptionsChanged;

  final TextEditingController maskController;
  final MaskError? maskError;
  final VoidCallback onMaskChanged;

  final TextEditingController lengthController;
  final bool lengthHasError;
  final VoidCallback onLengthChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final controls = switch (mode) {
      GenerationMode.binary || GenerationMode.hexadecimal => const <Widget>[],
      GenerationMode.charClass => [
        ClassRangeSelector(selection: classes, onChanged: onClassesChanged),
      ],
      GenerationMode.manual => [
        TextField(
          controller: manualController,
          decoration: InputDecoration(hintText: l10n.manualHint),
        ),
      ],
      GenerationMode.uuid => [
        UuidOptionsSelector(
          selection: uuidOptions,
          onChanged: onUuidOptionsChanged,
        ),
      ],
      GenerationMode.mask => [
        MaskField(
          controller: maskController,
          error: maskError,
          onChanged: (_) => onMaskChanged(),
        ),
        const SizedBox(height: 8),
        const MaskLegend(),
      ],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...controls,
        if (mode.usesLength) ...[
          if (controls.isNotEmpty) const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.length,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: LengthField(
                  controller: lengthController,
                  hasError: lengthHasError,
                  onChanged: (_) => onLengthChanged(),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
