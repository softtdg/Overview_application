import 'package:flutter/material.dart';
import 'package:overview_app/Screen/Login/login.dart';
import 'package:overview_app/Screen/OpenItems/Components/BackOrder.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  void _showLogoutConfirmDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token');
              await prefs.remove('UserName');
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => LoginPage()),
                (route) => false,
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(),
      drawer: CommonDrawer(
        username: username,
        onLogout: _showLogoutConfirmDialog,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showRemovedFromSop)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: const Text(
                    'REMOVED FROM SOP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFB71C1C),
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
              BackOrder(
                sopLeadHandEntryId: widget.sopLeadHandEntryId,
                showNewSearchButton: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
