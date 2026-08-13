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
      margin: fillHeight
          ? EdgeInsets.zero
          : EdgeInsets.only(bottom: r.cardGap),
      padding: EdgeInsets.all(r.cardPadding),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(r.cardRadius),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
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

Widget infoRow(String label, String value, {BuildContext? context}) {
  return Builder(
    builder: (ctx) {
      final r = Responsive.of(context ?? ctx);
      final fontSize = r.bodyFontSize;

      return Padding(
        padding: EdgeInsets.symmetric(vertical: r.rowVerticalPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: TextStyle(color: Colors.black, fontSize: fontSize),
                softWrap: true,
              ),
            ),
            SizedBox(width: r.isCompactPhone ? 8 : 12),
            Expanded(
              flex: 3,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
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
