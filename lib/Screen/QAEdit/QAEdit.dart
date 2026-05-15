import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/QAEdit/Services/Components/QAEditEntry.dart';
import 'package:overview_app/Screen/QAEdit/Services/QAEditService.dart';
import 'package:overview_app/Services/DioServices.dart';
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
  final ScrollController _headerHorizontalScroll = ScrollController();
  final ScrollController _bodyHorizontalScroll = ScrollController();

  static const int _rowsPerPage = 100;
  int _currentPage = 1;

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
      print("QA EDIT DATA $data");
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print("Error fetching QA Edit history: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _headerHorizontalScroll.addListener(
      () => _syncHorizontalScroll(
        _headerHorizontalScroll,
        _bodyHorizontalScroll,
      ),
    );
    _bodyHorizontalScroll.addListener(
      () => _syncHorizontalScroll(
        _bodyHorizontalScroll,
        _headerHorizontalScroll,
      ),
    );
    GetQAEditHistory();
  }

  void _syncHorizontalScroll(
    ScrollController source,
    ScrollController target,
  ) {
    if (!target.hasClients) {
      return;
    }
    if (target.offset != source.offset) {
      target.jumpTo(source.offset);
    }
  }

  @override
  void dispose() {
    _headerHorizontalScroll.dispose();
    _bodyHorizontalScroll.dispose();
    SOPController.dispose();
    super.dispose();
  }

  /// Case-insensitive match across the main table columns.
  List<Map<String, dynamic>> get _filteredHistory {
    final q = SOPController.text.trim().toLowerCase();
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

  static const TextStyle _cellTextStyle = TextStyle(fontSize: 12);

  /// Highlights [SOPController] query in [text] (case-insensitive).
  Widget _highlightedCellText(
    String text, {
    TextAlign textAlign = TextAlign.center,
    int? maxLines,
    bool softWrap = false,
  }) {
    final q = SOPController.text.trim();
    if (q.isEmpty) {
      return Text(
        text,
        textAlign: textAlign,
        style: _cellTextStyle,
        maxLines: maxLines,
        softWrap: softWrap,
        overflow: maxLines == null ? TextOverflow.visible : TextOverflow.clip,
      );
    }

    final lower = text.toLowerCase();
    final needle = q.toLowerCase();
    if (!lower.contains(needle)) {
      return Text(
        text,
        textAlign: textAlign,
        style: _cellTextStyle,
        maxLines: maxLines,
        softWrap: softWrap,
        overflow: maxLines == null ? TextOverflow.visible : TextOverflow.clip,
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
      overflow: maxLines == null ? TextOverflow.visible : TextOverflow.clip,
    );
  }

  static const Color _tableHeaderColor = Color.fromARGB(255, 57, 73, 95);

  Widget _headerCell(String text, double width) {
    return SizedBox(
      width: width,
      height: 56,
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

  Widget _bodyCell(
    String text,
    double width, {
    bool wrap = false,
  }) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 0.5),
      ),
      child: _highlightedCellText(
        text,
        softWrap: wrap,
        maxLines: wrap ? null : 1,
      ),
    );
  }

  Widget _buildTableHeaderRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerCell('SOP', 100),
        _headerCell('PO Num', 140),
        _headerCell('ODD', 90),
        _headerCell('Customer', 260),
        _headerCell('Prgm', 100),
        _headerCell('Loc.', 90),
        _headerCell('QC In', 140),
        _headerCell('RW QC Out', 75),
        _headerCell('Final Date Received In QC', 140),
        _headerCell('QC Out', 100),
        _headerCell('Comments', 110),
        _headerCell('Last Edited On', 100),
        _headerCell('Action', 90),
      ],
    );
  }

  Widget _buildTableDataRow(Map<String, dynamic> item) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bodyCell(item['SOPNum']?.toString() ?? '-', 100),
          _bodyCell(item['PONum']?.toString() ?? '-', 140),
          _bodyCell(formatDate(item['ODD']?.toString() ?? '-'), 90),
          _bodyCell(
            item['CustomerName']?.toString() ?? '-',
            260,
            wrap: true,
          ),
          _bodyCell(item['ProgramName']?.toString() ?? '-', 100),
          _bodyCell(item['LocationName']?.toString() ?? '-', 90),
          _bodyCell(formatDate(item['QCDateIn']?.toString() ?? '-'), 140),
          _bodyCell(formatDate(item['ReworkDateOut']?.toString() ?? '-'), 75),
          _bodyCell(
            formatDate(item['FinalDateReceivedInQC']?.toString() ?? '-'),
            140,
          ),
          _bodyCell(formatDate(item['QCOut']?.toString() ?? '-'), 100),
          _bodyCell(item['QAComments']?.toString() ?? '', 110),
          _bodyCell(formatDateTime(item['LastEdit']?.toString() ?? '-'), 100),
          Container(
            width: 90,
            constraints: const BoxConstraints(minHeight: 56),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 0.5),
            ),
            child: OutlinedButton.icon(
              onPressed: () async {
                final SOPId = item['SOPId']?.toString() ?? '-';
                print("PASSING SOPId: $SOPId");
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QAEditEntry(SOPId: SOPId),
                  ),
                );
                if (updated == true) {
                  await GetQAEditHistory();
                }
              },
              icon: const Icon(Icons.edit, size: 20, color: Colors.black),
              label: const Text(''),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTable() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _headerHorizontalScroll,
          child: _buildTableHeaderRow(),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _bodyHorizontalScroll,
              child: Column(
                children: _pagedHistory
                    .map(_buildTableDataRow)
                    .toList(growable: false),
              ),
            ),
          ),
        ),
      ],
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
                    'Search SOP to Edit',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: SOPController,
                      onChanged: (_) {
                        setState(() {
                          _currentPage = 1;
                          _clampCurrentPage();
                        });
                      },
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
                child: CircularProgressIndicator(
                  color: Color.fromARGB(255, 57, 73, 95),
                ),
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
