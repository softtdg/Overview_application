import 'package:flutter/material.dart';

/// Reusable pager: first · prev · page numbers (with …) · next · last.
///
/// [currentPage] and [totalPages] are **1-based**. [totalPages] must be >= 1.
/// Parent is responsible for hiding when there is no data.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.buttonSize = 40,
    this.selectedColor = const Color.fromARGB(255, 57, 73, 95),
    this.iconColorEnabled,
    this.iconColorDisabled,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final double buttonSize;
  final Color selectedColor;
  final Color? iconColorEnabled;
  final Color? iconColorDisabled;

  static List<int?> _pageNumbersToShow(int current, int last) {
    if (last <= 7) {
      return List<int?>.generate(last, (i) => i + 1);
    }
    if (current <= 3) {
      return [1, 2, 3, null, last];
    }
    if (current >= last - 2) {
      return [1, null, last - 2, last - 1, last];
    }
    return [1, null, current - 1, current, current + 1, null, last];
  }

  @override
  Widget build(BuildContext context) {
    final last = totalPages < 1 ? 1 : totalPages;
    final c = currentPage.clamp(1, last);
    final canBack = c > 1;
    final canFwd = c < last;
    final iconOn = iconColorEnabled ?? Colors.grey.shade800;
    final iconOff = iconColorDisabled ?? Colors.grey.shade400;

    Widget iconBtn({required IconData icon, required VoidCallback? onTap}) {
      final enabled = onTap != null;
      return SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Icon(icon, size: 22, color: enabled ? iconOn : iconOff),
          ),
        ),
      );
    }

    Widget numberBtn(int page) {
      final selected = page == c;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: Material(
            color: selected ? selectedColor : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: selected ? selectedColor : Colors.grey.shade300,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: selected ? null : () => onPageChanged(page),
              child: Center(
                child: Text(
                  '$page',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: selected ? Colors.white : Colors.grey.shade800,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final pages = _pageNumbersToShow(c, last);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconBtn(
            icon: Icons.first_page,
            onTap: canBack ? () => onPageChanged(1) : null,
          ),
          const SizedBox(width: 8),
          iconBtn(
            icon: Icons.chevron_left,
            onTap: canBack ? () => onPageChanged(c - 1) : null,
          ),
          const SizedBox(width: 8),
          ...pages.expand<Widget>((e) {
            if (e == null) {
              return [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '...',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ];
            }
            return [numberBtn(e)];
          }),
          const SizedBox(width: 8),
          iconBtn(
            icon: Icons.chevron_right,
            onTap: canFwd ? () => onPageChanged(c + 1) : null,
          ),
          const SizedBox(width: 8),
          iconBtn(
            icon: Icons.last_page,
            onTap: canFwd ? () => onPageChanged(last) : null,
          ),
        ],
      ),
    );
  }
}
