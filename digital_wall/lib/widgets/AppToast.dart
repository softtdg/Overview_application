import 'dart:async';

import 'package:flutter/material.dart';

/// App-wide toast: upper-right corner.
/// Success = green banner + check circle.
/// Error = red banner + error circle (short messages only).
class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static const Color successColor = Color(0xFF198754);
  static const Color errorColor = Color(0xFFDC3545);

  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(context, message, isError: false, duration: duration);
  }

  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      _sanitizeUserMessage(message, fallback: 'Something went wrong'),
      isError: true,
      duration: duration,
    );
  }

  static String _sanitizeUserMessage(
    String message, {
    required String fallback,
  }) {
    var text = message.trim();
    if (text.isEmpty) return fallback;
    text = text.replaceFirst(RegExp(r'^Exception:\s*'), '');
    text = text.replaceFirst(RegExp(r'^Error:\s*'), '');
    final lower = text.toLowerCase();
    final technical = lower.contains('exception') ||
        lower.contains('http://') ||
        lower.contains('https://') ||
        text.length > 120;
    if (technical) return fallback;
    return text;
  }

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    hide();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final display = isError
        ? _sanitizeUserMessage(message, fallback: 'Something went wrong')
        : message.trim();
    if (display.isEmpty) return;

    final bg = isError ? errorColor : successColor;
    final icon = isError ? Icons.cancel : Icons.check_circle;

    _entry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          top: MediaQuery.of(ctx).padding.top + 72,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          display,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_entry!);
    _timer = Timer(duration, hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}
