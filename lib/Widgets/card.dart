import 'package:flutter/material.dart';
import 'package:overview_app/Utils/responsive.dart';

class InfoCard extends StatelessWidget {
  final String title;
  final Color color;
  final List<Widget> children;

  /// When true, expands to parent height (use with equal-height tablet rows).
  final bool fillHeight;

  const InfoCard({
    super.key,
    required this.title,
    required this.color,
    required this.children,
    this.fillHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Container(
      width: fillHeight ? double.infinity : null,
      height: fillHeight ? double.infinity : null,
      margin: fillHeight ? EdgeInsets.zero : EdgeInsets.only(bottom: r.cardGap),
      padding: EdgeInsets.all(r.cardPadding),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(r.cardRadius),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Colors.black,
              fontSize: r.cardTitleSize,
            ),
          ),
          SizedBox(height: r.isPhone ? 6 : 10),
          const Divider(color: Color.fromRGBO(143, 146, 149, 1.0)),
          SizedBox(height: r.isPhone ? 4 : 8),
          ...children,
        ],
      ),
    );
  }
}

/// Shown when a field has no data, so a row never renders as a blank gap.
const String kEmptyValue = '\u2014'; // em dash

/// Values the API/formatters use for "nothing here" — all render as [kEmptyValue].
bool _isEmptyValue(String value) {
  final v = value.trim();
  return v.isEmpty || v == '*' || v == '-' || v.toLowerCase() == 'null';
}

Widget infoRow(String label, String value, {BuildContext? context}) {
  return Builder(
    builder: (ctx) {
      final r = Responsive.of(context ?? ctx);
      final fontSize = r.bodyFontSize;
      final isEmpty = _isEmptyValue(value);

      return Padding(
        padding: EdgeInsets.symmetric(vertical: r.rowVerticalPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                // Muted label so the value is what the eye lands on.
                style: TextStyle(color: Colors.black87, fontSize: fontSize),
                softWrap: true,
              ),
            ),
            SizedBox(width: r.isCompactPhone ? 8 : 12),
            Expanded(
              flex: 3,
              child: Text(
                isEmpty ? kEmptyValue : value,
                style: TextStyle(
                  fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                  fontSize: fontSize,
                  color: isEmpty ? Colors.black38 : Colors.black,
                ),
                textAlign: TextAlign.right,
                softWrap: true,
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget divider() {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Divider(color: Colors.grey[400]),
  );
}
