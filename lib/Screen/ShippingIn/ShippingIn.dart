import 'package:data_table_2/data_table_2.dart';
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

  double _tableRowHeight(String customer) {
    const minHeight = 72.0;
    final lines = customer.isEmpty ? 1 : (customer.length / 34).ceil();
    return lines <= 1 ? minHeight : (16.0 * lines) + 24.0;
  }

  Widget buildTable() {
    return DataTable2(
      fixedTopRows: 1,
      headingRowColor: MaterialStateProperty.all(
        Color.fromARGB(255, 57, 73, 95),
      ),
      horizontalMargin: 20,
      columnSpacing: 20,
      minWidth: 1070,
      border: TableBorder.all(color: Colors.grey, width: 1),
      columns: const [
        DataColumn2(
          minWidth: 60,
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
        DataColumn2(
          minWidth: 70,
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
        DataColumn2(
          minWidth: 90,
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
        DataColumn2(
          minWidth: 260,
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
        DataColumn2(
          minWidth: 100,
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
        DataColumn2(
          minWidth: 90,
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
        DataColumn2(
          minWidth: 140,
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
        DataColumn2(
          minWidth: 170,
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
        DataColumn2(
          minWidth: 90,
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
        final customer = item['customer']?.toString() ?? '';
        return DataRow2(
          specificRowHeight: _tableRowHeight(customer),
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
                    customer,
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
                      icon: const Icon(Icons.edit, size: 20, color: Colors.black),
                      label: const Text(''),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 700;
    final sopField = TextField(
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
          borderSide: const BorderSide(color: Colors.grey, width: 1),
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
    );
    final updateButton = SizedBox(
      height: 45,
      child: ElevatedButton(
        onPressed: handleEditShippingInDate,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF1565C0),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Update SOP Shipping In Date',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(),
      drawer: CommonDrawer(),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (isTablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Update Shipping In Date',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: sopField),
                  const SizedBox(width: 16),
                  updateButton,
                ],
              )
            else
              Column(
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Update Shipping In Date',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  sopField,
                  const SizedBox(height: 10),
                  updateButton,
                ],
              ),
            const SizedBox(height: 10),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color.fromARGB(255, 57, 73, 95),
                      ),
                    )
                  : buildTable(),
            ),
          ],
        ),
      ),
    );
  }
}
