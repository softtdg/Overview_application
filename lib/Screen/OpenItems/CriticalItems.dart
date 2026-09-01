import 'dart:math' show max, min;
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Screen/OpenItems/Components/Query.dart';
import 'package:overview_app/Screen/OpenItems/Services/OpenItemsServices.dart';
import 'package:overview_app/Utils/api_date.dart';
import 'package:overview_app/Utils/responsive.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/AppToast.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:overview_app/Widgets/pagination_bar.dart';
import 'package:overview_app/Screen/Public-Search/PublicSearch.dart';

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
  static const double _noticeColumnWidth = 200;
  static const double _noticeCellHorizontalPadding = 8;
  static const double _noticeCellVerticalPadding = 8;
  static const double _noticeMinSubRowHeight = 52;
  static const double _actionColumnWidth = 72;
  static const int _pickedColumnIndex = 11;
  static const int _sopColumnIndex = 0;
  static const int _oddColumnIndex = 1;
  static const int _fixtureColumnIndex = 2;
  static const int _leadHandColumnIndex = 3;
  static const int _assemblerColumnIndex = 4;
  static const int _descColumnIndex = 5;
  static const int _qtyColumnIndex = 6;
  static const int _hoursColumnIndex = 7;
  static const int _totalTimeColumnIndex = 8;
  static const int _amountColumnIndex = 9;
  static const int _inventoryCommentColumnIndex = 10;
  final String username = 'John Doe';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tableVerticalScroll = ScrollController();
  final ScrollController _tableHorizontalScroll = ScrollController();
  final ScrollController _actionsVerticalScroll = ScrollController();
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _filteredData = [];
  String _pickedFilter = 'All';
  String _searchQuery = '';
  bool _isLoading = true;
  int _currentPage = 1;
  int _rowsPerPage = 50;
  int? _sortColumnIndex;
  bool _sortAscending = true;

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

  String _pickOdd(Map<String, dynamic> row) {
    final direct = _pick(row, ['ODD', 'odd', 'Date']);
    if (direct.isNotEmpty) return direct;

    final sop = row['SOP'];
    if (sop is Map) {
      final odd = _pick(Map<String, dynamic>.from(sop), ['ODD', 'odd', 'Date']);
      if (odd.isNotEmpty) return odd;
    }

    return _pickPath(row, ['SOP', 'ODD']);
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

  String _searchableRowText(Map<String, dynamic> row) {
    final qtyText = _pick(row, ['Quantity']);
    final hoursText = _pick(row, ['Hours']);
    final qty = int.tryParse(qtyText) ?? 0;
    final hours = double.tryParse(hoursText) ?? 0;
    final parts = <String>[
      _pickSopNum(row),
      _formatDate(_pickOdd(row)),
      _pick(row, ['FixtureNumber']),
      _pickPath(row, ['SOP', 'ProductionLogEntry', 'LeadHand', 'LeadHandName']),
      _pickPath(row, ['Assembler', 'Name']),
      _pick(row, ['FixtureDescription']),
      qtyText,
      hoursText,
      (qty * hours).toStringAsFixed(2),
      _pick(row, ['Amount']),
      _pick(row, ['InventoryCommentsForProduction']),
      row['Picked'] == true ? 'Yes' : 'No',
      _pick(row, ['LeadHandCommentsForPurchasing']),
      _pick(row, [
        'PurchasingComments',
        'PurchasingResponse',
        'LeadHandPurchasingResponse',
      ]),
      _pick(row, ['LeadHandCommentsForProduction']),
      _pick(row, [
        'ProductionComments',
        'ProductionResponse',
        'LeadHandProductionResponse',
      ]),
    ];

    for (final notice in _buildNotices(row)) {
      parts.add(_valueText(notice['date']));
      parts.add(_valueText(notice['dept']));
      parts.add(_valueText(notice['notice']));
      parts.add(_valueText(notice['response']));
    }

    final backorders = row['Backorders'];
    if (backorders is List) {
      for (final item in backorders) {
        if (item is! Map) continue;
        parts.add(_valueText(item['TDGPN']));
        parts.add(_valueText(item['Quantity']));
        parts.add(_valueText(item['UOM']));
        parts.add(_valueText(item['Response']));
        parts.add(_valueText(item['NoticeDate']));
        parts.add(_valueText(item['ClosedDate']));
      }
    }

    return parts.where((p) => p.trim().isNotEmpty && p != '-').join(' ');
  }

  bool _matchesSearch(Map<String, dynamic> row, String query) {
    if (query.isEmpty) return true;
    return _searchableRowText(row).toLowerCase().contains(query.toLowerCase());
  }

  List<Map<String, dynamic>> get _filteredRows {
    List<Map<String, dynamic>> data =
        _filteredData.isEmpty && _pickedFilter == "All" ? _rows : _filteredData;

    if (_searchQuery.isNotEmpty) {
      data = data.where((row) => _matchesSearch(row, _searchQuery)).toList();
    }

    if (_sortColumnIndex != null) {
      data = List<Map<String, dynamic>>.from(data);
      data.sort((a, b) {
        final cmp = _compareForActiveSort(a, b);
        if (cmp != 0) return _sortAscending ? cmp : -cmp;
        return _pickSopNum(a).compareTo(_pickSopNum(b));
      });
    }

    return data;
  }

  int _pickedSortKey(Map<String, dynamic> row) {
    if (row['Picked'] == true || row['pickedStatus'] == 1) return 1;
    return 0;
  }

  DateTime? _oddAsDateTime(Map<String, dynamic> row) {
    final raw = _pickOdd(row).trim();
    if (raw.isEmpty || raw == '-') return null;
    return ApiDate.parseFlexible(raw);
  }

  double _numValue(Map<String, dynamic> row, List<String> keys) {
    return double.tryParse(_pick(row, keys).replaceAll(',', '')) ?? 0;
  }

  double _totalBuildTime(Map<String, dynamic> row) {
    return _numValue(row, ['Quantity']) * _numValue(row, ['Hours']);
  }

  int _compareForActiveSort(Map<String, dynamic> a, Map<String, dynamic> b) {
    final i = _sortColumnIndex;
    if (i == null) return 0;
    switch (i) {
      case _sopColumnIndex:
        final sa = _pickSopNum(a);
        final sb = _pickSopNum(b);
        final ia = int.tryParse(sa);
        final ib = int.tryParse(sb);
        if (ia != null && ib != null) return ia.compareTo(ib);
        return sa.toLowerCase().compareTo(sb.toLowerCase());
      case _oddColumnIndex:
        final da = _oddAsDateTime(a);
        final db = _oddAsDateTime(b);
        if (da != null && db != null) return da.compareTo(db);
        if (da != null) return -1;
        if (db != null) return 1;
        return _pickOdd(a).toLowerCase().compareTo(_pickOdd(b).toLowerCase());
      case _leadHandColumnIndex:
        return _pickPath(a, [
          'SOP',
          'ProductionLogEntry',
          'LeadHand',
          'LeadHandName',
        ]).toLowerCase().compareTo(
          _pickPath(b, [
            'SOP',
            'ProductionLogEntry',
            'LeadHand',
            'LeadHandName',
          ]).toLowerCase(),
        );
      case _assemblerColumnIndex:
        return _pickPath(a, ['Assembler', 'Name']).toLowerCase().compareTo(
          _pickPath(b, ['Assembler', 'Name']).toLowerCase(),
        );
      case _fixtureColumnIndex:
        return _pick(a, [
          'FixtureNumber',
        ]).toLowerCase().compareTo(_pick(b, ['FixtureNumber']).toLowerCase());
      case _descColumnIndex:
        return _pick(a, ['FixtureDescription']).toLowerCase().compareTo(
          _pick(b, ['FixtureDescription']).toLowerCase(),
        );
      case _qtyColumnIndex:
        return _numValue(a, ['Quantity']).compareTo(_numValue(b, ['Quantity']));
      case _hoursColumnIndex:
        return _numValue(a, ['Hours']).compareTo(_numValue(b, ['Hours']));
      case _totalTimeColumnIndex:
        return _totalBuildTime(a).compareTo(_totalBuildTime(b));
      case _amountColumnIndex:
        return _numValue(a, ['Amount']).compareTo(_numValue(b, ['Amount']));
      case _inventoryCommentColumnIndex:
        return _pick(a, [
          'InventoryCommentsForProduction',
        ]).toLowerCase().compareTo(
          _pick(b, ['InventoryCommentsForProduction']).toLowerCase(),
        );
      case _pickedColumnIndex:
        return _pickedSortKey(a).compareTo(_pickedSortKey(b));
      default:
        return 0;
    }
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _currentPage = 1;
      _clampCurrentPage();
    });
  }

  void _runSearch() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _currentPage = 1;
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
    const textStyle = TextStyle(
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w500,
    );
    final maxTextWidth = (noticeWidth - (_noticeCellHorizontalPadding * 2) - 4)
        .clamp(40.0, double.infinity);

    return noticeValues.map((value) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: textStyle),
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: maxTextWidth);

      final needed = painter.height + (_noticeCellVerticalPadding * 2) + 8;
      return needed < _noticeMinSubRowHeight ? _noticeMinSubRowHeight : needed;
    }).toList();
  }

  Widget _stackedNoticeCell({
    required double width,
    required List<String> values,
    required Color backgroundColor,
    List<Color>? rowBackgrounds,
    List<double>? rowHeights,
    TextAlign textAlign = TextAlign.left,
  }) {
    final perRowBg =
        rowBackgrounds != null && rowBackgrounds.length == values.length;

    final Color cellFillColor;
    if (perRowBg && rowBackgrounds.isNotEmpty) {
      final last = rowBackgrounds.last;
      cellFillColor = last == Colors.transparent ? backgroundColor : last;
    } else {
      cellFillColor = backgroundColor;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.hasBoundedWidth && constraints.maxWidth > 0
            ? constraints.maxWidth
            : width;

        final h = constraints.hasBoundedHeight && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : null;

        if (values.isEmpty) {
          return SizedBox(
            width: w,
            height: h ?? _noticeMinSubRowHeight,
            child: ColoredBox(color: cellFillColor),
          );
        }

        return SizedBox(
          width: w,
          height: h,
          child: ColoredBox(
            color: cellFillColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...values.asMap().entries.map((entry) {
                  final index = entry.key;
                  final value = entry.value;
                  final isLast = index == values.length - 1;
                  final rowHeight =
                      rowHeights != null && index < rowHeights.length
                      ? rowHeights[index]
                      : _noticeMinSubRowHeight;
                  final rowBg = perRowBg ? rowBackgrounds[index] : null;

                  return Container(
                    width: w,
                    height: rowHeight,
                    alignment: textAlign == TextAlign.left
                        ? Alignment.centerLeft
                        : textAlign == TextAlign.right
                        ? Alignment.centerRight
                        : Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: _noticeCellHorizontalPadding,
                      vertical: _noticeCellVerticalPadding,
                    ),
                    decoration: BoxDecoration(
                      color: rowBg,
                      border: isLast
                          ? null
                          : const Border(
                              bottom: BorderSide(
                                color: Color(0xFFD1D5DB),
                                width: 1,
                              ),
                            ),
                    ),
                    child: _highlightedText(
                      value,
                      textAlign: textAlign,
                      softWrap: true,
                      maxLines: 10,
                      overflow: TextOverflow.clip,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }),
                if (h != null) const Spacer(),
              ],
            ),
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

  String _formatDate(String value) => ApiDate.formatMmDdYyyy(value);

  Widget _heading(String text) {
    final multi = text.contains('\n');
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          text,
          textAlign: TextAlign.left,
          maxLines: multi ? 3 : 1,
          softWrap: multi,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            height: 1.15,
          ),
        ),
      ),
    );
  }

  Widget _sortableHeading(String text, int columnIndex) {
    const style = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 12,
      height: 1.15,
    );
    final active = _sortColumnIndex == columnIndex;
    final up = !active || _sortAscending;
    final multi = text.contains('\n');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.left,
              maxLines: multi ? 3 : 1,
              softWrap: multi,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            up ? Icons.arrow_upward : Icons.arrow_downward,
            size: 11,
            color: active ? Colors.white : const Color(0x99B8C8E8),
          ),
        ],
      ),
    );
  }

  DataColumn2 _column(
    String text, {
    required double minWidth,
    double? fixedWidth,
    int? sortKey,
    Widget? cutomLabels,
    DataColumnSortCallback? onSort,
  }) {
    final label =
        cutomLabels ??
        (sortKey != null ? _sortableHeading(text, sortKey) : _heading(text));
    return DataColumn2(
      headingRowAlignment: MainAxisAlignment.start,
      minWidth: minWidth,
      fixedWidth: fixedWidth,
      label: label,
      onSort: onSort,
    );
  }

  List<double> _columnBaseWidths({
    required bool includeAction,
    required bool compact,
  }) {
    // Order: SOP, ODD, Fixture are sticky (fixedLeftColumns: 3).
    return [
      compact ? 72 : 70, // SOP
      compact ? 100 : 100, // ODD
      130, // Fixture
      compact ? 100 : 96, // Lead Hand
      110, // Assembler
      compact ? 160 : 190, // Desc
      72, // Qty
      compact ? 76 : 100, // Time
      compact ? 76 : 100, // Total
      90, // Amount
      compact ? 130 : 150, // Comment
      84, // Picked
      100, // Date Sent
      110, // Dept (Purchasing)
      _noticeColumnWidth, // Notice
      compact ? 160 : 200, // Response
      if (includeAction) _actionColumnWidth, // Action
    ];
  }

  /// Readable column widths. Never shrink below base — when the viewport is
  /// narrower, DataTable2 scrolls horizontally instead of crushing text.
  List<double> _columnWidthsFor({
    required double available,
    required bool includeAction,
    required bool compact,
  }) {
    final bases = _columnBaseWidths(
      includeAction: includeAction,
      compact: compact,
    );
    final total = bases.fold<double>(0, (a, b) => a + b);
    if (total <= 0 || available <= total) return bases;
    final scale = available / total;
    final widths = bases.map((w) => w * scale).toList();
    final sum = widths.fold<double>(0, (a, b) => a + b);
    widths[widths.length - 1] += available - sum;
    return widths;
  }

  List<DataColumn2> _criticalDataColumns({
    required List<double> widths,
    required bool includeAction,
    required bool compact,
  }) {
    DataColumn2 col(
      int index,
      String text, {
      int? sortKey,
      DataColumnSortCallback? onSort,
    }) {
      final w = widths[index];
      return _column(
        text,
        minWidth: w,
        fixedWidth: w,
        sortKey: sortKey,
        onSort: onSort,
      );
    }

    return [
      col(0, 'SOP', sortKey: _sopColumnIndex, onSort: _onSort),
      col(1, 'ODD', sortKey: _oddColumnIndex, onSort: _onSort),
      col(2, 'Fixture', sortKey: _fixtureColumnIndex, onSort: _onSort),
      col(
        3,
        compact ? 'Lead Hand' : 'Lead\nHand',
        sortKey: _leadHandColumnIndex,
        onSort: _onSort,
      ),
      col(4, 'Assembler', sortKey: _assemblerColumnIndex, onSort: _onSort),
      col(5, 'Desc', sortKey: _descColumnIndex, onSort: _onSort),
      col(6, 'Qty', sortKey: _qtyColumnIndex, onSort: _onSort),
      col(
        7,
        compact ? 'Time' : 'Time To\nBuild/Per\nUnit',
        sortKey: _hoursColumnIndex,
        onSort: _onSort,
      ),
      col(
        8,
        compact ? 'Total' : 'Total\nTime To\nBuild',
        sortKey: _totalTimeColumnIndex,
        onSort: _onSort,
      ),
      col(9, 'Amount', sortKey: _amountColumnIndex, onSort: _onSort),
      col(
        10,
        compact ? 'Comment' : 'Inventory\nComment',
        sortKey: _inventoryCommentColumnIndex,
        onSort: _onSort,
      ),
      col(11, 'Picked', sortKey: _pickedColumnIndex, onSort: _onSort),
      col(12, 'Date Sent'),
      col(13, 'Dept'),
      col(14, 'Notice'),
      col(15, 'Response'),
      if (includeAction) col(16, 'Action'),
    ];
  }

  /// Display like reference: first two hyphen groups on line 1, rest below.
  /// e.g. `190-100-1573RPR` → `190-100-\n1573RPR`
  String _fixtureDisplayText(String fixture) {
    final parts = fixture.split('-');
    if (parts.length < 3) return fixture;
    final firstLine = '${parts[0]}-${parts[1]}-';
    final secondLine = parts.sublist(2).join('-');
    return '$firstLine\n$secondLine';
  }

  Widget _buildFixtureCell(Map<String, dynamic> row) {
    final fixture = _pick(row, ['FixtureNumber']);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 76.0;
        final boxW = min(76.0, max(24.0, cellW - 8));
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: GestureDetector(
              onTap: () {
                final f = fixture.trim();
                if (f.isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Publicsearch(fixtureNumber: f),
                  ),
                );
              },
              child: Container(
                width: boxW,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF39495F)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _highlightedText(
                  _fixtureDisplayText(fixture),
                  textAlign: TextAlign.center,
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.clip,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF5A6A83),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    Map<String, dynamic> row, {
    required bool isDisabled,
  }) {
    return IconButton(
      onPressed: () {
        final sopLeadHandEntryId = _pick(row, ['SOPLeadHandEntryId']);
        if (sopLeadHandEntryId.isEmpty) {
          AppToast.error(
            context,
            'SOP Lead Hand Entry Id not found for this row.',
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Query(
              sopLeadHandEntryId: sopLeadHandEntryId,
              showRemovedFromSop: isDisabled,
            ),
          ),
        );
      },
      tooltip: 'Edit',
      icon: const Icon(Icons.edit, size: 18, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF39495F),
        foregroundColor: Colors.white,
        minimumSize: const Size(36, 36),
        padding: const EdgeInsets.all(6),
        side: const BorderSide(color: Colors.black, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildStickyActionsPane(
    List<Map<String, dynamic>> groupedRows, {
    required double noticeWidth,
  }) {
    const borderColor = Color(0xFFD1D5DB);
    return SizedBox(
      width: _actionColumnWidth,
      child: Column(
        children: [
          Container(
            height: 52,
            width: _actionColumnWidth,
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              color: Color(0xFF344963),
              border: Border(left: BorderSide(color: borderColor)),
            ),
            child: const Text(
              'Action',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: ListView.builder(
                controller: _actionsVerticalScroll,
                itemCount: groupedRows.length,
                itemBuilder: (context, index) {
                  final group = groupedRows[index];
                  final row = group['row'] as Map<String, dynamic>;
                  final isDisabled = row['Disabled'] == true;
                  return Container(
                    height: _dataRowHeightForGroup(
                      group,
                      context,
                      noticeWidth: noticeWidth,
                    ),
                    width: _actionColumnWidth,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDisabled
                          ? const Color(0xFFB5B5B5)
                          : const Color(0xFFF0F1F3),
                      border: const Border(
                        left: BorderSide(color: borderColor),
                        bottom: BorderSide(color: borderColor),
                      ),
                    ),
                    child: _buildActionButton(row, isDisabled: isDisabled),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _dataRowHeightForGroup(
    Map<String, dynamic> group,
    BuildContext context, {
    double? noticeWidth,
  }) {
    final notices = group['notices'] as List<Map<String, dynamic>>;
    final noticeValues = _noticeValues(notices, 'notice', hideDash: true);
    if (noticeValues.isEmpty) return 52.0;
    final noticeRowHeights = _noticeRowHeights(
      noticeValues: noticeValues,
      noticeWidth: noticeWidth ?? _noticeColumnWidth,
      textScaler: MediaQuery.textScalerOf(context),
    );
    final totalHeight =
        noticeRowHeights.fold<double>(0, (a, b) => a + b) +
        (noticeValues.length > 1 ? (noticeValues.length - 1) * 0.6 : 0);
    return max(52.0, totalHeight);
  }

  Widget _highlightedText(
    String text, {
    TextAlign textAlign = TextAlign.center,
    int? maxLines = 5,
    bool softWrap = true,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    TextOverflow overflow = TextOverflow.ellipsis,
  }) {
    final style = TextStyle(
      fontSize: 13,
      height: 1.3,
      fontWeight: fontWeight,
      color: color,
    );
    final q = _searchQuery.trim();
    if (q.isEmpty) {
      return Text(
        text,
        softWrap: softWrap,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        style: style,
      );
    }

    final lower = text.toLowerCase();
    final needle = q.toLowerCase();
    if (!lower.contains(needle)) {
      return Text(
        text,
        softWrap: softWrap,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
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
      softWrap: softWrap,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }

  String _wrapFriendly(String text) {
    return text
        .replaceAll('-', '-\u200B')
        .replaceAll('_', '_\u200B')
        .replaceAll('/', '/\u200B')
        .replaceAll('#', '#\u200B');
  }

  Widget _tableTextCell(
    String text, {
    double? width,
    TextAlign align = TextAlign.left,
    int maxLines = 5,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW =
            width ??
            (constraints.hasBoundedWidth && constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : null);
        return SizedBox(
          width: maxW,
          height: constraints.hasBoundedHeight && constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Align(
              alignment: Alignment.topLeft,
              child: _highlightedText(
                _wrapFriendly(text),
                textAlign: align,
                maxLines: maxLines,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                fontWeight: fontWeight,
              ),
            ),
          ),
        );
      },
    );
  }

  void _syncVerticalScroll(ScrollController source, ScrollController target) {
    if (!target.hasClients) return;
    final maxExtent = target.position.maxScrollExtent;
    final nextOffset = source.offset.clamp(0.0, maxExtent);
    if ((target.offset - nextOffset).abs() > 0.5) {
      target.jumpTo(nextOffset);
    }
  }

  @override
  void initState() {
    super.initState();
    _tableVerticalScroll.addListener(
      () => _syncVerticalScroll(_tableVerticalScroll, _actionsVerticalScroll),
    );
    _actionsVerticalScroll.addListener(
      () => _syncVerticalScroll(_actionsVerticalScroll, _tableVerticalScroll),
    );
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
          _filteredData = List.from(_rows);
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
    final start = (_currentPage - 1) * _rowsPerPage;
    final end = min(start + _rowsPerPage, _filteredRows.length);
    return _filteredRows.sublist(start, end);
  }

  void _clampCurrentPage() {
    _currentPage = _currentPage.clamp(1, _totalPages);
  }

  @override
  void dispose() {
    _tableVerticalScroll.dispose();
    _tableHorizontalScroll.dispose();
    _actionsVerticalScroll.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 700;
    final r = Responsive.of(context);
    final searchField = TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _runSearch(),
      onChanged: (value) {
        // Clearing the input restores the full table immediately.
        if (value.trim().isEmpty && _searchQuery.isNotEmpty) {
          setState(() {
            _searchQuery = '';
            _currentPage = 1;
            _clampCurrentPage();
          });
        }
      },
      style: TextStyle(fontSize: r.searchFieldFontSize),
      decoration: InputDecoration(
        hintText: 'Search in table...',
        hintStyle: TextStyle(
          fontSize: r.searchFieldFontSize,
          color: const Color(0xFF9AA8B8),
          fontWeight: FontWeight.w500,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: r.searchFieldContentPaddingV,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.fieldRadius),
          borderSide: BorderSide(
            color: isTablet ? const Color(0xFFBDBDBD) : const Color(0xFF2196F3),
            width: isTablet ? 1 : 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.fieldRadius),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
      ),
    );
    final groupedRows = _groupRowsForDisplay(_pagedRows);
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
      drawer: CommonDrawer(),
      backgroundColor: Colors.white,
      // The table + pagination bar have a fixed minimum height, so letting the
      // keyboard shrink the body overflows it. Keep the layout full height and
      // let the keyboard overlay the bottom instead.
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: EdgeInsets.all(isTablet ? 12 : 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isTablet)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: Row(
                  children: [
                    Text(
                      widget.pageTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(width: 360, child: searchField),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _runSearch,
                      icon: const Icon(Icons.search, size: 20),
                      label: const Text('Search'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.pageTitle,
                    style: TextStyle(
                      fontSize: r.pageTitleSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: r.sectionGap),
                  SizedBox(
                    height: r.searchButtonHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _runSearch,
                          icon: Icon(Icons.search, size: r.searchIconSize),
                          label: Text(
                            'Search',
                            style: TextStyle(
                              fontSize: r.searchButtonFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                r.fieldRadius,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: AppLoader())
                  : _filteredRows.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No matching SOP found'
                            : 'No results found for "$_searchQuery".',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
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
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final includeAction = !isTablet;
                                  final compact = !isTablet;
                                  final actionW = isTablet
                                      ? _actionColumnWidth
                                      : 0.0;
                                  final available =
                                      (constraints.maxWidth - actionW).clamp(
                                        0.0,
                                        double.infinity,
                                      );
                                  final colWidths = _columnWidthsFor(
                                    available: available,
                                    includeAction: includeAction,
                                    compact: compact,
                                  );
                                  final tableMinWidth =
                                      colWidths.fold<double>(
                                        0,
                                        (a, b) => a + b,
                                      ) +
                                      1;
                                  final noticeW = colWidths[14];
                                  final dateW = colWidths[12];
                                  final deptW = colWidths[13];
                                  final responseW = colWidths[15];
                                  final tableColumns = _criticalDataColumns(
                                    widths: colWidths,
                                    includeAction: includeAction,
                                    compact: compact,
                                  );
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: Theme(
                                          data: Theme.of(context).copyWith(
                                            scrollbarTheme:
                                                const ScrollbarThemeData(
                                                  thickness:
                                                      WidgetStatePropertyAll(0),
                                                  thumbVisibility:
                                                      WidgetStatePropertyAll(
                                                        false,
                                                      ),
                                                  trackVisibility:
                                                      WidgetStatePropertyAll(
                                                        false,
                                                      ),
                                                  crossAxisMargin: 0,
                                                  mainAxisMargin: 0,
                                                  minThumbLength: 0,
                                                ),
                                          ),
                                          child: ScrollConfiguration(
                                            behavior: ScrollConfiguration.of(
                                              context,
                                            ).copyWith(scrollbars: false),
                                            child: DataTable2(
                                              fixedTopRows: 1,
                                              scrollController:
                                                  _tableVerticalScroll,
                                              horizontalScrollController:
                                                  _tableHorizontalScroll,
                                              showCheckboxColumn: false,
                                              sortColumnIndex: _sortColumnIndex,
                                              sortAscending: _sortAscending,
                                              sortArrowBuilder: (_, __) =>
                                                  const SizedBox.shrink(),
                                              headingRowColor:
                                                  MaterialStateProperty.all(
                                                    const Color(0xFF344963),
                                                  ),
                                              dataRowColor:
                                                  MaterialStateProperty.all(
                                                    const Color(0xFFF0F1F3),
                                                  ),
                                              fixedCornerColor: const Color(
                                                0xFF344963,
                                              ),
                                              fixedColumnsColor: const Color(
                                                0xFFF0F1F3,
                                              ),
                                              headingRowHeight: isTablet
                                                  ? 52
                                                  : 48,
                                              dataRowHeight: 52,
                                              columnSpacing: 0,
                                              horizontalMargin: 0,
                                              dividerThickness: 1,
                                              isHorizontalScrollBarVisible:
                                                  false,
                                              isVerticalScrollBarVisible: false,
                                              minWidth: tableMinWidth,
                                              fixedLeftColumns: 3,
                                              border: tableBorder,
                                              columns: tableColumns,
                                              rows: groupedRows.map((group) {
                                                final row =
                                                    group['row']
                                                        as Map<String, dynamic>;
                                                final notices =
                                                    group['notices']
                                                        as List<
                                                          Map<String, dynamic>
                                                        >;
                                                final qtyText = _pick(row, [
                                                  'Quantity',
                                                ]);
                                                final hoursText = _pick(row, [
                                                  'Hours',
                                                ]);
                                                final qty =
                                                    int.tryParse(qtyText) ?? 0;
                                                final hours =
                                                    double.tryParse(
                                                      hoursText,
                                                    ) ??
                                                    0;
                                                final isDisabled =
                                                    row['Disabled'] == true;
                                                final noticeBg =
                                                    _noticeBlockBackground(
                                                      notices,
                                                    );
                                                final responseRowBackgrounds =
                                                    notices
                                                        .map(
                                                          (n) =>
                                                              _responseRowBackground(
                                                                row,
                                                                n,
                                                              ),
                                                        )
                                                        .toList();
                                                final dateValues =
                                                    _noticeValues(
                                                      notices,
                                                      'date',
                                                      hideDash: true,
                                                    );
                                                final deptValues =
                                                    _noticeValues(
                                                      notices,
                                                      'dept',
                                                      hideDash: true,
                                                    );
                                                final noticeValues =
                                                    _noticeValues(
                                                      notices,
                                                      'notice',
                                                      hideDash: true,
                                                    );
                                                final responseValues =
                                                    _noticeValues(
                                                      notices,
                                                      'response',
                                                      hideDash: true,
                                                    );
                                                final noticeRowHeights =
                                                    _noticeRowHeights(
                                                      noticeValues:
                                                          noticeValues,
                                                      noticeWidth: noticeW,
                                                      textScaler:
                                                          MediaQuery.textScalerOf(
                                                            context,
                                                          ),
                                                    );

                                                return DataRow2(
                                                  specificRowHeight:
                                                      _dataRowHeightForGroup(
                                                        group,
                                                        context,
                                                        noticeWidth: noticeW,
                                                      ),
                                                  color:
                                                      WidgetStateProperty.all(
                                                        isDisabled
                                                            ? const Color(
                                                                0xFFB5B5B5,
                                                              )
                                                            : const Color(
                                                                0xFFF0F1F3,
                                                              ),
                                                      ),
                                                  cells: [
                                                    DataCell(
                                                      _tableTextCell(
                                                        _pickSopNum(row),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      _tableTextCell(
                                                        _formatDate(_pickOdd(row)),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      _buildFixtureCell(row),
                                                    ),
                                                    DataCell(
                                                      _tableTextCell(
                                                        _pickPath(row, [
                                                          'SOP',
                                                          'ProductionLogEntry',
                                                          'LeadHand',
                                                          'LeadHandName',
                                                        ]),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      _tableTextCell(
                                                        _pickPath(row, [
                                                          'Assembler',
                                                          'Name',
                                                        ]),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      _tableTextCell(
                                                        _pick(row, [
                                                          'FixtureDescription',
                                                        ]),
                                                        maxLines: 4,
                                                      ),
                                                    ),
                                                    DataCell(
                                                      _tableTextCell(
                                                        _pick(row, [
                                                          'Quantity',
                                                        ]),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      _tableTextCell(hoursText),
                                                    ),
                                                    DataCell(
                                                      _tableTextCell(
                                                        (qty * hours)
                                                            .toStringAsFixed(2),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      _tableTextCell(
                                                        _pick(row, ['Amount']),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      _tableTextCell(
                                                        _pick(row, [
                                                          'InventoryCommentsForProduction',
                                                        ]),
                                                        maxLines: 4,
                                                      ),
                                                    ),
                                                    DataCell(
                                                      LayoutBuilder(
                                                        builder: (context, constraints) {
                                                          final w =
                                                              constraints
                                                                      .hasBoundedWidth &&
                                                                  constraints
                                                                          .maxWidth >
                                                                      0
                                                              ? constraints
                                                                    .maxWidth
                                                              : 58.0;
                                                          return SizedBox(
                                                            width: w,
                                                            child: Stack(
                                                              clipBehavior:
                                                                  Clip.hardEdge,
                                                              fit: StackFit
                                                                  .expand,
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
                                                                    row['Picked'] ==
                                                                            true
                                                                        ? 'Yes'
                                                                        : 'No',
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
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
                                                        width: dateW,
                                                        values: dateValues,
                                                        backgroundColor:
                                                            noticeBg,
                                                        rowHeights:
                                                            noticeRowHeights,
                                                      ),
                                                    ),
                                                    DataCell(
                                                      _stackedNoticeCell(
                                                        width: deptW,
                                                        values: deptValues,
                                                        backgroundColor:
                                                            noticeBg,
                                                        rowHeights:
                                                            noticeRowHeights,
                                                      ),
                                                    ),
                                                    DataCell(
                                                      _stackedNoticeCell(
                                                        width: noticeW,
                                                        values: noticeValues,
                                                        backgroundColor:
                                                            noticeBg,
                                                        rowHeights:
                                                            noticeRowHeights,
                                                        textAlign:
                                                            TextAlign.left,
                                                      ),
                                                    ),
                                                    DataCell(
                                                      _stackedNoticeCell(
                                                        width: responseW,
                                                        values: responseValues,
                                                        backgroundColor:
                                                            notices.isEmpty
                                                            ? Colors.transparent
                                                            : noticeBg,
                                                        rowBackgrounds:
                                                            responseRowBackgrounds,
                                                        rowHeights:
                                                            noticeRowHeights,
                                                      ),
                                                    ),
                                                    if (!isTablet)
                                                      DataCell(
                                                        Center(
                                                          child:
                                                              _buildActionButton(
                                                                row,
                                                                isDisabled:
                                                                    isDisabled,
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
                                      if (isTablet)
                                        _buildStickyActionsPane(
                                          groupedRows,
                                          noticeWidth: noticeW,
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        ClipRRect(
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(color: Color(0xFF9AA8B8)),
                                right: BorderSide(color: Color(0xFF9AA8B8)),
                                bottom: BorderSide(color: Color(0xFF9AA8B8)),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: PaginationBar(
                                currentPage: _currentPage.clamp(1, _totalPages),
                                totalPages: _totalPages,
                                fromItem: _filteredData.isEmpty
                                    ? 0
                                    : ((_currentPage - 1) * _rowsPerPage) + 1,
                                toItem: _filteredData.isEmpty
                                    ? 0
                                    : min(
                                        _currentPage * _rowsPerPage,
                                        _filteredData.length,
                                      ),
                                totalItems: _filteredData.length,
                                onPageChanged: (page) {
                                  setState(() {
                                    _currentPage = page;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (_tableVerticalScroll.hasClients) {
                                      _tableVerticalScroll.jumpTo(0);
                                    }
                                    if (_tableHorizontalScroll.hasClients) {
                                      _tableHorizontalScroll.jumpTo(0);
                                    }
                                    if (_actionsVerticalScroll.hasClients) {
                                      _actionsVerticalScroll.jumpTo(0);
                                    }
                                  });
                                },
                              ),
                            ),
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
