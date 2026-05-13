import 'package:flutter/material.dart';
import 'package:overview_app/Screen/OpenItems/Components/BackOrder.dart';
import 'package:overview_app/Screen/OpenItems/Services/OpenItemsServices.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class SearchOpenItems extends StatefulWidget {
  final String username = "";
  @override
  _SearchOpenItemsState createState() => _SearchOpenItemsState();
}

class _SearchOpenItemsState extends State<SearchOpenItems> {
  final String username = "";
  final TextEditingController SearchController = TextEditingController();
  bool isLoading = false;
  List<dynamic>? SOPData;
  Map<String, dynamic>? selectedOpenItem;

  /// getSOPList returns `{ "data": { "sop": {...}, "fixtures": [ ... ] } }`.
  List<dynamic>? _rowsFromResponse(dynamic body, [int depth = 0]) {
    if (body == null || depth > 10) return null;
    if (body is List) return body;
    if (body is! Map) return null;
    final map = Map<dynamic, dynamic>.from(body);
    const keys = [
      'fixtures',
      'openItems',
      'lineItems',
      'items',
      'rows',
      'results',
      'list',
      'content',
      'records',
      'data',
    ];
    for (final key in keys) {
      if (!map.containsKey(key)) continue;
      final v = map[key];
      if (v is List) return v;
      if (v is Map) {
        final nested = _rowsFromResponse(v, depth + 1);
        if (nested != null) return nested;
      }
    }
    for (final v in map.values) {
      if (v is List) return v;
      if (v is Map) {
        final nested = _rowsFromResponse(v, depth + 1);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  void handleSOPSearch() async {
    if (isLoading) return;

    String SOPNumber = SearchController.text.trim();

    // check emptry sop search
    if (SOPNumber.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Enter SOP Number")));
      return;
    }

    setState(() {
      isLoading = true;
    });
    debugPrint("Open Items search clicked. SOP: $SOPNumber");

    try {
      await Dioservices.setToken();
      final response = await OpenItemsServices().SearchOpenItemsSOP(
        SOP: SOPNumber,
      );
      debugPrint("Open Items API status: ${response.statusCode}");
      debugPrint("Open Items API raw response: ${response.data}");

      setState(() {
        SOPData = _rowsFromResponse(response.data);
        selectedOpenItem = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("SOP found")));

      debugPrint("SOP Data From Open Items Search: $SOPData");
    } catch (e) {
      debugPrint("Error in Search Open Items: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Search failed: $e")));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _itemValue(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  void _handleFixtureClick(Map<String, dynamic> item) {
    setState(() {
      selectedOpenItem = item;
    });
  }

  Widget _buildTable(List data) {
    final count = data.length;
    final headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      // color: _tableHeaderTextColor,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Header: total row count + labels spaced across full width (same flex as data rows)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    '$count FIXTURES',
                    style: headerStyle,
                    textAlign: TextAlign.start,
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    'DESCRIPTION',
                    style: headerStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'QTY',
                    style: headerStyle,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 5),

          // Data Rows — API uses FixtureNumber, Description, Quantity (PascalCase)
          ...data.map((raw) {
            if (raw is! Map) return const SizedBox.shrink();
            final item = Map<String, dynamic>.from(raw);
            final fixture = (item['FixtureNumber'] ?? item['fixture'] ?? '')
                .toString();
            final description =
                (item['Description'] ?? item['description'] ?? '').toString();
            final qty = (item['Quantity'] ?? item['qty'] ?? item['Qty'] ?? '')
                .toString();
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () => _handleFixtureClick(item),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF1976D2)),
                        ),
                        child: Text(
                          fixture,
                          style: const TextStyle(
                            color: Color(0xFF1976D2),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(flex: 5, child: Text(description)),
                  Expanded(
                    flex: 1,
                    child: Text(qty, textAlign: TextAlign.right),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 700;
    final horizontalPadding = selectedOpenItem != null
        ? (isTablet ? 12.0 : 16.0)
        : (isTablet ? 24.0 : 16.0);
    final contentMaxWidth = isTablet && selectedOpenItem == null
        ? 820.0
        : double.infinity;
    final searchControlWidth = isTablet ? 420.0 : double.infinity;
    final searchButtonWidth = isTablet ? 200.0 : double.infinity;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(),
      drawer: CommonDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth - (horizontalPadding * 2);
          final contentWidth = selectedOpenItem != null
              ? availableWidth
              : (contentMaxWidth.isFinite ? contentMaxWidth : availableWidth);

          return SingleChildScrollView(
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
                    width: contentWidth,
                    child: selectedOpenItem != null
                        ? (() {
                            final item = selectedOpenItem!;
                            final fixtureId = _itemValue(item, [
                              'FixtureNumber',
                            ]);
                            final description = _itemValue(item, [
                              'Description',
                            ]);
                            final qty = _itemValue(item, ['Quantity']);
                            final sopLeadHandEntryId = _itemValue(item, [
                              'SOPLeadHandEntryId',
                            ]);

                            return BackOrder(
                              sop: SearchController.text.trim(),
                              odd: _itemValue(item, ['ODD', 'odd', 'Date']),
                              leadHand: _itemValue(item, ['LeadHand']),
                              assembler: _itemValue(item, ['Assembler']),
                              fixtureId: fixtureId.isEmpty ? '-' : fixtureId,
                              description: description.isEmpty
                                  ? 'No description'
                                  : description,
                              qty: qty.isEmpty ? '0' : qty,
                              sopLeadHandEntryId: sopLeadHandEntryId,
                              onNewSearch: () {
                                SearchController.clear();
                                setState(() {
                                  SOPData = null;
                                  selectedOpenItem = null;
                                });
                              },
                            );
                          })()
                        : Column(
                            children: [
                              Align(
                                alignment: Alignment.topCenter,
                                child: Text(
                                  "Open Items Search",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: isTablet ? 24 : 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: searchControlWidth,
                                child: TextField(
                                  controller: SearchController,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: 'Enter SOP Number (e.g., 70101)',
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
                                        color: Color(0xFF1565C0),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => handleSOPSearch(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: searchButtonWidth,
                                child: SizedBox(
                                  height: 45,
                                  child: ElevatedButton(
                                    onPressed: isLoading
                                        ? null
                                        : handleSOPSearch,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color.fromARGB(
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
                              const SizedBox(height: 20),
                              if (SOPData != null && SOPData!.isNotEmpty)
                                _buildTable(SOPData!),
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
}
