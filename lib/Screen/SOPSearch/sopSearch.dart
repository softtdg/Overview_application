import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:overview_app/Screen/Public-Search/PublicSearch.dart';
import 'package:overview_app/Screen/SOPSearch/Services/SOPSearchService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:overview_app/Widgets/card.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:overview_app/Screen/Login/login.dart';

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
    // String sopNumber = "70456";

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

      return DateFormat('MM/dd/yyyy').format(parsedDate);
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

  Widget _buildFixtureCard(Map<String, dynamic> fixture) {
    final bool isDisabled = fixture["Disabled"] == true;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDisabled ? const Color(0xFF8B8B8B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
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
                    builder: (_) =>
                        Publicsearch(fixtureNumber: fixture["FixtureNumber"]),
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
            ),
            const SizedBox(height: 10),
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

  // Widget _buildNoticeItem() {
  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 10),
  //     padding: const EdgeInsets.all(10),
  //     decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Container(
  //           width: 8,
  //           height: 8,
  //           margin: const EdgeInsets.only(top: 6),
  //           decoration: const BoxDecoration(shape: BoxShape.circle),
  //         ),
  //         const SizedBox(width: 10),
  //         const Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 "Notice message goes here...",
  //                 style: TextStyle(fontWeight: FontWeight.w500),
  //               ),
  //               SizedBox(height: 4),
  //               Text(
  //                 "Response / ETA / Status",
  //                 style: TextStyle(color: Colors.grey),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // static const Color _drawerBrand = Color.fromARGB(255, 57, 73, 95);

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

  // Widget _buildSimpleDrawer() {
  //   return Drawer(
  //     backgroundColor: Colors.white,
  //     child: SafeArea(
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.end,
  //         children: [
  //           Container(
  //             width: double.infinity,
  //             color: Colors.white,
  //             padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
  //             child: Column(
  //               children: [
  //                 Image.asset(
  //                   'assets/images/tdg_logo.png',
  //                   height: 52,
  //                   fit: BoxFit.contain,
  //                   errorBuilder: (_, __, ___) => const Icon(
  //                     Icons.business_rounded,
  //                     size: 48,
  //                     color: _drawerBrand,
  //                   ),
  //                 ),
  //                 const SizedBox(height: 16),
  //                 Text(
  //                   username.isEmpty ? 'User' : username,
  //                   textAlign: TextAlign.center,
  //                   style: const TextStyle(
  //                     fontSize: 17,
  //                     fontWeight: FontWeight.w600,
  //                     color: Color(0xFF1A1A1A),
  //                   ),
  //                   maxLines: 2,
  //                   overflow: TextOverflow.ellipsis,
  //                 ),
  //                 // const SizedBox(height: 12),
  //                 Container(
  //                   // padding: const EdgeInsets.symmetric(
  //                   //   horizontal: 14,
  //                   //   vertical: 10,
  //                   // ),
  //                   child: Row(
  //                     mainAxisAlignment: MainAxisAlignment.center,
  //                     children: [
  //                       Text(
  //                         'Sign out',
  //                         style: TextStyle(
  //                           color: _drawerBrand,
  //                           fontSize: 14,
  //                           fontWeight: FontWeight.w600,
  //                         ),
  //                       ),
  //                       IconButton(
  //                         padding: EdgeInsets.zero,
  //                         constraints: const BoxConstraints(),
  //                         style: IconButton.styleFrom(
  //                           minimumSize: const Size(36, 36),
  //                         ),
  //                         icon: const Icon(Icons.logout_rounded),
  //                         color: _drawerBrand,
  //                         onPressed: () {
  //                           Navigator.pop(context);
  //                           WidgetsBinding.instance.addPostFrameCallback((_) {
  //                             if (!mounted) return;
  //                             _showLogoutConfirmDialog();
  //                           });
  //                         },
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           Container(
  //             height: 1,
  //             decoration: BoxDecoration(
  //               border: Border(
  //                 bottom: BorderSide(color: _drawerBrand, width: 1),
  //               ),
  //               boxShadow: [
  //                 BoxShadow(
  //                   color: Colors.black.withValues(alpha: 0.12),
  //                   blurRadius: 8,
  //                   offset: const Offset(0, 4),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           Expanded(
  //             child: ListView(
  //               padding: const EdgeInsets.symmetric(vertical: 8),
  //               children: [
  //                 ListTile(
  //                   leading: Icon(Icons.search_rounded, color: _drawerBrand),
  //                   title: const Text('SOP Search'),
  //                   onTap: () => Navigator.pop(context),
  //                 ),
  //                 ListTile(
  //                   leading: Icon(Icons.public_rounded, color: _drawerBrand),
  //                   title: const Text('Public Search'),
  //                   onTap: () {
  //                     Navigator.pop(context);
  //                     Navigator.push(
  //                       context,
  //                       MaterialPageRoute(builder: (_) => Publicsearch()),
  //                     );
  //                   },
  //                 ),
  //                 ListTile(
  //                   leading: Icon(Icons.public, color: _drawerBrand),
  //                   title: const Text("Picked History"),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           Padding(
  //             padding: const EdgeInsets.all(16),
  //             child: Text(
  //               'TDG Overview',
  //               textAlign: TextAlign.center,
  //               style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // UI Design here
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 700;
    final horizontalPadding = isTablet ? 24.0 : 16.0;
    final contentMaxWidth = isTablet ? 820.0 : double.infinity;
    final searchControlWidth = isTablet ? 420.0 : double.infinity;
    final searchButtonWidth = isTablet ? 200.0 : double.infinity;

    return Scaffold(
      backgroundColor: Colors.white,
      // drawer: _buildSimpleDrawer(),
      // appBar: AppBar(
      //   backgroundColor: Color.fromARGB(255, 57, 73, 95),
      //   automaticallyImplyLeading: false,
      //   iconTheme: const IconThemeData(color: Colors.white),
      //   title: Row(
      //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //     children: [
      //       Image.asset('assets/images/tdg_logo.png', height: 35),
      //       Builder(
      //         builder: (context) {
      //           return IconButton(
      //             icon: const Icon(Icons.menu, color: Colors.white),
      //             onPressed: () => Scaffold.of(context).openDrawer(),
      //           );
      //         },
      //       ),
      //       // title: Text(
      //       //   username,
      //       //   style: TextStyle(
      //       //     color: Colors.white,
      //       //     fontSize: 18,
      //       //     fontWeight: FontWeight.bold,
      //       //     // ),
      //       //   ),
      //     ],
      //   ),
      // ),
      appBar: const CommonAppBar(),
      drawer: CommonDrawer(
        username: username,
        onLogout: _showLogoutConfirmDialog,
      ),

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
                  width: contentMaxWidth,
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
                              borderSide: BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color.fromARGB(255, 22, 129, 218),
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
                      ),

                      SizedBox(height: 16),

                      SizedBox(height: 16),

                      if (isLoading)
                        Center(
                          child: CircularProgressIndicator(
                            color: Color.fromARGB(255, 57, 73, 95),
                          ),
                        )
                      else if (sopData != null) ...[
                        InfoCard(
                          title: "ORDER INFO",
                          color: Colors.grey.shade300,
                          children: [
                            infoRow("SOP", safeValue(sopData?["SOPNum"])),
                            infoRow("PO Number", safeValue(sopData?["PONum"])),
                            infoRow("ODD", formatDate(sopData?["ODD"])),
                            infoRow(
                              "Customer",
                              safeValue(sopData?["customer"]?[0]?["Name"]),
                            ),
                            infoRow(
                              "Prgm",
                              safeValue(sopData?["program"]?[0]?["Name"]),
                            ),
                            infoRow(
                              "Location",
                              safeValue(sopData?["location"]?[0]?["Location"]),
                            ),
                          ],
                        ),

                        // SOP ENTRY
                        InfoCard(
                          title: "SOP ENTRY",
                          color: Color.fromRGBO(255, 204, 204, 1),
                          children: [
                            infoRow(
                              "SOP Entry",
                              formatDate(sopData?["SOPEntryDateIn"]),
                            ),
                            infoRow(
                              "SOP Out",
                              formatDate(sopData?['SOPOrderEntryOut']),
                            ),
                            infoRow(
                              "Prod MGR",
                              safeValue(
                                sopData?["sopProductionManager"]?[0]?["Name"],
                              ),
                            ),
                            // divider(),
                            infoRow(
                              "Order Entry Comments",
                              safeValue(sopData?["OrderEntryComments"]),
                            ),
                          ],
                        ),

                        // PRODUCTION
                        InfoCard(
                          title: "PRODUCTION",
                          color: Color.fromRGBO(153, 204, 255, 1),
                          children: [
                            infoRow(
                              "Prod In",
                              formatDate(
                                sopData?["productionEntry"]?[0]?['ProductionSOPDateIn'],
                              ),
                            ),
                            infoRow(
                              "Lead Hand",
                              safeValue(
                                sopData?["leadHand"]?[0]?["LeadHandName"],
                              ),
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
                            // divider(),
                            infoRow(
                              "Prod Comments",
                              safeValue(
                                sopData?["productionEntry"]?[0]?["ProductionComments"],
                              ),
                            ),
                          ],
                        ),

                        // QUALITY CONTROL
                        InfoCard(
                          title: "QUALITY CONTROL",
                          color: Color.fromRGBO(240, 230, 140, 1),
                          children: [
                            infoRow(
                              "Final Date Received In QC",
                              formatDate(sopData?["qaEntry"]?[0]?["QCDateIn"]),
                            ),
                            infoRow(
                              "RW Sent Back To Prod",
                              formatDate(
                                sopData?["qaEntry"]?[0]?["ReworkDateOut"],
                              ),
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
                          children: [
                            infoRow(
                              "Ship In",
                              formatDate(
                                sopData?["shippingEntry"]?[0]?["ShippingDateIn"],
                              ),
                            ),
                            infoRow(
                              "Ship Out",
                              formatDate(sopData?["FinalDeliveryDate"]),
                            ),
                          ],
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
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: (sopData?["fixtures"] as List).length,
                            itemBuilder: (context, index) => _buildFixtureCard(
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
