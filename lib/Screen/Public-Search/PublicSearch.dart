import 'package:flutter/material.dart';
import 'package:overview_app/Screen/Public-Search/Services/PublicSearchService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
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
  final Publicsearchservice _service = Publicsearchservice();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController PublicSearchController = TextEditingController();
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
    loadUserName();
    final passed = widget.fixtureNumber?.toString().trim();
    if (passed != null && passed.isNotEmpty) {
      PublicSearchController.text = passed;
      performSearch();
    }
  }

  Future<void> performSearch() async {
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
  }

  void _handleNewSearch() {
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
      print("Full response: ${response.data}");
      final data = response.data["data"];

      setState(() {
        sopList = data is List ? List<Map<String, dynamic>>.from(data) : [];
        isSopLoading = false;
      });
      // print("SOP Data ------------------>: $sopList");
    } catch (e) {
      print("Error fetching SOP Data $e");
      setState(() {
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
        result = data;
        final components = data["data"]?["Fixture"]?["Components"];

        items = components is List
            ? components.map<ItemModel>((e) {
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
                  color: e["color"]?.toString() ?? "white",
                );
              }).toList()
            : [];
        isTableLoading = false;
      });

      // print(data["data"].runtimeType);
      // print(data["data"]);

      // print("Response for Public Serach ${response.data}");
    } catch (e) {
      print("Error Public Search Fetch Data $e");
      setState(() {
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

  Widget _buildSOPCard(String sop, String date, String qty) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        // color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "SOP",
            style: TextStyle(
              fontSize: 14,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sop,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text("Date: $date", style: const TextStyle(fontSize: 14)),
          Text("Qty: $qty", style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  static const List<double> _bomColWidths = [130, 240, 220, 80, 90, 150, 150];

  /// Row width = TDGPN + Description + Material + (Qty/Size/UOM) + State + Vendor + FileName.
  double get _minBomTableWidth =>
      _bomColWidths[0] +
      _bomColWidths[1] +
      _bomColWidths[2] +
      3 * _bomColWidths[3] +
      _bomColWidths[4] +
      _bomColWidths[5] +
      _bomColWidths[6];

  List<double> _columnWidthsForBomTable(double available) {
    final sum = _minBomTableWidth;
    if (available <= sum) {
      return List<double>.from(_bomColWidths);
    }
    final scale = available / sum;
    return _bomColWidths.map((w) => w * scale).toList();
  }

  double _bomTableWidthFor(List<double> widths) =>
      widths[0] +
      widths[1] +
      widths[2] +
      3 * widths[3] +
      widths[4] +
      widths[5] +
      widths[6];

  Widget _bomHeaderCell(String label, double w) {
    final borderColor = Colors.grey.shade300;
    return SizedBox(
      width: w,
      height: 40,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 57, 73, 95),
          border: Border(
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            height: 1.0,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _bomDataCell(String value, double w) {
    final borderColor = Colors.grey.shade300;
    return SizedBox(
      width: w,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
        child: Text(
          value,
          maxLines: 1,
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final searchFieldWidth = (screenWidth - 32).clamp(240.0, 420.0);

    return Scaffold(
      appBar: const CommonAppBar(),
      drawer: const CommonDrawer(),
      backgroundColor: Colors.white,

      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Center(
                  child: Text(
                  "Public Search",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ),
                
              ),

              if (hasSearched) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: _handleNewSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shadowColor: Colors.black.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text(
                        "New Search",
                        style: TextStyle(
                          fontSize: 14,
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
                    child: TextField(
                      controller: PublicSearchController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        // prefixIcon: Icon(Icons.lock),
                        hintText: 'Enter Fixture Number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 22, 129, 218),
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.blue,
                            width: 1,
                          ),
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => performSearch(),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 45,
                        width: 200,
                        child: ElevatedButton(
                          onPressed: (isSopLoading || isTableLoading)
                              ? null
                              : performSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromARGB(255, 57, 73, 95),
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
                    ],
                  ),
                ),
              ],

              SizedBox(height: 16),

              if (hasSearched)
                const Text(
                  "Available SOPs",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),

              const SizedBox(height: 16),
              if (isSopLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color.fromARGB(255, 57, 73, 95),
                    ),
                  ),
                )
              else ...[
                SizedBox(
                  height: 180,
                  child: !hasSearched
                      ? const SizedBox.shrink()
                      : sopList.isEmpty
                      ? const Center(child: Text("No SOP Data Found"))
                      : Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: sopList.length,
                            itemBuilder: (context, index) {
                              final item = sopList[index];

                              return _buildSOPCard(
                                item["SOPNum"]?.toString() ?? "-",
                                formatDate(item["ODD"]),
                                item["Quantity"]?.toString() ?? "-",
                              );
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                if (isTableLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color.fromARGB(255, 57, 73, 95),
                      ),
                    ),
                  )
                else if (hasSearched && items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text("No table data found")),
                  )
                else if (hasSearched)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final available = constraints.maxWidth;
                      final colW = _columnWidthsForBomTable(available);
                      final tableW = _bomTableWidthFor(colW);

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: SizedBox(
                            width: tableW,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _bomHeaderCell("TDGPN", colW[0]),
                                    _bomHeaderCell("Description", colW[1]),
                                    _bomHeaderCell("Material", colW[2]),
                                    _bomHeaderCell("Quantity", colW[3]),
                                    _bomHeaderCell("Size", colW[3]),
                                    _bomHeaderCell("UOM", colW[3]),
                                    _bomHeaderCell("State", colW[4]),
                                    _bomHeaderCell("Vendor", colW[5]),
                                    _bomHeaderCell("FileName", colW[6]),
                                  ],
                                ),
                                for (final item in items)
                                  Container(
                                    color: (item.color.toLowerCase() == "white")
                                        ? Colors.white
                                        : Color(
                                            int.parse(
                                              "0xFF${item.color.replaceAll("#", "")}",
                                            ),
                                          ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _bomDataCell(item.tdgPn, colW[0]),
                                        _bomDataCell(
                                          item.description,
                                          colW[1],
                                        ),
                                        _bomDataCell(item.material, colW[2]),
                                        _bomDataCell(
                                          item.quantity.toString(),
                                          colW[3],
                                        ),
                                        _bomDataCell(
                                          item.size.toString(),
                                          colW[3],
                                        ),
                                        _bomDataCell(
                                          item.UOM.toString(),
                                          colW[3],
                                        ),
                                        _bomDataCell(item.state, colW[4]),
                                        _bomDataCell(item.vendor, colW[5]),
                                        _bomDataCell(
                                          item.PathName,
                                          colW[6],
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
