import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// App-wide toast: upper-right corner.
/// Success = green banner + check circle (web-style).
/// Error = red banner + error circle.
///
/// ```dart
/// AppToast.success(context, 'Updated successfully');
/// AppToast.error(context, 'Cannot find the SOP');
/// AppToast.errorFrom(context, e, fallback: 'Something went wrong');
/// ```
class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  /// Matches common web success alert (e.g. Bootstrap).
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

  /// Prefer API short message; never show raw Dio / stack dumps.
  static void errorFrom(
    BuildContext context,
    Object err, {
    String fallback = 'Something went wrong',
    Duration duration = const Duration(seconds: 3),
  }) {
    AppToast.error(
      context,
      friendlyMessage(err, fallback: fallback),
      duration: duration,
    );
  }

  /// Pull a short UI message from Dio / API errors.
  static String friendlyMessage(
    Object? error, {
    String fallback = 'Something went wrong',
  }) {
    final fromDio = _messageFromDio(_asDio(error));
    if (fromDio != null) return fromDio;

    // Wrapped: Exception('…') that still holds a DioException cause.
    if (error is Error && error.stackTrace != null) {
      // no-op; keep scanning toString below
    }

    final raw = error?.toString() ?? '';
    return _sanitizeUserMessage(raw, fallback: fallback);
  }

  static DioException? _asDio(Object? error) {
    if (error is DioException) return error;
    // Some services wrap: Exception('… $e') — original Dio may be lost.
    return null;
  }

  static String? _messageFromDio(DioException? e) {
    if (e == null) return null;
    final data = e.response?.data;
    if (data is Map) {
      for (final key in ['message', 'error', 'msg', 'detail', 'title']) {
        final v = data[key];
        if (v == null) continue;
        final text = v.toString().trim();
        if (text.isNotEmpty && !_isTechnical(text)) return text;
      }
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        final text = errors.first.toString().trim();
        if (text.isNotEmpty && !_isTechnical(text)) return text;
      }
    } else if (data is String) {
      final text = data.trim();
      if (text.isNotEmpty && !_isTechnical(text)) return text;
    }
    return null;
  }

  static String _sanitizeUserMessage(
    String message, {
    required String fallback,
  }) {
    var text = message.trim();
    if (text.isEmpty) return fallback;

    // Strip common Exception prefixes.
    text = text.replaceFirst(RegExp(r'^Exception:\s*'), '');
    text = text.replaceFirst(RegExp(r'^Error:\s*'), '');

    if (_isTechnical(text)) return fallback;

    // Keep toast readable.
    if (text.length > 120) {
      final cut = text.substring(0, 117).trimRight();
      return '$cut…';
    }
    return text;
  }

  static bool _isTechnical(String message) {
    final lower = message.toLowerCase();
    return lower.contains('dioexception') ||
        lower.contains('validatestatus') ||
        lower.contains('requestoptions') ||
        lower.contains('status code of') ||
        lower.contains('developer.mozilla') ||
        lower.contains('socketexception') ||
        lower.contains('http://') ||
        lower.contains('https://') ||
        lower.contains('stack overflow') ||
        lower.contains('#0 ') ||
        message.length > 180;
  }

  /// Dynamic helper — pass [isError] (or use [success] / [error]).
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
