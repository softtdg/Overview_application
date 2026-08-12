import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/QAOut/Components/QAOutEditEntry.dart';
import 'package:overview_app/Screen/QAOut/Services/QAOutService.dart';
import 'package:overview_app/Services/DioServices.dart';
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
      }
    }
  }

  void _runSearch() {
    final rawInput = SOPController.text.trim();
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
    HandleUpdateQCOutDate();
  }

  void _refreshSearchResults() {
    final rawInput = SOPController.text.trim();
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
    try {
      final response = await _service.UpdateQCOutDate(
        SOPController.text.trim(),
      );
      print("UPDATE QC OUT RESPONSE: ${response.data}");
      await GetQAOutHistory();
      if (!mounted) return;
      if (hasSearched) {
        _refreshSearchResults();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("QA Out date updated successfully")),
      );
    } catch (e) {
      print("Error updating QA Out date: $e");
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
      return "-";
    }
  }

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
    150, // Last Edited On
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

  Widget _bodyTextCell(String text, double width, {bool wrap = false}) {
    final displayText = wrap ? _wrapFriendly(text) : text;
    return Container(
      width: width,
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey, width: 0.5),
      ),
      child: Text(
        displayText,
        textAlign: TextAlign.center,
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
        _headerCell('Customer', middleWidths[0]),
        _headerCell('Prgm', middleWidths[1]),
        _headerCell('Loc.', middleWidths[2]),
        _headerCell('QC In', middleWidths[3]),
        _headerCell('RW QC Out', middleWidths[4]),
        _headerCell('Final Date Received In QC', middleWidths[5]),
        _headerCell('QC Out', middleWidths[6]),
        _headerCell('Comments', middleWidths[7]),
        if (showLastEdited) _headerCell('Last Edited On', middleWidths[8]),
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
          icon: const Icon(Icons.edit, size: 18, color: Colors.black),
          style: IconButton.styleFrom(
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
  }) {
    return Row(
      children: [
        _headerCell('SOP', widths[0]),
        _headerCell('PO Num', widths[1]),
        _headerCell('ODD', widths[2]),
        _headerCell('Customer', widths[3]),
        _headerCell('Prgm', widths[4]),
        _headerCell('Loc.', widths[5]),
        _headerCell('QC In', widths[6]),
        _headerCell('RW QC Out', widths[7]),
        _headerCell('Final Date Received In QC', widths[8]),
        _headerCell('QC Out', widths[9]),
        _headerCell('Comments', widths[10]),
        if (showLastEdited) _headerCell('Last Edited On', widths[11]),
      ],
    );
  }

  Widget _buildPlainDataRow(
    Map<String, dynamic> item,
    List<double> widths, {
    required bool showLastEdited,
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
      ],
    );
  }

  List<double> _plainTableWidths({
    required bool showLastEdited,
    required double availableWidth,
  }) {
    final base = showLastEdited
        ? _baseColWidths.take(12).toList()
        : _baseColWidths.take(11).toList();
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
    final leftWidths = _baseColWidths.take(3).toList();
    final leftWidth = leftWidths.fold<double>(0, (sum, w) => sum + w);
    final actionWidth = _baseColWidths[12];
    final showAction = showLastEditedAndAction;
    final showLastEdited = showLastEditedAndAction;
    final horizontalScroll = isSearchTable
        ? _searchMiddleHorizontalScroll
        : _historyMiddleHorizontalScroll;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Search/first table: normal scrollable table, no sticky columns.
        if (shrinkWrap || isSearchTable) {
          final widths = _plainTableWidths(
            showLastEdited: showLastEdited,
            availableWidth: constraints.maxWidth,
          );
          final tableWidth = widths.fold<double>(0, (sum, w) => sum + w);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: horizontalScroll,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPlainHeaderRow(widths, showLastEdited: showLastEdited),
                  ...rowsData.map(
                    (item) => _buildPlainDataRow(
                      item,
                      widths,
                      showLastEdited: showLastEdited,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final reserved = leftWidth + (showAction ? actionWidth : 0);
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
                      itemCount: rowsData.length,
                      itemExtent: _rowHeight,
                      itemBuilder: (context, index) {
                        return _leftDataRow(rowsData[index], leftWidths);
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
                          itemCount: rowsData.length,
                          itemExtent: _rowHeight,
                          itemBuilder: (context, index) {
                            return _middleDataRow(
                              rowsData[index],
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
                        itemCount: rowsData.length,
                        itemExtent: _rowHeight,
                        itemBuilder: (context, index) {
                          return _actionDataCell(rowsData[index], actionWidth);
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
    final isTablet = MediaQuery.sizeOf(context).width >= 700;
    final sopField = TextField(
      controller: SOPController,
      decoration: InputDecoration(
        hintText: 'Enter SOP Number',
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: isTablet ? 12 : 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTablet ? 4 : 12),
          borderSide: BorderSide(
            color: isTablet ? const Color(0xFFBDBDBD) : const Color(0xFF2196F3),
            width: isTablet ? 1 : 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTablet ? 4 : 12),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _runSearch(),
    );
    final searchButton = ElevatedButton.icon(
      onPressed: _runSearch,
      icon: const Icon(Icons.search, size: 20),
      label: const Text('Search for Entry'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTablet ? 4 : 12),
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
                  const Text(
                    'Update QA Out Date',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  sopField,
                  const SizedBox(height: 12),
                  searchButton,
                ],
              ),
            const SizedBox(height: 8),
            if (hasSearched) ...[
              if (searchedQaOutHistory.isNotEmpty)
                buildTable(
                  searchedQaOutHistory,
                  showLastEditedAndAction: false,
                  isSearchTable: true,
                  shrinkWrap: true,
                )
              else
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
              const SizedBox(height: 8),
            ],
            const Text(
              'SOP History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color.fromARGB(255, 57, 73, 95),
                      ),
                    )
                  : buildTable(QaOutHistory),
            ),
          ],
        ),
      ),
    );
  }
}
