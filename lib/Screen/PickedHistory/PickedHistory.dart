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
  final TextEditingController _searchController = TextEditingController();

  String username = "";
  List<ItemModel> _allItems = [];
  List<ItemModel> items = [];
  String _searchQuery = "";
  bool isLoading = false;

  static const int _pageSize = 200;
  int _currentPage = 1;

  int? _sortColumnIndex;
  bool _sortAscending = true;

  /// Base column widths (original Status width).
  static const List<double> _bomColWidths = [130, 160, 200, 100, 120];

  List<ItemModel> get _sortedItems {
    if (_sortColumnIndex == null ||
        _sortColumnIndex! < 0 ||
        _sortColumnIndex! > 4) {
      return items;
    }
    final rows = List<ItemModel>.from(items);
    rows.sort((a, b) {
      final cmp = _compareItems(a, b, _sortColumnIndex!);
      if (cmp != 0) return _sortAscending ? cmp : -cmp;
      return a.sopNumber.compareTo(b.sopNumber);
    });
    return rows;
  }

  DateTime? _asDateTime(String raw) {
    final text = raw.trim();
    if (text.isEmpty ||
        text == '-' ||
        text == '*' ||
        text.startsWith('0001-01-01')) {
      return null;
    }
    return DateTime.tryParse(text);
  }

  int _compareItems(ItemModel a, ItemModel b, int columnIndex) {
    switch (columnIndex) {
      case 0:
        final ia = int.tryParse(a.sopNumber);
        final ib = int.tryParse(b.sopNumber);
        if (ia != null && ib != null) return ia.compareTo(ib);
        return a.sopNumber.toLowerCase().compareTo(b.sopNumber.toLowerCase());
      case 1:
        return a.fixtureNumber.toLowerCase().compareTo(
          b.fixtureNumber.toLowerCase(),
        );
      case 2:
        final da = _asDateTime(a.dateChanged);
        final db = _asDateTime(b.dateChanged);
        if (da != null && db != null) return da.compareTo(db);
        if (da != null) return -1;
        if (db != null) return 1;
        return a.dateChanged.toLowerCase().compareTo(
          b.dateChanged.toLowerCase(),
        );
      case 3:
        return a.picked.toLowerCase().compareTo(b.picked.toLowerCase());
      case 4:
        return a.status.toLowerCase().compareTo(b.status.toLowerCase());
      default:
        return 0;
    }
  }

  void _onSort(int columnIndex) {
    if (columnIndex < 0 || columnIndex > 4) return;
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
      _currentPage = 1;
    });
  }

  List<ItemModel> get _visibleItems {
    final sorted = _sortedItems;
    final start = (_currentPage - 1) * _pageSize;
    if (start >= sorted.length) return [];
    final end = (start + _pageSize).clamp(0, sorted.length);
    return sorted.sublist(start, end);
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

  bool _itemMatchesQuery(ItemModel item, String query) {
    final q = query.toLowerCase();
    return item.sopNumber.toLowerCase().contains(q) ||
        item.fixtureNumber.toLowerCase().contains(q) ||
        _formatDateValue(item.dateChanged).toLowerCase().contains(q) ||
        item.picked.toLowerCase().contains(q) ||
        item.status.toLowerCase().contains(q);
  }

  void _applySearch({bool resetPage = true}) {
    final q = _searchQuery.trim();
    final filtered = q.isEmpty
        ? List<ItemModel>.from(_allItems)
        : _allItems.where((item) => _itemMatchesQuery(item, q)).toList();
    setState(() {
      items = filtered;
      if (resetPage) _currentPage = 1;
    });
  }

  void _runSearch() {
    _searchQuery = _searchController.text.trim();
    if (_allItems.isEmpty) {
      fetchHistoryData();
      return;
    }
    _applySearch();
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
      _searchQuery = _searchController.text.trim();
      final q = _searchQuery.trim();
      final filtered = q.isEmpty
          ? List<ItemModel>.from(parsedItems)
          : parsedItems.where((item) => _itemMatchesQuery(item, q)).toList();
      setState(() {
        _allItems = parsedItems;
        items = filtered;
        _currentPage = 1;
        isLoading = false;
      });
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

    return DateFormat("MM/dd/yyyy hh:mm:ss a").format(parsed);
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _bomHeaderCell(
    String label,
    double w, {
    required double fontSize,
    required double height,
    required double hPad,
    required int sortIndex,
  }) {
    final borderColor = Colors.grey.shade300;
    final active = _sortColumnIndex == sortIndex;
    final up = !active || _sortAscending;

    return SizedBox(
      width: w,
      height: height,
      child: Material(
        color: const Color.fromARGB(255, 57, 73, 95),
        child: InkWell(
          onTap: () => _onSort(sortIndex),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: borderColor),
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
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
                const SizedBox(width: 3),
                Icon(
                  up ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: active ? Colors.white : const Color(0x99B8C8E8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _highlightedCellText(String text, {required double fontSize}) {
    final style = TextStyle(fontSize: fontSize, height: 1.15);
    final q = _searchQuery.trim();
    if (q.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final lower = text.toLowerCase();
    final needle = q.toLowerCase();
    if (!lower.contains(needle)) {
      return Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final children = <InlineSpan>[];
    var i = 0;
    while (i < text.length) {
      final j = lower.indexOf(needle, i);
      if (j < 0) {
        children.add(TextSpan(text: text.substring(i)));
        break;
      }
      if (j > i) {
        children.add(TextSpan(text: text.substring(i, j)));
      }
      final end = j + needle.length;
      children.add(
        TextSpan(
          text: text.substring(j, end),
          style: style.copyWith(
            backgroundColor: const Color.fromARGB(255, 245, 197, 41),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      i = end;
    }

    return Text.rich(
      TextSpan(style: style, children: children),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
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
        child: _highlightedCellText(value, fontSize: fontSize),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    const fieldHeight = 48.0;
    final sharedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(
        color: Color.fromARGB(255, 229, 231, 235),
        width: 2,
      ),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF38485E), width: 2),
    );
    final searchField = SizedBox(
      height: fieldHeight,
      child: TextField(
        controller: _searchController,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 14),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: 'Search in table...',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: sharedBorder,
          enabledBorder: sharedBorder,
          focusedBorder: focusedBorder,
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Clear',
                icon: Icon(Icons.close, size: 20, color: Colors.grey.shade700),
                onPressed: () {
                  _searchController.clear();
                  _searchQuery = '';
                  _applySearch();
                },
              );
            },
          ),
        ),
        onChanged: (value) {
          if (value.trim().isEmpty) {
            _searchQuery = '';
            _applySearch();
          }
        },
        onSubmitted: (_) => _runSearch(),
      ),
    );
    final searchButton = SizedBox(
      height: fieldHeight,
      child: ElevatedButton.icon(
        onPressed: _runSearch,
        icon: const Icon(Icons.search, size: 20),
        label: const Text('Search'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
    final searchRow = Row(
      children: [
        Expanded(child: searchField),
        const SizedBox(width: 10),
        searchButton,
      ],
    );

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
              child: r.isPhone
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "Picked History",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: r.pageTitleSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        searchRow,
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Picked History",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: r.pageTitleSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: searchRow,
                            ),
                          ),
                        ),
                      ],
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
                            final tableW = needsHScroll
                                ? _minTableWidth
                                : available;
                            final colW = _columnWidthsForAvailable(tableW);
                            final density = _densityFor(
                              MediaQuery.sizeOf(context),
                            );

                            final table = DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
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
                                          sortIndex: 0,
                                        ),
                                        _bomHeaderCell(
                                          "Fixture Number",
                                          colW[1],
                                          fontSize: density.fontSize,
                                          height: density.headerH,
                                          hPad: density.hPad,
                                          sortIndex: 1,
                                        ),
                                        _bomHeaderCell(
                                          "Date Picked",
                                          colW[2],
                                          fontSize: density.fontSize,
                                          height: density.headerH,
                                          hPad: density.hPad,
                                          sortIndex: 2,
                                        ),
                                        _bomHeaderCell(
                                          "Picked Status",
                                          colW[3],
                                          fontSize: density.fontSize,
                                          height: density.headerH,
                                          hPad: density.hPad,
                                          sortIndex: 3,
                                        ),
                                        _bomHeaderCell(
                                          "Status",
                                          colW[4],
                                          fontSize: density.fontSize,
                                          height: density.headerH,
                                          hPad: density.hPad,
                                          sortIndex: 4,
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

                            return Responsive.hideScrollbars(
                              context,
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: table,
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
