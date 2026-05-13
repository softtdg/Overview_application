import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/ShippingIn/Services/ShippingInService.dart';
import 'package:overview_app/Services/DioServices.dart';
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
  bool isLoading = false;

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
      debugPrint("SEARCH DATA FROM EDIT ENTRY SHIPPING IN $data");
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

  String formatDate(dynamic date) {
    if (date == null) return "-";
    try {
      String dateStr = date.toString();
      if (dateStr.startsWith("0001-01-01")) {
        return "*";
      }
      DateTime parsedDate = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(parsedDate);
    } catch (e) {
      print("Date parse error: $e");
      return "";
    }
  }

  void handleShippingInDate() async {
    try {
      setState(() {
        isLoading = true;
      });
      final fromQADate = searchResults.first['shippingDateIn']
          .toString()
          .split('T')
          .first;
      await _service.EditDate(widget.sopNumber.toString(), fromQADate);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Update Successfully")));
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error in Edit Shipping in date $e");
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
                width: 140,
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
                    width: 140,
                    child: Center(
                      child: InkWell(
                        onTap: () async {
                          const pickerAccent = Color.fromARGB(255, 57, 73, 95);
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: item['shippingDateIn'] != null
                                ? DateTime.tryParse(item['shippingDateIn'])
                                : DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme
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
                                        MaterialStateProperty.resolveWith((
                                          states,
                                        ) {
                                          if (states.contains(
                                            MaterialState.selected,
                                          )) {
                                            return Colors.white;
                                          }
                                          return null;
                                        }),
                                    dayBackgroundColor:
                                        MaterialStateProperty.resolveWith((
                                          states,
                                        ) {
                                          if (states.contains(
                                            MaterialState.selected,
                                          )) {
                                            return pickerAccent;
                                          }
                                          return null;
                                        }),
                                    todayForegroundColor:
                                        MaterialStateProperty.resolveWith((
                                          states,
                                        ) {
                                          if (states.contains(
                                            MaterialState.selected,
                                          )) {
                                            return Colors.white;
                                          }
                                          return pickerAccent;
                                        }),
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_month,
                                size: 16,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 4),
                              Text(
                                formatDate(item['shippingDateIn']?.toString()),
                                style: TextStyle(fontSize: 12),
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
      appBar: const CommonAppBar(),
      drawer: const CommonDrawer(),
      body: SingleChildScrollView(
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
            buildTable(),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 200,
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading ? null : handleShippingInDate,
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
            ),
          ],
        ),
      ),
    );
  }
}
