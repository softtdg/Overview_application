import 'package:intl/intl.dart';

/// Shared API date helpers.
///
/// Some backends send years like `0026-07-31` (year 26) instead of `2026-07-31`.
/// [yyyy] then displays as `0026`. We map years 0–99 → 2000–2099.
class ApiDate {
  ApiDate._();

  static DateTime? parse(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty ||
        text == '-' ||
        text == '*' ||
        text.toLowerCase() == 'null') {
      return null;
    }
    if (text.startsWith('0001-01-01')) return null;

    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    if (parsed.year == 1) return null;

    if (parsed.year >= 0 && parsed.year < 100) {
      return DateTime(
        parsed.year + 2000,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      );
    }
    return parsed;
  }

  static String formatDate(dynamic raw, {String empty = '*'}) {
    final parsed = parse(raw);
    if (parsed == null) return empty;
    try {
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return '-';
    }
  }

  static String formatDateTime(dynamic raw, {String empty = '*'}) {
    final parsed = parse(raw);
    if (parsed == null) return empty;
    try {
      return DateFormat('dd/MM/yyyy hh:mm a').format(parsed);
    } catch (_) {
      return '-';
    }
  }
}
