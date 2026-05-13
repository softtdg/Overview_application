import 'package:flutter/material.dart';
import 'package:overview_app/Screen/OpenItems/Components/BackOrder.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class Query extends StatefulWidget {
  const Query({
    super.key,
    this.sopLeadHandEntryId,
    this.showRemovedFromSop = false,
  });

  final String? sopLeadHandEntryId;
  final bool showRemovedFromSop;

  @override
  _QueryState createState() => _QueryState();
}

class _QueryState extends State<Query> {
  final String username = 'John Doe';

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(),
      drawer: CommonDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BackOrder(
                sopLeadHandEntryId: widget.sopLeadHandEntryId,
                showNewSearchButton: false,
                showRemovedFromSop: widget.showRemovedFromSop,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
