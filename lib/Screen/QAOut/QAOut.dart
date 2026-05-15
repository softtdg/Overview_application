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
  final ScrollController _headerHorizontalScroll = ScrollController();
  final ScrollController _bodyHorizontalScroll = ScrollController();
  final ScrollController _searchHeaderHorizontalScroll = ScrollController();
  final ScrollController _searchBodyHorizontalScroll = ScrollController();
  bool hasSearched = false;
  List<Map<String, dynamic>> searchedQaOutHistory = [];
  List<Map<String, dynamic>> QaOutHistory = [];
  bool isLoading = false;

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
      print("QAOut Hisotry ${response.data['data']}");
    } catch (e) {
      print("Error fetching QA Out history: $e");
      setState(() {
        isLoading = false;
      });
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
    _searchHeaderHorizontalScroll.addListener(
      () => _syncHorizontalScroll(
        _searchHeaderHorizontalScroll,
        _searchBodyHorizontalScroll,
      ),
    );
    _searchBodyHorizontalScroll.addListener(
      () => _syncHorizontalScroll(
        _searchBodyHorizontalScroll,
        _searchHeaderHorizontalScroll,
      ),
    );
    GetQAOutHistory();
  }

  @override
  void dispose() {
    _headerHorizontalScroll.dispose();
    _bodyHorizontalScroll.dispose();
    _searchHeaderHorizontalScroll.dispose();
    _searchBodyHorizontalScroll.dispose();
    SOPController.dispose();
    super.dispose();
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

  Future<void> FetchQAOutSearch() async {
    setState(() {
      hasSearched = true;
      isLoading = true;
    });
    try {
      final response = await _service.QAOutSearch(SOPController.text.trim());
      setState(() {
        searchedQaOutHistory = List<Map<String, dynamic>>.from(
          response.data['data'],
        );
      });
      print("QAIN SEARCH RESULT ${response.data['data']}");
    } catch (e) {
      print("Error fetching QA Out search: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> HandleUpdateQCOutDate() async {
    try {
      final response = await _service.UpdateQCOutDate(
        SOPController.text.trim(),
      );
      print("UPDATE QC OUT RESPONSE: ${response.data}");
      await GetQAOutHistory();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("QA Out date updated successfully")),
      );
    } catch (e) {
      print("Error updating QA Out date: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
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
      // print("Date parse error: $e");
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
      return DateFormat('MM/dd/yyyy hh:mm a').format(parsedDate);
    } catch (e) {
      // print("DateTime parse error: $e");
      return "-";
    }
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

  Widget _bodyTextCell(
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
      child: Text(
        text,
        textAlign: TextAlign.center,
        softWrap: wrap,
        maxLines: wrap ? null : 1,
        overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildTableHeaderRow({required bool showLastEditedAndAction}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerCell('SOP', 60),
        _headerCell('PO Num', 100),
        _headerCell('ODD', 90),
        _headerCell('Customer', 260),
        _headerCell('Prgm', 100),
        _headerCell('Loc.', 90),
        _headerCell('QC In', 90),
        _headerCell('RW QC Out', 90),
        _headerCell('Final Date Received In QC', 120),
        _headerCell('QC Out', 90),
        _headerCell('Comments', 150),
        if (showLastEditedAndAction) _headerCell('Last Edited On', 170),
        if (showLastEditedAndAction) _headerCell('Action', 90),
      ],
    );
  }

  Widget _buildTableDataRow(
    Map<String, dynamic> item, {
    required bool showLastEditedAndAction,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bodyTextCell(item['SOPNum']?.toString() ?? '', 60),
          _bodyTextCell(item['PONum']?.toString() ?? '', 100),
          _bodyTextCell(formatDate(item['ODD']?.toString()), 90),
          _bodyTextCell(
            item['CustomerName']?.toString() ?? '',
            260,
            wrap: true,
          ),
          _bodyTextCell(item['ProgramName']?.toString() ?? '', 100),
          _bodyTextCell(item['Location']?.toString() ?? '', 90),
          _bodyTextCell(formatDate(item['QCDateIn']?.toString() ?? ''), 90),
          _bodyTextCell(
            formatDate(item['ReworkDateOut']?.toString() ?? ''),
            90,
          ),
          _bodyTextCell(
            formatDate(item['FinalDateReceivedInQC']?.toString() ?? ''),
            120,
          ),
          _bodyTextCell(formatDate(item['QCOut']?.toString() ?? ''), 90),
          _bodyTextCell(item['QAComments']?.toString() ?? '', 150),
          if (showLastEditedAndAction)
            _bodyTextCell(formatDateTime(item['LastEdit']?.toString()), 170),
          if (showLastEditedAndAction)
            Container(
              width: 90,
              constraints: const BoxConstraints(minHeight: 56),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 0.5),
              ),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final SOPId = item['SOPId']?.toString() ?? '';
                  print("PASSING SOP: $SOPId");
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QAOutEditEntry(SOPId: SOPId),
                    ),
                  );
                  if (updated == true) {
                    await GetQAOutHistory();
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

  Widget buildTable(
    List<Map<String, dynamic>> rowsData, {
    bool showLastEditedAndAction = true,
    bool isSearchTable = false,
  }) {
    final headerScroll = isSearchTable
        ? _searchHeaderHorizontalScroll
        : _headerHorizontalScroll;
    final bodyScroll =
        isSearchTable ? _searchBodyHorizontalScroll : _bodyHorizontalScroll;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: headerScroll,
          child: _buildTableHeaderRow(
            showLastEditedAndAction: showLastEditedAndAction,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: bodyScroll,
              child: Column(
                children: rowsData
                    .map(
                      (item) => _buildTableDataRow(
                        item,
                        showLastEditedAndAction: showLastEditedAndAction,
                      ),
                    )
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
    );
    final searchButton = ElevatedButton.icon(
      onPressed: () {
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
      },
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
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  sopField,
                  const SizedBox(height: 12),
                  searchButton,
                ],
              ),
            const SizedBox(height: 12),
            if (hasSearched) ...[
              const Text(
                'Searched SOP Data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (searchedQaOutHistory.isNotEmpty)
                SizedBox(
                  height: 220,
                  child: buildTable(
                    searchedQaOutHistory,
                    showLastEditedAndAction: false,
                    isSearchTable: true,
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No data found for searched SOP',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            const Text(
              'SOP History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
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
