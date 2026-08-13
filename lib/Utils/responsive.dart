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
    if (isDesktop) return 18;
    if (isTablet) return isCompactTablet ? 16.0 : 17.0;
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
    if (isDesktop) return 8;
    if (isTablet) return 7;
    return isCompactPhone ? 10 : 11;
  }

  double get fieldRadius {
    if (isPhone) return 10;
    return 4;
  }

  bool get useInlineSearchHeader => !isPhone;

  /// Equal-height card rows only on true desktop (avoids huge empty cards on tablets).
  bool get stretchCardRows => isDesktop;

  double get searchButtonFontSize {
    if (isDesktop) return 12;
    if (isTablet) return 11;
    return 13;
  }

  double get searchButtonHeight {
    if (isDesktop) return 32;
    if (isTablet) return 30;
    return 40;
  }

  double get searchIconSize {
    if (isDesktop) return 14;
    if (isTablet) return 13;
    return 16;
  }

  double get searchFieldFontSize {
    if (isDesktop) return 13;
    if (isTablet) return 12.5;
    return isCompactPhone ? 13 : 14;
  }

  double get searchFieldMaxWidth {
    if (isDesktop) return 280;
    if (isTablet) return isCompactTablet ? 220.0 : 250.0;
    return double.infinity;
  }

  double get searchFieldHeight {
    if (isDesktop) return 38;
    if (isTablet) return 36;
    return 42;
  }

  // --- Public Search: SOP cards ---

  double get sopCardWidth {
    if (isDesktop) return 130;
    if (isTablet) return isCompactTablet ? 110.0 : 120.0;
    return isCompactPhone ? 100.0 : 112.0;
  }

  double get sopCardListHeight {
    if (isDesktop) return 132;
    if (isTablet) return isCompactTablet ? 118.0 : 124.0;
    return isCompactPhone ? 112.0 : 120.0;
  }

  double get sopCardPadding {
    if (isDesktop) return 10;
    if (isTablet) return 8;
    return 8;
  }

  double get sopCardLabelSize {
    if (isDesktop) return 12;
    if (isTablet) return 11;
    return 11;
  }

  double get sopCardNumberSize {
    if (isDesktop) return 15;
    if (isTablet) return isCompactTablet ? 13.0 : 14.0;
    return isCompactPhone ? 13.0 : 14.0;
  }

  double get sopCardMetaSize {
    if (isDesktop) return 12;
    if (isTablet) return 11;
    return 11;
  }

  // --- Public Search: BOM table ---

  double get bomHeaderHeight {
    if (isDesktop) return 36;
    if (isTablet) return 32;
    return 30;
  }

  double get bomCellFontSize {
    if (isDesktop) return 12;
    if (isTablet) return isCompactTablet ? 10.5 : 11.0;
    return isCompactPhone ? 10.0 : 11.0;
  }

  double get bomCellPaddingH {
    if (isDesktop) return 8;
    if (isTablet) return 6;
    return 6;
  }

  double get bomCellPaddingV {
    if (isDesktop) return 6;
    if (isTablet) return 5;
    return 4;
  }

  /// Base column widths: TDGPN, Desc, Material, Qty/Size/UOM, State, Vendor, FileName.
  /// Phone/tablet keep wide readable mins so the table scrolls horizontally
  /// instead of crushing text.
  List<double> get bomColWidths {
    if (isDesktop) {
      return const [120, 220, 180, 72, 80, 120, 160];
    }
    // ~1100px total — forces H-scroll on phone & small/medium tablets
    return const [110, 280, 160, 70, 70, 100, 200];
  }

  /// Width for each card when laid out in [cardColumns] columns.
  double cardWidthFor(double availableWidth) {
    final cols = cardColumns;
    if (cols <= 1) return availableWidth;
    final gaps = cardGap * (cols - 1);
    return (availableWidth - gaps) / cols;
  }
}
