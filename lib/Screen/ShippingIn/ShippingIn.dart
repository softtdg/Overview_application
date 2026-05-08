import 'package:flutter/material.dart';
import 'package:overview_app/Screen/ShippingIn/Compomnents/EditShippingInEntry.dart';
import 'package:overview_app/Screen/ShippingIn/Services/ShippingInService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:intl/intl.dart';

class ShippingIn extends StatefulWidget {
  @override
  _ShippingInState createState() => _ShippingInState();
}

class _ShippingInState extends State<ShippingIn> {
  final TextEditingController SOPController = TextEditingController();
  final ShippingInService _service = ShippingInService();
  List<Map<String, dynamic>> shippingInHistory = [];
  String username = '';
  bool isLoading = false;

  Future<void> GetShippingInHistory() async {
    await Dioservices.setToken();
    setState(() {
      isLoading = true;
    });
    try {
      final response = await _service.ShippingInHistory();
      final data = response.data["data"];
      setState(() {
        shippingInHistory = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
      debugPrint("SHIPPING IN HISTORY DATA: $data");
    } catch (e) {
      print("Error while fetch shipping in data $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override  
  void initState() {
    super.initState();
    GetShippingInHistory();
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

  void handleEditShippingInDate() async {
    try {
      setState(() {
        isLoading = true;
      });
      await _service.EditShippingInDate(SOPController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Shipping in date updated successfully")),
      );
      await GetShippingInHistory();
    } catch (e) {
      print("Error while editing shipping in date $e");
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error while editing shipping in date $e")),
      );
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
          rows: shippingInHistory.map((item) {
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
                                  EditShippingInEntry(sopNumber: sopNumber),
                            ),
                          );
                          if (updated == true) {
                            await GetShippingInHistory();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(),
      drawer: CommonDrawer(),
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.center,
                child: Text(
                  "Update Shipping In Date",
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
                    onPressed: () => handleEditShippingInDate(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 57, 73, 95),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Update SOP Shipping In Date",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 10),

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

              SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
