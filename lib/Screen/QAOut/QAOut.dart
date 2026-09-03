import 'package:flutter/material.dart';
import 'package:overview_app/Screen/QAOut/Components/QAOutEditEntry.dart';
import 'package:overview_app/Screen/QAOut/Services/QAOutService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Utils/api_date.dart';
import 'package:overview_app/Utils/responsive.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/AppToast.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class QAOut extends StatefulWidget {
  @override
  _QAOutState createState() => _QAOutState();
}

class _QAOutState extends State<QAOut> {
  final QAOutService _service = const QAOutService();
  final SOPController = TextEditingController();
  bool hasSearched = false;
  List<Map<String, dynamic>> searchedQaOutHistory = [];
  List<Map<String, dynamic>> QaOutHistory = [];
  bool isLoading = false;

  final ScrollController _historyLeftVerticalScroll = ScrollController();
  final ScrollController _historyMiddleVerticalScroll = ScrollController();
  final ScrollController _historyActionsVerticalScroll = ScrollController();
  final ScrollController _historyMiddleHorizontalScroll = ScrollController();
  final ScrollController _searchMiddleHorizontalScroll = ScrollController();

  int? _sortColumnIndex;
  bool _sortAscending = true;

  /// Sortable columns only (excludes Action).
  static const List<String> _sortKeys = [
    'SOPNum',
    'PONum',
    'ODD',
    'CustomerName',
    'ProgramName',
    'Location',
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
    });
  }

  Future<void> GetQAOutHistory() async {
    await Dioservices.setToken();
    setState(() {
      isLoading = true;
    });
    try {
      final response = await _service.QAOutHistory();
      setState(() {
        QaOutHistory = List<Map<String, dynamic>>.from(response.data['data']);
        isLoading = false;
      });
      // print("QAOut Hisotry ${response.data['data']}");
    } catch (e) {
      print("Error fetching QA Out history: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        AppToast.error(context, 'Failed to load QA Out history');
      }
    }
  }

  void _clearSearch() {
    setState(() {
      hasSearched = false;
      searchedQaOutHistory = [];
    });
  }

  void _onSearchChanged(String value) {
    if (value.trim().isEmpty && hasSearched) {
      _clearSearch();
    }
  }

  void _runSearch() {
    final rawInput = SOPController.text.trim();
    if (rawInput.isEmpty) {
      AppToast.error(context, 'Please enter SOP number');
      return;
    }
    final sopTokens = rawInput
        .split(RegExp(r'[\s,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    setState(() {
      hasSearched = true;
      searchedQaOutHistory = sopTokens.isEmpty
          ? <Map<String, dynamic>>[]
          : QaOutHistory.where((item) {
              final sop = item['SOPNum']?.toString() ?? '';
              return sopTokens.contains(sop);
            }).toList();
    });
  }

  void _refreshSearchResults() {
    final rawInput = SOPController.text.trim();
    if (rawInput.isEmpty) {
      _clearSearch();
      return;
    }
    final sopTokens = rawInput
        .split(RegExp(r'[\s,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    setState(() {
      searchedQaOutHistory = sopTokens.isEmpty
          ? <Map<String, dynamic>>[]
          : QaOutHistory.where((item) {
              final sop = item['SOPNum']?.toString() ?? '';
              return sopTokens.contains(sop);
            }).toList();
    });
  }

  Future<void> HandleUpdateQCOutDate() async {
    final sop = SOPController.text.trim();
    if (sop.isEmpty) {
      AppToast.error(context, 'Please enter SOP number');
      return;
    }
    try {
      final response = await _service.UpdateQCOutDate(sop);
      print("UPDATE QC OUT RESPONSE: ${response.data}");
      await GetQAOutHistory();
      if (!mounted) return;
      if (hasSearched) {
        _refreshSearchResults();
      }
      AppToast.success(context, "QA Out date updated successfully");
    } catch (e) {
      print("Error updating QA Out date: $e");
      if (mounted) {
        AppToast.error(context, 'Something went wrong');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _historyLeftVerticalScroll.addListener(
      () => _syncScroll(_historyLeftVerticalScroll, [
        _historyMiddleVerticalScroll,
        _historyActionsVerticalScroll,
      ]),
    );
    _historyMiddleVerticalScroll.addListener(
      () => _syncScroll(_historyMiddleVerticalScroll, [
        _historyLeftVerticalScroll,
        _historyActionsVerticalScroll,
      ]),
    );
    _historyActionsVerticalScroll.addListener(
      () => _syncScroll(_historyActionsVerticalScroll, [
        _historyLeftVerticalScroll,
        _historyMiddleVerticalScroll,
      ]),
    );
    GetQAOutHistory();
  }

  @override
  void dispose() {
    _historyLeftVerticalScroll.dispose();
    _historyMiddleVerticalScroll.dispose();
    _historyActionsVerticalScroll.dispose();
    _historyMiddleHorizontalScroll.dispose();
    _searchMiddleHorizontalScroll.dispose();
    SOPController.dispose();
    super.dispose();
  }

  void _syncScroll(ScrollController source, List<ScrollController> targets) {
    for (final target in targets) {
      if (!target.hasClients) continue;
      if (target.offset != source.offset) {
        target.jumpTo(source.offset);
      }
    }
  }

  String formatDate(dynamic date) => ApiDate.formatMmDdYyyy(date, empty: '-');

  String formatDateTime(dynamic date) =>
      ApiDate.formatMmDdYyyyDateTime(date, empty: '-');

  static const Color _tableHeaderColor = Color.fromARGB(255, 57, 73, 95);
  static const double _rowHeight = 56;

  // SOP, PO Num, ODD | middle cols | Last Edited | Action
  static const List<double> _baseColWidths = [
    90, // SOP
    170, // PO Num
    100, // ODD
    260, // Customer
    120, // Prgm
    80, // Loc.
    100, // QC In
    100, // RW QC Out
    130, // Final Date Received In QC
    100, // QC Out
    160, // Comments
    160, // Last Edited On
    72, // Action
  ];

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

  List<double> _scaledMiddleWidths({
    required bool showLastEdited,
    required double availableMiddleWidth,
  }) {
    final middle = showLastEdited
        ? _baseColWidths.sublist(3, 12)
        : _baseColWidths.sublist(3, 11);
    final total = middle.fold<double>(0, (sum, w) => sum + w);
    if (availableMiddleWidth <= total) return middle;
    final scale = availableMiddleWidth / total;
    return middle.map((w) => w * scale).toList();
  }

  String _wrapFriendly(String text) {
    return text
        .replaceAll('-', '-\u200B')
        .replaceAll('_', '_\u200B')
        .replaceAll('#', '#\u200B');
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

  Widget _bodyTextCell(String text, double width, {bool wrap = false}) {
    final displayText = wrap ? _wrapFriendly(text) : text;
    return Container(
      width: width,
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey, width: 0.5),
      ),
      child: Text(
        displayText,
        textAlign: TextAlign.left,
        softWrap: wrap,
        maxLines: wrap ? 3 : 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
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
          _bodyTextCell(
            item['SOPNum']?.toString() ?? '',
            leftWidths[0],
            wrap: true,
          ),
          _bodyTextCell(
            item['PONum']?.toString() ?? '',
            leftWidths[1],
            wrap: true,
          ),
          _bodyTextCell(formatDate(item['ODD']?.toString()), leftWidths[2]),
        ],
      ),
    );
  }

  Widget _middleHeader(
    List<double> middleWidths, {
    required bool showLastEdited,
  }) {
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
        if (showLastEdited)
          _headerCell('Last Edited On', middleWidths[8], sortIndex: 11),
      ],
    );
  }

  Widget _middleDataRow(
    Map<String, dynamic> item,
    List<double> middleWidths, {
    required bool showLastEdited,
  }) {
    return Row(
      children: [
        _bodyTextCell(
          item['CustomerName']?.toString() ?? '',
          middleWidths[0],
          wrap: true,
        ),
        _bodyTextCell(
          item['ProgramName']?.toString() ?? '',
          middleWidths[1],
          wrap: true,
        ),
        _bodyTextCell(item['Location']?.toString() ?? '', middleWidths[2]),
        _bodyTextCell(
          formatDate(item['QCDateIn']?.toString() ?? ''),
          middleWidths[3],
        ),
        _bodyTextCell(
          formatDate(item['ReworkDateOut']?.toString() ?? ''),
          middleWidths[4],
        ),
        _bodyTextCell(
          formatDate(item['FinalDateReceivedInQC']?.toString() ?? ''),
          middleWidths[5],
        ),
        _bodyTextCell(
          formatDate(item['QCOut']?.toString() ?? ''),
          middleWidths[6],
        ),
        _bodyTextCell(
          item['QAComments']?.toString() ?? '',
          middleWidths[7],
          wrap: true,
        ),
        if (showLastEdited)
          _bodyTextCell(
            formatDateTime(item['LastEdit']?.toString()),
            middleWidths[8],
            wrap: true,
          ),
      ],
    );
  }

  Future<void> _openEdit(Map<String, dynamic> item) async {
    final SOPId = item['SOPId']?.toString() ?? '';
    print("PASSING SOP: $SOPId");
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QAOutEditEntry(SOPId: SOPId)),
    );
    if (updated == true) {
      await GetQAOutHistory();
      if (hasSearched) {
        _refreshSearchResults();
      }
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

  Widget _buildPlainHeaderRow(
    List<double> widths, {
    required bool showLastEdited,
    bool showAction = false,
  }) {
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
        if (showLastEdited)
          _headerCell('Last Edited On', widths[11], sortIndex: 11),
        if (showAction) _headerCell('Action', widths.last),
      ],
    );
  }

  Widget _buildPlainDataRow(
    Map<String, dynamic> item,
    List<double> widths, {
    required bool showLastEdited,
    bool showAction = false,
  }) {
    return Row(
      children: [
        _bodyTextCell(item['SOPNum']?.toString() ?? '', widths[0], wrap: true),
        _bodyTextCell(item['PONum']?.toString() ?? '', widths[1], wrap: true),
        _bodyTextCell(formatDate(item['ODD']?.toString()), widths[2]),
        _bodyTextCell(
          item['CustomerName']?.toString() ?? '',
          widths[3],
          wrap: true,
        ),
        _bodyTextCell(
          item['ProgramName']?.toString() ?? '',
          widths[4],
          wrap: true,
        ),
        _bodyTextCell(item['Location']?.toString() ?? '', widths[5]),
        _bodyTextCell(
          formatDate(item['QCDateIn']?.toString() ?? ''),
          widths[6],
        ),
        _bodyTextCell(
          formatDate(item['ReworkDateOut']?.toString() ?? ''),
          widths[7],
        ),
        _bodyTextCell(
          formatDate(item['FinalDateReceivedInQC']?.toString() ?? ''),
          widths[8],
        ),
        _bodyTextCell(formatDate(item['QCOut']?.toString() ?? ''), widths[9]),
        _bodyTextCell(
          item['QAComments']?.toString() ?? '',
          widths[10],
          wrap: true,
        ),
        if (showLastEdited)
          _bodyTextCell(
            formatDateTime(item['LastEdit']?.toString()),
            widths[11],
            wrap: true,
          ),
        if (showAction) _actionDataCell(item, widths.last),
      ],
    );
  }

  List<double> _plainTableWidths({
    required bool showLastEdited,
    required bool showAction,
    required double availableWidth,
  }) {
    final base = [
      ...showLastEdited ? _baseColWidths.take(12) : _baseColWidths.take(11),
      if (showAction) _baseColWidths[12],
    ];
    final total = base.fold<double>(0, (sum, w) => sum + w);
    if (availableWidth <= total) return base;
    final scale = availableWidth / total;
    return base.map((w) => w * scale).toList();
  }

  Widget buildTable(
    List<Map<String, dynamic>> rowsData, {
    bool showLastEditedAndAction = true,
    bool isSearchTable = false,
    bool shrinkWrap = false,
  }) {
    final rows = _sortedRows(rowsData);
    final leftWidths = _baseColWidths.take(3).toList();
    final leftWidth = leftWidths.fold<double>(0, (sum, w) => sum + w);
    final actionWidth = _baseColWidths[12];
    final showAction = showLastEditedAndAction;
    final showLastEdited = showLastEditedAndAction;
    final horizontalScroll = isSearchTable
        ? _searchMiddleHorizontalScroll
        : _historyMiddleHorizontalScroll;

    return Responsive.hideScrollbars(
      context,
      LayoutBuilder(
        builder: (context, constraints) {
          final reserved = leftWidth + (showAction ? actionWidth : 0);
          final tooNarrow = constraints.maxWidth < reserved + 48;

          // Phone / small tablet / search: one horizontally scrollable table.
          if (shrinkWrap ||
              isSearchTable ||
              tooNarrow ||
              Responsive.isMobileTableLayout(context)) {
            final widths = _plainTableWidths(
              showLastEdited: showLastEdited,
              showAction: showAction && !isSearchTable && !shrinkWrap,
              availableWidth: constraints.maxWidth,
            );
            final tableWidth = widths.fold<double>(0, (sum, w) => sum + w);
            final showPlainAction = showAction && !isSearchTable && !shrinkWrap;
            final table = Column(
              mainAxisSize: shrinkWrap || isSearchTable
                  ? MainAxisSize.min
                  : MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPlainHeaderRow(
                  widths,
                  showLastEdited: showLastEdited,
                  showAction: showPlainAction,
                ),
                if (shrinkWrap || isSearchTable)
                  ...rows.map(
                    (item) => _buildPlainDataRow(
                      item,
                      widths,
                      showLastEdited: showLastEdited,
                      showAction: showPlainAction,
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: _historyMiddleVerticalScroll,
                      itemCount: rows.length,
                      itemExtent: _rowHeight,
                      itemBuilder: (context, index) {
                        return _buildPlainDataRow(
                          rows[index],
                          widths,
                          showLastEdited: showLastEdited,
                          showAction: showPlainAction,
                        );
                      },
                    ),
                  ),
              ],
            );
            return SizedBox(
              width: constraints.maxWidth,
              height: shrinkWrap || isSearchTable
                  ? null
                  : constraints.maxHeight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: horizontalScroll,
                child: SizedBox(
                  width: tableWidth,
                  height: shrinkWrap || isSearchTable
                      ? null
                      : constraints.maxHeight,
                  child: table,
                ),
              ),
            );
          }

          final middleAvailable = (constraints.maxWidth - reserved).clamp(
            0.0,
            double.infinity,
          );
          final middleWidths = _scaledMiddleWidths(
            showLastEdited: showLastEdited,
            availableMiddleWidth: middleAvailable,
          );
          final middleWidth = middleWidths.fold<double>(0, (sum, w) => sum + w);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: leftWidth,
                child: Column(
                  children: [
                    _leftHeader(leftWidths),
                    Expanded(
                      child: ListView.builder(
                        controller: _historyLeftVerticalScroll,
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
                  controller: horizontalScroll,
                  child: SizedBox(
                    width: middleWidth,
                    child: Column(
                      children: [
                        _middleHeader(
                          middleWidths,
                          showLastEdited: showLastEdited,
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _historyMiddleVerticalScroll,
                            itemCount: rows.length,
                            itemExtent: _rowHeight,
                            itemBuilder: (context, index) {
                              return _middleDataRow(
                                rows[index],
                                middleWidths,
                                showLastEdited: showLastEdited,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showAction)
                SizedBox(
                  width: actionWidth,
                  child: Column(
                    children: [
                      _actionHeader(actionWidth),
                      Expanded(
                        child: ListView.builder(
                          controller: _historyActionsVerticalScroll,
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
        hintText: 'Enter SOP Number',
        hintStyle: TextStyle(fontSize: r.searchFieldFontSize),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: r.searchFieldContentPaddingV,
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
          isTablet ? 'Search for Entry' : 'Search',
          style: TextStyle(
            fontSize: r.searchButtonFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.fieldRadius),
          ),
        ),
      ),
    );
    final updateButton = ElevatedButton.icon(
      onPressed: HandleUpdateQCOutDate,
      icon: Icon(Icons.save, size: r.searchIconSize),
      label: Text(
        'Update QA Out Date',
        style: TextStyle(
          fontSize: isTablet ? 16 : r.searchButtonFontSize,
          fontWeight: FontWeight.bold,
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
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(),
      drawer: const CommonDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(12),
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
                    const Text(
                      'Update QA Out Date',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(width: 360, child: sopField),
                    const SizedBox(width: 16),
                    searchButton,
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Update QA Out Date',
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
            const SizedBox(height: 8),
            if (hasSearched) ...[
              if (searchedQaOutHistory.isNotEmpty) ...[
                buildTable(
                  searchedQaOutHistory,
                  showLastEditedAndAction: false,
                  isSearchTable: true,
                  shrinkWrap: true,
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: updateButton),
                const SizedBox(height: 8),
              ] else
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE57373)),
                  ),
                  child: const Text(
                    'Invalid or cancelled SOP number. Please enter a valid SOP.',
                    style: TextStyle(
                      color: Color(0xFFC62828),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
            Text(
              'SOP History',
              style: TextStyle(
                fontSize: r.sectionTitleSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: isLoading
                  ? const Center(child: Center(child: AppLoader()))
                  : buildTable(QaOutHistory),
            ),
          ],
        ),
      ),
    );
  }
}
