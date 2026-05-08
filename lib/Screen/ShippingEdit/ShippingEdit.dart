import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/ShippingEdit/Components/ShippingEditEntry.dart';
import 'package:overview_app/Screen/ShippingIn/Services/ShippingInService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class ShippingEdit extends StatefulWidget {
  @override
  _ShippingEditState createState() => _ShippingEditState();
}

class _ShippingEditState extends State<ShippingEdit> {
  final ShippingInService _service = ShippingInService();
  final SOPController = TextEditingController();
  List<Map<String, dynamic>> shippingEditHistory = [];
  bool isLoading = false;

  Future<void> GetShippingEditHistory() async {
    await Dioservices.setToken();
    setState(() {
      isLoading = true;
    });
    try {
      final response = await _service.ShippingInHistory();
      final data = response.data["data"];
      setState(() {
        shippingEditHistory = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
      // debugPrint("SHIPPING EDIT HISTORY DATA: $data");
    } catch (e) {
      print("Error while fetch shipping edit data $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    GetShippingEditHistory();
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
      print("DateTime parse error: $e");
      return "-";
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
            DataColumn(
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
          rows: shippingEditHistory.map((item) {
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
                    width: 80,
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
                      child: Text(
                        formatDate(item['shippingDateIn']?.toString()),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 170,
                    child: Center(
                      child: Text(
                        formatDateTime(item['lastEditedOn']?.toString()),
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
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final sopNumber = item['sopNum']?.toString() ?? '';
                          print("PASSING SOP: $sopNumber");
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ShippingEditEntry(sopNumber: sopNumber),
                            ),
                          );
                          if (updated == true) {
                            await GetShippingEditHistory();
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
                          minimumSize: const Size(0, 0),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.center,
                child: Text(
                  "Search SOP to Shipping Edit",
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
                      borderSide: const BorderSide(
                        color: Colors.grey,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color.fromARGB(255, 22, 129, 218),
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
                    onPressed: () async {
                      final sopNumber = SOPController.text.trim();
                      if (sopNumber.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter SOP number',
                              style: TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      print("Searching for SOP: $sopNumber");
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ShippingEditEntry(sopNumber: sopNumber),
                        ),
                      );
                      if (updated == true) {
                        await GetShippingEditHistory();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 22, 129, 218),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, color: Colors.white),
                        SizedBox(width: 10),
                        Text(
                          "Search for Entry",
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

              isLoading
                  ? const SizedBox(
                      height: 220,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color.fromARGB(255, 57, 73, 95),
                        ),
                      ),
                    )
                  : buildTable(),

              SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
