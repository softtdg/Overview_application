import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/QAIn/Components/QAInEditEntry.dart';
import 'package:overview_app/Screen/QAIn/Services/QAInService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class QAIn extends StatefulWidget {
  @override
  _QAInState createState() => _QAInState();
}

class _QAInState extends State<QAIn> {
  final SOPController = TextEditingController();
  final QAInService _service = QAInService();
  List<Map<String, dynamic>> QaInHistory = [];
  List<Map<String, dynamic>> searchedQaInHistory = [];
  bool hasSearched = false;
  bool isLoading = false;

  Future<void> GetQAInHistory() async {
    await Dioservices.setToken();
    setState(() {
      isLoading = true;
    });
    try {
      final response = await _service.QAInHistory();
      setState(() {
        QaInHistory = List<Map<String, dynamic>>.from(response.data['data']);
      });
      // print("QAIN HISTORY: ${response.data}");
    } catch (e) {
      print("Error fetching QA In history: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> FetchQAInSearch() async {
    setState(() {
      hasSearched = true;
      isLoading = true;
    });
    try {
      final response = await _service.QAInSearch(SOPController.text.trim());
      setState(() {
        searchedQaInHistory = List<Map<String, dynamic>>.from(
          response.data['data'],
        );
      });
      print("QA IN SEARCH RESULTS: ${response.data}");
    } catch (e) {
      print("Error fetching QA In search results: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> HandleUpdateQAInDate() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await _service.UpdateQAInDate(SOPController.text.trim());
      print("Update QA In Response: ${response.data}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QA In date updated successfully')),
      );
      await GetQAInHistory();
    } catch (e) {
      print("Error updating QA In date: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    GetQAInHistory();
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
      return DateFormat('dd/MM/yyyy hh:mm a').format(parsedDate);
    } catch (e) {
      // print("DateTime parse error: $e");
      return "-";
    }
  }

  Widget buildTable(
    List<Map<String, dynamic>> rowsData, {
    bool showLastEditedAndAction = true,
  }) {
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
          columns: [
            const DataColumn(
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
            const DataColumn(
              label: SizedBox(
                width: 70,
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
            const DataColumn(
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
            const DataColumn(
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
            const DataColumn(
              label: SizedBox(
                width: 100,
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
            const DataColumn(
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
            const DataColumn(
              label: SizedBox(
                width: 90,
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
            const DataColumn(
              label: SizedBox(
                width: 90,
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
            const DataColumn(
              label: SizedBox(
                width: 120,
                child: Center(
                  child: Text(
                    "Final Date Received In QC",
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const DataColumn(
              label: SizedBox(
                width: 90,
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
            const DataColumn(
              label: SizedBox(
                width: 140,
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
            if (showLastEditedAndAction)
              const DataColumn(
                label: SizedBox(
                  width: 170,
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
            if (showLastEditedAndAction)
              const DataColumn(
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
          rows: rowsData.map((item) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 60,
                    child: Center(
                      child: Text(
                        item['SOPNum']?.toString() ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 70,
                    child: Center(
                      child: Text(
                        item['PONum']?.toString() ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 90,
                    child: Center(
                      child: Text(
                        formatDate(item['ODD']?.toString()),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 260,
                    child: Center(
                      child: Text(
                        item['CustomerName']?.toString() ?? '',
                        textAlign: TextAlign.center,
                        softWrap: true,
                        maxLines: null,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 100,
                    child: Center(
                      child: Text(
                        item['ProgramName']?.toString() ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 90,
                    child: Center(
                      child: Text(
                        item['Location']?.toString() ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 90,
                    child: Center(
                      child: Text(
                        formatDate(item['QCDateIn']?.toString() ?? ''),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 90,
                    child: Center(
                      child: Text(
                        formatDate(item['ReworkDateOut']?.toString() ?? ''),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 120,
                    child: Center(
                      child: Text(
                        formatDate(
                          item['FinalDateReceivedInQC']?.toString() ?? '',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 90,
                    child: Center(
                      child: Text(
                        formatDate(item['QCOut']?.toString() ?? ''),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 140,
                    child: Center(
                      child: Text(
                        item['QAComments']?.toString() ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                if (showLastEditedAndAction)
                  DataCell(
                    SizedBox(
                      width: 170,
                      child: Center(
                        child: Text(
                          formatDateTime(item['QALastEdit']?.toString()),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                if (showLastEditedAndAction)
                  DataCell(
                    SizedBox(
                      width: 90,
                      child: Center(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final SOPId = item['SOPId']?.toString() ?? '';
                            print("PASSING SOP: $SOPId");
                            final updated = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QAInEditEntry(SOPId: SOPId),
                              ),
                            );
                            if (updated == true) {
                              await GetQAInHistory();
                            }
                          },
                          icon: Center(
                            child: Icon(
                              Icons.edit,
                              size: 20,
                              color: Colors.black,
                            ),
                          ),
                          label: Text(
                            // "Edit Entry",
                            "",
                            // style: TextStyle(fontSize: 12, color: Colors.black),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.black),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            padding: EdgeInsets.symmetric(
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

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(),
      drawer: const CommonDrawer(),
      body: Container(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.center,
                child: Text(
                  "Update QA Out Date",
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
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Enter SOP Number',
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
                      borderSide: BorderSide(
                        color: const Color.fromARGB(255, 22, 129, 218),
                        width: 2,
                      ),
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                ),
              ),

              SizedBox(height: 10),

              SizedBox(
                // width: searchButtonWidth,
                child: SizedBox(
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () {
                      final rawInput = SOPController.text.trim();
                      final sopTokens = rawInput
                          .split(RegExp(r'[\s,]+'))
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toSet();

                      setState(() {
                        hasSearched = true;
                        searchedQaInHistory = sopTokens.isEmpty
                            ? <Map<String, dynamic>>[]
                            : QaInHistory.where((item) {
                                final sop = item['SOPNum']?.toString() ?? '';
                                return sopTokens.contains(sop);
                              }).toList();
                      });
                      HandleUpdateQAInDate();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 22, 129, 218),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.save, color: Colors.white),
                        SizedBox(width: 10),
                        Text(
                          "Update QA Out Date",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 10),

              if (hasSearched) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Searched SOP Data",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 8),
                searchedQaInHistory.isNotEmpty
                    ? buildTable(
                        searchedQaInHistory,
                        showLastEditedAndAction: false,
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          "No data found for searched SOP",
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ),
                SizedBox(height: 16),
              ],

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "SOP History",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 8),

              isLoading
                  ? SizedBox(
                      height: 220,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color.fromARGB(255, 57, 73, 95),
                        ),
                      ),
                    )
                  : buildTable(QaInHistory),

              SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
