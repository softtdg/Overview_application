import 'package:flutter/material.dart';
import 'package:overview_app/Screen/Backorder/Backorders.dart';
import 'package:overview_app/Screen/ExpediteReport/expediteReport.dart';
import 'package:overview_app/Screen/InventoryPickedLog/InventoryPickedLog.dart';
import 'package:overview_app/Screen/MPF/MPFRequest.dart';
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
import 'package:digital_wall/digital_wall.dart';
import 'package:overview_app/Services/api_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Common AppBar
class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CommonAppBar({
    super.key,
    this.showBackButton = false,
    this.onBackPressed,
  });

  final bool showBackButton;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color.fromARGB(255, 57, 73, 95),
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: 0,
      iconTheme: const IconThemeData(color: Colors.white),

      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              child: Row(
                children: [
                  if (showBackButton) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: 'Back',
                      onPressed: () {
                        if (onBackPressed != null) {
                          onBackPressed!();
                          return;
                        }
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                  // Image.asset(
                  //   'assets/images/tdg_logo.png',
                  //   height: 35,
                  //   fit: BoxFit.contain,
                  //   filterQuality: FilterQuality.high,
                  // ),
                  Builder(
                    builder: (context) {
                      return IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      );
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const Dashboard()),
                      );
                    },
                    child: const Text(
                      'Digital Wall',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Image.asset(
                  //   'assets/images/tdg_logo.png',
                  //   height: 35,
                  //   fit: BoxFit.contain,
                  //   filterQuality: FilterQuality.high,
                  // ),
                  const Spacer(),
                  // TextButton(
                  //   onPressed: () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(builder: (_) => const Dashboard()),
                  //     );
                  //   },
                  //   child: const Text(
                  //     'Digital Wall',
                  //     style: TextStyle(
                  //       color: Colors.white,
                  //       fontWeight: FontWeight.w600,
                  //     ),
                  //   ),
                  // ),
                  // Builder(
                  //   builder: (context) {
                  //     return IconButton(
                  //       icon: const Icon(Icons.menu, color: Colors.white),
                  //       onPressed: () => Scaffold.of(context).openDrawer(),
                  //     );
                  //   },
                  // ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SOPSearch()),
                      );
                    },
                    child: Image.asset(
                      'assets/images/tdg_logo.png',
                      height: 35,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class CommonDrawer extends StatefulWidget {
  const CommonDrawer({super.key});

  static void showLogoutConfirmDialog(BuildContext context) {
    const brand = Color.fromARGB(255, 57, 73, 95);

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: brand.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: brand,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Logout',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Are you sure you want to logout?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF5F6368),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: brand,
                          side: const BorderSide(color: Color(0xFFD0D5DD)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('token');
                          await prefs.remove('UserName');
                          await ApiCache.instance.clear();
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => LoginPage()),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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

  void _go(BuildContext context, Widget page) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => page));
  }

  bool _isActivePage(BuildContext context, Type pageType) {
    var found = false;
    context.visitAncestorElements((element) {
      if (element.widget.runtimeType == pageType) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  Widget _menuItem({
    required String title,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    const activeColor = Color.fromARGB(255, 84, 178, 241);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          splashColor: Colors.white.withOpacity(0.12),
          highlightColor: Colors.white.withOpacity(0.06),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isActive ? Colors.white.withOpacity(0.14) : null,
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? activeColor : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color.fromARGB(255, 57, 73, 95);
    const activeColor = Color(0xFF3498DB);
    final displayName = _userName.isEmpty ? 'User' : _userName;

    final openItemsActive = _isActivePage(context, SearchOpenItems) ||
        _isActivePage(context, CriticalItems) ||
        _isActivePage(context, OpenItems) ||
        _isActivePage(context, Backorders);

    return Drawer(
      backgroundColor: brand,
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.22)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        CommonDrawer.showLogoutConfirmDialog(context),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign out'),
                    style: TextButton.styleFrom(
                      foregroundColor: brand,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                children: [
                  _menuItem(
                    title: 'SOP Search',
                    isActive: _isActivePage(context, SOPSearch),
                    onTap: () => _go(context, SOPSearch()),
                  ),
                  _menuItem(
                    title: 'Public Search',
                    isActive: _isActivePage(context, Publicsearch),
                    onTap: () => _go(context, Publicsearch()),
                  ),
                  _menuItem(
                    title: 'Picked History',
                    isActive: _isActivePage(context, PickedHistory),
                    onTap: () => _go(context, PickedHistory()),
                  ),
                  _menuItem(
                    title: 'Inventory Picked Log',
                    isActive: _isActivePage(context, InventoryPickedLog),
                    onTap: () => _go(context, InventoryPickedLog()),
                  ),
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      splashColor: Colors.white.withOpacity(0.12),
                      expansionTileTheme: ExpansionTileThemeData(
                        iconColor: openItemsActive ? activeColor : Colors.white,
                        collapsedIconColor:
                            openItemsActive ? activeColor : Colors.white70,
                        textColor: openItemsActive ? activeColor : Colors.white,
                        collapsedTextColor:
                            openItemsActive ? activeColor : Colors.white,
                      ),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: openItemsActive,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 22),
                      childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      iconColor: openItemsActive ? activeColor : Colors.white,
                      collapsedIconColor:
                          openItemsActive ? activeColor : Colors.white70,
                      title: Text(
                        'Open Items',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: openItemsActive ? activeColor : Colors.white,
                        ),
                      ),
                      children: [
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(left: 12),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              _menuItem(
                                title: 'Search',
                                isActive:
                                    _isActivePage(context, SearchOpenItems),
                                onTap: () => _go(context, SearchOpenItems()),
                              ),
                              _menuItem(
                                title: 'Critical Items',
                                isActive:
                                    _isActivePage(context, CriticalItems),
                                onTap: () => _go(context, CriticalItems()),
                              ),
                              _menuItem(
                                title: 'Open Items',
                                isActive: _isActivePage(context, OpenItems),
                                onTap: () => _go(context, OpenItems()),
                              ),
                              _menuItem(
                                title: 'Backorders',
                                isActive: _isActivePage(context, Backorders),
                                onTap: () => _go(context, Backorders()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _menuItem(
                    title: 'Shipping In',
                    isActive: _isActivePage(context, ShippingIn),
                    onTap: () => _go(context, ShippingIn()),
                  ),
                  _menuItem(
                    title: 'Shipping Out',
                    isActive: _isActivePage(context, ShippingOut),
                    onTap: () => _go(context, ShippingOut()),
                  ),
                  _menuItem(
                    title: 'Shipping Edit',
                    isActive: _isActivePage(context, ShippingEdit),
                    onTap: () => _go(context, ShippingEdit()),
                  ),
                  _menuItem(
                    title: 'QA In',
                    isActive: _isActivePage(context, QAIn),
                    onTap: () => _go(context, QAIn()),
                  ),
                  _menuItem(
                    title: 'QA Out',
                    isActive: _isActivePage(context, QAOut),
                    onTap: () => _go(context, QAOut()),
                  ),
                  _menuItem(
                    title: 'QA Edit',
                    isActive: _isActivePage(context, QAEdit),
                    onTap: () => _go(context, QAEdit()),
                  ),
                  _menuItem(
                    title: 'MPF',
                    isActive: _isActivePage(context, MPFRequest),
                    onTap: () => _go(context, MPFRequest()),
                  ),
                  _menuItem(
                    title: 'Expedite Report',
                    isActive: _isActivePage(context, ExpediteReport),
                    onTap: () => _go(context, ExpediteReport()),
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