import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/QAEdit/Services/Components/QAEditEntry.dart';
import 'package:overview_app/Screen/QAEdit/Services/QAEditService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class QAEdit extends StatefulWidget {
  @override
  _QAEditState createState() => _QAEditState();
}

class _QAEditState extends State<QAEdit> {
  final SOPController = TextEditingController();
  List<Map<String, dynamic>> QCEditHistory = [];
  final QAEditServices _service = QAEditServices();
  bool isLoading = false;
  bool _pageLoading = false;
  static const int _rowsPerPage = 100;
  int _currentPage = 1;

  Future<void> GetQAEditHistory() async {
    await Dioservices.setToken();
    setState(() {
      isLoading = true;
      _pageLoading = false;
    });
    try {
      final response = await _service.GetQAEditHistory();
      final data = response.data['data'];
      setState(() {
        QCEditHistory = List<Map<String, dynamic>>.from(data);
        _currentPage = 1;
        isLoading = false;
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
    GetQAEditHistory();
  }

  @override
  void dispose() {
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

  int get _totalPages {
    final n = _filteredHistory.length;
    if (n == 0) return 1;
    return (n + _rowsPerPage - 1) ~/ _rowsPerPage;
  }

  List<Map<String, dynamic>> get _pageRows {
    final tp = _totalPages;
    final c = _currentPage.clamp(1, tp);
    final start = (c - 1) * _rowsPerPage;
    return _filteredHistory.skip(start).take(_rowsPerPage).toList();
  }

  List<Object?> _pageButtons(int current, int total) {
    if (total <= 9) return List.generate(total, (i) => i + 1);
    // Fewer number chips on small screens (was 1–5; skip 4 & 5).
    if (current <= 3) return [1, 2, 3, null, total];
    if (current >= total - 2) {
      return [1, null, total - 4, total - 3, total - 2, total - 1, total];
    }
    return [1, null, current - 1, current, current + 1, null, total];
  }

  Widget _pagerSquare({
    required Widget child,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final active = Color(0xFF34495E);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: selected ? active : Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? active : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _iconPager({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return _pagerSquare(
      onTap: enabled ? onTap : null,
      child: Icon(
        icon,
        size: 20,
        color: enabled ? Colors.grey.shade800 : Colors.grey.shade400,
      ),
    );
  }

  Widget buildPaginationBar() {
    final total = _totalPages;
    final c = _currentPage.clamp(1, total);
    void go(int p) {
      if (_pageLoading) return;
      final next = p.clamp(1, total);
      if (next == _currentPage) return;
      setState(() => _pageLoading = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _currentPage = next;
          _pageLoading = false;
        });
      });
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _iconPager(
              icon: Icons.first_page,
              enabled: c > 1,
              onTap: () => go(1),
            ),
            _iconPager(
              icon: Icons.chevron_left,
              enabled: c > 1,
              onTap: () => go(c - 1),
            ),
            ..._pageButtons(c, total).map((e) {
              if (e == null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '...',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                );
              }
              final p = e as int;
              return _pagerSquare(
                selected: p == c,
                onTap: () => go(p),
                child: Text(
                  '$p',
                  style: TextStyle(
                    fontSize: 14,
                    color: p == c ? Colors.white : Colors.grey.shade800,
                    fontWeight: p == c ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              );
            }),
            _iconPager(
              icon: Icons.chevron_right,
              enabled: c < total,
              onTap: () => go(c + 1),
            ),
            _iconPager(
              icon: Icons.last_page,
              enabled: c < total,
              onTap: () => go(total),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(
            Color.fromARGB(255, 57, 73, 95),
          ),
          dataRowMinHeight: 56,
          dataRowMaxHeight: double.infinity,
          horizontalMargin: 20,
          columnSpacing: 20,
          border: TableBorder.all(color: Colors.grey, width: 1),
          columns: const [
            DataColumn(
              label: SizedBox(
                width: 60,
                child: Center(
                  child: Text(
                    "SOP",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 80,
                child: Center(
                  child: Text(
                    "PO Num",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 90,
                child: Center(
                  child: Text(
                    "ODD",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 260,
                child: Center(
                  child: Text(
                    "Customer",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 60,
                child: Center(
                  child: Text(
                    "Prgm",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 90,
                child: Center(
                  child: Text(
                    "Loc.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 140,
                child: Center(
                  child: Text(
                    "QC In",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 75,
                child: Center(
                  child: Text(
                    "RW QC Out",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 140,
                child: Center(
                  child: Text(
                    "Final Date Received In QC",
                    textAlign: TextAlign.center,
                    softWrap: true,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 100,
                child: Center(
                  child: Text(
                    "QC Out",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 110,
                child: Center(
                  child: Text(
                    "Comments",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 60,
                child: Center(
                  child: Text(
                    "Last Edited On",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: 90,
                child: Center(
                  child: Text(
                    "Action",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
          rows: _pageRows.map((item) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 60,
                    child: Center(
                      child: _highlightedCellText(
                        item['SOPNum']?.toString() ?? '-',
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 80,
                    child: Center(
                      child: _highlightedCellText(
                        item['PONum']?.toString() ?? '-',
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 90,
                    child: Center(
                      child: _highlightedCellText(
                        formatDate(item['ODD']?.toString() ?? '-'),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 260,
                    child: Center(
                      child: _highlightedCellText(
                        item['CustomerName']?.toString() ?? '-',
                        softWrap: true,
                        maxLines: null,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 100,
                    child: Center(
                      child: _highlightedCellText(
                        item['ProgramName']?.toString() ?? '-',
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 90,
                    child: Center(
                      child: _highlightedCellText(
                        item['LocationName']?.toString() ?? '-',
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 140,
                    child: Center(
                      child: _highlightedCellText(
                        formatDate(item['QCDateIn']?.toString() ?? '-'),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 75,
                    child: Center(
                      child: _highlightedCellText(
                        formatDate(item['ReworkDateOut']?.toString() ?? '-'),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 140,
                    child: Center(
                      child: _highlightedCellText(
                        formatDate(
                          item['FinalDateReceivedInQC']?.toString() ?? '-',
                        ),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 100,
                    child: Center(
                      child: _highlightedCellText(
                        formatDate(item['QCOut']?.toString() ?? '-'),
                      ),
                    ),
                  ),
                ),

                DataCell(
                  SizedBox(
                    width: 110,
                    child: Center(
                      child: _highlightedCellText(
                        item['QAComments']?.toString() ?? '',
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 100,
                    child: Center(
                      child: _highlightedCellText(
                        formatDateTime(item['LastEdit']?.toString() ?? '-'),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 90,
                    child: Center(
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
                        icon: const Center(
                          child: Icon(
                            Icons.edit,
                            size: 20,
                            color: Colors.black,
                          ),
                        ),
                        label: const Text(
                          // "Edit Entry",
                          "",
                          // style: TextStyle(fontSize: 12, color: Colors.black),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.black),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          minimumSize: Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(),
      drawer: const CommonDrawer(),
      body: Container(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.center,
                child: Text(
                  "QA Edit SOP History",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(
                // width: ,
                child: TextField(
                  controller: SOPController,
                  onChanged: (_) {
                    setState(() {
                      _currentPage = 1;
                    });
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Search in table...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color.fromARGB(255, 22, 129, 218),
                        width: 2,
                      ),
                    ),
                    suffixIcon: SOPController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              SOPController.clear();
                              setState(() {
                                _currentPage = 1;
                              });
                            },
                          ),
                  ),
                  textInputAction: TextInputAction.search,
                ),
              ),

              const SizedBox(height: 10),

              isLoading
                  ? const SizedBox(
                      height: 220,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color.fromARGB(255, 57, 73, 95),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _pageLoading
                            ? const SizedBox(
                                height: 220,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Color.fromARGB(255, 57, 73, 95),
                                  ),
                                ),
                              )
                            : buildTable(),
                        if (_filteredHistory.isNotEmpty) buildPaginationBar(),
                      ],
                    ),

              SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
