import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/QAOut/Services/QAOutService.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class QAOutEditEntry extends StatefulWidget {
  final String SOPId;
  const QAOutEditEntry({super.key, required this.SOPId});
  @override
  _QAOutEditEntryState createState() => _QAOutEditEntryState();
}

class _QAOutEditEntryState extends State<QAOutEditEntry> {
  Map<String, dynamic> QAOutEditData = {};
  final QAOutService _service = const QAOutService();
  final SOPController = TextEditingController();
  bool isLoading = false;

  Future<void> GetQAOutSOPById() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await _service.QAOutSOPById(widget.SOPId);
      final data = response.data['data'];
      final firstRow = (data is List && data.isNotEmpty && data.first is Map)
          ? Map<String, dynamic>.from(data.first as Map)
          : <String, dynamic>{};
      setState(() {
        QAOutEditData = firstRow;
        SOPController.text = QAOutEditData['SOPNum']?.toString() ?? '';
      });
      print("QA Out SOP By ID Response: ${response.data['data']}");
    } catch (e) {
      print("Error fetching QA Out SOP by ID: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> HandleUpdateQAOutEntry() async {
    try {
      setState(() {
        isLoading = true;
      });
      final payload = {
        'sopId': int.tryParse(widget.SOPId) ?? widget.SOPId,
        'qaInDate': QAOutEditData['QCDateIn']?.toString() ?? '',
        'reworkOutDate': QAOutEditData['ReworkDateOut']?.toString() ?? '',
        'finalInDate': QAOutEditData['FinalDateReceivedInQC']?.toString() ?? '',
        'qaOutDate': QAOutEditData['QCOut']?.toString() ?? '',
        'qaComments': QAOutEditData['QAComments']?.toString() ?? '',
      };
      final response = await _service.UpdateQAOutEntry(payload);
      print("UPDATE QA OUT ENTRY RESPONSE: ${response.data['data']}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("QA Out entry updated successfully")),
      );
      Navigator.pop(context, true);
    } catch (e) {
      print("Error updating QA Out entry: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    GetQAOutSOPById();
  }

  Future<DateTime?> _pickDateWithStyledPicker(DateTime? initialDate) {
    const pickerAccent = Color.fromARGB(255, 57, 73, 95);
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: pickerAccent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              headerForegroundColor: Colors.black87,
              dayForegroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.white;
                }
                return null;
              }),
              dayBackgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return pickerAccent;
                }
                return null;
              }),
              todayForegroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.white;
                }
                return pickerAccent;
              }),
              todayBorder: const BorderSide(color: pickerAccent),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Widget _buildDateDisplay(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String formatDate(dynamic date) {
    if (date == null) return "-";
    try {
      String dateStr = date.toString();
      DateTime parsedDate = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(parsedDate);
    } catch (e) {
      return "";
    }
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
                width: 140,
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
          ],
          rows: QAOutEditData.isEmpty
              ? []
              : [
                  DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 90,
                          child: TextFormField(
                            controller: SOPController,
                            readOnly: true,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),

                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(
                                  color: Colors.grey,
                                ),
                              ),

                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            onChanged: (value) {
                              QAOutEditData['SOPNum'] = value;
                            },
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 70,
                          child: Center(
                            child: Text(
                              QAOutEditData['PoNum']?.toString() ?? '',
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
                              formatDate(QAOutEditData['ODD']?.toString()),
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
                              QAOutEditData['CustomerName']?.toString() ?? '',
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
                              QAOutEditData['ProgramName']?.toString() ?? '',
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
                              QAOutEditData['Location']?.toString() ?? '',
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
                            child: InkWell(
                              onTap: () async {
                                final pickedDate =
                                    await _pickDateWithStyledPicker(
                                      DateTime.tryParse(
                                        QAOutEditData['QCDateIn'] ?? '',
                                      ),
                                    );

                                if (pickedDate != null) {
                                  setState(() {
                                    QAOutEditData['QCDateIn'] = DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(pickedDate);
                                  });
                                }
                              },
                              child: _buildDateDisplay(
                                formatDate(
                                  QAOutEditData['QCDateIn']?.toString(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Center(
                            child: InkWell(
                              onTap: () async {
                                final pickedDate =
                                    await _pickDateWithStyledPicker(
                                      DateTime.tryParse(
                                        QAOutEditData['ReworkDateOut'] ?? '',
                                      ),
                                    );

                                if (pickedDate != null) {
                                  setState(() {
                                    QAOutEditData['ReworkDateOut'] = DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(pickedDate);
                                  });
                                }
                              },
                              child: _buildDateDisplay(
                                formatDate(
                                  QAOutEditData['ReworkDateOut']?.toString(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Center(
                            child: InkWell(
                              onTap: () async {
                                final pickedDate =
                                    await _pickDateWithStyledPicker(
                                      DateTime.tryParse(
                                        QAOutEditData['FinalDateReceivedInQC'] ??
                                            '',
                                      ),
                                    );

                                if (pickedDate != null) {
                                  setState(() {
                                    QAOutEditData['FinalDateReceivedInQC'] =
                                        DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(pickedDate);
                                  });
                                }
                              },
                              child: _buildDateDisplay(
                                formatDate(
                                  QAOutEditData['FinalDateReceivedInQC']
                                      ?.toString(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Center(
                            child: InkWell(
                              onTap: () async {
                                final pickedDate =
                                    await _pickDateWithStyledPicker(
                                      DateTime.tryParse(
                                        QAOutEditData['QCOut'] ?? '',
                                      ),
                                    );

                                if (pickedDate != null) {
                                  setState(() {
                                    QAOutEditData['QCOut'] = DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(pickedDate);
                                  });
                                }
                              },
                              child: _buildDateDisplay(
                                formatDate(QAOutEditData['QCOut']?.toString()),
                              ),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 140,
                          child: TextFormField(
                            initialValue:
                                QAOutEditData['QAComments']?.toString() ?? '',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),

                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(
                                  color: Colors.grey,
                                ),
                              ),

                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                QAOutEditData['QAComments'] = value;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
                  "Edit SOP",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              isLoading
                  ? SizedBox(
                      height: 220,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color.fromARGB(255, 57, 73, 95),
                        ),
                      ),
                    )
                  : buildTable(),

              SizedBox(height: 20),

              SizedBox(
                width: 200,
                height: 48,
                child: ElevatedButton(
                  onPressed: QAOutEditData.isEmpty
                      ? null
                      : () => HandleUpdateQAOutEntry(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF1565C0),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 8,
                    shadowColor: Colors.black.withOpacity(0.35),
                    surfaceTintColor: Colors.transparent,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Icon(
                                Icons.save,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Update Entry',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
