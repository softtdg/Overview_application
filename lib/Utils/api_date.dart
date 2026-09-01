import 'package:intl/intl.dart' hide TextDirection;

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

  /// ISO, slash, and dash date strings (e.g. `2025-08-14`, `08/14/2025`).
  static DateTime? parseFlexible(dynamic raw) {
    final parsed = parse(raw);
    if (parsed != null) return parsed;

    var text = raw?.toString().trim() ?? '';
    if (text.isEmpty ||
        text == '-' ||
        text == '*' ||
        text.toLowerCase() == 'null' ||
        text.startsWith('0001-01-01')) {
      return null;
    }

    // Drop any time suffix: `08/14/2025 3:45 PM` → `08/14/2025`
    text = text.split(RegExp(r'\s+')).first;

    final match = RegExp(
      r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$',
    ).firstMatch(text);
    if (match == null) return null;

    final a = int.tryParse(match.group(1)!);
    final b = int.tryParse(match.group(2)!);
    var year = int.tryParse(match.group(3)!);
    if (a == null || b == null || year == null) return null;
    if (year < 100) year += 2000;

    if (a > 12 && b <= 12) {
      return DateTime(year, b, a);
    }
    if (b > 12 && a <= 12) {
      return DateTime(year, a, b);
    }
    return DateTime(year, a, b);
  }

  static String formatMmDdYyyy(dynamic raw, {String empty = '*'}) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty || text == '-') return empty;
    if (text.startsWith('0001-01-01')) return empty;

    final parsed = parseFlexible(raw);
    if (parsed == null) return empty;

    try {
      return DateFormat('MM/dd/yyyy').format(parsed.toLocal());
    } catch (_) {
      return empty;
    }
  }

  static String formatMmDdYyyyTime(dynamic raw, {String empty = '*'}) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return empty;
    if (text.startsWith('0001-01-01')) return empty;

    final parsed = parse(raw) ?? parseFlexible(raw);
    if (parsed == null) return empty;

    try {
      return DateFormat('MM/dd/yyyy hh:mm a').format(parsed.toLocal());
    } catch (_) {
      return empty;
    }
  }

  /// e.g. `08/07/2026 11:23:49 AM`
  static String formatMmDdYyyyDateTime(dynamic raw, {String empty = '*'}) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty || text == '-') return empty;
    if (text.startsWith('0001-01-01')) return empty;

    final parsed = parse(raw) ?? parseFlexible(raw);
    if (parsed == null) return empty;

    try {
      return DateFormat('MM/dd/yyyy hh:mm:ss a').format(parsed.toLocal());
    } catch (_) {
      return empty;
    }
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
