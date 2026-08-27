import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/Inventory-Search/Services/InventorySearchService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Utils/responsive.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:overview_app/Widgets/pagination_bar.dart';

class InventorySearch extends StatefulWidget {
  @override
  _InventorySearchState createState() => _InventorySearchState();
}

class _InventorySearchState extends State<InventorySearch> {
  final InventorySearchService _service = const InventorySearchService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _suggestionScrollController = ScrollController();

  static const Color _searchButtonColor = Color(0xFF1565C0);
  static const Color _headerBlue = Color.fromARGB(255, 57, 73, 95);
  static const int _pageSize = 25;

  List<_PartSuggestion> _suggestions = [];
  Map<String, dynamic> _partSummary = {};
  List<Map<String, dynamic>> _inventoryItems = [];
  List<Map<String, dynamic>> _rows = [];
  bool _showDetail = false;
  bool _isLoading = false;
  int _currentPage = 1;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _suggestionScrollController.dispose();
    super.dispose();
  }

  String _display(dynamic value) {
    if (value == null) return '-';
    final s = value.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return '-';
    return s;
  }

  String _formatDate(String raw) {
    if (raw.isEmpty || raw == '-') return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('MM/dd/yyyy').format(parsed.toLocal());
  }

  String _formatPrice(dynamic value) {
    if (value == null) return '-';
    final n = num.tryParse(value.toString().trim());
    if (n == null) return _display(value);
    return n.toStringAsFixed(2);
  }

  void _newSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _suggestions = [];
      _partSummary = {};
      _inventoryItems = [];
      _rows = [];
      _showDetail = false;
      _isLoading = false;
      _currentPage = 1;
      _sortColumnIndex = null;
      _sortAscending = true;
    });
  }

  List<_PartSuggestion> _parseSuggestions(dynamic data) {
    if (data is! Map) return [];
    final list = data['data'];
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) {
          final tdgpn = (e['TDGPN']).toString().trim();
          final description = (e['Description']).toString().trim();
          return _PartSuggestion(tdgpn: tdgpn, description: description);
        })
        .where((s) => s.tdgpn.isNotEmpty)
        .toList();
  }

  void _applyInventoryPayload(dynamic payload) {
    final data = payload is Map ? payload['data'] : null;
    if (data is! Map) {
      setState(() {
        _partSummary = {};
        _inventoryItems = [];
        _rows = [];
        _showDetail = true;
        _suggestions = [];
        _isLoading = false;
        _currentPage = 1;
      });
      return;
    }

    final inventory = data['inventory'];
    final items = inventory is List
        ? inventory
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    setState(() {
      _partSummary = Map<String, dynamic>.from(data);
      _inventoryItems = items;
      _rows = _parseAllSopsRows(data['allSops']);
      _showDetail = true;
      _suggestions = [];
      _isLoading = false;
      _currentPage = 1;
    });
  }

  /// Flatten [allSops]: one SOP row from each entry + one row per nested mpf.
  List<Map<String, dynamic>> _parseAllSopsRows(dynamic allSops) {
    if (allSops is! List) return [];

    final rows = <Map<String, dynamic>>[];
    for (final raw in allSops.whereType<Map>()) {
      final sop = Map<String, dynamic>.from(raw);

      rows.add({
        'sopMpf': 'SOP',
        'sopNumber': sop['SOPNumber'],
        'totalQtyNeeded': sop['totalQtyNeeded'] ?? sop['totalQty'],
        'qtyPicked': sop['qtyToPick'],
        'comment': sop['comments'],
        'requestedBy': '',
        'date': sop['requestedOn'],
        'totalPrice': sop['unitPrice'],
      });

      final mpfList = sop['mpf'];
      if (mpfList is! List) continue;
      for (final mpfRaw in mpfList.whereType<Map>()) {
        final mpf = Map<String, dynamic>.from(mpfRaw);
        final sheet = mpf['mpfSheetNumber'];
        rows.add({
          'sopMpf': sheet == null || '$sheet'.trim().isEmpty
              ? 'MPF'
              : 'MPF ($sheet)',
          'sopNumber': sop['SOPNumber'],
          'totalQtyNeeded': mpf['totalQtyNeeded'],
          'qtyPicked': mpf['qtyToPick'],
          'comment': mpf['comments'],
          'requestedBy': mpf['requestedBy'],
          'date': mpf['requestedOn'],
          'totalPrice': mpf['mpfPrice'],
        });
      }
    }
    return rows;
  }

  Future<void> _fetchSuggestions(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      if (!mounted) return;
      setState(() => _suggestions = []);
      return;
    }

    try {
      await Dioservices.setToken();
      final response = await _service.searchPart(tdgpn: q);
      if (!mounted) return;
      setState(() => _suggestions = _parseSuggestions(response.data));
    } catch (e) {
      if (!mounted) return;
      setState(() => _suggestions = []);
      debugPrint('Inventory search suggestions error: $e');
    }
  }

  Future<void> _fetchInventory(String query) async {
    final tdgpn = query.trim();
    if (tdgpn.isEmpty) return;

    setState(() {
      _isLoading = true;
      _suggestions = [];
      _showDetail = true;
      _partSummary = {};
      _inventoryItems = [];
      _rows = [];
    });
    _searchFocus.unfocus();

    try {
      await Dioservices.setToken();
      final response = await _service.getSearchPartInventory(tdgpn: tdgpn);
      if (!mounted) return;
      _applyInventoryPayload(response.data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _partSummary = {};
        _inventoryItems = [];
        _rows = [];
        _isLoading = false;
      });
      debugPrint('Inventory fetch error: $e');
    }
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(value);
    });
  }

  void _selectSuggestion(_PartSuggestion item) {
    _searchController.text = item.tdgpn;
    _searchController.selection = TextSelection.collapsed(
      offset: item.tdgpn.length,
    );
    _fetchInventory(item.tdgpn);
  }

  List<Map<String, dynamic>> get _sortedRows {
    final list = List<Map<String, dynamic>>.from(_rows);
    final col = _sortColumnIndex;
    if (col == null) return list;

    String cell(Map<String, dynamic> row) {
      switch (col) {
        case 0:
          return _display(row['sopMpf']);
        case 1:
          return _display(row['sopNumber']);
        case 2:
          return _display(row['totalQtyNeeded']);
        case 3:
          return _display(row['qtyPicked']);
        case 4:
          return _display(row['comment']);
        case 5:
          return _display(row['requestedBy']);
        case 6:
          return _formatDate(_display(row['date']));
        case 7:
          return _formatPrice(row['totalPrice']);
        default:
          return '';
      }
    }

    list.sort((a, b) {
      final cmp = cell(a).toLowerCase().compareTo(cell(b).toLowerCase());
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  List<Map<String, dynamic>> get _visibleRows {
    final sorted = _sortedRows;
    final start = (_currentPage - 1) * _pageSize;
    if (start >= sorted.length) return [];
    final end = (start + _pageSize).clamp(0, sorted.length);
    return sorted.sublist(start, end);
  }

  int get _totalPages {
    if (_rows.isEmpty) return 1;
    return (_rows.length + _pageSize - 1) ~/ _pageSize;
  }

  void _onSort(int columnIndex) {
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

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: _searchButtonColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  Widget _summaryCell(
    String text, {
    int flex = 1,
    bool header = false,
    bool showRightBorder = true,
  }) {
    final borderColor = Colors.grey.shade500;
    return Expanded(
      flex: flex,
      child: Container(
        alignment: header ? Alignment.centerLeft : Alignment.topLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: header ? const Color(0xFFF3F4F6) : Colors.white,
          border: Border(
            right: showRightBorder
                ? BorderSide(color: borderColor)
                : BorderSide.none,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: header ? FontWeight.w700 : FontWeight.w400,
            color: const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryTable() {
    final List<Map<String, dynamic>> rows = _inventoryItems.isEmpty
        ? <Map<String, dynamic>>[{}]
        : _inventoryItems;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade500),
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _summaryCell('Location', header: true),
                _summaryCell('Type', header: true),
                _summaryCell('Qty On Hand', header: true),
                _summaryCell('Unit Price', header: true),
                _summaryCell('Category', header: true),
                _summaryCell(
                  'Description',
                  flex: 3,
                  header: true,
                  showRightBorder: false,
                ),
              ],
            ),
          ),
          for (final item in rows) ...[
            Divider(height: 1, thickness: 1, color: Colors.grey.shade500),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _summaryCell(_display(item['location'])),
                  _summaryCell(_display(item['fileType'])),
                  _summaryCell(_display(item['qtyOnHand'])),
                  _summaryCell(
                    (double.tryParse(_display(item['unitPrice'])) ?? 0)
                        .toStringAsFixed(2),
                  ),
                  _summaryCell(_display(item['category'])),
                  _summaryCell(
                    _display(item['description']),
                    flex: 3,
                    showRightBorder: false,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerCell(String label, double width, int sortIndex) {
    final active = _sortColumnIndex == sortIndex;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => _onSort(sortIndex),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: _headerBlue,
            border: Border(
              right: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color.fromRGBO(255, 255, 255, 1),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                active && !_sortAscending
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                size: 12,
                color: active ? Colors.white : const Color(0x99B8C8E8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dataCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey.shade300),
            bottom: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
        ),
      ),
    );
  }

  Widget _buildTransactionsTable() {
    // Min widths for small screens; scaled up to fill available width.
    const minWidths = <double>[100, 80, 130, 90, 160, 110, 100, 100];
    final minTotal = minWidths.fold<double>(0, (a, b) => a + b);

    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Border takes 1px left + 1px right; columns must fit inside content box.
          const borderWidth = 1.0;
          final contentW = (constraints.maxWidth - borderWidth * 2).clamp(
            0.0,
            double.infinity,
          );
          final needsHScroll = contentW < minTotal;
          final tableW = needsHScroll ? minTotal : contentW;

          // Floor scaled widths, give leftover to last column so sum == tableW.
          final scale = tableW / minTotal;
          final widths = List<double>.generate(minWidths.length, (i) {
            if (i == minWidths.length - 1) return 0;
            return (minWidths[i] * scale).floorToDouble();
          });
          final used = widths.fold<double>(0, (a, b) => a + b);
          widths[widths.length - 1] = tableW - used;

          final table = Container(
            width: tableW + borderWidth * 2,
            height: constraints.maxHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: Colors.grey.shade300,
                width: borderWidth,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _headerCell('SOP/MPF', widths[0], 0),
                    _headerCell('SOP#', widths[1], 1),
                    _headerCell('Total QTY Needed', widths[2], 2),
                    _headerCell('Qty Picked', widths[3], 3),
                    _headerCell('Comment', widths[4], 4),
                    _headerCell('Requested by', widths[5], 5),
                    _headerCell('Date', widths[6], 6),
                    _headerCell('Total Price', widths[7], 7),
                  ],
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _visibleRows.length,
                    itemBuilder: (context, index) {
                      final row = _visibleRows[index];
                      return Row(
                        children: [
                          _dataCell(_display(row['sopMpf']), widths[0]),
                          _dataCell(_display(row['sopNumber']), widths[1]),
                          _dataCell(_display(row['totalQtyNeeded']), widths[2]),
                          _dataCell(_display(row['qtyPicked']), widths[3]),
                          _dataCell(_display(row['comment']), widths[4]),
                          _dataCell(_display(row['requestedBy']), widths[5]),
                          _dataCell(
                            _formatDate(_display(row['date'])),
                            widths[6],
                          ),
                          _dataCell(_formatPrice(row['totalPrice']), widths[7]),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );

          if (!needsHScroll) return table;
          return Responsive.hideScrollbars(
            context,
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: table,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailView(Responsive r) {
    // Prefer allSops[].unitPrice when present; otherwise inventory[].unitPrice.
    final allSops = _partSummary['allSops'];
    String perUnit = '0';
    if (allSops is List && allSops.isNotEmpty && allSops.first is Map) {
      perUnit = _display((allSops.first as Map)['unitPrice']);
    } else if (_inventoryItems.isNotEmpty) {
      perUnit = _display(_inventoryItems.first['unitPrice']);
    }

    final headerRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _actionButton(
          icon: Icons.search,
          label: 'New Search',
          onPressed: _newSearch,
        ),
        Flexible(
          child: Text(
            'TDGPN: ${_display(_partSummary['TDGPN'])}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            'Per Unit Price: ${perUnit == '-' ? '0' : perUnit}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.pagePaddingH,
        r.pagePaddingV,
        r.pagePaddingH,
        r.pagePaddingV,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(padding: const EdgeInsets.all(12), child: headerRow),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: AppLoader()),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _buildSummaryTable(),
                  ),
              ],
            ),
          ),
          if (!_isLoading) ...[
            const SizedBox(height: 14),
            if (_rows.isEmpty)
              Expanded(
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    'No results found for "${_display(_partSummary['TDGPN'])}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  ),
                ),
              )
            else ...[
              _buildTransactionsTable(),
              const SizedBox(height: 12),
              PaginationBar(
                currentPage: _currentPage.clamp(1, _totalPages),
                totalPages: _totalPages,
                fromItem: ((_currentPage - 1) * _pageSize) + 1,
                toItem: (_currentPage * _pageSize).clamp(0, _rows.length),
                totalItems: _rows.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionBox() {
    const headerStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: Color.fromARGB(255, 72, 75, 82),
    );
    const tdgpnStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Color.fromARGB(255, 70, 76, 88),
    );
    const descStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: Color.fromARGB(255, 66, 69, 77),
    );

    Widget columns({
      required Widget tdgpn,
      required Widget description,
      Color? background,
    }) {
      return ColoredBox(
        color: background ?? Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 150, child: tdgpn),
              const SizedBox(width: 12),
              Expanded(child: description),
            ],
          ),
        ),
      );
    }

    return Material(
      elevation: 4,
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 260,
        child: Column(
          children: [
            columns(
              background: const Color.fromARGB(255, 224, 227, 230),
              tdgpn: const Text('TDGPN', style: headerStyle),
              description: const Text('DESCRIPTION', style: headerStyle),
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
            Expanded(
              child: RawScrollbar(
                controller: _suggestionScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                thickness: 10,
                radius: const Radius.circular(4),
                thumbColor: Colors.grey.shade600,
                trackColor: Colors.grey.shade300,
                trackBorderColor: Colors.transparent,
                child: ListView.separated(
                  controller: _suggestionScrollController,
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey.shade200,
                  ),
                  itemBuilder: (context, index) {
                    final item = _suggestions[index];
                    return InkWell(
                      onTap: () => _selectSuggestion(item),
                      child: columns(
                        tdgpn: Text(
                          item.tdgpn,
                          style: tdgpnStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        description: Text(
                          item.description.isEmpty
                              ? '-'
                              : item.description.toUpperCase(),
                          style: descStyle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredSearch(Responsive r) {
    const fieldHeight = 48.0;
    const navy = Color.fromARGB(255, 57, 73, 95);
    const fieldBorder = Color.fromARGB(255, 22, 129, 218);
    final searchFieldWidth = (r.width - (r.pagePaddingH * 2)).clamp(
      260.0,
      r.isPhone ? 320.0 : 480.0,
    );

    final sharedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: fieldBorder, width: 1.5),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Colors.blue, width: 1.5),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _searchFocus.unfocus();
        setState(() => _suggestions = []);
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: r.pagePaddingH,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: searchFieldWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Inventory Search',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: r.isPhone ? 22 : r.pageTitleSize + 4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: r.isPhone ? 16 : 20),
                SizedBox(
                  height: fieldHeight,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: _onQueryChanged,
                    onSubmitted: (_) => _fetchInventory(_searchController.text),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Enter part number',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: sharedBorder,
                      enabledBorder: sharedBorder,
                      focusedBorder: focusedBorder,
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: Icon(
                                Icons.close,
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                _debounce?.cancel();
                                _searchController.clear();
                                setState(() => _suggestions = []);
                              },
                            ),
                    ),
                  ),
                ),
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _buildSuggestionBox(),
                ],
                SizedBox(height: r.isPhone ? 12 : 14),
                SizedBox(
                  height: fieldHeight,
                  width: 160,
                  child: ElevatedButton(
                    onPressed: () => _fetchInventory(_searchController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Scaffold(
      backgroundColor: _showDetail ? const Color(0xFFF3F4F6) : Colors.white,
      appBar: CommonAppBar(
        showBackButton: true,
        onBackPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
      drawer: const CommonDrawer(),
      body: _showDetail ? _buildDetailView(r) : _buildCenteredSearch(r),
    );
  }
}

class _PartSuggestion {
  const _PartSuggestion({required this.tdgpn, required this.description});

  final String tdgpn;
  final String description;
}
