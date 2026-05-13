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

  Widget _buildFixtureCard(
    Map<String, dynamic> fixture, {
    bool compact = false,
  }) {
    final bool isDisabled = fixture["Disabled"] == true;
    return Card(
      margin: compact
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDisabled
              ? const Color(0xFF5C5C5C)
              : const Color.fromARGB(255, 141, 143, 145),
          width: 1.5,
        ),
      ),
      color: isDisabled ? const Color(0xFF8B8B8B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Fixture Data",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Publicsearch(
                          fixtureNumber: fixture["FixtureNumber"],
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF5FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF1A73E8),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      "Fixture # ${fixture["FixtureNumber"] ?? "-"}",
                      style: const TextStyle(
                        color: Color(0xFF1A73E8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Description: ${fixture["fixtureMongoData"]?[0]?["Description"] ?? "-"}",
                  style: const TextStyle(fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Qty: ${fixture["Quantity"] ?? "-"}",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  child: Text(
                    "Amount: \$${fixture["Amount"] != null ? (double.tryParse(fixture["Amount"].toString()) ?? 0).ceil() : "-"}",
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
    final searchControlWidth = isTablet ? 420.0 : double.infinity;
    final searchButtonWidth = isTablet ? 200.0 : double.infinity;
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
                      Align(
                        alignment: Alignment.topCenter,
                        child: Text(
                          "SOP Search",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: isTablet ? 24 : 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // SOP Input
                      SizedBox(
                        width: searchControlWidth,
                        child: TextField(
                          controller: SOPController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Enter SOP Number',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color.fromARGB(255, 22, 129, 218),
                                width: 2,
                              ),
                            ),
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => handleSOPSearch(),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // search button
                      SizedBox(
                        width: searchButtonWidth,
                        child: SizedBox(
                          height: 45,
                          child: ElevatedButton(
                            onPressed: handleSOPSearch,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                57,
                                73,
                                95,
                              ),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Search",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
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
                          if (isTablet)
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: (sopData?["fixtures"] as List).length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    mainAxisExtent: 180,
                                  ),
                              itemBuilder: (context, index) =>
                                  _buildFixtureCard(
                                    (sopData?["fixtures"][index]
                                        as Map<String, dynamic>),
                                    compact: true,
                                  ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: (sopData?["fixtures"] as List).length,
                              itemBuilder: (context, index) =>
                                  _buildFixtureCard(
                                    (sopData?["fixtures"][index]
                                        as Map<String, dynamic>),
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
