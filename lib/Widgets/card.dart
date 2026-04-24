import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  final String title;
  final Color color;
  final List<Widget> children;

  const InfoCard({
    required this.title,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Colors.black,
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
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 1,
          child: Text(label, style: TextStyle(color: Colors.black)),
        ),
        SizedBox(width: 20),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.topRight,
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
              softWrap: true,
            ),
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
