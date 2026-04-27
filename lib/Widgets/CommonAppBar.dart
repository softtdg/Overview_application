import 'package:flutter/material.dart';
import 'package:overview_app/Screen/InventoryPickedLog/InventoryPickedLog.dart';
import 'package:overview_app/Screen/OpenItems/SearchOpenItems.dart';
import 'package:overview_app/Screen/PickedHistory/PickedHistory.dart';
import 'package:overview_app/Screen/Public-Search/PublicSearch.dart';
import 'package:overview_app/Screen/SOPSearch/sopSearch.dart';

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

class CommonDrawer extends StatelessWidget {
  final String username;
  final VoidCallback onLogout;

  const CommonDrawer({
    super.key,
    required this.username,
    required this.onLogout,
  });

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
                    username.isEmpty ? 'User' : username,
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
                        onPressed: onLogout,
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
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
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
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Critical Items screen not added yet.',
                                  ),
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
                                MaterialPageRoute(
                                  builder: (_) => SearchOpenItems(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
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
