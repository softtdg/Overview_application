import 'package:flutter/material.dart';
import 'package:overview_app/Screen/Public-Search/Services/PublicSearchService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/SOPSearch/sopSearch.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:overview_app/Screen/Login/login.dart';

class ItemModel {
  final String tdgPn;
  final String description;
  final String material;
  final String state;
  final String vendor;
  final String PathName;
  final double quantity;
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
  bool isLoading = true;
  String username = "";

  /// Same fixture string used for both APIs — from the text field (or prefilled from navigation).
  String get _fixtureNumberInput => PublicSearchController.text.trim();

  @override
  void initState() {
    super.initState();
    loadUserName();
    final passed = widget.fixtureNumber?.toString().trim();
    if (passed != null && passed.isNotEmpty) {
      PublicSearchController.text = passed;
      fetchData();
      fetchFixtureDetailsData();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Same as when you tap a fixture from SOP search: `PublicSearchService` + `FixtureDetailsService`.
  Future<void> performSearch() async {
    if (_fixtureNumberInput.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter fixture number')));
      return;
    }
    await fetchData();
    await fetchFixtureDetailsData();
  }

  Future<void> fetchFixtureDetailsData() async {
    if (_fixtureNumberInput.isEmpty) {
      setState(() {
        isLoading = false;
      });
    }

    setState(() {
      isLoading = true;
    });
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
      });
      isLoading = false;
      // print("SOP Data ------------------>: $sopList");
    } catch (e) {
      print("Error fetching SOP Data $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchData() async {
    final fixtureNumber = _fixtureNumberInput;
    if (fixtureNumber.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }
    setState(() {
      isLoading = true;
    });
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
                  color: e["color"]?.toString() ?? "white",
                );
              }).toList()
            : [];
        isLoading = false;
      });

      // print(data["data"].runtimeType);
      // print(data["data"]);

      // print("Response for Public Serach ${response.data}");
    } catch (e) {
      print("Error Public Search Fetch Data $e");
      setState(() {
        isLoading = false;
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

  static const List<double> _bomColWidths = [90, 150, 150, 150, 150, 150, 150];
  static const Color _drawerBrand = Color.fromARGB(255, 57, 73, 95);

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

  void _showLogoutConfirmDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token');
              await prefs.remove('UserName');
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => LoginPage()),
                (route) => false,
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/tdg_logo.png',
                    height: 52,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.business_rounded,
                      size: 48,
                      color: _drawerBrand,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    username.isEmpty ? 'User' : username,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // const SizedBox(height: 12),
                  Container(
                    // padding: const EdgeInsets.symmetric(
                    //   horizontal: 14,
                    //   vertical: 10,
                    // ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sign out',
                          style: TextStyle(
                            color: _drawerBrand,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(36, 36),
                          ),
                          icon: const Icon(Icons.logout_rounded),
                          color: _drawerBrand,
                          onPressed: () {
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              _showLogoutConfirmDialog();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: _drawerBrand, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: Icon(Icons.search_rounded, color: _drawerBrand),
                    title: const Text('SOP Search'),
                    onTap: () => {
                      Navigator.pop(context),
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SOPSearch()),
                      ),
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.public_rounded, color: _drawerBrand),
                    title: const Text('Public Search'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => Publicsearch()),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'TDG Overview',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildSimpleDrawer(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 57, 73, 95),
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Image.asset('assets/images/tdg_logo.png', height: 35),
            Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                );
              },
            ),
          ],
        ),
      ),

      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Public Search",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Container(
                // padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // SizedBox(width: 10),
                    Expanded(
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
                            borderSide: BorderSide(
                              color: const Color.fromARGB(255, 22, 129, 218),
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.blue,
                              width: 1,
                            ),
                          ),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => performSearch(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // search and fixture details button with flex
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 45,
                      width: 200, // give fixed width (since no Expanded)
                      child: ElevatedButton(
                        onPressed: performSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 57, 73, 95),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
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

              SizedBox(height: 16),

              Text(
                "Available SOPs",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),

              SizedBox(height: 16),
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color.fromARGB(255, 57, 73, 95),
                    ),
                  ),
                )
              else ...[
                SizedBox(
                  height: 180,
                  child: sopList.isEmpty
                      ? Center(child: Text("No SOP Data Found"))
                      : Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: ListView.builder(
                            padding: EdgeInsets.only(bottom: 24),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bomHeaderCell("TDGPN", _bomColWidths[0]),
                            _bomHeaderCell("Description", _bomColWidths[1]),
                            _bomHeaderCell("Material", _bomColWidths[2]),
                            _bomHeaderCell("Quantity", _bomColWidths[3]),
                            _bomHeaderCell("State", _bomColWidths[4]),
                            _bomHeaderCell("Vendor", _bomColWidths[5]),
                            _bomHeaderCell("FileName", _bomColWidths[6]),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _bomDataCell(item.tdgPn, _bomColWidths[0]),
                                _bomDataCell(
                                  item.description,
                                  _bomColWidths[1],
                                ),
                                _bomDataCell(
                                  item.material,
                                  _bomColWidths[2],
                                ),
                                _bomDataCell(
                                  item.quantity.toString(),
                                  _bomColWidths[3],
                                ),
                                _bomDataCell(item.state, _bomColWidths[4]),
                                _bomDataCell(item.vendor, _bomColWidths[5]),
                                _bomDataCell(
                                  item.PathName,
                                  _bomColWidths[6],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
