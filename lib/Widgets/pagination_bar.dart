import 'package:flutter/material.dart';

/// Reusable pager: first · prev · page numbers (with …) · next · last.
///
/// [currentPage] and [totalPages] are **1-based**. [totalPages] must be >= 1.
/// Parent is responsible for hiding when there is no data.
///
/// Optional [fromItem]/[toItem]/[totalItems] show a "Showing X to Y of Z results"
/// label (tablet / wide layout puts it on the left; phone stacks above or scrolls).
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.buttonSize,
    this.selectedColor = const Color.fromARGB(255, 57, 73, 95),
    this.iconColorEnabled,
    this.iconColorDisabled,
    this.fromItem,
    this.toItem,
    this.totalItems,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final double? buttonSize;
  final Color selectedColor;
  final Color? iconColorEnabled;
  final Color? iconColorDisabled;
  final int? fromItem;
  final int? toItem;
  final int? totalItems;

  static List<int?> _pageNumbersToShow(
    int current,
    int last, {
    required bool compact,
  }) {
    if (compact) {
      if (last <= 5) {
        return List<int?>.generate(last, (i) => i + 1);
      }
      if (current <= 3) {
        return [1, 2, 3, null, last];
      }
      if (current >= last - 2) {
        return [1, null, last - 2, last - 1, last];
      }
      return [1, null, current, null, last];
    }
    if (last <= 7) {
      return List<int?>.generate(last, (i) => i + 1);
    }
    // Match common table UI: 1 2 3 4 5 … last near the start.
    if (current <= 3) {
      return [1, 2, 3, 4, 5, null, last];
    }
    if (current >= last - 2) {
      return [1, null, last - 2, last - 1, last];
    }
    return [1, null, current - 1, current, current + 1, null, last];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 700;
    final size = buttonSize ?? (isNarrow ? 32.0 : 36.0);
    final gap = isNarrow ? 4.0 : 8.0;

    final last = totalPages < 1 ? 1 : totalPages;
    final c = currentPage.clamp(1, last);
    final canBack = c > 1;
    final canFwd = c < last;
    final iconOn = iconColorEnabled ?? Colors.grey.shade800;
    final iconOff = iconColorDisabled ?? Colors.grey.shade400;

    final hasSummary =
        fromItem != null && toItem != null && totalItems != null;

    Widget iconBtn({required IconData icon, required VoidCallback? onTap}) {
      final enabled = onTap != null;
      return SizedBox(
        width: size,
        height: size,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Icon(
              icon,
              size: isNarrow ? 18 : 20,
              color: enabled ? iconOn : iconOff,
            ),
          ),
        ),
      );
    }

    Widget numberBtn(int page) {
      final selected = page == c;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: isNarrow ? 2 : 3),
        child: SizedBox(
          width: size,
          height: size,
          child: Material(
            color: selected ? selectedColor : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(
                color: selected ? selectedColor : Colors.grey.shade300,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: selected ? null : () => onPageChanged(page),
              child: Center(
                child: Text(
                  '$page',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isNarrow ? 12 : 13,
                    color: selected ? Colors.white : Colors.grey.shade800,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final pages = _pageNumbersToShow(c, last, compact: isNarrow);

    final pagerRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isNarrow) ...[
          iconBtn(
            icon: Icons.first_page,
            onTap: canBack ? () => onPageChanged(1) : null,
          ),
          SizedBox(width: gap),
        ],
        iconBtn(
          icon: Icons.chevron_left,
          onTap: canBack ? () => onPageChanged(c - 1) : null,
        ),
        SizedBox(width: gap),
        ...pages.expand<Widget>((e) {
          if (e == null) {
            return [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isNarrow ? 4 : 6),
                child: Text(
                  '...',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: isNarrow ? 12 : 14,
                  ),
                ),
              ),
            ];
          }
          return [numberBtn(e)];
        }),
        SizedBox(width: gap),
        iconBtn(
          icon: Icons.chevron_right,
          onTap: canFwd ? () => onPageChanged(c + 1) : null,
        ),
        if (!isNarrow) ...[
          SizedBox(width: gap),
          iconBtn(
            icon: Icons.last_page,
            onTap: canFwd ? () => onPageChanged(last) : null,
          ),
        ],
      ],
    );

    Widget buildScrollablePager({required bool centerWhenFits}) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final child = centerWhenFits
              ? ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: pagerRow.children,
                  ),
                )
              : pagerRow;

          return ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            ),
          );
        },
      );
    }

    final summary = hasSummary
        ? Text(
            'Showing $fromItem to $toItem of $totalItems results',
            textAlign: isNarrow ? TextAlign.center : TextAlign.left,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: isNarrow ? 12 : 14,
            ),
          )
        : null;

    // Tablet / wide: summary left, pager right.
    if (!isNarrow) {
      return Row(
        children: [
          if (summary != null)
            Expanded(child: summary)
          else
            const Spacer(),
          const SizedBox(width: 12),
          buildScrollablePager(centerWhenFits: false),
        ],
      );
    }

    // Phone: summary and pager both centered; scale pager down if needed.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (summary != null) ...[
          summary,
          const SizedBox(height: 8),
        ],
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: pagerRow,
        ),
      ],
    );
  }
}
