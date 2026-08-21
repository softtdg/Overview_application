import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:overview_app/Screen/Public-Search/PublicSearch.dart';
import 'package:overview_app/Screen/SOPSearch/Services/SOPSearchService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Utils/responsive.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/AppToast.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:overview_app/Widgets/SearchKeyboard.dart';
import 'package:overview_app/Widgets/card.dart';
import 'package:overview_app/Widgets/ScrollFade.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SOPSearch extends StatefulWidget {
  @override
  _SOPSearchState createState() => _SOPSearchState();
}

class _SOPSearchState extends State<SOPSearch> {
  // controller for take a input
  final TextEditingController SOPController = TextEditingController();

  /// Drives the in-app keypad: it is shown only while the SOP field has focus.
  final FocusNode SOPFocusNode = FocusNode();
  bool _useNumericKeyboard = true;
  bool isLoading = false;
  Map<String, dynamic>? sopData;
  String username = "";

  Future<void> loadUserName() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      username = prefs.getString("UserName") ?? "";
    });
    // print("username ---------> $username");
  }

  @override
  void initState() {
    super.initState();
    loadUserName();
    SOPFocusNode.addListener(_onSOPFocusChanged);
  }

  @override
  void dispose() {
    SOPFocusNode.removeListener(_onSOPFocusChanged);
    SOPFocusNode.dispose();
    SOPController.dispose();
    super.dispose();
  }

  void _onSOPFocusChanged() {
    setState(() {
      if (SOPFocusNode.hasFocus) {
        _useNumericKeyboard = true;
      }
    });
  }

  bool get _keypadVisible =>
      SearchKeyboard.isTouchPlatform && SOPFocusNode.hasFocus;

  void handleSOPSearch() async {
    if (isLoading) return;

    // Close the keypad so results are not hidden behind it.
    SOPFocusNode.unfocus();

    String sopNumber = SOPController.text.trim();

    // check emptry sop search
    if (sopNumber.isEmpty) {
      AppToast.error(context, "Please enter SOP number");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await Dioservices.setToken();

      // Call API
      final response = await SOPSearchService().SOPSearch(SOP: sopNumber);

      setState(() {
        sopData = response.data["data"];
      });

      if (!mounted) return;
      AppToast.success(context, "Data Loaded");
    } catch (e) {
      print("SOP Error --------> $e");

      // Show backend 401 message
      if (e is DioException) {
        print("SOP Request URL --------> ${e.requestOptions.uri}");
        print("SOP Request Headers --------> ${e.requestOptions.headers}");
        print("SOP Error Data --------> ${e.response}");
      }

      if (mounted) {
        AppToast.error(context, "Failed to fetch SOP");
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  String formatDate(dynamic date) {
    if (date == null) return kEmptyValue;

    try {
      String dateStr = date.toString();
      if (dateStr.startsWith("0001-01-01")) {
        return kEmptyValue;
      }
      DateTime parsedDate = DateTime.parse(dateStr);

      return DateFormat('dd/MM/yyyy').format(parsedDate);
    } catch (e) {
      print("Date parse error: $e");
      return kEmptyValue;
    }
  }

  String safeValue(dynamic value, {String fallback = ""}) {
    if (value == null) return fallback;
    String str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == "null") {
      return fallback;
    }
    return str;
  }

  /// Converts decimal hours (e.g. 1.5) to display format (e.g. "1h30m").
  String convertPerUnitTimeToMinutes(dynamic perUnitTime) {
    final perUnitHours = double.tryParse(perUnitTime?.toString() ?? '');
    if (perUnitHours == null) return '-';

    final totalMinutes = (perUnitHours * 60).ceil();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h${minutes}m';
  }

  /// Total build time: Hours × Quantity (e.g. 2.25 × 3 → "6h45m").
  String convertDecimalToTime(dynamic perUnitTime, dynamic quantity) {
    final perUnitHours = double.tryParse(perUnitTime?.toString() ?? '');
    final qty = double.tryParse(quantity?.toString() ?? '');
    if (perUnitHours == null || qty == null) return '-';

    final totalHoursDecimal = perUnitHours * qty;
    final totalMinutes = (totalHoursDecimal * 60).floor();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) return '${hours}h';
    return '${hours}h${minutes}m';
  }

  static const Color _fixtureTableHeaderColor = Color.fromARGB(255, 57, 73, 95);
  static const Color _fixtureButtonColor = Color(0xFF1A73E8);

  /// Reads `pickedStatusList.Picked` from the fixture (or its mongo payload).
  String _pickedStatusText(Map<String, dynamic> fixture) {
    final source =
        fixture["pickedStatusList"] ??
        fixture["fixtureMongoData"]?[0]?["pickedStatusList"];

    dynamic picked;
    if (source is Map) {
      picked = source["Picked"];
    } else if (source is List && source.isNotEmpty && source.first is Map) {
      picked = (source.first as Map)["Picked"];
    } else {
      picked = fixture["pickedStatus"] ?? fixture["Picked"];
    }

    if (picked == null) return "-";
    if (picked == true ||
        picked == 1 ||
        picked.toString().toLowerCase() == "true") {
      return "Yes";
    }
    return "No";
  }

  Widget _fixtureDataTable(List<dynamic> fixtures) {
    return Responsive.hideScrollbars(
      context,
      LayoutBuilder(
        builder: (context, constraints) {
          final r = Responsive.of(context);
          final headerStyle = TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: r.bodyFontSize,
          );
          final cellStyle = TextStyle(fontSize: r.bodyFontSize);

          return Padding(
            padding: EdgeInsets.symmetric(vertical: r.isPhone ? 8 : 16),
            child: SizedBox(
              width: constraints.maxWidth,
              child: HorizontalScrollFade(
                builder: (context, hCtrl) => SingleChildScrollView(
                  controller: hCtrl,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      border: TableBorder.all(color: Colors.black, width: 1),
                      headingRowColor: WidgetStateProperty.all(
                        _fixtureTableHeaderColor,
                      ),
                      headingTextStyle: headerStyle,
                      dataTextStyle: cellStyle,
                      dataRowMinHeight: r.isPhone ? 36 : 48,
                      dataRowMaxHeight: r.isPhone ? 56 : 64,
                      headingRowHeight: r.isPhone ? 40 : 56,
                      columnSpacing: r.isPhone ? 16 : 24,
                      horizontalMargin: r.isPhone ? 12 : 24,
                      dataRowColor: WidgetStateProperty.all(Colors.white),
                      columns: [
                        DataColumn(label: Text('Fixture', style: headerStyle)),
                        DataColumn(label: Text('Desc', style: headerStyle)),
                        DataColumn(
                          label: Text(
                            'Time To Build/Per Unit',
                            style: headerStyle,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Total Time To Build',
                            style: headerStyle,
                          ),
                        ),
                        DataColumn(label: Text('Currency', style: headerStyle)),
                        DataColumn(label: Text('Qty', style: headerStyle)),
                        DataColumn(label: Text('Amount', style: headerStyle)),
                        DataColumn(
                          label: Text('Picked Status', style: headerStyle),
                        ),
                      ],
                      rows: [
                        for (final raw in fixtures)
                          _fixtureDataRow(raw as Map<String, dynamic>),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  DataRow _fixtureDataRow(Map<String, dynamic> fixture) {
    final isDisabled = fixture["Disabled"] == true;
    final desc =
        fixture["fixtureMongoData"]?[0]?["Description"]?.toString() ?? "-";
    final qty = fixture["Quantity"]?.toString() ?? "-";
    final amt = fixture["Amount"];
    final amtStr = amt != null
        ? "\$${(double.tryParse(amt.toString()) ?? 0).ceil()}"
        : "-";
    final perUnitTimeText = convertPerUnitTimeToMinutes(fixture["Hours"]);
    final totalTimeText = convertDecimalToTime(
      fixture["Hours"],
      fixture["Quantity"],
    );
    final currency = fixture["Currency"]?.toString() ?? "N/A";
    final pickedStatusText = _pickedStatusText(fixture);

    return DataRow(
      color: isDisabled ? WidgetStateProperty.all(Colors.grey.shade400) : null,
      cells: [
        DataCell(
          GestureDetector(
            onTap: () {
              final f = fixture["FixtureNumber"]?.toString().trim() ?? '';
              if (f.isEmpty || f == '-') return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Publicsearch(fixtureNumber: f),
                ),
              );
            },
            child: Container(
              constraints: const BoxConstraints(minWidth: 76),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: const Color.fromARGB(255, 17, 107, 224),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                safeValue(fixture["FixtureNumber"], fallback: "-"),
                textAlign: TextAlign.center,
                softWrap: true,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _fixtureButtonColor,
                ),
              ),
            ),
          ),
        ),
        DataCell(Text(desc)),
        DataCell(Text(perUnitTimeText)),
        DataCell(Text(totalTimeText)),
        DataCell(Text(currency)),
        DataCell(Text(qty)),
        DataCell(Text(amtStr)),
        DataCell(Text(pickedStatusText)),
      ],
    );
  }

  List<Widget> _sopCardRows({
    required List<Widget> cards,
    required int columns,
    required double cardWidth,
    required double gap,
    required bool stretch,
  }) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += columns) {
      final end = i + columns <= cards.length ? i + columns : cards.length;
      rows.add(
        _sopCardRow(cards.sublist(i, end), cardWidth, gap, stretch: stretch),
      );
      if (end < cards.length) {
        rows.add(SizedBox(height: gap));
      }
    }
    return rows;
  }

  Widget _sopCardRow(
    List<Widget> chunk,
    double cardWidth,
    double gap, {
    required bool stretch,
  }) {
    final row = Row(
      crossAxisAlignment: stretch
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        for (var j = 0; j < chunk.length; j++) ...[
          if (j > 0) SizedBox(width: gap),
          SizedBox(
            width: cardWidth,
            child: stretch ? SizedBox.expand(child: chunk[j]) : chunk[j],
          ),
        ],
      ],
    );
    return stretch ? IntrinsicHeight(child: row) : row;
  }

  Widget _searchHeader({
    required Responsive r,
    required Widget sopField,
    required Widget searchButton,
  }) {
    final title = Text(
      "SOP Search",
      style: TextStyle(
        color: Colors.black,
        fontSize: r.pageTitleSize,
        fontWeight: FontWeight.bold,
      ),
    );

    if (r.useInlineSearchHeader) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          title,
          SizedBox(width: r.sectionGap),
          sopField,
          SizedBox(width: r.sectionGap),
          searchButton,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        SizedBox(height: r.isCompactPhone ? 8 : 10),
        SizedBox(
          height: r.searchButtonHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: sopField),
              const SizedBox(width: 8),
              searchButton,
            ],
          ),
        ),
      ],
    );
  }

  // UI Design here
  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final useGrid = r.cardColumns > 1;
    final stretchCards = r.stretchCardRows;

    final sopCards = sopData == null
        ? null
        : <Widget>[
            InfoCard(
              title: "ORDER INFO",
              color: Colors.grey.shade300,
              fillHeight: stretchCards,
              children: [
                infoRow("SOP", safeValue(sopData?["SOPNum"])),
                infoRow("PO Number", safeValue(sopData?["PONum"])),
                infoRow("ODD", formatDate(sopData?["ODD"])),
                infoRow(
                  "Customer",
                  safeValue(sopData?["customer"]?[0]?["Name"]),
                ),
                infoRow("Prgm", safeValue(sopData?["program"]?[0]?["Name"])),
                infoRow(
                  "Location",
                  safeValue(sopData?["location"]?[0]?["Location"]),
                ),
              ],
            ),
            InfoCard(
              title: "SOP ENTRY",
              color: const Color.fromRGBO(255, 204, 204, 1),
              fillHeight: stretchCards,
              children: [
                infoRow("SOP Entry", formatDate(sopData?["SOPEntryDateIn"])),
                infoRow("SOP Out", formatDate(sopData?['SOPOrderEntryOut'])),
                infoRow(
                  "Prod MGR",
                  safeValue(sopData?["sopProductionManager"]?[0]?["Name"]),
                ),
                infoRow(
                  "Order Entry Comments",
                  safeValue(sopData?["OrderEntryComments"]),
                ),
              ],
            ),
            InfoCard(
              title: "PRODUCTION",
              color: const Color.fromRGBO(153, 204, 255, 1),
              fillHeight: stretchCards,
              children: [
                infoRow(
                  "Prod In",
                  formatDate(
                    sopData?["productionEntry"]?[0]?['ProductionSOPDateIn'],
                  ),
                ),
                infoRow(
                  "Lead Hand",
                  safeValue(sopData?["leadHand"]?[0]?["LeadHandName"]),
                ),
                infoRow(
                  "Lead Hand In",
                  formatDate(
                    sopData?["productionEntry"]?[0]?["LeadHandDateIn"],
                  ),
                ),
                infoRow(
                  "Prod Out",
                  formatDate(
                    sopData?["productionEntry"]?[0]?["ProductionDateOut"],
                  ),
                ),
                infoRow(
                  "Prod Comments",
                  safeValue(
                    sopData?["productionEntry"]?[0]?["ProductionComments"],
                  ),
                ),
              ],
            ),
            InfoCard(
              title: "QUALITY CONTROL",
              color: const Color.fromRGBO(240, 230, 140, 1),
              fillHeight: stretchCards,
              children: [
                infoRow(
                  "Final Date Received In QC",
                  formatDate(sopData?["qaEntry"]?[0]?["QCDateIn"]),
                ),
                infoRow(
                  "RW Sent Back To Prod",
                  formatDate(sopData?["qaEntry"]?[0]?["ReworkDateOut"]),
                ),
                infoRow(
                  "QC Out",
                  formatDate(sopData?["qaEntry"]?[0]?["QCOut"]),
                ),
                infoRow(
                  "QC Comments",
                  safeValue(sopData?["qaEntry"]?[0]?["QAComments"]),
                ),
              ],
            ),
            InfoCard(
              title: "SHIPPING",
              color: const Color.fromRGBO(218, 247, 166, 1),
              fillHeight: stretchCards,
              children: [
                infoRow(
                  "Ship In",
                  formatDate(sopData?["shippingEntry"]?[0]?["ShippingDateIn"]),
                ),
                infoRow("Ship Out", formatDate(sopData?["FinalDeliveryDate"])),
              ],
            ),
          ];

    final fieldRadius = r.fieldRadius;
    // Fixed control height — keep field & button identical.
    final controlHeight = r.searchControlHeight;
    final fieldWidth = r.isPhone ? double.infinity : r.searchFieldMaxWidth;
    final borderColor = r.isPhone
        ? const Color(0xFF2196F3)
        : const Color(0xFFBDBDBD);

    final sopField = SizedBox(
      width: r.isPhone ? null : fieldWidth,
      height: controlHeight,
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
          controller: SOPController,
          focusNode: SOPFocusNode,
          // readOnly + TextInputType.none keep the OS keyboard closed on
          // phones/tablets while the caret stays visible for the in-app pad.
          readOnly: SearchKeyboard.isTouchPlatform,
          keyboardType: KeypadInput.keyboardType(),
          showCursor: true,
          onTap: SearchKeyboard.isTouchPlatform
              ? () {
                  setState(() {
                    _useNumericKeyboard = true;
                  });
                }
              : null,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(fontSize: r.searchFieldFontSize),
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: 'Enter SOP Number',
            hintStyle: TextStyle(fontSize: r.searchFieldFontSize),
            filled: true,
            fillColor: Colors.white,
            isCollapsed: false,
            isDense: !r.isPhone,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: r.searchFieldContentPaddingV,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(fieldRadius),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(fieldRadius),
              borderSide: BorderSide(
                color: borderColor,
                width: r.isPhone ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(fieldRadius),
              borderSide: const BorderSide(
                color: Color(0xFF1565C0),
                width: 1.5,
              ),
            ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => handleSOPSearch(),
        ),
      ),
    );

    final searchButton = SizedBox(
      height: controlHeight,
      child: ElevatedButton.icon(
        onPressed: handleSOPSearch,
        icon: Icon(Icons.search, size: r.searchIconSize),
        label: Text(
          'Search',
          style: TextStyle(
            fontSize: r.searchButtonFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: Size(88, controlHeight),
          fixedSize: Size.fromHeight(controlHeight),
          padding: EdgeInsets.symmetric(horizontal: r.isPhone ? 16 : 12),
          visualDensity: r.isPhone
              ? VisualDensity.standard
              : VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(fieldRadius),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(),
      drawer: CommonDrawer(),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth =
                    (constraints.maxWidth - (r.pagePaddingH * 2)).clamp(
                      0.0,
                      r.contentMaxWidth,
                    );
                final cardWidth = r.cardWidthFor(contentWidth);

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          r.pagePaddingH,
                          r.pagePaddingV,
                          r.pagePaddingH,
                          r.pagePaddingV,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: r.contentMaxWidth,
                          ),
                          child: Column(
                            children: [
                              _searchHeader(
                                r: r,
                                sopField: sopField,
                                searchButton: searchButton,
                              ),
                              SizedBox(height: r.sectionGap),
                              if (isLoading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 32),
                                  child: Center(child: AppLoader()),
                                )
                              else if (sopCards != null) ...[
                                if (useGrid)
                                  ..._sopCardRows(
                                    cards: sopCards,
                                    columns: r.cardColumns,
                                    cardWidth: cardWidth,
                                    gap: r.cardGap,
                                    stretch: stretchCards,
                                  )
                                else
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: sopCards,
                                  ),
                                if ((sopData?["fixtures"] as List?)
                                        ?.isNotEmpty ??
                                    false) ...[
                                  SizedBox(height: r.sectionGap),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      "Fixture Data",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: r.sectionTitleSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: r.isPhone ? 8 : 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: _fixtureDataTable(
                                      sopData!["fixtures"] as List,
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_keypadVisible)
            SearchKeyboard(
              isNumeric: _useNumericKeyboard,
              onToggleMode: () {
                setState(() {
                  _useNumericKeyboard = !_useNumericKeyboard;
                });
              },
              onKey: (value) =>
                  SearchKeyboardInput.insert(SOPController, value),
              onBackspace: () => SearchKeyboardInput.backspace(SOPController),
              onSearch: handleSOPSearch,
            ),
        ],
      ),
    );
  }
}
