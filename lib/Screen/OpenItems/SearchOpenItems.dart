import 'package:flutter/material.dart';
import 'package:overview_app/Screen/OpenItems/Components/BackOrder.dart';
import 'package:overview_app/Screen/OpenItems/Services/OpenItemsServices.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/AppToast.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    SearchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    SearchController.removeListener(_onSearchTextChanged);
    SearchController.dispose();
    super.dispose();
  }

  /// Hide the results box as soon as the SOP field is cleared.
  void _onSearchTextChanged() {
    if (SearchController.text.trim().isNotEmpty) return;
    if (SOPData == null && !isLoading) return;
    setState(() {
      SOPData = null;
      isLoading = false;
      selectedOpenItem = null;
    });
  }

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
      AppToast.error(context, "Please enter SOP number");
      return;
    }

    setState(() {
      isLoading = true;
      SOPData = null;
      selectedOpenItem = null;
    });

    try {
      await Dioservices.setToken();
      final response = await OpenItemsServices().SearchOpenItemsSOP(
        SOP: SOPNumber,
      );

      if (!mounted) return;
      // Field was cleared while the request was in flight — keep the box hidden.
      if (SearchController.text.trim().isEmpty) {
        setState(() {
          SOPData = null;
          isLoading = false;
          selectedOpenItem = null;
        });
        return;
      }
      setState(() {
        SOPData = _rowsFromResponse(response.data) ?? [];
        selectedOpenItem = null;
      });
    } catch (e) {
      debugPrint("Error in Search Open Items: $e");
      if (!mounted) return;
      if (SearchController.text.trim().isEmpty) {
        setState(() {
          SOPData = null;
          isLoading = false;
        });
        return;
      }
      AppToast.errorFrom(context, e, fallback: 'Search failed');
    } finally {
      if (!mounted) return;
      if (SearchController.text.trim().isEmpty) {
        setState(() {
          SOPData = null;
          isLoading = false;
        });
        return;
      }
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

  Widget _buildTable(List data, {required bool loading}) {
    final count = loading ? 0 : data.length;
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 700;
    final headerSize = isNarrow ? 11.0 : 13.0;
    final bodySize = isNarrow ? 12.0 : 14.0;

    final headerStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: headerSize,
      letterSpacing: 0.3,
      color: const Color(0xFF4B5563),
    );
    final bodyStyle = TextStyle(
      fontSize: bodySize,
      height: 1.3,
      color: const Color(0xFF111827),
    );

    Widget headerCell(
      String text,
      int flex, {
      TextAlign align = TextAlign.left,
    }) {
      return Expanded(
        flex: flex,
        child: Text(text, style: headerStyle, textAlign: align),
      );
    }

    return Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: isNarrow ? 10 : 12,
              horizontal: isNarrow ? 14 : 18,
            ),
            color: const Color(0xFFE5E7EB),
            child: Row(
              children: [
                headerCell('$count FIXTURES', 2),
                headerCell('DESCRIPTION', 5),
                headerCell('QTY', 1, align: TextAlign.right),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFD1D5DB)),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: isNarrow ? 160 : 220),
            child: loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppLoader(size: 64),
                        SizedBox(height: 8),
                        Text(
                          'Searching...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      for (final raw in data)
                        if (raw is Map)
                          _fixtureResultRow(
                            Map<String, dynamic>.from(raw),
                            isNarrow: isNarrow,
                            bodyStyle: bodyStyle,
                          ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _fixtureResultRow(
    Map<String, dynamic> item, {
    required bool isNarrow,
    required TextStyle bodyStyle,
  }) {
    final fixture = (item['FixtureNumber'] ?? item['fixture'] ?? '').toString();
    final description = (item['Description'] ?? item['description'] ?? '')
        .toString();
    final qty = (item['Quantity'] ?? item['qty'] ?? item['Qty'] ?? '')
        .toString();

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _handleFixtureClick(item),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: isNarrow ? 10 : 12,
            horizontal: isNarrow ? 14 : 18,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: Text(fixture, style: bodyStyle)),
              Expanded(flex: 5, child: Text(description, style: bodyStyle)),
              Expanded(
                flex: 1,
                child: Text(
                  qty,
                  textAlign: TextAlign.right,
                  style: bodyStyle.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
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
    return Scaffold(
      backgroundColor: selectedOpenItem != null
          ? Colors.white
          : const Color(0xFFF3F4F6),
      appBar: CommonAppBar(
        showBackButton: false,
        onBackPressed: selectedOpenItem != null
            ? () {
                setState(() {
                  selectedOpenItem = null;
                });
              }
            : null,
      ),
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (!isTablet) ...[
                                const Text(
                                  "Search SOP Number",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF111827),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              SizedBox(
                                height: isTablet ? 48 : 45,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (isTablet) ...[
                                      const Center(
                                        child: Text(
                                          "Search SOP Number",
                                          style: TextStyle(
                                            color: Color(0xFF111827),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    SizedBox(
                                      width: isTablet
                                          ? 320
                                          : (contentWidth * 0.72).clamp(
                                              180.0,
                                              260.0,
                                            ),
                                      child: TextField(
                                        controller: SearchController,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white,
                                          hintText: isTablet
                                              ? 'Enter SOP Number (e.g., 70101)'
                                              : 'Enter SOP Number',
                                          hintStyle: const TextStyle(
                                            color: Color(0xFF9CA3AF),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 10,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF2196F3),
                                              width: 1.5,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF1565C0),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        textInputAction: TextInputAction.search,
                                        onSubmitted: (_) => handleSOPSearch(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: isLoading
                                          ? null
                                          : handleSOPSearch,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1565C0,
                                        ),
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: const Color(
                                          0xFF1565C0,
                                        ),
                                        disabledForegroundColor: Colors.white70,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Search',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (isLoading)
                                SizedBox(
                                  width: double.infinity,
                                  child: _buildTable(const [], loading: true),
                                )
                              else if (SOPData != null)
                                SizedBox(
                                  width: double.infinity,
                                  child: _buildTable(SOPData!, loading: false),
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.only(top: 28),
                                  child: Text(
                                    'Enter a SOP Number above to search for open items',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
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
