import 'package:flutter/material.dart';

/// Shared breakpoints and sizing for phone / tablet / desktop layouts.
/// Use across screens so tablets and phones of different widths stay consistent.
class Responsive {
  Responsive._(this.width);

  final double width;

  /// Phones & small phablets.
  static const double phoneMax = 600;

  /// Portrait / smaller tablets stay in the tablet band.
  static const double tabletMax = 1100;

  factory Responsive.of(BuildContext context) {
    return Responsive._(MediaQuery.sizeOf(context).width);
  }

  factory Responsive.fromWidth(double width) => Responsive._(width);

  bool get isPhone => width < phoneMax;

  /// Includes most tablets (incl. landscape ~768–1099).
  bool get isTablet => width >= phoneMax && width < tabletMax;

  /// Wide web / large desktop only.
  bool get isDesktop => width >= tabletMax;

  /// Compact phones (e.g. ~360dp) need tighter padding/fonts.
  bool get isCompactPhone => width < 380;

  /// Mid tablets that used to look oversized with desktop sizing.
  bool get isCompactTablet => isTablet && width < 850;

  /// Card / grid column count for info panels.
  int get cardColumns {
    if (isDesktop) return 3;
    if (isTablet) return 2;
    return 1;
  }

  /// Keep content from stretching too wide on large tablets.
  double get contentMaxWidth {
    if (isDesktop) return 1400;
    if (isTablet) return 960;
    return double.infinity;
  }

  double get pagePaddingH {
    if (isDesktop) return 20;
    if (isTablet) return isCompactTablet ? 14.0 : 16.0;
    return isCompactPhone ? 12 : 16;
  }

  double get pagePaddingV {
    if (isDesktop) return 14;
    if (isTablet) return 12;
    return isCompactPhone ? 10 : 12;
  }

  double get sectionGap {
    if (isDesktop) return 14;
    if (isTablet) return 10;
    return 12;
  }

  double get cardGap {
    if (isDesktop) return 10;
    if (isTablet) return 8;
    return 8;
  }

  double get pageTitleSize {
    if (isDesktop) return 24;
    if (isTablet) return isCompactTablet ? 20.0 : 21.0;
    return isCompactPhone ? 18 : 20;
  }

  double get sectionTitleSize {
    if (isDesktop) return 20;
    if (isTablet) return isCompactTablet ? 17.0 : 18.0;
    return isCompactPhone ? 17 : 18;
  }

  double get cardTitleSize {
    if (isDesktop) return 14;
    if (isTablet) return isCompactTablet ? 12.5 : 13.0;
    return isCompactPhone ? 13 : 14;
  }

  double get bodyFontSize {
    if (isDesktop) return 13;
    if (isTablet) return isCompactTablet ? 11.5 : 12.0;
    return isCompactPhone ? 12 : 13;
  }

  double get cardPadding {
    if (isDesktop) return 12;
    if (isTablet) return isCompactTablet ? 8.0 : 10.0;
    return isCompactPhone ? 10 : 12;
  }

  double get cardRadius {
    if (isDesktop) return 14;
    if (isTablet) return 12;
    return 12;
  }

  double get rowVerticalPadding {
    if (isDesktop) return 4;
    if (isTablet) return isCompactTablet ? 2.5 : 3.5;
    return isCompactPhone ? 3.5 : 4.5;
  }

  double get fieldVerticalPadding {
    if (isDesktop) return 0;
    if (isTablet) return 0;
    return 0;
  }

  double get fieldRadius {
    if (isPhone) return 10;
    return 4;
  }

  bool get useInlineSearchHeader => !isPhone;

  /// Equal-height card rows on tablet and desktop — ragged card bottoms in a
  /// multi-column grid look broken. Phones are single column, so no need.
  bool get stretchCardRows => !isPhone;

  /// Shared height for SOP search field + Search button (keeps them aligned).
  double get searchControlHeight {
    if (isDesktop) return 36;
    if (isTablet) return 36;
    return 44;
  }

  double get searchFieldContentPaddingV {
    if (isDesktop) return 8;
    if (isTablet) return 8;
    return 12;
  }

  double get searchButtonFontSize {
    if (isDesktop) return 13;
    if (isTablet) return 12;
    return 14;
  }

  double get searchButtonHeight => searchControlHeight;

  double get searchIconSize {
    if (isDesktop) return 16;
    if (isTablet) return 16;
    return 18;
  }

  double get searchFieldFontSize {
    if (isDesktop) return 13;
    if (isTablet) return 13;
    return isCompactPhone ? 13 : 14;
  }

  double get searchFieldMaxWidth {
    if (isDesktop) return 360;
    if (isTablet) return isCompactTablet ? 240.0 : 280.0;
    return double.infinity;
  }

  double get searchFieldHeight => searchControlHeight;

  // --- Public Search: SOP cards ---
  // Compact tablet = "perfect" look; large tablet/desktop = smaller text.

  double get sopCardWidth {
    if (isDesktop) return 128;
    if (isTablet) return isCompactTablet ? 150.0 : 135.0;
    return isCompactPhone ? 130.0 : 145.0;
  }

  double get sopCardListHeight {
    if (isDesktop) return 110;
    if (isTablet) return isCompactTablet ? 124.0 : 114.0;
    // Phone needs extra room so Date/Qty don't overflow.
    return isCompactPhone ? 132.0 : 136.0;
  }

  double get sopCardPadding {
    if (isDesktop) return 10;
    if (isTablet) return isCompactTablet ? 12.0 : 10.0;
    return isCompactPhone ? 8.0 : 10.0;
  }

  double get sopCardLabelSize {
    if (isDesktop) return 12;
    if (isTablet) return isCompactTablet ? 14.0 : 12.0;
    return isCompactPhone ? 12.0 : 13.0;
  }

  double get sopCardNumberSize {
    if (isDesktop) return 16;
    if (isTablet) return isCompactTablet ? 18.0 : 16.0;
    return isCompactPhone ? 16.0 : 17.0;
  }

  double get sopCardMetaSize {
    if (isDesktop) return 12;
    if (isTablet) return isCompactTablet ? 14.0 : 12.0;
    return isCompactPhone ? 12.0 : 13.0;
  }

  // --- Public Search: BOM table ---

  double get bomHeaderHeight {
    if (isDesktop) return 34;
    if (isTablet) return isCompactTablet ? 42.0 : 36.0;
    return 40;
  }

  double get bomCellFontSize {
    if (isDesktop) return 12;
    if (isTablet) return isCompactTablet ? 15.0 : 13.0;
    return 14;
  }

  double get bomCellPaddingH {
    if (isDesktop) return 8;
    if (isTablet) return isCompactTablet ? 10.0 : 8.0;
    return 10;
  }

  double get bomCellPaddingV {
    if (isDesktop) return 6;
    if (isTablet) return isCompactTablet ? 10.0 : 7.0;
    return 9;
  }

  /// Base column widths: TDGPN, Desc, Material, Qty/Size/UOM, State, Vendor, FileName.
  List<double> get bomColWidths {
    if (isDesktop) {
      return const [120, 240, 180, 72, 72, 120, 180];
    }
    if (isTablet && !isCompactTablet) {
      return const [120, 260, 170, 76, 76, 120, 200];
    }
    // Small tablet — matches the "perfect" look
    return const [130, 300, 180, 84, 84, 120, 220];
  }

  /// Hides platform scrollbars while still allowing swipe / drag.
  static Widget hideScrollbars(BuildContext context, Widget child) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: child,
    );
  }

  /// Width for each card when laid out in [cardColumns] columns.
  double cardWidthFor(double availableWidth) {
    final cols = cardColumns;
    if (cols <= 1) return availableWidth;
    final gaps = cardGap * (cols - 1);
    return (availableWidth - gaps) / cols;
  }
}
