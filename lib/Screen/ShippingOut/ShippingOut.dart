import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/ShippingOut/Services/ShippingOutServices.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class ShippingOut extends StatefulWidget {
  @override
  _ShippingOutState createState() => _ShippingOutState();
}

class _ShippingOutState extends State<ShippingOut> {
  final TextEditingController SOPController = TextEditingController();
  final ShippingOutService _service = ShippingOutService();
  List<Map<String,dynamic>> ShippingOutHistory = [];
  bool isLoading = false;

  Future<void> GetShippingOutHistory() async{
    await Dioservices.setToken();
    setState(() {
      isLoading = true;
    });
    try{
      final response = await _service.ShippingOutHistory();
      final data = response.data["data"];
      setState(() {
        ShippingOutHistory = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
      debugPrint("SHIPPING OUT DATA $data");
    } catch (e) {
      print("Error while feth data for shipping out $e");
    }
  }

  void handleSOPs() async {
    try{
      setState(() {
        isLoading = true;
      });
      await _service.EditSOPNums(SOPController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ShippingOut Date Updated Successfully"))
      );
      await GetShippingOutHistory();
    } catch(e) {
      print("Error in shipping out while update shipping out date");
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Something went wrong")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    GetShippingOutHistory();
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
      print("Date parse error: $e");
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
                    "SOP Entry",
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
                width: 75,
                child: Center(
                  child: Text(
                    "SOP Out",
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
                width: 60,
                child: Center(
                  child: Text(
                    "PROD MGR",
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
                    "Delivery Date",
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
                width: 110,
                child: Center(
                  child: Text(
                    "New Comments",
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
                width: 60,
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
          rows: ShippingOutHistory.map((item) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 60,
                    child: Center(
                      child: Text(
                        item['SOPNum']?.toString() ?? '-',
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
                        item['PONum']?.toString() ?? '-',
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
                        formatDate(item['ODD']?.toString() ?? '-'),
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
                        item['customer']?.toString() ?? '-',
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
                        item['program']?.toString() ?? '-',
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
                        item['Location']?.toString() ?? '-',
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
                        formatDate(item['SOPEntryDateIn']?.toString() ?? '-'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 75,
                    child: Center(
                      child: Text(
                        formatDate(item['SOPOrderEntryOut']?.toString() ?? '-'),
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
                        item['prodMgr']?.toString() ?? '-',
                        textAlign: TextAlign.center,
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
                        formatDate(item['FinalDeliveryDate']?.toString() ?? '-'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),

                DataCell(
                  SizedBox(
                    width: 110,
                    child: Center(
                      child: Text(
                        item['OrderEntryComments']?.toString() ?? '-',
                        textAlign: TextAlign.center,
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
                        formatDateTime(item['LastEdit']?.toString() ?? '-'),
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
                          final sopNumber = item['sopNum']?.toString() ?? '-';
                          print("PASSING SOP: $sopNumber");
                          // final updated = await Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (_) =>
                          //         EditShippingInEntry(sopNumber: sopNumber),
                          //   ),
                          // );
                          // if (updated == true) {
                          //   await GetShippingInHistory();
                          // }
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
                  "Update SOP Shipping Out Date",
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
                    onPressed: () => handleSOPs(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 57, 73, 95),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Update SOP Shipping Out Date",
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
