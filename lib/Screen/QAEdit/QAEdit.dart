import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/QAEdit/Services/Components/QAEditEntry.dart';
import 'package:overview_app/Screen/QAEdit/Services/QAEditService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
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

  static const Color _tableHeaderColor = Color.fromARGB(255, 57, 73, 95);
  static const double _rowHeight = 76;
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
    150, // Last Edited On
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
    }
  }

  void _runSearch() {
    setState(() {
      _searchQuery = SOPController.text.trim();
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
    if (_filteredHistory.isEmpty) return [];
    final start = (_currentPage - 1) * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, _filteredHistory.length);
    return _filteredHistory.sublist(start, end);
  }

  void _clampCurrentPage() {
    _currentPage = _currentPage.clamp(1, _totalPages);
  }

  String formatDate(dynamic date) {
    if (date == null) return "*";
    try {
      String dateStr = date.toString();
      if (dateStr.startsWith("0001-01-01")) {
        return "*";
      }
      DateTime parsedDate = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(parsedDate);
    } catch (e) {
      return "-";
    }
  }

  String formatDateTime(dynamic date) {
    if (date == null) return "*";
    try {
      String dateStr = date.toString();
      if (dateStr.startsWith("0001-01-01")) {
        return "*";
      }
      DateTime parsedDate = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy hh:mm a').format(parsedDate);
    } catch (e) {
      print("DateTime parse error: $e");
      return "-";
    }
  }

  String _wrapFriendly(String text) {
    return text
        .replaceAll('-', '-\u200B')
        .replaceAll('_', '_\u200B')
        .replaceAll('#', '#\u200B');
  }

  /// Highlights [_searchQuery] in [text] (case-insensitive).
  Widget _highlightedCellText(
    String text, {
    TextAlign textAlign = TextAlign.center,
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

  Widget _headerCell(String text, double width) {
    return SizedBox(
      width: width,
      height: _rowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _tableHeaderColor,
          border: Border.all(color: Colors.grey, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      alignment: Alignment.center,
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
          _headerCell('SOP', leftWidths[0]),
          _headerCell('PO Num', leftWidths[1]),
          _headerCell('ODD', leftWidths[2]),
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
        _headerCell('Customer', middleWidths[0]),
        _headerCell('Prgm', middleWidths[1]),
        _headerCell('Loc.', middleWidths[2]),
        _headerCell('QC In', middleWidths[3]),
        _headerCell('RW QC Out', middleWidths[4]),
        _headerCell('Final Date Received In QC', middleWidths[5]),
        _headerCell('QC Out', middleWidths[6]),
        _headerCell('Comments', middleWidths[7]),
        _headerCell('Last Edited On', middleWidths[8]),
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

  Widget buildTable() {
    final rows = _pagedHistory;
    final leftWidths = _baseColWidths.take(3).toList();
    final leftWidth = leftWidths.fold<double>(0, (sum, w) => sum + w);
    final actionWidth = _baseColWidths[12];

    return LayoutBuilder(
      builder: (context, constraints) {
        final reserved = leftWidth + actionWidth;
        final middleAvailable = (constraints.maxWidth - reserved).clamp(
          0.0,
          double.infinity,
        );
        final middleWidths = _scaledMiddleWidths(middleAvailable);
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
                            return _middleDataRow(rows[index], middleWidths);
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(),
      drawer: const CommonDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: Row(
                children: [
                  const Text(
                    'Search SOP to QA Edit',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: SOPController,
                      decoration: const InputDecoration(
                        hintText: 'Search in table...',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                          borderSide: BorderSide(color: Color(0xFFBDBDBD)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                          borderSide: BorderSide(
                            color: Color(0xFF1565C0),
                            width: 2,
                          ),
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _runSearch(),
                    ),
                  ),
                  const SizedBox(width: 12),
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
            ),
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const Expanded(
              child: Center(
                child: Center(child: AppLoader())
              ),
            )
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: buildTable()),
                    if (_filteredHistory.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
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
