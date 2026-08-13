import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/PickedHistory/Services/PickedHistoryService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Utils/responsive.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:overview_app/Widgets/pagination_bar.dart';


class ItemModel {
  final String sopNumber;
  final String fixtureNumber;
  final String dateChanged;
  final String picked;
  final String status;

  ItemModel({
    required this.sopNumber,
    required this.fixtureNumber,
    required this.dateChanged,
    required this.picked,
    required this.status,
  });
}

class PickedHistory extends StatefulWidget {
  @override
  _PickedHistoryState createState() => _PickedHistoryState();
}

class _PickedHistoryState extends State<PickedHistory> {
  final PickedHistoryService _service = PickedHistoryService();
  String username = "";
  List<ItemModel> items = [];
  bool isLoading = false;

  static const int _pageSize = 200;
  int _currentPage = 1;

  /// Base column widths (original Status width).
  static const List<double> _bomColWidths = [130, 160, 200, 100, 120];

  List<ItemModel> get _visibleItems {
    final start = (_currentPage - 1) * _pageSize;
    if (start >= items.length) return [];
    final end = (start + _pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  int get _totalPages {
    if (items.isEmpty) return 1;
    return (items.length + _pageSize - 1) ~/ _pageSize;
  }

  double get _minTableWidth =>
      _bomColWidths.fold<double>(0, (sum, w) => sum + w);

  List<double> _columnWidthsForAvailable(double available) {
    final sum = _minTableWidth;
    if (available <= sum) return List<double>.from(_bomColWidths);
    final scale = available / sum;
    final scaled = _bomColWidths.map((w) => w * scale).toList();
    final scaledSum = scaled.fold<double>(0, (a, b) => a + b);
    scaled[scaled.length - 1] += available - scaledSum;
    return scaled;
  }

  /// Phone & small tablet → larger text. Big tablet → slightly compact.
  ({double fontSize, double headerH, double vPad, double hPad}) _densityFor(
    Size screenSize,
  ) {
    final shortest = screenSize.shortestSide;
    final width = screenSize.width;

    // Big tablet / wide layout.
    if (shortest >= 800 || width >= 1100) {
      return (fontSize: 13, headerH: 36, vPad: 6, hPad: 10);
    }

    // Phone & small tablet.
    return (fontSize: 13, headerH: 40, vPad: 8, hPad: 10);
  }

  Future<void> fetchHistoryData() async {
    setState(() {
      isLoading = true;
    });

    try {
      await Dioservices.setToken();
      final Response response = await _service.PickedLogHistoryService();
      final List<ItemModel> parsedItems = _parseItems(response.data);

      if (!mounted) return;
      setState(() {
        items = parsedItems;
        _currentPage = 1;
        isLoading = false;
      });

      // debugPrint("PICKED HISTORY STATUS: ${response.statusCode}");
      // debugPrint("PICKED HISTORY ROW COUNT: ${parsedItems.length}");
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      debugPrint("Error in fetching picked history data: $e");
    }
  }

  static String _normalizeFieldKey(String input) =>
      input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static Map<String, dynamic> _normalizedFieldMap(Map<String, dynamic> row) {
    final out = <String, dynamic>{};
    row.forEach((k, v) {
      out[_normalizeFieldKey(k)] = v;
    });
    return out;
  }

  static String _firstMatchingValue(
    Map<String, dynamic> normalizedRow,
    List<String> keys,
  ) {
    for (final key in keys) {
      final current = normalizedRow[_normalizeFieldKey(key)]?.toString().trim();
      if (current != null && current.isNotEmpty) return current;
    }
    return "-";
  }

  static String _formatDateValue(String value) {
    final raw = value.trim();
    if (raw.isEmpty || raw == "-") return "-";

    DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      final fallbackFormats = [
        DateFormat("yyyy-MM-dd HH:mm:ss"),
        DateFormat("yyyy-MM-dd HH:mm"),
        DateFormat("yyyy-MM-dd"),
        DateFormat("dd-MM-yyyy HH:mm:ss"),
        DateFormat("dd-MM-yyyy HH:mm"),
        DateFormat("dd-MM-yyyy"),
        DateFormat("dd/MM/yyyy hh:mm:ss a"),
        DateFormat("dd/MM/yyyy hh:mm a"),
        DateFormat("dd/MM/yyyy"),
      ];
      for (final format in fallbackFormats) {
        try {
          parsed = format.parseStrict(raw);
          break;
        } catch (_) {}
      }
    }

    if (parsed == null) return raw;
    return DateFormat("dd/MM/yyyy hh:mm:ss a").format(parsed.toLocal());
  }

  List<ItemModel> _parseItems(dynamic payload) {
    dynamic data = payload;
    if (payload is Map<String, dynamic>) {
      data =
          payload['data'] ?? payload['items'] ?? payload['result'] ?? payload;
      if (data is Map<String, dynamic>) {
        data =
            data['data'] ??
            data['items'] ??
            data['rows'] ??
            data['result'] ??
            data['list'];
      }
    }
    if (data is! List) return [];

    final parsed = <ItemModel>[];
    for (final raw in data.whereType<Map>()) {
      final row = Map<String, dynamic>.from(raw);
      final normalizedRow = _normalizedFieldMap(row);
      parsed.add(
        ItemModel(
          sopNumber: _firstMatchingValue(normalizedRow, const ["SOPNumber"]),
          fixtureNumber: _firstMatchingValue(normalizedRow, const [
            "FixtureNumber",
          ]),
          dateChanged: _firstMatchingValue(normalizedRow, const [
            "dateChanged",
          ]),
          picked: _firstMatchingValue(normalizedRow, const ["picked"]),
          status: _firstMatchingValue(normalizedRow, const ['status']),
        ),
      );
    }

    if (parsed.isNotEmpty &&
        parsed.first.sopNumber == "-" &&
        parsed.first.fixtureNumber == "-") {
      final firstRaw = data.first;
      if (firstRaw is Map) {
        // debugPrint(
        //   "PickedHistory: first row keys => ${firstRaw.keys.toList()}",
        // );
      }
    }
    return parsed;
  }

  @override
  void initState() {
    super.initState();
    fetchHistoryData();
  }

  Widget _bomHeaderCell(
    String label,
    double w, {
    required double fontSize,
    required double height,
    required double hPad,
  }) {
    final borderColor = Colors.grey.shade300;
    return SizedBox(
      width: w,
      height: height,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: hPad),
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
            fontSize: fontSize,
            height: 1.0,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _bomDataCell(
    String value,
    double w, {
    required double fontSize,
    required double vPad,
    required double hPad,
  }) {
    final borderColor = Colors.grey.shade300;
    return SizedBox(
      width: w,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
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
          style: TextStyle(fontSize: fontSize, height: 1.15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Scaffold(
      appBar: CommonAppBar(),
      drawer: CommonDrawer(),
      body: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                r.pagePaddingH,
                r.pagePaddingV,
                r.pagePaddingH,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Picked History",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: r.pageTitleSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: r.sectionGap),
            if (isLoading)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: AppLoader()),
                ),
              )
            else if (items.isEmpty)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text("No picked history found"),
                  ),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    r.pagePaddingH,
                    0,
                    r.pagePaddingH,
                    r.pagePaddingV,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final available = constraints.maxWidth;
                              final needsHScroll = available < _minTableWidth;
                              final tableW =
                                  needsHScroll ? _minTableWidth : available;
                              final colW = _columnWidthsForAvailable(tableW);
                              final density = _densityFor(
                                MediaQuery.sizeOf(context),
                              );

                              final table = DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: SizedBox(
                                  width: tableW,
                                  height: constraints.maxHeight,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          _bomHeaderCell(
                                            "SOP Number",
                                            colW[0],
                                            fontSize: density.fontSize,
                                            height: density.headerH,
                                            hPad: density.hPad,
                                          ),
                                          _bomHeaderCell(
                                            "Fixture Number",
                                            colW[1],
                                            fontSize: density.fontSize,
                                            height: density.headerH,
                                            hPad: density.hPad,
                                          ),
                                          _bomHeaderCell(
                                            "Date Changed",
                                            colW[2],
                                            fontSize: density.fontSize,
                                            height: density.headerH,
                                            hPad: density.hPad,
                                          ),
                                          _bomHeaderCell(
                                            "Picked",
                                            colW[3],
                                            fontSize: density.fontSize,
                                            height: density.headerH,
                                            hPad: density.hPad,
                                          ),
                                          _bomHeaderCell(
                                            "Status",
                                            colW[4],
                                            fontSize: density.fontSize,
                                            height: density.headerH,
                                            hPad: density.hPad,
                                          ),
                                        ],
                                      ),
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: _visibleItems.length,
                                          itemBuilder: (context, index) {
                                            final item = _visibleItems[index];
                                            return Row(
                                              children: [
                                                _bomDataCell(
                                                  item.sopNumber,
                                                  colW[0],
                                                  fontSize: density.fontSize,
                                                  vPad: density.vPad,
                                                  hPad: density.hPad,
                                                ),
                                                _bomDataCell(
                                                  item.fixtureNumber,
                                                  colW[1],
                                                  fontSize: density.fontSize,
                                                  vPad: density.vPad,
                                                  hPad: density.hPad,
                                                ),
                                                _bomDataCell(
                                                  _formatDateValue(
                                                    item.dateChanged,
                                                  ),
                                                  colW[2],
                                                  fontSize: density.fontSize,
                                                  vPad: density.vPad,
                                                  hPad: density.hPad,
                                                ),
                                                _bomDataCell(
                                                  item.picked,
                                                  colW[3],
                                                  fontSize: density.fontSize,
                                                  vPad: density.vPad,
                                                  hPad: density.hPad,
                                                ),
                                                _bomDataCell(
                                                  item.status,
                                                  colW[4],
                                                  fontSize: density.fontSize,
                                                  vPad: density.vPad,
                                                  hPad: density.hPad,
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              if (!needsHScroll) {
                                return SizedBox(
                                  width: available,
                                  height: constraints.maxHeight,
                                  child: table,
                                );
                              }

                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: table,
                              );
                            },
                          ),
                        ),
                        if (items.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          PaginationBar(
                            currentPage: _currentPage.clamp(1, _totalPages),
                            totalPages: _totalPages,
                            fromItem: items.isEmpty
                                ? 0
                                : ((_currentPage - 1) * _pageSize) + 1,
                            toItem: items.isEmpty
                                ? 0
                                : (_currentPage * _pageSize).clamp(
                                    0,
                                    items.length,
                                  ),
                            totalItems: items.length,
                            onPageChanged: (page) {
                              setState(() {
                                _currentPage = page;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
