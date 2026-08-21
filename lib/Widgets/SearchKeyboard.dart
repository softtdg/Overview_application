import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// In-app search keyboard used on Public Search and SOP Search.
///
/// Numeric layout matches the Digital Wall pad (1–9, ABC / 0 / -, backspace,
/// Search). ABC toggles a compact QWERTY pad. Pair with a TextField using
/// [KeypadInput.keyboardType] so the OS keyboard never opens on touch devices.
class SearchKeyboard extends StatelessWidget {
  final bool isNumeric;
  final VoidCallback onToggleMode;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onSearch;

  const SearchKeyboard({
    super.key,
    required this.isNumeric,
    required this.onToggleMode,
    required this.onKey,
    required this.onBackspace,
    required this.onSearch,
  });

  /// True on the platforms where a system keyboard would otherwise pop up.
  static bool get isTouchPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Widest the pad is allowed to get. A 3-column numeric pad stretched
  /// across a tablet turns every key into an unusable ~400pt-wide bar, so it
  /// stays much narrower than the 10-column alpha pad.
  double get _maxPadWidth => isNumeric ? 400 : 780;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isPhone = MediaQuery.sizeOf(context).width < 600;
    final pad = isNumeric ? _buildNumericPad(isPhone) : _buildAlphaPad(isPhone);

    // Phone: full-bleed bar, the way a system keyboard sits.
    if (isPhone) {
      return Material(
        color: const Color(0xFFD1D5DB),
        elevation: 8,
        child: Padding(
          padding: EdgeInsets.fromLTRB(6, 8, 6, 8 + bottomInset),
          child: pad,
        ),
      );
    }

    // Tablet/desktop: float a compact pad so the keys stay key-shaped.
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomInset),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _maxPadWidth),
          child: Material(
            color: const Color(0xFFD1D5DB),
            elevation: 12,
            borderRadius: BorderRadius.circular(18),
            child: Padding(padding: const EdgeInsets.all(10), child: pad),
          ),
        ),
      ),
    );
  }

  Widget _buildNumericPad(bool isPhone) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['ABC', '0', '-'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _keyButton(
                        label: key,
                        isPhone: isPhone,
                        onTap: () {
                          if (key == 'ABC') {
                            onToggleMode();
                          } else {
                            onKey(key);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _keyButton(
                  label: '⌫',
                  isPhone: isPhone,
                  onTap: onBackspace,
                  isAction: true,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _keyButton(
                  label: 'Search',
                  isPhone: isPhone,
                  onTap: onSearch,
                  isPrimary: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlphaPad(bool isPhone) {
    const rows = [
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
      ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _keyButton(
                        label: key,
                        isPhone: isPhone,
                        onTap: () => onKey(key),
                        compact: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _keyButton(
                  label: '123',
                  isPhone: isPhone,
                  onTap: onToggleMode,
                  isAction: true,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _keyButton(
                  label: '-',
                  isPhone: isPhone,
                  onTap: () => onKey('-'),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _keyButton(
                  label: '⌫',
                  isPhone: isPhone,
                  onTap: onBackspace,
                  isAction: true,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _keyButton(
                  label: 'Search',
                  isPhone: isPhone,
                  onTap: onSearch,
                  isPrimary: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keyButton({
    required String label,
    required VoidCallback onTap,
    required bool isPhone,
    bool isAction = false,
    bool isPrimary = false,
    bool compact = false,
  }) {
    final bg = isPrimary
        ? const Color(0xFF1E88E5)
        : isAction
        ? const Color(0xFFB0B7C3)
        : Colors.white;
    final fg = isPrimary ? Colors.white : const Color(0xFF1A1A1A);
    return SizedBox(
      height: compact ? (isPhone ? 40 : 46) : (isPhone ? 48 : 58),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: compact ? (isPhone ? 14 : 17) : (isPhone ? 18 : 22),
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text editing helpers for the in-app [SearchKeyboard].
class SearchKeyboardInput {
  const SearchKeyboardInput._();

  /// Replaces the current selection (or inserts at the caret) with [text].
  static void insert(TextEditingController controller, String text) {
    final value = controller.value;
    final selection = value.selection;

    if (!selection.isValid) {
      final next = value.text + text;
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      return;
    }

    final next =
        selection.textBefore(value.text) +
        text +
        selection.textAfter(value.text);
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: selection.start + text.length),
    );
  }

  /// Deletes the selection, or the character before the caret.
  static void backspace(TextEditingController controller) {
    final value = controller.value;
    final selection = value.selection;

    if (!selection.isValid) {
      if (value.text.isEmpty) return;
      final next = value.text.substring(0, value.text.length - 1);
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      return;
    }

    if (!selection.isCollapsed) {
      final next =
          selection.textBefore(value.text) + selection.textAfter(value.text);
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: selection.start),
      );
      return;
    }

    if (selection.start == 0) return;
    final before = selection.textBefore(value.text);
    final next =
        before.substring(0, before.length - 1) +
        selection.textAfter(value.text);
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: selection.start - 1),
    );
  }
}

/// TextField settings that keep the OS keyboard closed on touch platforms
/// while leaving the caret visible and tappable.
class KeypadInput {
  const KeypadInput._();

  static TextInputType? keyboardType() =>
      SearchKeyboard.isTouchPlatform ? TextInputType.none : null;
}
