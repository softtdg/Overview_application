import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  final String title;
  final Color color;
  final List<Widget> children;
  /// When true, expands to parent height (use with equal-height tablet rows).
  final bool fillHeight;

  const InfoCard({
    required this.title,
    required this.color,
    required this.children,
    this.fillHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fillHeight ? double.infinity : null,
      height: fillHeight ? double.infinity : null,
      margin: fillHeight ? EdgeInsets.zero : EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // Title
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Colors.black,
              fontSize: 16,
            ),
          ),

          SizedBox(height: 10),

          Divider(color: Color.fromRGBO(143, 146, 149, 1.0)),

          SizedBox(height: 8),

          ...children,
        ],
      ),
    );
  }
}

Widget infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(color: Colors.black),
            softWrap: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
            softWrap: true,
          ),
        ),
      ],
    ),
  );
}

Widget divider() {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Divider(color: Colors.grey[400]),
  );
}
