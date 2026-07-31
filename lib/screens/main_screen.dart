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
import '../theme/breakpoints.dart';
import '../theme/dimens.dart';
import '../widgets/class_range_selector.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/icon_action_button.dart';
import '../widgets/length_field.dart';
import '../widgets/mask_field.dart';
import '../widgets/mask_legend.dart';
import '../widgets/result_display.dart';
import '../widgets/save_as_dialog.dart';
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

  // The legacy default_length string resource, kept as a string because that is
  // what the field holds.
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

    await store.upsert(
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
      ..showSnackBar(SnackBar(content: Text(l10n.entrySaved(name))));
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
            _ModeRadioGroup(
              mode: _mode,
              onChanged: (mode) => setState(() => _mode = mode),
            ),
            if (_mode == GenerationMode.charClass) ...[
              const SizedBox(height: 8),
              ClassRangeSelector(
                selection: _classes,
                onChanged: (classes) => setState(() => _classes = classes),
              ),
            ],
            if (_mode == GenerationMode.manual) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _manualController,
                decoration: InputDecoration(hintText: l10n.manualHint),
              ),
            ],
            if (_mode == GenerationMode.uuid) ...[
              const SizedBox(height: 8),
              UuidOptionsSelector(
                selection: _uuidOptions,
                onChanged: (options) => setState(() => _uuidOptions = options),
              ),
            ],
            if (_mode == GenerationMode.mask) ...[
              const SizedBox(height: 8),
              MaskField(
                controller: _maskController,
                // Quiet until the user has typed, like the length field: an
                // empty mask on arrival is not a mistake yet.
                error: _maskTouched ? _maskPattern.error : null,
                onChanged: (_) => setState(() => _maskTouched = true),
              ),
              const SizedBox(height: 8),
              const MaskLegend(),
            ],
            if (_mode.usesLength) ...[
              const SizedBox(height: 16),
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
                      controller: _lengthController,
                      hasError: _lengthHasError,
                      onChanged: (_) => setState(() => _lengthTouched = true),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            ResultDisplay(text: result?.text ?? '', emptyHint: l10n.gotoSaved),
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

/// The vertical radio group, sized to the legacy row heights.
///
/// Deliberately not `RadioListTile`, which is full-width with heavy padding and
/// nothing like the legacy `wrap_content` rows.
class _ModeRadioGroup extends StatelessWidget {
  const _ModeRadioGroup({required this.mode, required this.onChanged});

  final GenerationMode mode;
  final ValueChanged<GenerationMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = {
      GenerationMode.binary: l10n.rBinary,
      GenerationMode.hexadecimal: l10n.rHexadecimal,
      GenerationMode.charClass: l10n.rClass,
      GenerationMode.manual: l10n.rManual,
      GenerationMode.uuid: l10n.rUuid,
      GenerationMode.mask: l10n.rMask,
    };
    final rowHeight = Breakpoints.isTablet(context)
        ? Dimens.radioRowTablet
        : Dimens.radioRow;

    return RadioGroup<GenerationMode>(
      groupValue: mode,
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in labels.entries)
            SizedBox(
              height: rowHeight,
              child: InkWell(
                onTap: () => onChanged(entry.key),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<GenerationMode>(
                      value: entry.key,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 4),
                    Text(entry.value),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
