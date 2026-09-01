import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/ShippingEdit/Services/ShippingEditEntryService.dart';
import 'package:overview_app/Screen/ShippingIn/Services/ShippingInService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/AppToast.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class ShippingEditEntry extends StatefulWidget {
  final dynamic sopNumber;
  const ShippingEditEntry({Key? key, required this.sopNumber})
    : super(key: key);
  @override
  _ShippingEditEntryState createState() => _ShippingEditEntryState();
}

class _ShippingEditEntryState extends State<ShippingEditEntry> {
  final ShippingEditEntryService _service = ShippingEditEntryService();
  final ShippingInService _shippingInService = ShippingInService();
  List<Map<String, dynamic>> searchResults = [];
  bool isLoading = false;

  Future<void> GetSOPSearchData() async {
    await Dioservices.setToken();
    setState(() {
      isLoading = true;
    });
    try {
      final response = await _service.ShippingSearchSOP(
        widget.sopNumber.toString(),
      );
      final data = response.data["data"];
      setState(() {
        searchResults = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
      // debugPrint("SEARCH DATA FROM EDIT ENTRY SHIPPING IN $data");
    } catch (e) {
      debugPrint("Error occur while edit in Edit ShippingIn Entry $e");
      setState(() {
        isLoading = false;
      });
    }
    // debugPrint("SOP NUMBER IN EDIT SHIPPING IN ENTRY ${widget.sopNumber}");
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
    if (_isEmptyShippingDate(date)) return 'mm-dd-yyyy';
    try {
      final parsedDate = DateTime.parse(date.toString());
      return DateFormat('MM/dd/yyyy').format(parsedDate);
    } catch (e) {
      print("Date parse error: $e");
      return 'mm-dd-yyyy';
    }
  }

  DateTime _initialPickerDate(dynamic date) {
    if (_isEmptyShippingDate(date)) return DateTime.now();
    final parsed = DateTime.tryParse(date.toString());
    if (parsed == null || parsed.year < 2000) return DateTime.now();
    return parsed;
  }

  void handleShippingEditDate() async {
    try {
      setState(() {
        isLoading = true;
      });
      final fromQADate = searchResults.first['shippingDateIn']
          .toString()
          .split('T')
          .first;
      await _shippingInService.EditDate(
        widget.sopNumber.toString(),
        fromQADate,
      );
      AppToast.success(context, "Update Successfully");
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error in Edit Shipping in date $e");
      if (mounted) {
        AppToast.error(context, "Update failed");
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
                          "Ship In",
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
                rows: searchResults.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 60,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              item['sopNum']?.toString() ?? '',
                              textAlign: TextAlign.left,
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 70,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              item['poNum']?.toString() ?? '',
                              textAlign: TextAlign.left,
                              style: TextStyle(fontSize: 12),
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
                              formatDate(item['odd']?.toString()),
                              textAlign: TextAlign.left,
                              style: TextStyle(fontSize: 12),
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
                              item['customer']?.toString() ?? '',
                              textAlign: TextAlign.left,
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
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              item['program']?.toString() ?? '',
                              textAlign: TextAlign.left,
                              style: TextStyle(fontSize: 12),
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
                              item['location']?.toString() ?? '',
                              textAlign: TextAlign.left,
                              style: TextStyle(fontSize: 12),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.calendar_month,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(showBackButton: true),
      drawer: const CommonDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
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
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: AppLoader()),
                )
              else if (searchResults.isNotEmpty) ...[
                buildTable(),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 200,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: handleShippingEditDate,
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
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
