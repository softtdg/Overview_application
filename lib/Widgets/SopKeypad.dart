import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// In-app numeric keypad for SOP numbers (e.g. 70264, 73635A).
///
/// The SOP format is digits with an optional trailing letter, so the system
/// QWERTY keyboard wastes space and slows entry. Pair this with a TextField
/// using [KeypadInput.keyboardType] so the OS keyboard never opens.
class SopKeypad extends StatelessWidget {
  const SopKeypad({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.onClose,
    this.suffixKeys = const ['A', 'B'],
    this.submitLabel = 'Search',
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  /// Hides the keypad (unfocuses the field). Null hides the close button.
  final VoidCallback? onClose;

  /// Letter keys shown down the right edge. Use lowercase here if the
  /// backend lookup is case sensitive.
  final List<String> suffixKeys;

  final String submitLabel;

  static const int _rows = 4;
  static const double _rowGap = 6;
  static const double _closeButtonRow = 40;

  /// Widest the pad gets. Stretched across a tablet, a 3-column pad turns
  /// every key into an unusable ~400pt-wide bar.
  static const double _maxPadWidth = 400;

  static double _keyHeight(bool isPhone) => isPhone ? 52 : 60;

  /// Height the keypad occupies, so callers can pad content out from under it.
  static double heightFor(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 600;
    // Phone is a full-bleed bar; tablet floats a card with outer margin.
    final chromeHeight = isPhone ? 6.0 + 8.0 : 8.0 + 12.0 + (10.0 * 2);
    return (_keyHeight(isPhone) + _rowGap) * _rows +
        chromeHeight +
        _closeButtonRow +
        MediaQuery.paddingOf(context).bottom;
  }

  /// True on the platforms where a system keyboard would otherwise pop up.
  static bool get isTouchPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // --- Text editing -------------------------------------------------------

  /// Replaces the current selection (or inserts at the caret) with [text].
  void _insert(String text) {
    final value = controller.value;
    final selection = value.selection;

    // A never-focused controller has an invalid selection; append instead.
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
  void _backspace() {
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

  void _clear() {
    controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
  }

  // --- Layout -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 600;
    final keyHeight = _keyHeight(isPhone);
    final fontSize = isPhone ? 22.0 : 24.0;

    final letters = suffixKeys.take(2).toList();

    final pad = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onClose != null)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: onClose,
              visualDensity: VisualDensity.compact,
              tooltip: 'Hide keypad',
              icon: const Icon(Icons.keyboard_hide_outlined, size: 20),
            ),
          ),
        _row(keyHeight, fontSize, [
          _digit('1'),
          _digit('2'),
          _digit('3'),
          _action(
            icon: Icons.backspace_outlined,
            onTap: _backspace,
            onLongPress: _clear,
            color: const Color(0xFFD7DCE3),
          ),
        ]),
        _row(keyHeight, fontSize, [
          _digit('4'),
          _digit('5'),
          _digit('6'),
          if (letters.isNotEmpty)
            _digit(letters[0], color: const Color(0xFFD7DCE3))
          else
            const _KeySpec.blank(),
        ]),
        _row(keyHeight, fontSize, [
          _digit('7'),
          _digit('8'),
          _digit('9'),
          if (letters.length > 1)
            _digit(letters[1], color: const Color(0xFFD7DCE3))
          else
            const _KeySpec.blank(),
        ]),
        _row(keyHeight, fontSize, [
          _action(
            label: 'Clear',
            onTap: _clear,
            color: const Color(0xFFD7DCE3),
            labelSize: isPhone ? 15 : 17,
          ),
          _digit('0'),
          _action(
            label: submitLabel,
            icon: Icons.search,
            onTap: onSubmit,
            color: const Color(0xFF1E88E5),
            foreground: Colors.white,
            flex: 2,
            labelSize: isPhone ? 15 : 17,
          ),
        ]),
      ],
    );

    // Phone: full-bleed bar, the way a system keyboard sits.
    if (isPhone) {
      return Material(
        color: const Color(0xFFECEFF3),
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: pad,
          ),
        ),
      );
    }

    // Tablet/desktop: float a compact pad so the keys stay key-shaped.
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxPadWidth),
              child: Material(
                color: const Color(0xFFECEFF3),
                elevation: 12,
                borderRadius: BorderRadius.circular(18),
                child: Padding(padding: const EdgeInsets.all(10), child: pad),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(double height, double fontSize, List<_KeySpec> keys) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (final key in keys)
              Expanded(
                flex: key.flex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: key.build(fontSize),
                ),
              ),
          ],
        ),
      ),
    );
  }

  _KeySpec _digit(String value, {Color? color}) => _KeySpec(
    label: value,
    color: color ?? Colors.white,
    onTap: () => _insert(value),
  );

  _KeySpec _action({
    String? label,
    IconData? icon,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    required Color color,
    Color foreground = const Color(0xFF1F2933),
    int flex = 1,
    double? labelSize,
  }) => _KeySpec(
    label: label,
    icon: icon,
    color: color,
    foreground: foreground,
    onTap: onTap,
    onLongPress: onLongPress,
    flex: flex,
    labelSize: labelSize,
  );
}

class _KeySpec {
  const _KeySpec({
    this.label,
    this.icon,
    this.onTap,
    this.onLongPress,
    this.color = Colors.white,
    this.foreground = const Color(0xFF1F2933),
    this.flex = 1,
    this.labelSize,
  });

  const _KeySpec.blank()
    : label = null,
      icon = null,
      onTap = null,
      onLongPress = null,
      color = Colors.transparent,
      foreground = Colors.transparent,
      flex = 1,
      labelSize = null;

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color color;
  final Color foreground;
  final int flex;
  final double? labelSize;

  Widget build(double fontSize) {
    if (onTap == null) return const SizedBox.shrink();

    final hasBoth = icon != null && label != null;
    final Widget child = hasBoth
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Text(
                label!,
                style: TextStyle(
                  fontSize: labelSize ?? fontSize,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          )
        : icon != null
        ? Icon(icon, size: 22, color: foreground)
        : Text(
            label!,
            style: TextStyle(
              fontSize: labelSize ?? fontSize,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          );

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!.call();
        },
        onLongPress: onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onLongPress!.call();
              },
        child: Center(child: child),
      ),
    );
  }
}

/// TextField settings that keep the OS keyboard closed on touch platforms
/// while leaving the caret visible and tappable.
class KeypadInput {
  const KeypadInput._();

  static TextInputType? keyboardType() =>
      SopKeypad.isTouchPlatform ? TextInputType.none : null;
}
