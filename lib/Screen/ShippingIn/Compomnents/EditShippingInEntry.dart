import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/ShippingIn/Services/ShippingInService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class EditShippingInEntry extends StatefulWidget {
  final dynamic sopNumber;
  final String? fromQADate;
  const EditShippingInEntry({
    Key? key,
    required this.sopNumber,
    this.fromQADate,
  }) : super(key: key);
  @override
  _EditShippingInEntryState createState() => _EditShippingInEntryState();
}

class _EditShippingInEntryState extends State<EditShippingInEntry> {
  final ShippingInService _service = ShippingInService();
  List<Map<String, dynamic>> searchResults = [];
  bool isLoading = true;
  bool isUpdating = false;

  Future<void> GetSOPSearchData() async {
    await Dioservices.setToken();
    setState(() {
      isLoading = true;
    });
    try {
      final response = await _service.SearchShippingIn(widget.sopNumber);
      final data = response.data["data"];
      setState(() {
        searchResults = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error occur while edit in Edit ShippingIn Entry $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    GetSOPSearchData();
  }

  bool _isEmptyShippingDate(dynamic date) {
    if (date == null) return true;
    final dateStr = date.toString().trim();
    if (dateStr.isEmpty || dateStr.toLowerCase() == 'null') return true;
    return dateStr.startsWith('0001-01-01');
  }

  String formatDate(dynamic date) {
    if (_isEmptyShippingDate(date)) return "dd - mm - yyyy";
    try {
      final parsedDate = DateTime.parse(date.toString());
      return DateFormat('dd/MM/yyyy').format(parsedDate);
    } catch (e) {
      print("Date parse error: $e");
      return "dd - mm - yyyy";
    }
  }

  DateTime _initialPickerDate(dynamic date) {
    if (_isEmptyShippingDate(date)) return DateTime.now();
    return DateTime.tryParse(date.toString()) ?? DateTime.now();
  }

  void handleShippingInDate() async {
    if (searchResults.isEmpty || isUpdating) return;
    try {
      setState(() {
        isUpdating = true;
      });
      final fromQADate = searchResults.first['shippingDateIn']
          .toString()
          .split('T')
          .first;
      await _service.EditDate(widget.sopNumber.toString(), fromQADate);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Update Successfully")));
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error in Edit Shipping in date $e");
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  Widget buildTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
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
                      width: 160,
                      child: Center(
                        child: Text(
                          "Ship In",
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
                rows: searchResults.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 60,
                          child: Center(
                            child: Text(
                              item['sopNum']?.toString() ?? '',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 70,
                          child: Center(
                            child: Text(
                              item['poNum']?.toString() ?? '',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 90,
                          child: Center(
                            child: Text(
                              formatDate(item['odd']?.toString()),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 260,
                          child: Center(
                            child: Text(
                              item['customer']?.toString() ?? '',
                              textAlign: TextAlign.center,
                              softWrap: true,
                              maxLines: null,
                              overflow: TextOverflow.visible,
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 100,
                          child: Center(
                            child: Text(
                              item['program']?.toString() ?? '',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 90,
                          child: Center(
                            child: Text(
                              item['location']?.toString() ?? '',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 160,
                          child: Center(
                            child: InkWell(
                              onTap: () async {
                                const pickerAccent = Color.fromARGB(
                                  255,
                                  57,
                                  73,
                                  95,
                                );
                                DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: _initialPickerDate(
                                    item['shippingDateIn'],
                                  ),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: Theme.of(context)
                                            .colorScheme
                                            .copyWith(
                                              primary: pickerAccent,
                                              onPrimary: Colors.white,
                                              surface: Colors.white,
                                              onSurface: Colors.black87,
                                            ),
                                        datePickerTheme: DatePickerThemeData(
                                          backgroundColor: Colors.white,
                                          surfaceTintColor: Colors.transparent,
                                          headerForegroundColor: Colors.black87,
                                          dayForegroundColor:
                                              MaterialStateProperty.resolveWith(
                                                (states) {
                                                  if (states.contains(
                                                    MaterialState.selected,
                                                  )) {
                                                    return Colors.white;
                                                  }
                                                  return null;
                                                },
                                              ),
                                          dayBackgroundColor:
                                              MaterialStateProperty.resolveWith(
                                                (states) {
                                                  if (states.contains(
                                                    MaterialState.selected,
                                                  )) {
                                                    return pickerAccent;
                                                  }
                                                  return null;
                                                },
                                              ),
                                          todayForegroundColor:
                                              MaterialStateProperty.resolveWith(
                                                (states) {
                                                  if (states.contains(
                                                    MaterialState.selected,
                                                  )) {
                                                    return Colors.white;
                                                  }
                                                  return pickerAccent;
                                                },
                                              ),
                                          todayBorder: const BorderSide(
                                            color: pickerAccent,
                                          ),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );

                                if (pickedDate != null) {
                                  setState(() {
                                    item['shippingDateIn'] = pickedDate
                                        .toIso8601String();
                                  });
                                }
                              },
                              child: Container(
                                width: 150,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        formatDate(item['shippingDateIn']),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              _isEmptyShippingDate(
                                                item['shippingDateIn'],
                                              )
                                              ? Colors.grey.shade700
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 16,
                                      color: Colors.black87,
                                    ),
                                  ],
                                ),
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTableData = !isLoading && searchResults.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(showBackButton: true),
      drawer: const CommonDrawer(),
      body: isLoading
          ? const Center(child: AppLoader())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: Text(
                      "Edit Shipping Entry",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (hasTableData) ...[
                    buildTable(),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 200,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isUpdating ? null : handleShippingInDate,
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
                          child: isUpdating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
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
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(
                          "No shipping entry data found",
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
