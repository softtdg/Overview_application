import 'package:flutter/material.dart';
import 'package:overview_app/Screen/InventoryPickedLog/InventoryPickedLog.dart';
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
      iconTheme: const IconThemeData(color: Colors.white),

      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset('assets/images/tdg_logo.png', height: 35),

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
                      nav.push(
                        MaterialPageRoute(builder: (_) => SOPSearch()),
                      );
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
                          MaterialPageRoute(builder: (_)=> InventoryPickedLog())
                      );
                    },
                  )
              ],
            ),
          ),
        ],
      ),
    ));
  }
}
