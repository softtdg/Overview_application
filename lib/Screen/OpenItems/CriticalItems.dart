import 'dart:math' show max, min;
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Screen/Login/login.dart';
import 'package:overview_app/Screen/OpenItems/Components/Query.dart';
import 'package:overview_app/Screen/OpenItems/Services/OpenItemsServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CriticalItems extends StatefulWidget {
  const CriticalItems({
    super.key,
    this.useCriticalApi = true,
    this.pageTitle = 'Critical Items',
  });

  final bool useCriticalApi;
  final String pageTitle;

  @override
  _CriticalItemsState createState() => _CriticalItemsState();
}

class _CriticalItemsState extends State<CriticalItems> {
  static const double _noticeColumnWidth = 150;
  final String username = 'John Doe';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  String _searchQuery = '';
  bool _isLoading = true;
  int _currentPage = 0;
  int _rowsPerPage = 50;

  String _pick(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  String _pickSopNum(Map<String, dynamic> row) {
    final sop = row['SOP'];
    if (sop is Map) {
      final sopMap = Map<String, dynamic>.from(sop);
      final sopNum = sopMap['SOPNum'];
      if (sopNum != null && sopNum.toString().trim().isNotEmpty) {
        return sopNum.toString();
      }
    }
    return _pick(row, ['SOP']);
  }

  String _pickPath(Map<String, dynamic> row, List<String> path) {
    dynamic current = row;
    for (final key in path) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        return '-';
      }
    }
    if (current == null) return '-';
    final value = current.toString().trim();
    return value.isEmpty ? '-' : value;
  }

  bool _hasTextValue(dynamic value) {
    if (value == null) return false;
    if (value is List) {
      return value.any((item) => _hasTextValue(item));
    }
    final text = value.toString().trim();
    return text.isNotEmpty && text != '-';
  }

  String _valueText(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      final parts = value
          .where((item) => _hasTextValue(item))
          .map((item) => item.toString().trim())
          .toList();
      return parts.isEmpty ? '-' : parts.join(', ');
    }
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  bool _responseIsEmpty(dynamic responseField) {
    final t = _valueText(responseField).trim();
    return t.isEmpty || t == '-';
  }

  List<Map<String, dynamic>> _buildNotices(Map<String, dynamic> row) {
    final notices = <Map<String, dynamic>>[];
    final notProduced = !_isProduced(row);

    if (_hasTextValue(row['LeadHandCommentsForPurchasing'])) {
      notices.add({
        'date': _formatDate(_valueText(row['NotifiedPurchasingDate'])),
        'dept': 'Purchasing',
        'notice': _valueText(row['LeadHandCommentsForPurchasing']),
        'response': _valueText(
          _pick(row, [
            'PurchasingComments',
            'PurchasingResponse',
            'LeadHandPurchasingResponse',
          ]),
        ),
        'type': 'purchasing',
        'bgColor': row['NotifyPurchasing'] == true && notProduced
            ? const Color(0xFF99CCFF)
            : const Color(0xFF607D99),
      });
    }

    final backorders = row['Backorders'];
    if (backorders is List) {
      for (final item in backorders) {
        if (item is! Map) continue;
        final tdgpn = _valueText(item['TDGPN']);
        final quantity = _valueText(item['Quantity']);
        final uom = _valueText(item['UOM']);
        final closedDate = _formatDate(_valueText(item['ClosedDate']));
        final qtyNum = num.tryParse((item['Quantity'] ?? '').toString()) ?? 0;
        final recvNum = num.tryParse((item['Received'] ?? '').toString()) ?? 0;
        notices.add({
          'date': _formatDate(_valueText(item['NoticeDate'])),
          'dept': 'Purchasing',
          'notice': 'Missing: $tdgpn ($quantity) $uom - CLOSED - $closedDate',
          'response': _valueText(item['Response']),
          'type': 'backorder',
          'hasMismatch': qtyNum != recvNum,
          'bgColor': qtyNum != recvNum
              ? const Color(0xFF99CCFF)
              : const Color(0xFF607D99),
        });
      }
    }

    if (_hasTextValue(row['InventoryCommentsForProduction'])) {
      notices.add({
        'date': _formatDate(_valueText(row['NotifiedProductionDate'])),
        'dept': 'Production',
        'notice': _valueText(row['InventoryCommentsForProduction']),
        'response': _valueText(row['ProductionComments']),
        'type': 'production',
        'bgColor': row['NotifyProduction'] == true && notProduced
            ? const Color(0xFFFFCCCC)
            : const Color(0xFFC9A1A1),
      });
    }

    return notices;
  }

  List<Map<String, dynamic>> _groupRowsForDisplay(
    List<Map<String, dynamic>> rows,
  ) {
    final grouped = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final key = '${_pickSopNum(row)}|${_pick(row, ['FixtureNumber'])}';
      final notices = _buildNotices(row);
      final bucket = grouped.putIfAbsent(
        key,
        () => {'row': row, 'notices': <Map<String, dynamic>>[]},
      );

      final bucketNotices = bucket['notices'] as List<Map<String, dynamic>>;
      if (notices.isEmpty) {
        if (bucketNotices.isEmpty) {
          bucketNotices.add({
            'date': '-',
            'dept': '-',
            'notice': '-',
            'response': '',
            'bgColor': Colors.transparent,
          });
        }
      } else {
        bucketNotices.addAll(notices);
      }
    }

    return grouped.values.toList();
  }

  bool _matchesSearch(Map<String, dynamic> row, String query) {
    if (query.isEmpty) return true;
    return _pickSopNum(row).toLowerCase().contains(query.toLowerCase());
  }

  List<Map<String, dynamic>> get _filteredRows {
    if (_searchQuery.isEmpty) return _rows;
    return _rows.where((row) => _matchesSearch(row, _searchQuery)).toList();
  }

  void _runSearch() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _currentPage = 0;
      _clampCurrentPage();
    });
  }

  List<String> _noticeValues(
    List<Map<String, dynamic>> notices,
    String key, {
    bool hideDash = false,
  }) {
    if (notices.isEmpty) return const [];
    final values = notices.map((entry) {
      final value = _valueText(entry[key]);
      if (hideDash && value == '-') {
        return ' ';
      }
      return value.trim().isEmpty ? ' ' : value;
    }).toList();
    return values;
  }

  List<double> _noticeRowHeights({
    required List<String> noticeValues,
    required double noticeWidth,
    required TextScaler textScaler,
  }) {
    const textStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
    const minHeight = 52.0;
    const horizontalPadding = 8.0;
    const verticalPadding = 14.0;
    final maxTextWidth = (noticeWidth - horizontalPadding).clamp(
      0.0,
      double.infinity,
    );

    return noticeValues.map((value) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: textStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: maxTextWidth);

      return (painter.height + verticalPadding) < minHeight
          ? minHeight
          : painter.height + verticalPadding;
    }).toList();
  }

  Widget _stackedNoticeCell({
    required double width,
    required List<String> values,
    required Color backgroundColor,
    List<Color>? rowBackgrounds,
    List<double>? rowHeights,
    TextAlign textAlign = TextAlign.center,
  }) {
    final perRowBg =
        rowBackgrounds != null && rowBackgrounds.length == values.length;

    final Color cellFillColor;
    if (perRowBg && rowBackgrounds.isNotEmpty) {
      final last = rowBackgrounds.last;
      cellFillColor =
          last == Colors.transparent ? backgroundColor : last;
    } else {
      cellFillColor = backgroundColor;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.hasBoundedWidth && constraints.maxWidth > 0
            ? constraints.maxWidth
            : width;
        return SizedBox(
          width: w,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ColoredBox(color: cellFillColor),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: values.asMap().entries.map((entry) {
                final index = entry.key;
                final value = entry.value;
                final isLast = index == values.length - 1;
                final rowHeight =
                    rowHeights != null && index < rowHeights.length
                    ? rowHeights[index]
                    : null;
                final rowBg = perRowBg ? rowBackgrounds[index] : null;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      height: rowHeight,
                      color: rowBg,
                      constraints: rowHeight == null
                          ? const BoxConstraints(minHeight: 52)
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Text(
                        value,
                        textAlign: textAlign,
                        softWrap: true,
                        maxLines: null,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (!isLast)
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SizedBox(
                          height: 0.6,
                          child: ColoredBox(color: Colors.white),
                        ),
                      ),
                  ],
                );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _noticeBlockBackground(List<Map<String, dynamic>> notices) {
    if (notices.isEmpty) return Colors.transparent;
    final bg = notices.first['bgColor'];
    return bg is Color ? bg : Colors.transparent;
  }

  /// Per Response sub-row: stripe when there is text; when empty, light red vs
  /// dark red (same rules as before). Production stripes stay pink if empty.
  Color _responseRowBackground(
    Map<String, dynamic> row,
    Map<String, dynamic> notice,
  ) {
    const lightRed = Color(0xFFD9534F);
    const darkRed = Color(0xFF913734);
    const productionBaseColor = Color(0xFFC9A1A1);
    const productionPendingColor = Color(0xFFFFCCCC);
    const purchasingPendingColor = Color(0xFF99CCFF);

    final stripe = notice['bgColor'] is Color
        ? notice['bgColor'] as Color
        : Colors.transparent;

    if (stripe == Colors.transparent) {
      return Colors.transparent;
    }
    if (!_responseIsEmpty(notice['response'])) {
      return stripe;
    }

    if (stripe == productionBaseColor || stripe == productionPendingColor) {
      return stripe;
    }

    final notProduced = !_isProduced(row);
    final type = (notice['type'] ?? '').toString();

    if (type == 'purchasing') {
      return row['NotifyPurchasing'] == true && notProduced
          ? lightRed
          : darkRed;
    }
    if (type == 'backorder') {
      final hasMismatch = notice['hasMismatch'] == true;
      return hasMismatch && notProduced ? lightRed : darkRed;
    }
    if (type == 'production') {
      return row['NotifyProduction'] == true && notProduced
          ? lightRed
          : darkRed;
    }

    if (stripe == purchasingPendingColor || stripe == productionPendingColor) {
      return lightRed;
    }
    return darkRed;
  }

  bool _isProduced(Map<String, dynamic> row) {
    final productionDateOut = _pickPath(row, [
      'SOP',
      'ProductionLogEntry',
      'ProductionDateOut',
    ]);
    return productionDateOut != '-';
  }

  bool _hasPendingBackorder(Map<String, dynamic> row) {
    final backorders = row['Backorders'];
    if (backorders is! List || backorders.isEmpty) return false;
    for (final item in backorders) {
      if (item is! Map) continue;
      final quantity = num.tryParse((item['Quantity'] ?? '').toString()) ?? 0;
      final received = num.tryParse((item['Received'] ?? '').toString()) ?? 0;
      if (quantity != received) {
        return true;
      }
    }
    return false;
  }

  Color _pickedCellBackground(Map<String, dynamic> row) {
    final isPicked = row['Picked'] == true;
    if (!isPicked) return Colors.transparent;

    final notProduced = !_isProduced(row);
    if (notProduced && _hasPendingBackorder(row)) {
      return const Color(0xFF99CCFF);
    }
    return const Color(0xFF607D99);
  }

  String _formatDate(String value) {
    final raw = value.trim();
    if (raw.isEmpty || raw == '-') return '*';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null || parsed.year <= 1) return '*';
    final dd = parsed.day.toString().padLeft(2, '0');
    final mm = parsed.month.toString().padLeft(2, '0');
    final yyyy = parsed.year.toString();
    return '$dd/$mm/$yyyy';
  }

  Widget _heading(String text) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  /// Use [minWidth] only, not [DataColumn2.fixedWidth]: fixed widths must sum to
  /// less than the layout width (data_table_2 asserts); min widths scale safely.
  DataColumn2 _column(String text, {required double minWidth}) {
    return DataColumn2(
      headingRowAlignment: MainAxisAlignment.center,
      minWidth: minWidth,
      label: SizedBox(width: minWidth, child: _heading(text)),
    );
  }

  List<DataColumn2> _criticalDataColumns() {
    return [
      _column('SOP', minWidth: 56),
      _column('ODD', minWidth: 90),
      _column('Lead\nHand', minWidth: 82),
      _column('Assembler', minWidth: 90),
      _column('Fixture', minWidth: 96),
      _column('Desc', minWidth: 150),
      _column('Qty', minWidth: 40),
      _column('Time To\nBuild/Per\nUnit', minWidth: 88),
      _column('Total\nTime To\nBuild', minWidth: 92),
      _column('Amount', minWidth: 70),
      _column('Inventory\nComment', minWidth: 130),
      _column('Picked', minWidth: 58),
      _column('Date Sent', minWidth: 90),
      _column('Dept', minWidth: 88),
      _column('Notice', minWidth: _noticeColumnWidth),
      _column('Response', minWidth: 180),
      _column('Action', minWidth: 120),
    ];
  }

  /// Row height from this row's stacked Notice text only (not the max of the whole page).
  double _dataRowHeightForGroup(
    Map<String, dynamic> group,
    BuildContext context,
  ) {
    final notices = group['notices'] as List<Map<String, dynamic>>;
    final noticeValues = _noticeValues(
      notices,
      'notice',
      hideDash: true,
    );
    if (noticeValues.isEmpty) return 52.0;
    final noticeRowHeights = _noticeRowHeights(
      noticeValues: noticeValues,
      noticeWidth: _noticeColumnWidth,
      textScaler: MediaQuery.textScalerOf(context),
    );
    final totalHeight = noticeRowHeights.fold<double>(
      0,
      (a, b) => a + b,
    );
    return max(52.0, totalHeight + 8);
  }

  Widget _tableTextCell(
    String text, {
    double width = 90,
    TextAlign align = TextAlign.center,
    int maxLines = 5,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        softWrap: true,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: TextStyle(fontSize: 13, fontWeight: fontWeight),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchCriticalItems();
  }

  void _fetchCriticalItems() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await Dioservices.setToken();
      final response = widget.useCriticalApi
          ? await OpenItemsServices().CriticalItems()
          : await OpenItemsServices().OpenItems();
      // print('Critical Items API response: ${response.data}');
      if (response.statusCode == 200) {
        final payload = response.data;
        final rawData = payload is Map<String, dynamic>
            ? payload['data']
            : payload;
        setState(() {
          _rows = rawData is List
              ? rawData
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList()
              : <Map<String, dynamic>>[];
          _clampCurrentPage();
        });
        // print('Critical Items rows count: ${_rows.length}');
        // print('Critical Items rows: $_rows');
      }
    } catch (e) {
      print("Error fetching critical items: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int get _totalPages => _filteredRows.isEmpty
      ? 1
      : ((_filteredRows.length + _rowsPerPage - 1) ~/ _rowsPerPage);

  List<Map<String, dynamic>> get _pagedRows {
    if (_filteredRows.isEmpty) return [];
    final start = _currentPage * _rowsPerPage;
    final end = min(start + _rowsPerPage, _filteredRows.length);
    return _filteredRows.sublist(start, end);
  }

  void _clampCurrentPage() {
    final last = max(0, _totalPages - 1);
    if (_currentPage > last) _currentPage = last;
  }

  void _setPage(int page) {
    setState(() {
      _currentPage = page.clamp(0, max(0, _totalPages - 1));
    });
  }

  List<int?> _paginationItems() {
    final lastPage = _totalPages - 1;
    if (_totalPages <= 7) {
      return List<int?>.generate(_totalPages, (i) => i);
    }

    final items = <int?>[0];
    final showLeftDots = _currentPage > 3;
    final showRightDots = _currentPage < lastPage - 3;

    if (showLeftDots) {
      items.add(null);
    }

    final start = max(1, _currentPage - 1);
    final end = min(lastPage - 1, _currentPage + 1);
    for (int i = start; i <= end; i++) {
      items.add(i);
    }

    if (showRightDots) {
      items.add(null);
    }

    items.add(lastPage);
    return items;
  }

  Widget _pageBox({
    required Widget child,
    required VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return Material(
      color: isSelected ? const Color(0xFF314D75) : const Color(0xFFE9ECEF),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(width: 36, height: 36, child: Center(child: child)),
      ),
    );
  }

  Widget _paginationBar() {
    final pages = _paginationItems();
    final hasPrev = _currentPage > 0;
    final hasNext = _currentPage < _totalPages - 1;

    return Material(
      color: const Color(0xFFF5F6F8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            _pageBox(
              onTap: hasPrev ? () => _setPage(_currentPage - 1) : null,
              child: Icon(
                Icons.chevron_left,
                size: 18,
                color: hasPrev
                    ? const Color(0xFF546375)
                    : const Color(0xFFB7C0CB),
              ),
            ),
            ...pages.map((pageIndex) {
              if (pageIndex == null) {
                return const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Text(
                      '...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF657589),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }

              final isSelected = _currentPage == pageIndex;
              return _pageBox(
                isSelected: isSelected,
                onTap: () => _setPage(pageIndex),
                child: Text(
                  '${pageIndex + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF546375),
                  ),
                ),
              );
            }),
            _pageBox(
              onTap: hasNext ? () => _setPage(_currentPage + 1) : null,
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: hasNext
                    ? const Color(0xFF546375)
                    : const Color(0xFFB7C0CB),
              ),
            ),
          ],
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupedRows = _groupRowsForDisplay(_pagedRows);
    final tableColumns = _criticalDataColumns();
    const tableBorderColor = Color(0xFFD1D5DB);
    final tableBorder = TableBorder(
      top: const BorderSide(color: tableBorderColor, width: 1),
      bottom: const BorderSide(color: tableBorderColor, width: 1),
      left: const BorderSide(color: tableBorderColor, width: 1),
      right: const BorderSide(color: tableBorderColor, width: 1),
      horizontalInside: const BorderSide(color: tableBorderColor, width: 1),
      verticalInside: const BorderSide(color: tableBorderColor, width: 1),
    );

    return Scaffold(
      appBar: CommonAppBar(),
      drawer: CommonDrawer(
        username: username,
        onLogout: _showLogoutConfirmDialog,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.pageTitle,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (_) => _runSearch(),
              decoration: InputDecoration(
                hintText: 'Search in table...',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF2196F3),
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF2196F3),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                width: 170,
                height: 46,
                child: ElevatedButton(
                  onPressed: _runSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A4F6B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Search',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF344963),
                      ),
                    )
                  : _filteredRows.isEmpty
                  ? const Center(child: Text('No matching SOP found'))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF9AA8B8),
                              ),
                            ),
                            child: ClipRRect(
                              child: DataTable2(
                                fixedTopRows: 1,
                                showCheckboxColumn: false,
                                headingRowColor: MaterialStateProperty.all(
                                  const Color(0xFF344963),
                                ),
                                dataRowColor: MaterialStateProperty.all(
                                  const Color(0xFFF0F1F3),
                                ),
                                headingRowHeight: 52,
                                dataRowHeight: 52,
                                columnSpacing: 0,
                                horizontalMargin: 0,
                                dividerThickness: 1,
                                minWidth: 1670,
                                border: tableBorder,
                                columns: tableColumns,
                                rows: groupedRows.map((group) {
                                      final row =
                                          group['row'] as Map<String, dynamic>;
                                      final notices =
                                          group['notices']
                                              as List<Map<String, dynamic>>;
                                      final qtyText = _pick(row, [
                                        'Qty',
                                        'qty',
                                        'Quantity',
                                      ]);
                                      final hoursText = _pick(row, [
                                        'Hours',
                                        'hours',
                                      ]);
                                      final qty = int.tryParse(qtyText) ?? 0;
                                      final hours =
                                          double.tryParse(hoursText) ?? 0;
                                      final isDisabled =
                                          row['Disabled'] == true;
                                      final noticeBg = _noticeBlockBackground(
                                        notices,
                                      );
                                      final responseRowBackgrounds = notices
                                          .map(
                                            (n) =>
                                                _responseRowBackground(row, n),
                                          )
                                          .toList();
                                      final dateValues = _noticeValues(
                                        notices,
                                        'date',
                                        hideDash: true,
                                      );
                                      final deptValues = _noticeValues(
                                        notices,
                                        'dept',
                                        hideDash: true,
                                      );
                                      final noticeValues = _noticeValues(
                                        notices,
                                        'notice',
                                        hideDash: true,
                                      );
                                      final responseValues = _noticeValues(
                                        notices,
                                        'response',
                                        hideDash: true,
                                      );
                                      final noticeRowHeights =
                                          _noticeRowHeights(
                                            noticeValues: noticeValues,
                                            noticeWidth: _noticeColumnWidth,
                                            textScaler: MediaQuery.textScalerOf(
                                              context,
                                            ),
                                          );

                                      return DataRow2(
                                        specificRowHeight:
                                            _dataRowHeightForGroup(
                                              group,
                                              context,
                                            ),
                                        color: WidgetStateProperty.all(
                                          isDisabled
                                              ? const Color(0xFFB5B5B5)
                                              : const Color(0xFFF0F1F3),
                                        ),
                                        cells: [
                                          DataCell(
                                            _tableTextCell(
                                              _pickSopNum(row),
                                              width: 56,
                                            ),
                                          ),
                                          DataCell(
                                            _tableTextCell(
                                              _formatDate(
                                                _pickPath(row, ['SOP', 'ODD']),
                                              ),
                                              width: 90,
                                            ),
                                          ),
                                          DataCell(
                                            _tableTextCell(
                                              _pickPath(row, [
                                                'SOP',
                                                'ProductionLogEntry',
                                                'LeadHand',
                                                'LeadHandName',
                                              ]),
                                              width: 82,
                                            ),
                                          ),
                                          DataCell(
                                            _tableTextCell(
                                              _pickPath(row, [
                                                'Assembler',
                                                'Name',
                                              ]),
                                              width: 90,
                                            ),
                                          ),
                                          DataCell(
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                              child: Container(
                                                width: 76,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF39495F,
                                                    ),
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  _pick(row, ['FixtureNumber']),
                                                  textAlign: TextAlign.center,
                                                  softWrap: true,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color.fromARGB(
                                                      255,
                                                      90,
                                                      106,
                                                      131,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            _tableTextCell(
                                              _pick(row, [
                                                'FixtureDescription',
                                                'Description',
                                                'Desc',
                                                'description',
                                              ]),
                                              width: 150,
                                              maxLines: 4,
                                            ),
                                          ),
                                          DataCell(
                                            _tableTextCell(
                                              _pick(row, [
                                                'Qty',
                                                'qty',
                                                'Quantity',
                                              ]),
                                              width: 40,
                                              align: TextAlign.center,
                                            ),
                                          ),
                                          DataCell(
                                            _tableTextCell(
                                              hoursText,
                                              width: 88,
                                              align: TextAlign.center,
                                            ),
                                          ),
                                          DataCell(
                                            _tableTextCell(
                                              (qty * hours).toStringAsFixed(2),
                                              width: 92,
                                              align: TextAlign.center,
                                            ),
                                          ),
                                          DataCell(
                                            _tableTextCell(
                                              _pick(row, ['Amount']),
                                              width: 70,
                                            ),
                                          ),
                                          DataCell(
                                            _tableTextCell(
                                              _pick(row, [
                                                'InventoryCommentsForProduction',
                                              ]),
                                              width: 130,
                                            ),
                                          ),
                                          DataCell(
                                            LayoutBuilder(
                                              builder: (context, constraints) {
                                                final w =
                                                    constraints.hasBoundedWidth &&
                                                        constraints.maxWidth > 0
                                                    ? constraints.maxWidth
                                                    : 58.0;
                                                return SizedBox(
                                                  width: w,
                                                  child: Stack(
                                                    clipBehavior: Clip.hardEdge,
                                                    fit: StackFit.expand,
                                                    children: [
                                                      Positioned(
                                                        left: 0,
                                                        right: 0,
                                                        top: 0,
                                                        bottom: 0,
                                                        child: ColoredBox(
                                                          color:
                                                              _pickedCellBackground(
                                                                row,
                                                              ),
                                                        ),
                                                      ),
                                                      Center(
                                                        child: Text(
                                                          row['Picked'] == true
                                                              ? 'Yes'
                                                              : 'No',
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          DataCell(
                                            _stackedNoticeCell(
                                              width: 90,
                                              values: dateValues,
                                              backgroundColor: noticeBg,
                                              rowHeights: noticeRowHeights,
                                            ),
                                          ),
                                          DataCell(
                                            _stackedNoticeCell(
                                              width: 88,
                                              values: deptValues,
                                              backgroundColor: noticeBg,
                                              rowHeights: noticeRowHeights,
                                            ),
                                          ),
                                          DataCell(
                                            _stackedNoticeCell(
                                              width: _noticeColumnWidth,
                                              values: noticeValues,
                                              backgroundColor: noticeBg,
                                              rowHeights: noticeRowHeights,
                                            ),
                                          ),
                                          DataCell(
                                            _stackedNoticeCell(
                                              width: 180,
                                              values: responseValues,
                                              backgroundColor: notices.isEmpty
                                                  ? Colors.transparent
                                                  : noticeBg,
                                              rowBackgrounds:
                                                  responseRowBackgrounds,
                                              rowHeights: noticeRowHeights,
                                            ),
                                          ),
                                          DataCell(
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                              child: OutlinedButton.icon(
                                                onPressed: () {
                                                  final sopLeadHandEntryId =
                                                      _pick(row, [
                                                        'SOPLeadHandEntryId',
                                                      ]);
                                                  if (sopLeadHandEntryId
                                                      .isEmpty) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'SOP Lead Hand Entry Id not found for this row.',
                                                        ),
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => Query(
                                                        sopLeadHandEntryId:
                                                            sopLeadHandEntryId,
                                                        showRemovedFromSop:
                                                            isDisabled,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  minimumSize: const Size(
                                                    86,
                                                    45,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 6,
                                                      ),
                                                  side: const BorderSide(
                                                    color: Colors.black,
                                                    width: 1,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  foregroundColor: Colors.black,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                                icon: const Icon(
                                                  Icons.edit,
                                                  size: 13,
                                                ),
                                                label: const Text(
                                                  'Edit',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                              ),
                            ),
                          ),
                        ),
                        ClipRRect(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: const Color(0xFF9AA8B8),
                                ),
                                right: BorderSide(
                                  color: const Color(0xFF9AA8B8),
                                ),
                                bottom: BorderSide(
                                  color: const Color(0xFF9AA8B8),
                                ),
                              ),
                            ),
                            child: _paginationBar(),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
