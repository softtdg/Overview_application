import 'package:flutter/material.dart';
import 'package:overview_app/Screen/InventoryPickedLog/InventoryPickedLog.dart';
import 'package:overview_app/Screen/OpenItems/CriticalItems.dart';
import 'package:overview_app/Screen/OpenItems/OpenItems.dart';
import 'package:overview_app/Screen/OpenItems/SearchOpenItems.dart';
import 'package:overview_app/Screen/PickedHistory/PickedHistory.dart';
import 'package:overview_app/Screen/Public-Search/PublicSearch.dart';
import 'package:overview_app/Screen/QAEdit/QAEdit.dart';
import 'package:overview_app/Screen/QAIn/QAIn.dart';
import 'package:overview_app/Screen/QAOut/QAOut.dart';
import 'package:overview_app/Screen/SOPSearch/sopSearch.dart';
import 'package:overview_app/Screen/ShippingEdit/ShippingEdit.dart';
import 'package:overview_app/Screen/ShippingIn/ShippingIn.dart';
import 'package:overview_app/Screen/Login/login.dart';
import 'package:overview_app/Screen/ShippingOut/ShippingOut.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Common AppBar
class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CommonAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color.fromARGB(255, 57, 73, 95),
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: 0,
      iconTheme: const IconThemeData(color: Colors.white),

      title: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            child: Row(
              children: [
                Image.asset('assets/images/tdg_logo.png', height: 35),
                const Spacer(),
                Builder(
                  builder: (context) {
                    return IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class CommonDrawer extends StatefulWidget {
  const CommonDrawer({super.key});

  static void showLogoutConfirmDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        backgroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'No',
              style: TextStyle(color: Color.fromARGB(255, 57, 73, 95)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token');
              await prefs.remove('UserName');
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => LoginPage()),
                (route) => false,
              );
            },
            child: const Text(
              'Yes',
              style: TextStyle(color: Color.fromARGB(255, 57, 73, 95)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  State<CommonDrawer> createState() => _CommonDrawerState();
}

class _CommonDrawerState extends State<CommonDrawer> {
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('UserName') ?? '';
    if (!mounted) return;
    setState(() => _userName = name);
  }

  @override
  Widget build(BuildContext context) {
    const dropdownBg = Color.fromARGB(255, 57, 73, 95);
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                children: [
                  // Logo
                  Image.asset('assets/images/tdg_logo.png', height: 52),

                  const SizedBox(height: 16),

                  //Username
                  Text(
                    _userName.isEmpty ? 'User' : _userName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),

                  const SizedBox(height: 12),

                  //Logout row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Sign out',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded),
                        onPressed: () =>
                            CommonDrawer.showLogoutConfirmDialog(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(),

            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('SOP Search'),
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(MaterialPageRoute(builder: (_) => SOPSearch()));
                    },
                  ),
                  ListTile(
                    title: const Text('Public Search'),
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(
                        MaterialPageRoute(builder: (_) => Publicsearch()),
                      );
                    },
                  ),
                  ListTile(
                    title: const Text('Picked History'),
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(
                        MaterialPageRoute(builder: (_) => PickedHistory()),
                      );
                    },
                  ),
                  ListTile(
                    title: const Text("Inventory Picked Log"),
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(
                        MaterialPageRoute(builder: (_) => InventoryPickedLog()),
                      );
                    },
                  ),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: const Text('Open Items'),
                      childrenPadding: const EdgeInsets.only(bottom: 6),
                      children: [
                        Container(
                          color: dropdownBg,
                          child: ListTile(
                            title: const Text(
                              'Search',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              final nav = Navigator.of(context);
                              nav.pop();
                              nav.push(
                                MaterialPageRoute(
                                  builder: (_) => SearchOpenItems(),
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          color: dropdownBg,
                          child: ListTile(
                            title: const Text(
                              'Critical Items',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              final nav = Navigator.of(context);
                              nav.pop();
                              nav.push(
                                MaterialPageRoute(
                                  builder: (_) => CriticalItems(),
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          color: dropdownBg,
                          child: ListTile(
                            title: const Text(
                              'Open Items',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              final nav = Navigator.of(context);
                              nav.pop();
                              nav.push(
                                MaterialPageRoute(builder: (_) => OpenItems()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    title: const Text("Shipping In"),
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(MaterialPageRoute(builder: (_) => ShippingIn()));
                    },
                  ),
                  ListTile(
                    title: const Text("Shipping Out"),
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(
                        MaterialPageRoute(builder: (_) => ShippingOut()),
                      );
                    },
                  ),
                  ListTile(
                    title: const Text("Shipping Edit"),
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(
                        MaterialPageRoute(builder: (_) => ShippingEdit()),
                      );
                    },
                  ),
                  ListTile(
                    title: const Text("QA In"),
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(MaterialPageRoute(builder: (_) => QAIn()));
                    },
                  ),
                  ListTile(
                    title: const Text("QA Out"),
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(MaterialPageRoute(builder: (_) => QAOut()));
                    },
                  ),
                  ListTile(
                    title: const Text("QA Edit"),
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(MaterialPageRoute(builder: (_) => QAEdit()));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
