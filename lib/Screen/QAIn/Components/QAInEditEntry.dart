import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/QAIn/Services/QAInService.dart';
import 'package:overview_app/Utils/api_date.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/AppToast.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class QAInEditEntry extends StatefulWidget {
  final String SOPId;
  const QAInEditEntry({super.key, required this.SOPId});
  @override
  _QAInEditEntryState createState() => _QAInEditEntryState();
}

class _QAInEditEntryState extends State<QAInEditEntry> {
  Map<String, dynamic> QAInEditData = {};
  final QAInService _service = QAInService();
  bool isLoading = true;
  final SOPController = TextEditingController();

  Future<void> GetQAInSOPById() async {
    setState(() {
      isLoading = true;
      QAInEditData = {};
    });
    try {
      final response = await _service.QAInSOPById(widget.SOPId);
      if (!mounted) return;
      final data = response.data['data'];
      setState(() {
        QAInEditData = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
        SOPController.text = QAInEditData['SOPNum']?.toString() ?? '';
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        QAInEditData = {};
      });
      AppToast.error(context, 'Failed to load QA In entry');
    }
  }

  void handleUpdate() async {
    try {
      setState(() {
        isLoading = true;
      });
      final payload = {
        'sopId': widget.SOPId,
        'finalInDate': QAInEditData['FinalDateReceivedInQC']?.toString() ?? '',
        'qaComments': QAInEditData['QAComments']?.toString() ?? '',
        'qaInDate': QAInEditData['QCDateIn']?.toString() ?? '',
        'qaOutDate': QAInEditData['QCOut']?.toString() ?? '',
        'reworkOutDate': QAInEditData['ReworkDateOut']?.toString() ?? '',
      };
      // print("PAYLOAD OF QAIN EDIT : $payload");
      final resposne = await _service.UpdateQAInEntry(widget.SOPId, payload);
      print("RESPONSE OF QAIN EDIT : $resposne");
      await GetQAInSOPById();
      if (!mounted) return;
      AppToast.success(context, "Updated Successfully");
      Navigator.pop(context, true);
    } catch (e) {
      print('Error updating QA In entry: $e');
      if (mounted) {
        AppToast.error(context, 'Failed to update QA In entry');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  DateTime? _parseEditableDate(dynamic raw) => ApiDate.parse(raw);

  Future<DateTime?> _pickDateWithStyledPicker(DateTime? initialDate) {
    const pickerAccent = Color.fromARGB(255, 57, 73, 95);
    final firstDate = DateTime(2000);
    final lastDate = DateTime(2100);
    final now = DateTime.now();
    var safeInitial = initialDate ?? now;
    if (safeInitial.isBefore(firstDate)) safeInitial = now;
    if (safeInitial.isAfter(lastDate)) safeInitial = lastDate;

    return showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: lastDate,
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

  @override
  void initState() {
    super.initState();
    GetQAInSOPById();
  }

  String formatDate(dynamic date) => ApiDate.formatMmDdYyyy(date, empty: '-');

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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "SOP",
                    textAlign: TextAlign.left,
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "PO Num",
                    textAlign: TextAlign.left,
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "ODD",
                    textAlign: TextAlign.left,
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Customer",
                    textAlign: TextAlign.left,
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Prgm",
                    textAlign: TextAlign.left,
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Loc.",
                    textAlign: TextAlign.left,
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "QC In",
                    textAlign: TextAlign.left,
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "RW QC Out",
                    textAlign: TextAlign.left,
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Final Date Received In QC",
                    textAlign: TextAlign.left,
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "QC Out",
                    textAlign: TextAlign.left,
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Comments",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
          rows: QAInEditData.isEmpty
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
                            textAlign: TextAlign.left,
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
                              QAInEditData['SOPNum'] = value;
                            },
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 70,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              QAInEditData['PONum']?.toString() ?? '',
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 90,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatDate(QAInEditData['ODD']?.toString()),
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 260,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              QAInEditData['CustomerName']?.toString() ?? '',
                              textAlign: TextAlign.left,
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
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              QAInEditData['ProgramName']?.toString() ?? '',
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 90,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              QAInEditData['Location']?.toString() ?? '',
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),

                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              onTap: () async {
                                final pickedDate =
                                    await _pickDateWithStyledPicker(
                                      _parseEditableDate(
                                        QAInEditData['QCDateIn'],
                                      ),
                                    );

                                if (pickedDate != null) {
                                  setState(() {
                                    QAInEditData['QCDateIn'] = DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(pickedDate);
                                  });
                                }
                              },
                              child: _buildDateDisplay(
                                formatDate(
                                  QAInEditData['QCDateIn']?.toString(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              onTap: () async {
                                final pickedDate =
                                    await _pickDateWithStyledPicker(
                                      _parseEditableDate(
                                        QAInEditData['ReworkDateOut'],
                                      ),
                                    );

                                if (pickedDate != null) {
                                  setState(() {
                                    QAInEditData['ReworkDateOut'] = DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(pickedDate);
                                  });
                                }
                              },
                              child: _buildDateDisplay(
                                formatDate(
                                  QAInEditData['ReworkDateOut']?.toString(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              onTap: () async {
                                final pickedDate =
                                    await _pickDateWithStyledPicker(
                                      _parseEditableDate(
                                        QAInEditData['FinalDateReceivedInQC'],
                                      ),
                                    );

                                if (pickedDate != null) {
                                  setState(() {
                                    QAInEditData['FinalDateReceivedInQC'] =
                                        DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(pickedDate);
                                  });
                                }
                              },
                              child: _buildDateDisplay(
                                formatDate(
                                  QAInEditData['FinalDateReceivedInQC']
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
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              onTap: () async {
                                final pickedDate =
                                    await _pickDateWithStyledPicker(
                                      _parseEditableDate(
                                        QAInEditData['QCOut'],
                                      ),
                                    );

                                if (pickedDate != null) {
                                  setState(() {
                                    QAInEditData['QCOut'] = DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(pickedDate);
                                  });
                                }
                              },
                              child: _buildDateDisplay(
                                formatDate(QAInEditData['QCOut']?.toString()),
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
                                QAInEditData['QAComments']?.toString() ?? '',
                            textAlign: TextAlign.left,
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
                                QAInEditData['QAComments'] = value;
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

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(showBackButton: true),
      drawer: const CommonDrawer(),
      body: isLoading
          ? const Center(child: AppLoader())
          : Container(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Align(
                alignment: Alignment.center,
                child: Text(
                  "Edit QA SOP",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // if (isLoading)
              //   const SizedBox(
              //     height: 280,
              //     child: Center(child: AppLoader()),
              //   )
              // else ...[
                buildTable(),
                const SizedBox(height: 20),
                SizedBox(
                  width: 200,
                  height: 48,
                  child: ElevatedButton(
                    onPressed:
                        QAInEditData.isEmpty ? null : () => handleUpdate(),
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
            // ],
          ),
        ),
      ),
    );
  }
}
