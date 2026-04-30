import 'package:flutter/material.dart';
import 'package:overview_app/Screen/OpenItems/CriticalItems.dart';

class OpenItems extends StatelessWidget {
  const OpenItems({super.key});

  @override
  Widget build(BuildContext context) {
    return const CriticalItems(
      useCriticalApi: false,
      pageTitle: 'Open Items',
    );
  }
}
