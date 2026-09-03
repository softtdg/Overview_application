import 'package:flutter/material.dart';
import 'package:overview_app/Screen/QAEdit/Components/QAEditEntry.dart';
import 'package:overview_app/Screen/QAEdit/Services/QAEditService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Utils/api_date.dart';
import 'package:overview_app/Utils/responsive.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/AppToast.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:overview_app/Widgets/pagination_bar.dart';

class QAEdit extends StatefulWidget {
  @override
  _QAEditState createState() => _QAEditState();
}

class _QAEditState extends State<QAEdit> {
  final SOPController = TextEditingController();
  List<Map<String, dynamic>> QCEditHistory = [];
  final QAEditServices _service = QAEditServices();
  bool isLoading = false;

  /// Applied only when user clicks Search (or presses Enter).
  String _searchQuery = '';

  final ScrollController _leftVerticalScroll = ScrollController();
  final ScrollController _middleVerticalScroll = ScrollController();
  final ScrollController _actionsVerticalScroll = ScrollController();
  final ScrollController _middleHorizontalScroll = ScrollController();

  static const int _rowsPerPage = 100;
  int _currentPage = 1;

  int? _sortColumnIndex;
  bool _sortAscending = true;

  /// Sortable columns only (excludes Action).
  static const List<String> _sortKeys = [
    'SOPNum',
    'PONum',
    'ODD',
    'CustomerName',
    'ProgramName',
    'LocationName',
    'QCDateIn',
    'ReworkDateOut',
    'FinalDateReceivedInQC',
    'QCOut',
    'QAComments',
    'LastEdit',
  ];

  List<Map<String, dynamic>> _sortedRows(List<Map<String, dynamic>> source) {
    if (_sortColumnIndex == null ||
        _sortColumnIndex! < 0 ||
        _sortColumnIndex! >= _sortKeys.length) {
      return source;
    }
    final key = _sortKeys[_sortColumnIndex!];
    final rows = List<Map<String, dynamic>>.from(source);
    rows.sort((a, b) {
      final cmp = _compareValues(a[key], b[key], key);
      if (cmp != 0) return _sortAscending ? cmp : -cmp;
      final sa = a['SOPNum']?.toString() ?? '';
      final sb = b['SOPNum']?.toString() ?? '';
      return sa.compareTo(sb);
    });
    return rows;
  }

  DateTime? _asDateTime(dynamic raw) => ApiDate.parse(raw);

  int _compareValues(dynamic a, dynamic b, String key) {
    const dateKeys = {
      'ODD',
      'QCDateIn',
      'ReworkDateOut',
      'FinalDateReceivedInQC',
      'QCOut',
      'LastEdit',
    };
    if (dateKeys.contains(key)) {
      final da = _asDateTime(a);
      final db = _asDateTime(b);
      if (da != null && db != null) return da.compareTo(db);
      if (da != null) return -1;
      if (db != null) return 1;
      return 0;
    }
    final sa = a?.toString().trim() ?? '';
    final sb = b?.toString().trim() ?? '';
    final ia = int.tryParse(sa);
    final ib = int.tryParse(sb);
    if (ia != null && ib != null) return ia.compareTo(ib);
    return sa.toLowerCase().compareTo(sb.toLowerCase());
  }

  void _onSort(int columnIndex) {
    if (columnIndex < 0 || columnIndex >= _sortKeys.length) return;
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

  static const Color _tableHeaderColor = Color.fromARGB(255, 57, 73, 95);
  static const double _rowHeight = 56;
  static const TextStyle _cellTextStyle = TextStyle(fontSize: 12);

  // SOP, PO Num, ODD | middle | Action
  static const List<double> _baseColWidths = [
    100, // SOP
    170, // PO Num
    100, // ODD
    260, // Customer
    120, // Prgm
    90, // Loc.
    110, // QC In
    100, // RW QC Out
    140, // Final Date Received In QC
    100, // QC Out
    160, // Comments
    160, // Last Edited On
    72, // Action
  ];

  Future<void> GetQAEditHistory() async {
    await Dioservices.setToken();
    setState(() {
      isLoading = true;
    });
    try {
      final response = await _service.GetQAEditHistory();
      final data = response.data['data'];
      setState(() {
        QCEditHistory = List<Map<String, dynamic>>.from(data);
        isLoading = false;
        _clampCurrentPage();
      });
      // print("QA EDIT DATA $data");
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print("Error fetching QA Edit history: $e");
      if (mounted) {
        AppToast.error(context, 'Failed to load QA Edit history');
      }
    }
  }

  void _runSearch() {
    setState(() {
      _searchQuery = SOPController.text.trim();
      _currentPage = 1;
      _clampCurrentPage();
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim();
      _currentPage = 1;
      _clampCurrentPage();
    });
  }

  void _clearSearch() {
    SOPController.clear();
    setState(() {
      _searchQuery = '';
      _currentPage = 1;
      _clampCurrentPage();
    });
  }

  @override
  void initState() {
    super.initState();
    _leftVerticalScroll.addListener(
      () => _syncScroll(_leftVerticalScroll, [
        _middleVerticalScroll,
        _actionsVerticalScroll,
      ]),
    );
    _middleVerticalScroll.addListener(
      () => _syncScroll(_middleVerticalScroll, [
        _leftVerticalScroll,
        _actionsVerticalScroll,
      ]),
    );
    _actionsVerticalScroll.addListener(
      () => _syncScroll(_actionsVerticalScroll, [
        _leftVerticalScroll,
        _middleVerticalScroll,
      ]),
    );
    GetQAEditHistory();
  }

  void _syncScroll(ScrollController source, List<ScrollController> targets) {
    for (final target in targets) {
      if (!target.hasClients) continue;
      if (target.offset != source.offset) {
        target.jumpTo(source.offset);
      }
    }
  }

  @override
  void dispose() {
    _leftVerticalScroll.dispose();
    _middleVerticalScroll.dispose();
    _actionsVerticalScroll.dispose();
    _middleHorizontalScroll.dispose();
    SOPController.dispose();
    super.dispose();
  }

  /// Case-insensitive match across the main table columns.
  List<Map<String, dynamic>> get _filteredHistory {
    final q = _searchQuery.toLowerCase();
    if (q.isEmpty) return QCEditHistory;

    String cell(dynamic v) => (v?.toString() ?? '').toLowerCase();

    bool rowMatches(Map<String, dynamic> item) {
      return cell(item['SOPNum']).contains(q) ||
          cell(item['PONum']).contains(q) ||
          cell(item['CustomerName']).contains(q) ||
          cell(item['ProgramName']).contains(q) ||
          cell(item['LocationName']).contains(q) ||
          cell(item['QAComments']).contains(q) ||
          cell(item['ODD']).contains(q) ||
          cell(item['QCDateIn']).contains(q) ||
          cell(item['ReworkDateOut']).contains(q) ||
          cell(item['FinalDateReceivedInQC']).contains(q) ||
          cell(item['QCOut']).contains(q) ||
          cell(item['LastEdit']).contains(q);
    }

    return QCEditHistory.where(rowMatches).toList();
  }

  int get _totalPages => _filteredHistory.isEmpty
      ? 1
      : ((_filteredHistory.length + _rowsPerPage - 1) ~/ _rowsPerPage);

  List<Map<String, dynamic>> get _pagedHistory {
    final filtered = _sortedRows(_filteredHistory);
    if (filtered.isEmpty) return [];
    final start = (_currentPage - 1) * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  void _clampCurrentPage() {
    _currentPage = _currentPage.clamp(1, _totalPages);
  }

  String formatDate(dynamic date) => ApiDate.formatMmDdYyyy(date, empty: '-');

  String formatDateTime(dynamic date) =>
      ApiDate.formatMmDdYyyyDateTime(date, empty: '-');

  String _wrapFriendly(String text) {
    return text
        .replaceAll('-', '-\u200B')
        .replaceAll('_', '_\u200B')
        .replaceAll('#', '#\u200B');
  }

  /// Highlights [_searchQuery] in [text] (case-insensitive).
  Widget _highlightedCellText(
    String text, {
    TextAlign textAlign = TextAlign.left,
    int? maxLines,
    bool softWrap = false,
  }) {
    final displayText = softWrap ? _wrapFriendly(text) : text;
    final q = _searchQuery.trim();
    if (q.isEmpty) {
      return Text(
        displayText,
        textAlign: textAlign,
        style: _cellTextStyle,
        maxLines: maxLines,
        softWrap: softWrap,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lower = displayText.toLowerCase();
    final needle = q.toLowerCase();
    if (!lower.contains(needle)) {
      return Text(
        displayText,
        textAlign: textAlign,
        style: _cellTextStyle,
        maxLines: maxLines,
        softWrap: softWrap,
        overflow: TextOverflow.ellipsis,
      );
    }

    final children = <InlineSpan>[];
    var i = 0;
    while (i < displayText.length) {
      final j = lower.indexOf(needle, i);
      if (j < 0) {
        children.add(TextSpan(text: displayText.substring(i)));
        break;
      }
      if (j > i) {
        children.add(TextSpan(text: displayText.substring(i, j)));
      }
      final end = j + needle.length;
      children.add(
        TextSpan(
          text: displayText.substring(j, end),
          style: _cellTextStyle.copyWith(
            backgroundColor: const Color.fromARGB(255, 245, 197, 41),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      i = end;
    }

    return Text.rich(
      TextSpan(style: _cellTextStyle, children: children),
      textAlign: textAlign,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<BoxShadow> get _leftStickyShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 6,
      offset: const Offset(2, 0),
    ),
  ];

  List<BoxShadow> get _rightStickyShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 6,
      offset: const Offset(-2, 0),
    ),
  ];

  List<double> _scaledMiddleWidths(double availableMiddleWidth) {
    final middle = _baseColWidths.sublist(3, 12);
    final total = middle.fold<double>(0, (sum, w) => sum + w);
    if (availableMiddleWidth <= total) return middle;
    final scale = availableMiddleWidth / total;
    return middle.map((w) => w * scale).toList();
  }

  Widget _headerCell(String text, double width, {int? sortIndex}) {
    final sortable = sortIndex != null;
    final active = sortable && _sortColumnIndex == sortIndex;
    final up = !active || _sortAscending;

    return SizedBox(
      width: width,
      height: _rowHeight,
      child: Material(
        color: _tableHeaderColor,
        child: InkWell(
          onTap: sortable ? () => _onSort(sortIndex) : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 0.5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        textAlign: TextAlign.left,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (sortable) ...[
                      const SizedBox(width: 3),
                      Icon(
                        up ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: active ? Colors.white : const Color(0x99B8C8E8),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bodyCell(String text, double width, {bool wrap = false}) {
    return Container(
      width: width,
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey, width: 0.5),
      ),
      child: _highlightedCellText(text, softWrap: wrap, maxLines: wrap ? 3 : 1),
    );
  }

  Widget _leftHeader(List<double> leftWidths) {
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: _leftStickyShadow),
      child: Row(
        children: [
          _headerCell('SOP', leftWidths[0], sortIndex: 0),
          _headerCell('PO Num', leftWidths[1], sortIndex: 1),
          _headerCell('ODD', leftWidths[2], sortIndex: 2),
        ],
      ),
    );
  }

  Widget _leftDataRow(Map<String, dynamic> item, List<double> leftWidths) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: _leftStickyShadow,
      ),
      child: Row(
        children: [
          _bodyCell(
            item['SOPNum']?.toString() ?? '-',
            leftWidths[0],
            wrap: true,
          ),
          _bodyCell(
            item['PONum']?.toString() ?? '-',
            leftWidths[1],
            wrap: true,
          ),
          _bodyCell(formatDate(item['ODD']?.toString() ?? '-'), leftWidths[2]),
        ],
      ),
    );
  }

  Widget _middleHeader(List<double> middleWidths) {
    return Row(
      children: [
        _headerCell('Customer', middleWidths[0], sortIndex: 3),
        _headerCell('Prgm', middleWidths[1], sortIndex: 4),
        _headerCell('Loc.', middleWidths[2], sortIndex: 5),
        _headerCell('QC In', middleWidths[3], sortIndex: 6),
        _headerCell('RW QC Out', middleWidths[4], sortIndex: 7),
        _headerCell('Final Date Received In QC', middleWidths[5], sortIndex: 8),
        _headerCell('QC Out', middleWidths[6], sortIndex: 9),
        _headerCell('Comments', middleWidths[7], sortIndex: 10),
        _headerCell('Last Edited On', middleWidths[8], sortIndex: 11),
      ],
    );
  }

  Widget _middleDataRow(Map<String, dynamic> item, List<double> middleWidths) {
    return Row(
      children: [
        _bodyCell(
          item['CustomerName']?.toString() ?? '-',
          middleWidths[0],
          wrap: true,
        ),
        _bodyCell(
          item['ProgramName']?.toString() ?? '-',
          middleWidths[1],
          wrap: true,
        ),
        _bodyCell(item['LocationName']?.toString() ?? '-', middleWidths[2]),
        _bodyCell(
          formatDate(item['QCDateIn']?.toString() ?? '-'),
          middleWidths[3],
        ),
        _bodyCell(
          formatDate(item['ReworkDateOut']?.toString() ?? '-'),
          middleWidths[4],
        ),
        _bodyCell(
          formatDate(item['FinalDateReceivedInQC']?.toString() ?? '-'),
          middleWidths[5],
        ),
        _bodyCell(
          formatDate(item['QCOut']?.toString() ?? '-'),
          middleWidths[6],
        ),
        _bodyCell(
          item['QAComments']?.toString() ?? '',
          middleWidths[7],
          wrap: true,
        ),
        _bodyCell(
          formatDateTime(item['LastEdit']?.toString() ?? '-'),
          middleWidths[8],
          wrap: true,
        ),
      ],
    );
  }

  Future<void> _openEdit(Map<String, dynamic> item) async {
    final SOPId = item['SOPId']?.toString() ?? '-';
    print("PASSING SOPId: $SOPId");
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QAEditEntry(SOPId: SOPId)),
    );
    if (updated == true) {
      await GetQAEditHistory();
    }
  }

  Widget _actionHeader(double width) {
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: _rightStickyShadow),
      child: _headerCell('Action', width),
    );
  }

  Widget _actionDataCell(Map<String, dynamic> item, double width) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: _rightStickyShadow,
      ),
      child: Container(
        width: width,
        height: _rowHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey, width: 0.5),
        ),
        child: IconButton(
          onPressed: () => _openEdit(item),
          tooltip: 'Edit',
          icon: const Icon(Icons.edit, size: 18, color: Colors.white),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF39495F),
            foregroundColor: Colors.white,
            minimumSize: const Size(32, 32),
            padding: const EdgeInsets.all(4),
            side: const BorderSide(color: Colors.black),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }

  Widget _buildPlainHeaderRow(List<double> widths) {
    return Row(
      children: [
        _headerCell('SOP', widths[0], sortIndex: 0),
        _headerCell('PO Num', widths[1], sortIndex: 1),
        _headerCell('ODD', widths[2], sortIndex: 2),
        _headerCell('Customer', widths[3], sortIndex: 3),
        _headerCell('Prgm', widths[4], sortIndex: 4),
        _headerCell('Loc.', widths[5], sortIndex: 5),
        _headerCell('QC In', widths[6], sortIndex: 6),
        _headerCell('RW QC Out', widths[7], sortIndex: 7),
        _headerCell('Final Date Received In QC', widths[8], sortIndex: 8),
        _headerCell('QC Out', widths[9], sortIndex: 9),
        _headerCell('Comments', widths[10], sortIndex: 10),
        _headerCell('Last Edited On', widths[11], sortIndex: 11),
        _headerCell('Action', widths[12]),
      ],
    );
  }

  Widget _buildPlainDataRow(Map<String, dynamic> item, List<double> widths) {
    return Row(
      children: [
        _bodyCell(item['SOPNum']?.toString() ?? '-', widths[0], wrap: true),
        _bodyCell(item['PONum']?.toString() ?? '-', widths[1], wrap: true),
        _bodyCell(formatDate(item['ODD']?.toString() ?? '-'), widths[2]),
        _bodyCell(
          item['CustomerName']?.toString() ?? '-',
          widths[3],
          wrap: true,
        ),
        _bodyCell(
          item['ProgramName']?.toString() ?? '-',
          widths[4],
          wrap: true,
        ),
        _bodyCell(item['LocationName']?.toString() ?? '-', widths[5]),
        _bodyCell(formatDate(item['QCDateIn']?.toString() ?? '-'), widths[6]),
        _bodyCell(
          formatDate(item['ReworkDateOut']?.toString() ?? '-'),
          widths[7],
        ),
        _bodyCell(
          formatDate(item['FinalDateReceivedInQC']?.toString() ?? '-'),
          widths[8],
        ),
        _bodyCell(formatDate(item['QCOut']?.toString() ?? '-'), widths[9]),
        _bodyCell(item['QAComments']?.toString() ?? '', widths[10], wrap: true),
        _bodyCell(
          formatDateTime(item['LastEdit']?.toString() ?? '-'),
          widths[11],
          wrap: true,
        ),
        _actionDataCell(item, widths[12]),
      ],
    );
  }

  List<double> _plainTableWidths(double availableWidth) {
    final base = List<double>.from(_baseColWidths);
    final total = base.fold<double>(0, (sum, w) => sum + w);
    if (availableWidth <= total) return base;
    final scale = availableWidth / total;
    return base.map((w) => w * scale).toList();
  }

  Widget buildTable() {
    final rows = _pagedHistory;
    final leftWidths = _baseColWidths.take(3).toList();
    final leftWidth = leftWidths.fold<double>(0, (sum, w) => sum + w);
    final actionWidth = _baseColWidths[12];

    return Responsive.hideScrollbars(
      context,
      LayoutBuilder(
        builder: (context, constraints) {
          final reserved = leftWidth + actionWidth;
          final tooNarrow = constraints.maxWidth < reserved + 48;

          final contentH = _rowHeight + (_rowHeight * rows.length);
          final maxH = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : contentH;
          final tableH = contentH > maxH ? maxH : contentH;

          if (tooNarrow || Responsive.isMobileTableLayout(context)) {
            final widths = _plainTableWidths(constraints.maxWidth);
            final tableWidth = widths.fold<double>(0, (sum, w) => sum + w);
            return SizedBox(
              width: constraints.maxWidth,
              height: tableH,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _middleHorizontalScroll,
                child: SizedBox(
                  width: tableWidth,
                  height: tableH,
                  child: Column(
                    children: [
                      _buildPlainHeaderRow(widths),
                      Expanded(
                        child: ListView.builder(
                          controller: _middleVerticalScroll,
                          itemCount: rows.length,
                          itemExtent: _rowHeight,
                          itemBuilder: (context, index) {
                            return _buildPlainDataRow(rows[index], widths);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final middleAvailable = (constraints.maxWidth - reserved).clamp(
            0.0,
            double.infinity,
          );
          final middleWidths = _scaledMiddleWidths(middleAvailable);
          final middleWidth = middleWidths.fold<double>(0, (sum, w) => sum + w);

          return SizedBox(
            width: constraints.maxWidth,
            height: tableH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: leftWidth,
                  child: Column(
                    children: [
                      _leftHeader(leftWidths),
                      Expanded(
                        child: ListView.builder(
                          controller: _leftVerticalScroll,
                          itemCount: rows.length,
                          itemExtent: _rowHeight,
                          itemBuilder: (context, index) {
                            return _leftDataRow(rows[index], leftWidths);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _middleHorizontalScroll,
                    child: SizedBox(
                      width: middleWidth,
                      child: Column(
                        children: [
                          _middleHeader(middleWidths),
                          Expanded(
                            child: ListView.builder(
                              controller: _middleVerticalScroll,
                              itemCount: rows.length,
                              itemExtent: _rowHeight,
                              itemBuilder: (context, index) {
                                return _middleDataRow(
                                  rows[index],
                                  middleWidths,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: actionWidth,
                  child: Column(
                    children: [
                      _actionHeader(actionWidth),
                      Expanded(
                        child: ListView.builder(
                          controller: _actionsVerticalScroll,
                          itemCount: rows.length,
                          itemExtent: _rowHeight,
                          itemBuilder: (context, index) {
                            return _actionDataCell(rows[index], actionWidth);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 700;
    final r = Responsive.of(context);
    final sopField = TextField(
      controller: SOPController,
      onChanged: _onSearchChanged,
      style: TextStyle(fontSize: r.searchFieldFontSize),
      decoration: InputDecoration(
        hintText: 'Search in table...',
        hintStyle: TextStyle(fontSize: r.searchFieldFontSize),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: r.searchFieldContentPaddingV,
        ),
        suffixIcon: SOPController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                onPressed: _clearSearch,
                icon: const Icon(Icons.clear, size: 20),
              ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.fieldRadius),
          borderSide: BorderSide(
            color: isTablet ? const Color(0xFFBDBDBD) : const Color(0xFF1565C0),
            width: isTablet ? 1 : 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.fieldRadius),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _runSearch(),
    );
    final searchButton = SizedBox(
      height: isTablet ? null : r.searchButtonHeight,
      child: ElevatedButton.icon(
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
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.fieldRadius),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(),
      drawer: const CommonDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: isTablet
                ? Container(
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
                        const Flexible(
                          child: Text(
                            'Search SOP to QA Edit',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(width: 280, child: sopField),
                        const SizedBox(width: 12),
                        searchButton,
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Search SOP to QA Edit',
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
                            Expanded(child: sopField),
                            const SizedBox(width: 8),
                            searchButton,
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const Expanded(
              child: Center(child: Center(child: AppLoader())),
            )
          else
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 16 : 12,
                  0,
                  isTablet ? 16 : 12,
                  isTablet ? 16 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // loose = table only as tall as rows (or max), so pager
                    // stays ~12px under the table — not a big empty body.
                    Flexible(fit: FlexFit.loose, child: buildTable()),
                    if (_filteredHistory.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: PaginationBar(
                          currentPage: _currentPage.clamp(1, _totalPages),
                          totalPages: _totalPages,
                          onPageChanged: (page) {
                            setState(() {
                              _currentPage = page;
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
