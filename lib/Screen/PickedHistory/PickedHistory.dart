import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/PickedHistory/Services/PickedHistoryService.dart';
import 'package:overview_app/Services/DioServices.dart';
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

  /// Minimum table width (all columns; used when parent is narrower — horizontal scroll).
  double get _minTableWidth =>
      _bomColWidths.fold<double>(0, (sum, w) => sum + w);

  List<double> _columnWidthsForAvailable(double available) {
    final sum = _minTableWidth;
    if (available <= sum) {
      return List<double>.from(_bomColWidths);
    }
    final scale = available / sum;
    return _bomColWidths.map((w) => w * scale).toList();
  }

  double _tableWidthFor(List<double> widths) =>
      widths.fold<double>(0, (a, b) => a + b);

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

      debugPrint("PICKED HISTORY STATUS: ${response.statusCode}");
      debugPrint("PICKED HISTORY ROW COUNT: ${parsedItems.length}");
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
        debugPrint(
          "PickedHistory: first row keys => ${firstRaw.keys.toList()}",
        );
      }
    }
    return parsed;
  }

  @override
  void initState() {
    super.initState();
    fetchHistoryData();
  }

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
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(),
      drawer: CommonDrawer(),
      body: Container(
        color: Colors.white,
        child: Container(
          // padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.center,
                child: Center(
                  child: Text(
                    "Picked History",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color.fromARGB(255, 57, 73, 95),
                    ),
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
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final available = constraints.maxWidth;
                              final colW = _columnWidthsForAvailable(available);
                              final tableW = _tableWidthFor(colW);

                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DecoratedBox(
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
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _bomHeaderCell(
                                              "SOP Number",
                                              colW[0],
                                            ),
                                            _bomHeaderCell(
                                              "Fixture Number",
                                              colW[1],
                                            ),
                                            _bomHeaderCell(
                                              "Date Changed",
                                              colW[2],
                                            ),
                                            _bomHeaderCell("Picked", colW[3]),
                                            _bomHeaderCell("Status", colW[4]),
                                          ],
                                        ),
                                        Expanded(
                                          child: ListView.builder(
                                            itemCount: _visibleItems.length,
                                            itemBuilder: (context, index) {
                                              final item = _visibleItems[index];
                                              return Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  _bomDataCell(
                                                    item.sopNumber,
                                                    colW[0],
                                                  ),
                                                  _bomDataCell(
                                                    item.fixtureNumber,
                                                    colW[1],
                                                  ),
                                                  _bomDataCell(
                                                    _formatDateValue(
                                                      item.dateChanged,
                                                    ),
                                                    colW[2],
                                                  ),
                                                  _bomDataCell(
                                                    item.picked,
                                                    colW[3],
                                                  ),
                                                  _bomDataCell(
                                                    item.status,
                                                    colW[4],
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (items.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          PaginationBar(
                            currentPage: _currentPage.clamp(1, _totalPages),
                            totalPages: _totalPages,
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
      ),
    );
  }
}
