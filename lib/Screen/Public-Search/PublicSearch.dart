import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:overview_app/Screen/Public-Search/Services/PublicSearchService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Utils/api_date.dart';
import 'package:overview_app/Utils/responsive.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/AppToast.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:overview_app/Widgets/SearchKeyboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ItemModel {
  final String tdgPn;
  final String description;
  final String material;
  final String state;
  final String vendor;
  final String PathName;
  final double quantity;
  final String size;
  final String UOM;
  final String color;

  bool isExpanded;

  ItemModel({
    required this.tdgPn,
    required this.description,
    required this.material,
    required this.state,
    required this.vendor,
    required this.PathName,
    required this.quantity,
    required this.size,
    required this.UOM,
    this.isExpanded = false,
    required this.color,
  });
}

class Publicsearch extends StatefulWidget {
  final fixtureNumber;

  const Publicsearch({Key? key, this.fixtureNumber}) : super(key: key);

  @override
  _PublicSearchState createState() => _PublicSearchState();
}

class _PublicSearchState extends State<Publicsearch> {
  static const double _kMaxBodyVerticalScrollPixels = 500;
  static const String _kFixturePrefix = '190-100-';

  final Publicsearchservice _service = Publicsearchservice();

  // Main page vertical scroll.
  final ScrollController _bodyScrollController = ScrollController();

  // BOM table vertical scroll.
  final ScrollController _tableVerticalScrollController = ScrollController();

  // BOM table horizontal scroll.
  final ScrollController _tableHorizontalBodyController = ScrollController();

  final TextEditingController PublicSearchController = TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  bool _useNumericKeyboard = true;
  bool _showCustomKeyboard = false;

  Map<String, dynamic> result = {};

  List<ItemModel> items = [];

  List<Map<String, dynamic>> sopList = [];

  bool isSopLoading = false;
  bool isTableLoading = false;
  bool hasSearched = false;

  String username = "";

  // Current sorting information.
  String? _sortColumn;
  bool _sortAscending = true;

  String get _fixtureNumberInput => PublicSearchController.text.trim();

  // ============================================================
  // SORTING
  // ============================================================

  void _sortItems(String column) {
    setState(() {
      // Same column -> toggle ASC/DESC.
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        // New column -> start ASC.
        _sortColumn = column;
        _sortAscending = true;
      }

      items.sort((a, b) {
        int comparison = 0;

        switch (column) {
          case "TDGPN":
            comparison = a.tdgPn.toLowerCase().compareTo(b.tdgPn.toLowerCase());
            break;

          case "Description":
            comparison = a.description.toLowerCase().compareTo(
              b.description.toLowerCase(),
            );
            break;

          case "Material":
            comparison = a.material.toLowerCase().compareTo(
              b.material.toLowerCase(),
            );
            break;

          case "Quantity":
            // Numeric sorting.
            comparison = a.quantity.compareTo(b.quantity);
            break;

          case "Size":
            // Try numeric sorting first.
            final aSize = double.tryParse(a.size.trim());
            final bSize = double.tryParse(b.size.trim());

            if (aSize != null && bSize != null) {
              comparison = aSize.compareTo(bSize);
            } else {
              comparison = a.size.toLowerCase().compareTo(b.size.toLowerCase());
            }
            break;

          case "UOM":
            comparison = a.UOM.toLowerCase().compareTo(b.UOM.toLowerCase());
            break;

          case "State":
            comparison = a.state.toLowerCase().compareTo(b.state.toLowerCase());
            break;

          case "Vendor":
            comparison = a.vendor.toLowerCase().compareTo(
              b.vendor.toLowerCase(),
            );
            break;

          case "FileName":
            comparison = a.PathName.toLowerCase().compareTo(
              b.PathName.toLowerCase(),
            );
            break;

          default:
            comparison = 0;
        }

        return _sortAscending ? comparison : -comparison;
      });
    });
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _bodyScrollController.addListener(_enforceBodyVerticalScrollLimit);

    _searchFocusNode.addListener(_onSearchFocusChanged);

    loadUserName();

    final passed = widget.fixtureNumber?.toString().trim();

    if (passed != null && passed.isNotEmpty) {
      PublicSearchController.text = passed;
      performSearch();
    } else {
      _applyFixturePrefix();
    }
  }

  // ============================================================
  // SEARCH INPUT
  // ============================================================

  void _applyFixturePrefix() {
    PublicSearchController.value = const TextEditingValue(
      text: _kFixturePrefix,
      selection: TextSelection.collapsed(offset: _kFixturePrefix.length),
    );
  }

  void _onSearchFocusChanged() {
    if (!mounted) return;

    setState(() {
      _showCustomKeyboard = _searchFocusNode.hasFocus && !hasSearched;

      if (_searchFocusNode.hasFocus) {
        _useNumericKeyboard = true;
      }
    });
  }

  void _insertSearchText(String value) {
    final text = PublicSearchController.text;
    final selection = PublicSearchController.selection;

    final start = selection.start >= 0 ? selection.start : text.length;

    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, value);

    PublicSearchController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + value.length),
    );
  }

  void _backspaceSearchText() {
    final text = PublicSearchController.text;
    final selection = PublicSearchController.selection;

    if (text.isEmpty) return;

    if (selection.isValid && !selection.isCollapsed) {
      final newText = text.replaceRange(selection.start, selection.end, '');

      PublicSearchController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start),
      );

      return;
    }

    final cursor = selection.baseOffset >= 0
        ? selection.baseOffset
        : text.length;

    if (cursor <= 0) return;

    final newText = text.replaceRange(cursor - 1, cursor, '');

    PublicSearchController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor - 1),
    );
  }

  // ============================================================
  // PAGE SCROLL
  // ============================================================

  void _enforceBodyVerticalScrollLimit() {
    if (!_bodyScrollController.hasClients) return;

    final p = _bodyScrollController.position;

    final limit = _kMaxBodyVerticalScrollPixels.clamp(0.0, p.maxScrollExtent);

    if (p.pixels > limit) {
      p.jumpTo(limit);
    }
  }

  void _scheduleScrollBodyToVerticalLimit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_bodyScrollController.hasClients) {
          return;
        }

        if (!hasSearched || isSopLoading || isTableLoading) {
          return;
        }

        final p = _bodyScrollController.position;

        final target = _kMaxBodyVerticalScrollPixels.clamp(
          0.0,
          p.maxScrollExtent,
        );

        if (target <= 0) return;

        _bodyScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
      });
    });
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Future<void> performSearch() async {
    _searchFocusNode.unfocus();

    setState(() {
      _showCustomKeyboard = false;
    });

    if (_fixtureNumberInput.isEmpty) {
      AppToast.error(context, 'Enter fixture number');
      return;
    }

    setState(() {
      hasSearched = true;
      isSopLoading = true;
      isTableLoading = true;

      // Reset sorting for every new search.
      _sortColumn = null;
      _sortAscending = true;
    });

    await Future.wait([fetchData(), fetchFixtureDetailsData()]);

    if (!mounted) return;

    _scheduleScrollBodyToVerticalLimit();
  }

  // ============================================================
  // NEW SEARCH
  // ============================================================

  void _handleNewSearch() {
    if (_bodyScrollController.hasClients) {
      _bodyScrollController.jumpTo(0);
    }

    if (_tableVerticalScrollController.hasClients) {
      _tableVerticalScrollController.jumpTo(0);
    }

    if (_tableHorizontalBodyController.hasClients) {
      _tableHorizontalBodyController.jumpTo(0);
    }

    setState(() {
      _applyFixturePrefix();

      hasSearched = false;

      isSopLoading = false;
      isTableLoading = false;

      sopList = [];
      items = [];
      result = {};

      // Reset sorting.
      _sortColumn = null;
      _sortAscending = true;
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _bodyScrollController.removeListener(_enforceBodyVerticalScrollLimit);

    _bodyScrollController.dispose();

    _tableVerticalScrollController.dispose();

    _tableHorizontalBodyController.dispose();

    PublicSearchController.dispose();

    _searchFocusNode.removeListener(_onSearchFocusChanged);

    _searchFocusNode.dispose();

    super.dispose();
  }

  // ============================================================
  // SOP API
  // ============================================================

  Future<void> fetchFixtureDetailsData() async {
    if (_fixtureNumberInput.isEmpty) {
      setState(() {
        sopList = [];
        isSopLoading = false;
      });

      return;
    }

    await Dioservices.setToken();

    try {
      final response = await _service.FixtureDetailsService(
        fixtureNumber: _fixtureNumberInput,
        user: "om",
      );

      final data = response.data["data"];

      setState(() {
        sopList = data is List ? List<Map<String, dynamic>>.from(data) : [];

        isSopLoading = false;
      });
    } catch (e) {
      print("Error fetching SOP Data $e");

      setState(() {
        sopList = [];
        isSopLoading = false;
      });
    }
  }

  // ============================================================
  // BOM API
  // ============================================================

  Future<void> fetchData() async {
    final fixtureNumber = _fixtureNumberInput;

    if (fixtureNumber.isEmpty) {
      setState(() {
        items = [];
        result = {};
        isTableLoading = false;
      });

      return;
    }

    try {
      await Dioservices.setToken();

      Response response = await _service.PublicSearchService(
        fixtureNumber: fixtureNumber,
      );

      final data = response.data;

      setState(() {
        result = data is Map ? Map<String, dynamic>.from(data) : {};

        final components = result["data"]?["Fixture"]?["Components"];

        items = components is List
            ? components.map<ItemModel>((e) {
                final rawColor =
                    e["Color"] ?? e["color"] ?? e["Colour"] ?? e["colour"];

                final colorStr = rawColor?.toString().trim().isNotEmpty == true
                    ? rawColor.toString().trim()
                    : "white";

                return ItemModel(
                  tdgPn: e["TDGPN"]?.toString() ?? "-",

                  description: e["Description"]?.toString() ?? "",

                  material: e["Material"]?.toString() ?? "",

                  state: e["State"]?.toString() ?? "",

                  vendor: e["Vendor"]?.toString() ?? "",

                  PathName: e["PathName"]?.toString() ?? "",

                  quantity:
                      double.tryParse(e["Quantity"]?.toString() ?? "1") ?? 1.0,

                  size: e["Size"]?.toString() ?? "",

                  UOM: e["UnitOfMeasure"]?.toString() ?? "",

                  color: colorStr,
                );
              }).toList()
            : [];

        if (items.isNotEmpty) {
          final uniqueColors = items.map((e) => e.color).toSet().toList()
            ..sort();

          print(
            "PublicSearch fixture=$fixtureNumber "
            "unique Colors=$uniqueColors",
          );
        }

        isTableLoading = false;
      });
    } catch (e) {
      print("Error Public Search Fetch Data $e");

      setState(() {
        items = [];
        result = {};
        isTableLoading = false;
      });
    }
  }

  // ============================================================
  // USER NAME
  // ============================================================

  Future<void> loadUserName() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      username = prefs.getString("UserName") ?? "";
    });
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  /// Card dates: month day year → `MM/dd/yyyy`.
  String formatDate(dynamic date) {
    if (date == null) return "-";

    final dateStr = date.toString().trim();
    if (dateStr.isEmpty ||
        dateStr == '-' ||
        dateStr.toLowerCase() == 'null') {
      return "-";
    }
    if (dateStr.startsWith("0001-01-01") || dateStr == '*') {
      return "*";
    }

    DateTime? parsed = ApiDate.parse(dateStr);

    // Slash / dash forms the API sometimes sends (dd/MM/yyyy or MM/dd/yyyy).
    if (parsed == null) {
      final match = RegExp(
        r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$',
      ).firstMatch(dateStr);
      if (match != null) {
        final a = int.tryParse(match.group(1)!);
        final b = int.tryParse(match.group(2)!);
        var year = int.tryParse(match.group(3)!);
        if (a != null && b != null && year != null) {
          if (year < 100) year += 2000;
          // Prefer day-first when day > 12; otherwise treat as MM/dd/yyyy.
          if (a > 12 && b <= 12) {
            parsed = DateTime(year, b, a);
          } else if (b > 12 && a <= 12) {
            parsed = DateTime(year, a, b);
          } else {
            parsed = DateTime(year, a, b); // assume MM/dd/yyyy
          }
        }
      }
    }

    if (parsed == null) return "-";

    try {
      return DateFormat('MM/dd/yyyy').format(parsed);
    } catch (_) {
      return "-";
    }
  }

  // ============================================================
  // SOP CARD WIDTH
  // ============================================================

  double _calculateSopCardWidth(double availableWidth, Responsive r) {
    const double gap = 12;

    // Minimum readable width.
    const double minCardWidth = 175;

    int columns = ((availableWidth + gap) / (minCardWidth + gap)).floor();

    columns = columns.clamp(1, 20);

    return (availableWidth - ((columns - 1) * gap)) / columns;
  }

  // ============================================================
  // SOP CARD
  // ============================================================

  Widget _buildSOPCard(
    String sop,
    String date,
    String qty,
    Responsive r,
    double cardWidth,
  ) {
    final double cardHeight = r.isPhone ? 100 : 107;

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFFD0D5DB), width: 1),
        ),
        padding: EdgeInsets.fromLTRB(
          r.isPhone ? 8 : 10,
          r.isPhone ? 8 : 9,
          r.isPhone ? 8 : 10,
          r.isPhone ? 6 : 7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "SOP",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: r.isPhone ? 9 : 10,
                color: const Color(0xFF374151),
                fontWeight: FontWeight.w400,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              sop,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: r.isPhone ? 14 : 15,
                color: Colors.black,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),

            const SizedBox(height: 6),

            Container(height: 1, color: const Color(0xFFE0E3E7)),

            const SizedBox(height: 6),

            // DATE
            Row(
              children: [
                SizedBox(
                  width: 35,
                  child: Text(
                    "Date:",
                    style: TextStyle(
                      fontSize: r.isPhone ? 9 : 10,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      date,
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: r.isPhone ? 10 : 11,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 5),

            // QUANTITY
            Row(
              children: [
                SizedBox(
                  width: 35,
                  child: Text(
                    "Qty:",
                    style: TextStyle(
                      fontSize: r.isPhone ? 9 : 10,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    qty,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.isPhone ? 10 : 11,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ROW COLOR
  // ============================================================

  Color _rowColorFromApi(String? raw) {
    var value = (raw ?? '').trim();

    if (value.isEmpty) {
      return Colors.white;
    }

    final lower = value.toLowerCase().replaceAll('#', '');

    if (lower == 'white') {
      return Colors.white;
    }

    if (lower == 'orange') {
      return const Color(0xFFFFA500);
    }

    var hex = value.replaceAll('#', '');

    if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
      if (hex.length == 6) {
        hex = 'FF$hex';
      }

      if (hex.length == 8) {
        final parsed = int.tryParse(hex, radix: 16);

        if (parsed != null) {
          return Color(parsed);
        }
      }
    }

    return Colors.white;
  }

  // ============================================================
  // BOM COLUMN WIDTHS
  // ============================================================

  double _minBomTableWidth(List<double> widths) {
    assert(widths.length >= 9);
    return widths.fold<double>(0, (sum, w) => sum + w);
  }

  List<double> _columnWidthsForBomTable(double available, Responsive r) {
    final base = r.bomColWidths;
    final sum = _minBomTableWidth(base);

    // Phone / tablet: keep readable fixed widths and scroll horizontally.
    if (!r.isDesktop || available <= sum) {
      return List<double>.from(base);
    }

    // Desktop: stretch columns to fill available width.
    final scale = available / sum;
    return base.map((w) => w * scale).toList();
  }

  double _bomTableWidthFor(List<double> widths) {
    return _minBomTableWidth(widths);
  }

  // ============================================================
  // BOM HEADER CELL
  // ============================================================

  Widget _bomHeaderCell(
    String label,
    double w,
    Responsive r, {
    String? sortKey,
  }) {
    final borderColor = Colors.grey.shade300;
    final key = sortKey ?? label;
    final isSorted = _sortColumn == key;
    final iconSize = (r.bomCellFontSize + 2).clamp(12.0, 16.0);

    return SizedBox(
      width: w,
      height: r.bomHeaderHeight,
      child: Material(
        color: const Color.fromARGB(255, 57, 73, 95),
        child: InkWell(
          onTap: () {
            _sortItems(key);
          },
          child: Container(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.symmetric(horizontal: r.bomCellPaddingH),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 57, 73, 95),
              border: Border(
                right: BorderSide(color: borderColor),
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: r.bomCellFontSize,
                      height: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  isSorted && !_sortAscending
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  size: iconSize,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOM DATA CELL
  // ============================================================

  Widget _bomDataCell(
    String value,
    double w,
    Responsive r, {
    TextStyle? style,
  }) {
    final borderColor = Colors.grey.shade300;
    final baseStyle = TextStyle(
      fontSize: r.bomCellFontSize,
      height: 1.2,
      color: const Color(0xFF374151),
      fontWeight: FontWeight.w400,
    );

    return SizedBox(
      width: w,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(
          horizontal: r.bomCellPaddingH,
          vertical: r.bomCellPaddingV,
        ),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
        child: Text(
          value,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          strutStyle: StrutStyle(
            fontSize: r.bomCellFontSize,
            height: 1.2,
            forceStrutHeight: true,
          ),
          style: baseStyle.merge(style),
        ),
      ),
    );
  }

  // ============================================================
  // BOM TABLE
  // ============================================================

  Widget _buildBomTable({
    required double availableWidth,
    required double tableHeight,
    required Responsive r,
  }) {
    final colW = _columnWidthsForBomTable(availableWidth, r);

    final tableW = _bomTableWidthFor(colW);

    // ----------------------------
    // HEADER
    // ----------------------------

    final header = Material(
      color: const Color.fromARGB(255, 57, 73, 95),
      elevation: 2,
      shadowColor: Colors.black26,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bomHeaderCell("TDGPN", colW[0], r),
          _bomHeaderCell("Description", colW[1], r),
          _bomHeaderCell("Material", colW[2], r),
          _bomHeaderCell(
            r.isPhone ? "Qty" : "Quantity",
            colW[3],
            r,
            sortKey: "Quantity",
          ),
          _bomHeaderCell("Size", colW[4], r),
          _bomHeaderCell("UOM", colW[5], r),
          _bomHeaderCell("State", colW[6], r),
          _bomHeaderCell("Vendor", colW[7], r),
          _bomHeaderCell("FileName", colW[8], r),
        ],
      ),
    );

    // ----------------------------
    // ROWS
    // ----------------------------

    final rows = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Container(
            color: _rowColorFromApi(item.color),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _bomDataCell(item.tdgPn, colW[0], r),
                _bomDataCell(item.description, colW[1], r),
                _bomDataCell(item.material, colW[2], r),
                _bomDataCell(item.quantity.toString(), colW[3], r),
                _bomDataCell(item.size, colW[4], r),
                _bomDataCell(item.UOM, colW[5], r),
                _bomDataCell(item.state, colW[6], r),
                _bomDataCell(item.vendor, colW[7], r),
                _bomDataCell(
                  item.PathName,
                  colW[8],
                  r,
                  style: TextStyle(
                    fontSize: r.bomCellFontSize,
                    height: 1.2,
                    fontFamily: 'Courier New',
                    fontFamilyFallback: const [
                      'Courier',
                      'Menlo',
                      'Consolas',
                      'monospace',
                    ],
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    // ==========================================================
    // TABLE SCROLLING
    // ==========================================================

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRect(
        child: ScrollConfiguration(
          behavior: const _NoScrollbarScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: SingleChildScrollView(
            controller: _tableHorizontalBodyController,
            scrollDirection: Axis.horizontal,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            child: SizedBox(
              width: tableW,
              height: tableHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _tableVerticalScrollController,
                      primary: false,
                      scrollDirection: Axis.vertical,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: rows,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    final searchFieldWidth = (r.width - (r.pagePaddingH * 2)).clamp(
      220.0,
      r.isPhone ? 360.0 : (r.isTablet ? 340.0 : 360.0),
    );

    final media = MediaQuery.of(context);

    final bodyViewportHeight =
        media.size.height - media.padding.vertical - kToolbarHeight;

    final estimatedHeaderPx = r.isPhone ? 300.0 : (r.isTablet ? 320.0 : 340.0);

    final tableBoxHeight = (bodyViewportHeight - estimatedHeaderPx + 120).clamp(
      r.isPhone ? 200.0 : 240.0,
      r.isDesktop ? 680.0 : (r.isTablet ? 520.0 : 420.0),
    );

    final openedFromFixtureLink =
        widget.fixtureNumber?.toString().trim().isNotEmpty ?? false;

    return Scaffold(
      appBar: CommonAppBar(
        showBackButton: openedFromFixtureLink || hasSearched,

        onBackPressed: () {
          if (openedFromFixtureLink && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            return;
          }

          _handleNewSearch();
        },
      ),

      drawer: const CommonDrawer(),

      backgroundColor: Colors.white,

      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.white,

              child: Scrollbar(
                controller: _bodyScrollController,

                thumbVisibility: r.isDesktop,

                trackVisibility: r.isDesktop,

                child: SingleChildScrollView(
                  controller: _bodyScrollController,

                  physics: const AlwaysScrollableScrollPhysics(),

                  padding: EdgeInsets.symmetric(
                    horizontal: r.pagePaddingH,
                    vertical: r.pagePaddingV,
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,

                    children: [
                      // ==================================================
                      // TITLE
                      // ==================================================
                      Align(
                        alignment: hasSearched
                            ? Alignment.centerLeft
                            : Alignment.center,

                        child: Text(
                          "Public Search",

                          style: TextStyle(
                            color: Colors.black,
                            fontSize: r.isPhone ? 22 : r.pageTitleSize + 4,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // ==================================================
                      // NEW SEARCH BUTTON
                      // ==================================================
                      if (hasSearched) ...[
                        SizedBox(height: r.isPhone ? 8 : 10),

                        Align(
                          alignment: Alignment.centerRight,

                          child: SizedBox(
                            height: r.searchControlHeight,

                            child: ElevatedButton.icon(
                              onPressed: _handleNewSearch,

                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),

                                foregroundColor: Colors.white,

                                elevation: 1,

                                shadowColor: Colors.black.withOpacity(0.05),

                                padding: EdgeInsets.symmetric(
                                  horizontal: r.isPhone ? 12 : 14,
                                ),

                                visualDensity: VisualDensity.compact,

                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),

                              icon: Icon(Icons.search, size: r.searchIconSize),

                              label: Text(
                                "New Search",
                                style: TextStyle(
                                  fontSize: r.searchButtonFontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      // ==================================================
                      // SEARCH FORM
                      // ==================================================
                      if (!hasSearched) ...[
                        Center(
                          child: SizedBox(
                            width: searchFieldWidth,

                            height: r.searchControlHeight,

                            child: Theme(
                              data: Theme.of(context).copyWith(
                                inputDecorationTheme: InputDecorationTheme(
                                  isDense: !r.isPhone,

                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,

                                    vertical: r.searchFieldContentPaddingV,
                                  ),

                                  constraints: const BoxConstraints(),
                                ),
                              ),

                              child: TextField(
                                controller: PublicSearchController,

                                focusNode: _searchFocusNode,

                                readOnly: true,

                                showCursor: true,

                                keyboardType: TextInputType.none,

                                style: TextStyle(
                                  fontSize: r.searchFieldFontSize,
                                ),

                                textAlignVertical: TextAlignVertical.center,

                                decoration: InputDecoration(
                                  filled: true,

                                  fillColor: Colors.white,

                                  isDense: !r.isPhone,

                                  hintText: 'Enter Fixture Number',

                                  hintStyle: TextStyle(
                                    fontSize: r.searchFieldFontSize,
                                  ),

                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,

                                    vertical: r.searchFieldContentPaddingV,
                                  ),

                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      r.fieldRadius,
                                    ),

                                    borderSide: BorderSide.none,
                                  ),

                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      r.fieldRadius,
                                    ),

                                    borderSide: const BorderSide(
                                      color: Color.fromARGB(255, 22, 129, 218),
                                      width: 1.5,
                                    ),
                                  ),

                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      r.fieldRadius,
                                    ),

                                    borderSide: const BorderSide(
                                      color: Colors.blue,
                                      width: 1.5,
                                    ),
                                  ),
                                ),

                                onTap: () {
                                  setState(() {
                                    _showCustomKeyboard = true;

                                    _useNumericKeyboard = true;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: r.isPhone ? 8 : 10),

                        Center(
                          child: SizedBox(
                            height: r.searchControlHeight,

                            width: 160,

                            child: ElevatedButton(
                              onPressed: (isSopLoading || isTableLoading)
                                  ? null
                                  : performSearch,

                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(
                                  255,
                                  57,
                                  73,
                                  95,
                                ),

                                foregroundColor: Colors.white,

                                elevation: 0,

                                minimumSize: Size(0, r.searchControlHeight),

                                fixedSize: Size.fromHeight(
                                  r.searchControlHeight,
                                ),

                                padding: EdgeInsets.symmetric(
                                  horizontal: r.isPhone ? 16 : 12,
                                ),

                                visualDensity: r.isPhone
                                    ? VisualDensity.standard
                                    : VisualDensity.compact,

                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,

                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    r.fieldRadius,
                                  ),
                                ),
                              ),

                              child: Text(
                                "Search",
                                style: TextStyle(
                                  fontSize: r.searchButtonFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      // ==================================================
                      // AVAILABLE SOPS
                      // ==================================================
                      SizedBox(height: r.sectionGap),

                      if (hasSearched)
                        Text(
                          "Available SOPs",

                          style: TextStyle(
                            fontWeight: FontWeight.bold,

                            fontSize: r.sectionTitleSize,
                          ),
                        ),

                      SizedBox(height: r.sectionGap),

                      // ==================================================
                      // SOP CONTENT
                      // ==================================================
                      if (isSopLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),

                          child: Center(child: AppLoader()),
                        )
                      else if (!hasSearched)
                        const SizedBox.shrink()
                      else if (sopList.isEmpty)
                        Center(
                          child: Text(
                            "No SOPs available for this fixture",

                            style: TextStyle(fontSize: r.bodyFontSize),
                          ),
                        )
                      else if (r.isPhone)
                        SizedBox(
                          height: 107,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cardW = (constraints.maxWidth * 0.78)
                                  .clamp(180.0, 240.0);
                              return ScrollConfiguration(
                                behavior:
                                    const _NoScrollbarScrollBehavior().copyWith(
                                  dragDevices: {
                                    PointerDeviceKind.touch,
                                    PointerDeviceKind.mouse,
                                    PointerDeviceKind.trackpad,
                                    PointerDeviceKind.stylus,
                                  },
                                ),
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: sopList.length,
                                  itemBuilder: (context, index) {
                                    final item = sopList[index];
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right: index == sopList.length - 1
                                            ? 0
                                            : 10,
                                      ),
                                      child: _buildSOPCard(
                                        item["SOPNum"]?.toString() ?? "-",
                                        formatDate(item["ODD"]),
                                        item["Quantity"]?.toString() ?? "-",
                                        r,
                                        cardW,
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        )
                      else
                        // ==================================================
                        // TABLET / DESKTOP:
                        // WRAP
                        // ==================================================
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = _calculateSopCardWidth(
                              constraints.maxWidth,
                              r,
                            );

                            return Wrap(
                              spacing: 12,

                              runSpacing: 12,

                              children: [
                                for (final item in sopList)
                                  _buildSOPCard(
                                    item["SOPNum"]?.toString() ?? "-",

                                    formatDate(item["ODD"]),

                                    item["Quantity"]?.toString() ?? "-",

                                    r,

                                    cardWidth,
                                  ),
                              ],
                            );
                          },
                        ),

                      // ==================================================
                      // GAP BEFORE TABLE
                      // ==================================================
                      SizedBox(height: r.sectionGap),

                      // ==================================================
                      // BOM TABLE
                      // ==================================================
                      if (isTableLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),

                          child: Center(child: AppLoader()),
                        )
                      else if (hasSearched)
                        SizedBox(
                          height: tableBoxHeight,

                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return _buildBomTable(
                                availableWidth: constraints.maxWidth,

                                tableHeight: constraints.maxHeight,

                                r: r,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ==================================================
          // CUSTOM KEYBOARD
          // ==================================================
          if (_showCustomKeyboard && !hasSearched)
            SearchKeyboard(
              isNumeric: _useNumericKeyboard,

              onToggleMode: () {
                setState(() {
                  _useNumericKeyboard = !_useNumericKeyboard;
                });
              },

              onKey: _insertSearchText,

              onBackspace: _backspaceSearchText,

              onSearch: performSearch,
            ),
        ],
      ),
    );
  }
}

// ============================================================
// NO SCROLLBAR BEHAVIOR
// ============================================================

class _NoScrollbarScrollBehavior extends MaterialScrollBehavior {
  const _NoScrollbarScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
