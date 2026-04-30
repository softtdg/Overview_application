import 'dart:math' show max, min;
import 'package:flutter/material.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Screen/Login/login.dart';
import 'package:overview_app/Screen/OpenItems/Components/Query.dart';
import 'package:overview_app/Screen/OpenItems/Services/OpenItemsServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CriticalItems extends StatefulWidget {
  @override
  _CriticalItemsState createState() => _CriticalItemsState();
}

class _CriticalItemsState extends State<CriticalItems> {
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
    if (value == null) return '*';
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

  List<Map<String, dynamic>> _buildNotices(Map<String, dynamic> row) {
    final notices = <Map<String, dynamic>>[];
    final notProduced = !_isProduced(row);

    if (_hasTextValue(row['LeadHandCommentsForPurchasing'])) {
      notices.add({
        'date': _formatDate(_valueText(row['NotifiedPurchasingDate'])),
        'dept': 'Purchasing',
        'notice': _valueText(row['LeadHandCommentsForPurchasing']),
        'response': '',
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

  Color _responseCellBackground(
    Map<String, dynamic> row,
    Map<String, dynamic> notice,
  ) {
    const alertColor = Color(0xFFD9534F);
    const darkAlertColor = Color(0xFF913734);
    const productionBaseColor = Color(0xFFC9A1A1);
    const productionPendingColor = Color(0xFFFFCCCC);
    const purchasingPendingColor = Color(0xFF99CCFF);

    final responseText = _valueText(notice['response']);
    final noticeBgColor = notice['bgColor'] is Color
        ? notice['bgColor'] as Color
        : Colors.transparent;

    if (responseText != '-') {
      return noticeBgColor;
    }

    // Keep production base shades as-is when response is empty.
    if (noticeBgColor == productionBaseColor ||
        noticeBgColor == productionPendingColor) {
      return noticeBgColor;
    }

    final notProduced = !_isProduced(row);
    final type = (notice['type'] ?? '').toString();

    if (type == 'purchasing') {
      return row['NotifyPurchasing'] == true && notProduced
          ? alertColor
          : darkAlertColor;
    }

    if (type == 'backorder') {
      final hasMismatch = notice['hasMismatch'] == true;
      return hasMismatch && notProduced ? alertColor : darkAlertColor;
    }

    if (type == 'production') {
      return row['NotifyProduction'] == true && notProduced
          ? alertColor
          : darkAlertColor;
    }

    // Final fallback.
    if (noticeBgColor == purchasingPendingColor ||
        noticeBgColor == productionPendingColor) {
      return alertColor;
    }
    return darkAlertColor;
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
      final response = await OpenItemsServices().CriticalItems();
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
            const Text(
              'Critical Items',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
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
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.all(
                                      const Color(0xFF344963),
                                    ),
                                    dataRowColor: MaterialStateProperty.all(
                                      const Color(0xFFF0F1F3),
                                    ),
                                    headingRowHeight: 52,
                                    dataRowMinHeight: 72,
                                    dataRowMaxHeight: 120,
                                    columnSpacing: 14,
                                    horizontalMargin: 12,
                                    dividerThickness: 1,
                                    border: TableBorder(
                                      top: BorderSide(
                                        color: Colors.black,
                                        width: 1,
                                      ),
                                      bottom: BorderSide(
                                        color: Colors.black,
                                        width: 1,
                                      ),
                                      left: BorderSide(
                                        color: Colors.black,
                                        width: 1,
                                      ),
                                      right: BorderSide(
                                        color: Colors.black,
                                        width: 1,
                                      ),
                                      horizontalInside: BorderSide(
                                        color: Colors.black,
                                        width: 1,
                                      ),
                                      verticalInside: BorderSide(
                                        color: Colors.black,
                                        width: 1,
                                      ),
                                    ),
                                    columns: [
                                      DataColumn(label: _heading('SOP')),
                                      DataColumn(label: _heading('ODD')),
                                      DataColumn(label: _heading('Lead\nHand')),
                                      DataColumn(label: _heading('Assembler')),
                                      DataColumn(label: _heading('Fixture')),
                                      DataColumn(label: _heading('Desc')),
                                      DataColumn(label: _heading('Qty')),
                                      DataColumn(
                                        label: _heading(
                                          'Time To\nBuild/Per\nUnit',
                                        ),
                                      ),
                                      DataColumn(
                                        label: _heading(
                                          'Total\nTime To\nBuild',
                                        ),
                                      ),
                                      DataColumn(label: _heading('Amount')),
                                      DataColumn(
                                        label: _heading('Inventory\nComment'),
                                      ),
                                      DataColumn(label: _heading('Picked')),
                                      DataColumn(label: _heading('Date Sent')),
                                      DataColumn(label: _heading('Dept')),
                                      DataColumn(label: _heading('Notice')),
                                      DataColumn(label: _heading('Response')),
                                      DataColumn(label: _heading('Action')),
                                    ],
                                    rows: _groupRowsForDisplay(_pagedRows).expand((
                                      group,
                                    ) {
                                      final row =
                                          group['row'] as Map<String, dynamic>;
                                      final displayNotices =
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

                                      return List<
                                        DataRow
                                      >.generate(displayNotices.length, (
                                        noticeIndex,
                                      ) {
                                        final notice =
                                            displayNotices[noticeIndex];
                                        final isFirstNotice = noticeIndex == 0;
                                        final noticeBg =
                                            notice['bgColor'] is Color
                                            ? notice['bgColor'] as Color
                                            : Colors.transparent;

                                        return DataRow(
                                          color: WidgetStateProperty.all(
                                            isDisabled
                                                ? const Color(0xFFB5B5B5)
                                                : const Color(0xFFF0F1F3),
                                          ),
                                          cells: [
                                            DataCell(
                                              _tableTextCell(
                                                isFirstNotice
                                                    ? _pickSopNum(row)
                                                    : '',
                                                width: 56,
                                              ),
                                            ),
                                            DataCell(
                                              _tableTextCell(
                                                isFirstNotice
                                                    ? _formatDate(
                                                        _pickPath(row, [
                                                          'SOP',
                                                          'ODD',
                                                        ]),
                                                      )
                                                    : '',
                                                width: 90,
                                              ),
                                            ),
                                            DataCell(
                                              _tableTextCell(
                                                isFirstNotice
                                                    ? _pickPath(row, [
                                                        'SOP',
                                                        'ProductionLogEntry',
                                                        'LeadHand',
                                                        'LeadHandName',
                                                      ])
                                                    : '',
                                                width: 82,
                                              ),
                                            ),
                                            DataCell(
                                              _tableTextCell(
                                                isFirstNotice
                                                    ? _pickPath(row, [
                                                        'Assembler',
                                                        'Name',
                                                      ])
                                                    : '',
                                                width: 90,
                                              ),
                                            ),
                                            DataCell(
                                              isFirstNotice
                                                  ? Container(
                                                      width: 76,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color: const Color(
                                                            0xFF39495F,
                                                          ),
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        _pick(row, [
                                                          'FixtureNumber',
                                                        ]),
                                                        textAlign:
                                                            TextAlign.center,
                                                        softWrap: true,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Color.fromARGB(
                                                            255,
                                                            90,
                                                            106,
                                                            131,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : _tableTextCell(
                                                      '',
                                                      width: 76,
                                                    ),
                                            ),
                                            DataCell(
                                              _tableTextCell(
                                                isFirstNotice
                                                    ? _pick(row, [
                                                        'FixtureDescription',
                                                        'Description',
                                                        'Desc',
                                                        'description',
                                                      ])
                                                    : '',
                                                width: 150,
                                                maxLines: 4,
                                              ),
                                            ),
                                            DataCell(
                                              _tableTextCell(
                                                isFirstNotice
                                                    ? _pick(row, [
                                                        'Qty',
                                                        'qty',
                                                        'Quantity',
                                                      ])
                                                    : '',
                                                width: 40,
                                                align: TextAlign.center,
                                              ),
                                            ),
                                            DataCell(
                                              _tableTextCell(
                                                isFirstNotice ? hoursText : '',
                                                width: 88,
                                                align: TextAlign.center,
                                              ),
                                            ),
                                            DataCell(
                                              _tableTextCell(
                                                isFirstNotice
                                                    ? (qty * hours)
                                                          .toStringAsFixed(2)
                                                    : '',
                                                width: 92,
                                                align: TextAlign.center,
                                              ),
                                            ),
                                            DataCell(
                                              _tableTextCell(
                                                isFirstNotice
                                                    ? _pick(row, ['Amount'])
                                                    : '',
                                                width: 70,
                                              ),
                                            ),
                                            DataCell(
                                              _tableTextCell(
                                                isFirstNotice
                                                    ? _pick(row, [
                                                        'InventoryCommentsForProduction',
                                                      ])
                                                    : '',
                                                width: 130,
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: 58,
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  fit: StackFit.expand,
                                                  children: [
                                                    Positioned(
                                                      left: -7,
                                                      right: -7,
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
                                                        isFirstNotice
                                                            ? (row['Picked'] ==
                                                                      true
                                                                  ? 'Yes'
                                                                  : 'No')
                                                            : '',
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
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: 90,
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  fit: StackFit.expand,
                                                  children: [
                                                    Positioned(
                                                      left: -7,
                                                      right: -7,
                                                      top: 0,
                                                      bottom: 0,
                                                      child: ColoredBox(
                                                        color: noticeBg,
                                                      ),
                                                    ),
                                                    Center(
                                                      child: Text(
                                                        _valueText(
                                                          notice['date'],
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: 88,
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  fit: StackFit.expand,
                                                  children: [
                                                    Positioned(
                                                      left: -7,
                                                      right: -7,
                                                      top: 0,
                                                      bottom: 0,
                                                      child: ColoredBox(
                                                        color: noticeBg,
                                                      ),
                                                    ),
                                                    Center(
                                                      child: Text(
                                                        _valueText(
                                                          notice['dept'],
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                        maxLines: 4,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: 90,
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  fit: StackFit.expand,
                                                  children: [
                                                    Positioned(
                                                      left: -7,
                                                      right: -7,
                                                      top: 0,
                                                      bottom: 0,
                                                      child: ColoredBox(
                                                        color: noticeBg,
                                                      ),
                                                    ),
                                                    Center(
                                                      child: Text(
                                                        _valueText(
                                                          notice['notice'],
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                        maxLines: 6,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: 180,
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  fit: StackFit.expand,
                                                  children: [
                                                    Positioned(
                                                      left: -7,
                                                      right: -7,
                                                      top: 0,
                                                      bottom: 0,
                                                      child: ColoredBox(
                                                        color:
                                                            _responseCellBackground(
                                                              row,
                                                              notice,
                                                            ),
                                                      ),
                                                    ),
                                                    Center(
                                                      child: Text(
                                                        _valueText(
                                                                  notice['response'],
                                                                ) ==
                                                                ''
                                                            ? ''
                                                            : _valueText(
                                                                notice['response'],
                                                              ),
                                                        textAlign:
                                                            TextAlign.center,
                                                        maxLines: 6,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              isFirstNotice
                                                  ? OutlinedButton.icon(
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
                                                              horizontal: 10,
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
                                                        foregroundColor:
                                                            Colors.black,
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                      ),
                                                      icon: const Icon(
                                                        Icons.edit,
                                                        size: 13,
                                                      ),
                                                      label: const Text(
                                                        'Edit',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    )
                                                  : const SizedBox.shrink(),
                                            ),
                                          ],
                                        );
                                      });
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(10),
                          ),
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
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(10),
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
