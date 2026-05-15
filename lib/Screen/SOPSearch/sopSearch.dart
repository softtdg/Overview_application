import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:overview_app/Screen/Public-Search/PublicSearch.dart';
import 'package:overview_app/Screen/SOPSearch/Services/SOPSearchService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:overview_app/Widgets/card.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SOPSearch extends StatefulWidget {
  @override
  _SOPSearchState createState() => _SOPSearchState();
}

class _SOPSearchState extends State<SOPSearch> {
  // controller for take a input
  final TextEditingController SOPController = TextEditingController();
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
  }

  void handleSOPSearch() async {
    if (isLoading) return;

    String sopNumber = SOPController.text.trim();

    // check emptry sop search
    if (sopNumber.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Enter SOP Number")));
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Data Loaded")));

      // print("SOP Search Data From SOPSearch --===---==--->: $response");
    } catch (e) {
      print("SOP Error --------> $e");

      // Show backend 401 message
      if (e is DioException) {
        print("SOP Request URL --------> ${e.requestOptions.uri}");
        print("SOP Request Headers --------> ${e.requestOptions.headers}");
        print("SOP Error Data --------> ${e.response}");
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to fetch SOP")));
    }
    setState(() {
      isLoading = false;
    });
  }

  String formatDate(dynamic date) {
    if (date == null) return "-";

    try {
      String dateStr = date.toString();
      if (dateStr.startsWith("0001-01-01")) {
        return "*";
      }
      DateTime parsedDate = DateTime.parse(dateStr);

      return DateFormat('dd/MM/yyyy').format(parsedDate);
    } catch (e) {
      print("Date parse error: $e");
      return "";
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

  Widget _fixtureDataTable(List<dynamic> fixtures) {
    const headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  border: TableBorder.all(color: Colors.black, width: 1),
                  headingRowColor: WidgetStateProperty.all(
                    _fixtureTableHeaderColor,
                  ),
                  headingTextStyle: headerStyle,
                  dataRowColor: WidgetStateProperty.all(Colors.white),
                  columns: const [
                    DataColumn(label: Text('Fixture', style: headerStyle)),
                    DataColumn(label: Text('Desc', style: headerStyle)),
                    DataColumn(
                      label: Text('Time To Build/Per Unit', style: headerStyle),
                    ),
                    DataColumn(
                      label: Text('Total Time To Build', style: headerStyle),
                    ),
                    DataColumn(label: Text('Currency', style: headerStyle)),
                    DataColumn(label: Text('Qty', style: headerStyle)),
                    DataColumn(label: Text('Amount', style: headerStyle)),
                  ],
                  rows: [
                    for (final raw in fixtures)
                      _fixtureDataRow(raw as Map<String, dynamic>),
                  ],
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

    return DataRow(
      color: isDisabled ? WidgetStateProperty.all(Colors.grey.shade400) : null,
      cells: [
        DataCell(
          GestureDetector(
            onTap: isDisabled
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Publicsearch(
                          fixtureNumber: fixture["FixtureNumber"],
                        ),
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
      ],
    );
  }

  static const double _tabletCardGap = 12;

  List<Widget> _tabletSopCardRows(List<Widget> cards, double cardWidth) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 3) {
      final end = i + 3 <= cards.length ? i + 3 : cards.length;
      rows.add(_tabletSopCardRow(cards.sublist(i, end), cardWidth));
      if (end < cards.length) {
        rows.add(const SizedBox(height: _tabletCardGap));
      }
    }
    return rows;
  }

  Widget _tabletSopCardRow(List<Widget> chunk, double cardWidth) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var j = 0; j < chunk.length; j++) ...[
            if (j > 0) SizedBox(width: _tabletCardGap),
            SizedBox(
              width: cardWidth,
              child: SizedBox.expand(child: chunk[j]),
            ),
          ],
        ],
      ),
    );
  }

  // static const Color _drawerBrand = Color.fromARGB(255, 57, 73, 95);

  // UI Design here
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 700;
    final horizontalPadding = isTablet ? 24.0 : 16.0;
    final tabletCardWidth = isTablet
        ? (screenWidth - 2 * horizontalPadding - 24) / 3
        : 0.0;

    final sopCards = sopData == null
        ? null
        : <Widget>[
            InfoCard(
              title: "ORDER INFO",
              color: Colors.grey.shade300,
              fillHeight: isTablet,
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
              color: Color.fromRGBO(255, 204, 204, 1),
              fillHeight: isTablet,
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
              color: Color.fromRGBO(153, 204, 255, 1),
              fillHeight: isTablet,
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
              color: Color.fromRGBO(240, 230, 140, 1),
              fillHeight: isTablet,
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
              title: "QUALITY CONTROL",
              color: Color.fromRGBO(218, 247, 166, 1),
              fillHeight: isTablet,
              children: [
                infoRow(
                  "Ship In",
                  formatDate(sopData?["shippingEntry"]?[0]?["ShippingDateIn"]),
                ),
                infoRow("Ship Out", formatDate(sopData?["FinalDeliveryDate"])),
              ],
            ),
          ];

    final sopField = TextField(
      controller: SOPController,
      decoration: InputDecoration(
        hintText: 'Enter SOP Number',
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: isTablet ? 12 : 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTablet ? 4 : 12),
          borderSide: BorderSide(
            color: isTablet ? const Color(0xFFBDBDBD) : const Color(0xFF2196F3),
            width: isTablet ? 1 : 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTablet ? 4 : 12),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => handleSOPSearch(),
    );
    final searchButton = ElevatedButton.icon(
      onPressed: handleSOPSearch,
      icon: const Icon(Icons.search, size: 20),
      label: const Text('Search'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTablet ? 4 : 12),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(),
      drawer: CommonDrawer(),

      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      if (isTablet)
                        Row(
                          children: [
                            const Text(
                              "SOP Search",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(width: 360, child: sopField),
                            const SizedBox(width: 16),
                            searchButton,
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "SOP Search",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            sopField,
                            const SizedBox(height: 10),
                            searchButton,
                          ],
                        ),

                      SizedBox(height: 16),

                      SizedBox(height: 16),

                      if (isLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            color: Color.fromARGB(255, 57, 73, 95),
                          ),
                        )
                      else if (sopCards != null) ...[
                        if (isTablet)
                          ..._tabletSopCardRows(sopCards, tabletCardWidth)
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: sopCards,
                          ),

                        if ((sopData?["fixtures"] as List?)?.isNotEmpty ??
                            false) ...[
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Fixture Data",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: isTablet ? 22 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
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
        ),
      ),
    );
  }
}
