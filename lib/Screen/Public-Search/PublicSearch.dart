import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:overview_app/Screen/Public-Search/Services/PublicSearchService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Utils/responsive.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
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

  final Publicsearchservice _service = Publicsearchservice();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _bodyScrollController = ScrollController();
  final ScrollController _tableVerticalScrollController = ScrollController();
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

  String get _fixtureNumberInput => PublicSearchController.text.trim();

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
    }
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

    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    if (cursor <= 0) return;
    final newText = text.replaceRange(cursor - 1, cursor, '');
    PublicSearchController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor - 1),
    );
  }

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
        if (!mounted || !_bodyScrollController.hasClients) return;
        if (!hasSearched || isSopLoading || isTableLoading) return;
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

  Future<void> performSearch() async {
    _searchFocusNode.unfocus();
    setState(() {
      _showCustomKeyboard = false;
    });
    if (_fixtureNumberInput.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter fixture number')));
      return;
    }
    setState(() {
      hasSearched = true;
      isSopLoading = true;
      isTableLoading = true;
    });
    await Future.wait([fetchData(), fetchFixtureDetailsData()]);
    if (!mounted) return;
    _scheduleScrollBodyToVerticalLimit();
  }

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
      PublicSearchController.clear();
      hasSearched = false;
      isSopLoading = false;
      isTableLoading = false;
      sopList = [];
      items = [];
      result = {};
    });
  }

  @override
  void dispose() {
    _bodyScrollController.removeListener(_enforceBodyVerticalScrollLimit);
    _bodyScrollController.dispose();
    _tableVerticalScrollController.dispose();
    _tableHorizontalBodyController.dispose();
    _scrollController.dispose();
    PublicSearchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> fetchFixtureDetailsData() async {
    if (_fixtureNumberInput.isEmpty) {
      setState(() {
        sopList = [];
        isSopLoading = false;
      });
      return;
    }

    await Dioservices.setToken();
    // print("Calling Fetch Fixture Details Data..........");
    try {
      final response = await _service.FixtureDetailsService(
        fixtureNumber: _fixtureNumberInput,
        user: "om",
      );
      // print("Full response: ${response.data}");
      final data = response.data["data"];

      setState(() {
        sopList = data is List ? List<Map<String, dynamic>>.from(data) : [];
        isSopLoading = false;
      });
      // print("SOP Data ------------------>: $sopList");
    } catch (e) {
      print("Error fetching SOP Data $e");
      setState(() {
        sopList = [];
        isSopLoading = false;
      });
    }
  }

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
        // user: "om",
      );

      final data = response.data;

      setState(() {
        result = data is Map ? Map<String, dynamic>.from(data) : {};
        final components = result["data"]?["Fixture"]?["Components"];

        items = components is List
            ? components.map<ItemModel>((e) {
                // API uses PascalCase for most fields; color may be "color" or "Color".
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
                  size: e['Size']?.toString() ?? '',
                  UOM: e['UnitOfMeasure']?.toString() ?? "",
                  color: colorStr,
                );
              }).toList()
            : [];

        // One summary log: unique Color values from this fixture's Components.
        if (items.isNotEmpty) {
          final uniqueColors = items.map((e) => e.color).toSet().toList()
            ..sort();
          print(
            "PublicSearch fixture=$fixtureNumber unique Colors=$uniqueColors",
          );
        }
        isTableLoading = false;
      });

      // print(data["data"].runtimeType);
      // print(data["data"]);

      // print("Response for Public Serach ${response.data}");
    } catch (e) {
      print("Error Public Search Fetch Data $e");
      setState(() {
        items = [];
        result = {};
        isTableLoading = false;
      });
    }
  }

  Future<void> loadUserName() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      username = prefs.getString("UserName") ?? "";
    });
    // print("username ---------> $username");
  }

  String formatDate(dynamic date) {
    if (date == null) return "-";

    try {
      String dateStr = date.toString();
      if (dateStr.startsWith("0001-01-01")) {
        return "*";
      }
      DateTime parsedDate = DateTime.parse(dateStr);

      return DateFormat('MM/dd/yyyy').format(parsedDate);
    } catch (e) {
      print("Date parse error: $e");
      return "";
    }
  }

  Widget _buildSOPCard(String sop, String date, String qty, Responsive r) {
    // Leave 2px so the bottom border is not clipped by the horizontal ListView.
    final cardHeight = r.sopCardListHeight - 2;

    return Padding(
      padding: EdgeInsets.only(right: r.isPhone ? 8 : 10),
      child: SizedBox(
        width: r.sopCardWidth,
        height: cardHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(r.isPhone ? 10 : 12),
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
          child: Padding(
            padding: EdgeInsets.all(r.sopCardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  "SOP",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.sopCardLabelSize,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: r.isPhone ? 2 : 4),
                Text(
                  sop,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.sopCardNumberSize,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: r.isPhone ? 4 : 8),
                Text(
                  "Date: $date",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.sopCardMetaSize,
                    height: 1.15,
                  ),
                ),
                Text(
                  "Qty: $qty",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.sopCardMetaSize,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// API may return hex ("#FFA500") or the name "orange".
  Color _rowColorFromApi(String? raw) {
    var value = (raw ?? '').trim();
    if (value.isEmpty) return Colors.white;

    final lower = value.toLowerCase().replaceAll('#', '');
    if (lower == 'white') return Colors.white;
    if (lower == 'orange') return const Color(0xFFFFA500); // #FFA500

    // Hex only: "#RRGGBB", "RRGGBB", "#AARRGGBB", "AARRGGBB"
    var hex = value.replaceAll('#', '');
    if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length == 8) {
        final parsed = int.tryParse(hex, radix: 16);
        if (parsed != null) return Color(parsed);
      }
    }

    // Unknown value → white (never crash)
    return Colors.white;
  }

  double _minBomTableWidth(List<double> widths) =>
      widths[0] +
      widths[1] +
      widths[2] +
      3 * widths[3] +
      widths[4] +
      widths[5] +
      widths[6];

  List<double> _columnWidthsForBomTable(double available, Responsive r) {
    final base = r.bomColWidths;
    final sum = _minBomTableWidth(base);
    // Small screens: never shrink/stretch to fit — keep readable widths + H-scroll.
    if (!r.isDesktop || available <= sum) {
      return List<double>.from(base);
    }
    final scale = available / sum;
    return base.map((w) => w * scale).toList();
  }

  double _bomTableWidthFor(List<double> widths) => _minBomTableWidth(widths);

  Widget _bomHeaderCell(String label, double w, Responsive r) {
    final borderColor = Colors.grey.shade300;
    return SizedBox(
      width: w,
      height: r.bomHeaderHeight,
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
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: r.bomCellFontSize,
            height: 1.0,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _bomDataCell(String value, double w, Responsive r) {
    final borderColor = Colors.grey.shade300;
    return SizedBox(
      width: w,
      child: Container(
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
          style: TextStyle(fontSize: r.bomCellFontSize),
        ),
      ),
    );
  }

  Widget _buildBomTable({
    required double availableWidth,
    required double tableHeight,
    required Responsive r,
  }) {
    final colW = _columnWidthsForBomTable(availableWidth, r);
    final tableW = _bomTableWidthFor(colW);

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
          _bomHeaderCell("Quantity", colW[3], r),
          _bomHeaderCell("Size", colW[3], r),
          _bomHeaderCell("UOM", colW[3], r),
          _bomHeaderCell("State", colW[4], r),
          _bomHeaderCell("Vendor", colW[5], r),
          _bomHeaderCell("FileName", colW[6], r),
        ],
      ),
    );

    final rows = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Container(
            color: _rowColorFromApi(item.color),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bomDataCell(item.tdgPn, colW[0], r),
                _bomDataCell(item.description, colW[1], r),
                _bomDataCell(item.material, colW[2], r),
                _bomDataCell(item.quantity.toString(), colW[3], r),
                _bomDataCell(item.size.toString(), colW[3], r),
                _bomDataCell(item.UOM.toString(), colW[3], r),
                _bomDataCell(item.state, colW[4], r),
                _bomDataCell(item.vendor, colW[5], r),
                _bomDataCell(item.PathName, colW[6], r),
              ],
            ),
          ),
      ],
    );

    // Horizontal scroll without visible scrollbar (swipe / drag still works).
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
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
    );
  }

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
    final estimatedHeaderPx = r.isPhone
        ? 300.0
        : (r.isTablet ? 320.0 : 340.0);
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
          // Opened from Critical Items / fixture click → return to that page.
          if (openedFromFixtureLink && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            return;
          }
          // Standalone Public Search → clear results (same as New Search).
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
                          style: TextStyle(fontSize: r.searchFieldFontSize),
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
                              borderRadius:
                                  BorderRadius.circular(r.fieldRadius),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(r.fieldRadius),
                              borderSide: const BorderSide(
                                color: Color.fromARGB(255, 22, 129, 218),
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(r.fieldRadius),
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
                      width: r.isPhone ? 160 : 160,
                      child: ElevatedButton(
                        onPressed: (isSopLoading || isTableLoading)
                            ? null
                            : performSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 57, 73, 95),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: Size(0, r.searchControlHeight),
                          fixedSize: Size.fromHeight(r.searchControlHeight),
                          padding: EdgeInsets.symmetric(
                            horizontal: r.isPhone ? 16 : 12,
                          ),
                          visualDensity: r.isPhone
                              ? VisualDensity.standard
                              : VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(r.fieldRadius),
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
                if (isSopLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: AppLoader()),
                  )
                else ...[
                  SizedBox(
                    height: hasSearched ? r.sopCardListHeight : 0,
                    child: !hasSearched
                        ? const SizedBox.shrink()
                        : sopList.isEmpty
                        ? Center(
                            child: Text(
                              "No SOPs available for this fixture",
                              style: TextStyle(fontSize: r.bodyFontSize),
                            ),
                          )
                        : ListView.builder(
                            clipBehavior: Clip.none,
                            padding: EdgeInsets.zero,
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: sopList.length,
                            itemBuilder: (context, index) {
                              final item = sopList[index];

                              return _buildSOPCard(
                                item["SOPNum"]?.toString() ?? "-",
                                formatDate(item["ODD"]),
                                item["Quantity"]?.toString() ?? "-",
                                r,
                              );
                            },
                          ),
                  ),
                  SizedBox(height: r.sectionGap),
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
              ],
            ),
          ),
        ),
            ),
          ),
          if (_showCustomKeyboard && !hasSearched)
            _FixtureSearchKeyboard(
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

class _FixtureSearchKeyboard extends StatelessWidget {
  final bool isNumeric;
  final VoidCallback onToggleMode;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onSearch;

  const _FixtureSearchKeyboard({
    required this.isNumeric,
    required this.onToggleMode,
    required this.onKey,
    required this.onBackspace,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: const Color(0xFFD1D5DB),
      elevation: 8,
      child: Padding(
        padding: EdgeInsets.fromLTRB(6, 8, 6, 8 + bottomInset),
        child: isNumeric ? _buildNumericPad() : _buildAlphaPad(),
      ),
    );
  }

  Widget _buildNumericPad() {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['ABC', '0', '-'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _keyButton(
                        label: key,
                        onTap: () {
                          if (key == 'ABC') {
                            onToggleMode();
                          } else {
                            onKey(key);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _keyButton(
                  label: '⌫',
                  onTap: onBackspace,
                  isAction: true,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _keyButton(
                  label: 'Search',
                  onTap: onSearch,
                  isPrimary: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlphaPad() {
    const rows = [
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
      ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _keyButton(
                        label: key,
                        onTap: () => onKey(key),
                        compact: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _keyButton(
                  label: '123',
                  onTap: onToggleMode,
                  isAction: true,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _keyButton(
                  label: '-',
                  onTap: () => onKey('-'),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _keyButton(
                  label: '⌫',
                  onTap: onBackspace,
                  isAction: true,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _keyButton(
                  label: 'Search',
                  onTap: onSearch,
                  isPrimary: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keyButton({
    required String label,
    required VoidCallback onTap,
    bool isAction = false,
    bool isPrimary = false,
    bool compact = false,
  }) {
    final bg = isPrimary
        ? const Color(0xFF1E88E5)
        : isAction
            ? const Color(0xFFB0B7C3)
            : Colors.white;
    final fg = isPrimary ? Colors.white : const Color(0xFF1A1A1A);
    return SizedBox(
      height: compact ? 40 : 48,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: compact ? 14 : 18,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hides platform/Flutter scrollbars while keeping scroll gestures.
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

