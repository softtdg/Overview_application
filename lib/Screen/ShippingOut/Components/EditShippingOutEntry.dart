import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/ShippingOut/Services/ShippingOutServices.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class EditShippingOutEntry extends StatefulWidget {
  final String SOPId;
  EditShippingOutEntry({required this.SOPId});

  @override
  _EditShippingOutEntryState createState() => _EditShippingOutEntryState();
}

class _EditShippingOutEntryState extends State<EditShippingOutEntry> {
  List<Map<String, dynamic>> SOPByIdData = [];
  final ShippingOutService _service = ShippingOutService();
  final SOPController = TextEditingController();
  final POController = TextEditingController();
  final ODDController = TextEditingController();
  final CustomerController = TextEditingController();
  final ProgramController = TextEditingController();
  final LocationController = TextEditingController();
  final SOPEntryDateInController = TextEditingController();
  final SOPOrderEntryOutController = TextEditingController();
  final ProdMgrController = TextEditingController();
  final FinalDeliveryDateController = TextEditingController();
  final CommentsController = TextEditingController();
  List<String> locations = [];
  List<Map<String, dynamic>> locationOptions = [];
  String? selectedLocation;
  List<String> prodMgrs = [];
  List<Map<String, dynamic>> prodMgrOptions = [];
  String? selectedProdMgr;
  bool isLoading = true;

  Future<void> GetSOPById() async {
    await Dioservices.setToken();
    setState(() {
      isLoading = true;
    });
    try {
      final response = await _service.SOPById(widget.SOPId);
      final data = response.data['data'];
      setState(() {
        SOPByIdData = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
      debugPrint("SOP by ID data: $SOPByIdData");
    } catch (e) {
      debugPrint("Error fetching SOP by ID: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> GetLocations() async {
    await Dioservices.setToken();
    setState(() {
      isLoading = true;
    });
    try {
      final response = await _service.Locations();
      setState(() {
        locationOptions = List<Map<String, dynamic>>.from(
          response.data['data'],
        );
        locations = List<String>.from(
          (response.data['data'] as List)
              .map((e) => (e['Location'] ?? '').toString())
              .where((e) => e.isNotEmpty),
        );
        for (final item in SOPByIdData) {
          if (item['SOPLocationId'] == null && item['Location'] != null) {
            final selected = locationOptions.firstWhere(
              (e) => e['Location']?.toString() == item['Location']?.toString(),
              orElse: () => <String, dynamic>{},
            );
            if (selected.isNotEmpty) {
              item['SOPLocationId'] = selected['SOPLocationId'];
            }
          }
        }
      });
      debugPrint("Locations data: ${response.data['data']}");
    } catch (e) {
      debugPrint("Error fetching locations: $e");
    }
  }

  Future<void> GetProgMgr() async {
    await Dioservices.setToken();
    setState(() {
      isLoading = true;
    });
    try {
      final response = await _service.ProdMgr();
      final data = response.data['data'];
      setState(() {
        isLoading = false;
        prodMgrOptions = List<Map<String, dynamic>>.from(data);
        prodMgrs = List<String>.from(
          (data as List)
              .map((e) => (e['Name'] ?? '').toString())
              .where((e) => e.isNotEmpty),
        );
        for (final item in SOPByIdData) {
          if (item['SOPProductionManagerId'] == null &&
              item['prodMgr'] != null) {
            final selected = prodMgrOptions.firstWhere(
              (e) => e['Name']?.toString() == item['prodMgr']?.toString(),
              orElse: () => <String, dynamic>{},
            );
            if (selected.isNotEmpty) {
              item['SOPProductionManagerId'] =
                  selected['SOPProductionManagerId'];
            }
          }
        }
      });
      debugPrint("Prod Mgr data: $data");
    } catch (e) {
      debugPrint("Error fetching Prod Mgr: $e");
    }
  }

  void handleUpdateShippingOut(Map<String, dynamic> item) async {
    try {
      setState(() {
        isLoading = true;
      });

      if (item['SOPLocationId'] == null && item['Location'] != null) {
        final selected = locationOptions.firstWhere(
          (e) => e['Location']?.toString() == item['Location']?.toString(),
          orElse: () => <String, dynamic>{},
        );
        if (selected.isNotEmpty) {
          item['SOPLocationId'] = selected['SOPLocationId'];
        }
      }

      if (item['SOPProductionManagerId'] == null && item['prodMgr'] != null) {
        final selected = prodMgrOptions.firstWhere(
          (e) => e['Name']?.toString() == item['prodMgr']?.toString(),
          orElse: () => <String, dynamic>{},
        );
        if (selected.isNotEmpty) {
          item['SOPProductionManagerId'] = selected['SOPProductionManagerId'];
        }
      }

      if (item['SOPLocationId'] == null ||
          (item['Location']?.toString().trim().isEmpty ?? true)) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Please select a valid location",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final payload = {
        "FinalDeliveryDate": item['FinalDeliveryDate'],
        "Location": item['Location'],
        "ODD": item['ODD'],
        "OrderEntryComments": item['OrderEntryComments'],
        "PONum": item['PONum'],
        "SOPEntryDateIn": item['SOPEntryDateIn'],
        "SOPLocationId": item['SOPLocationId'],
        "SOPNum": item['SOPNum'],
        "SOPOrderEntryOut": item['SOPOrderEntryOut'],
        "SOPProductionManagerId": item['SOPProductionManagerId'],
        "Customer": item['customer'],
        "prodMgr": item['prodMgr'],
        "Program": item['program'],
      };
      final resposne = await _service.UpdateShippingOut(widget.SOPId, payload);
      debugPrint("Update shipping out response: ${resposne.data}");
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Shipping out updated successfully",
            style: TextStyle(color: Colors.white),
          ),
          // backgroundColor: const Color.fromARGB(255, 40, 137, 38),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error updating shipping out: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    GetSOPById();
    GetLocations();
    GetProgMgr();
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
      debugPrint("Date parse error: $e");
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
                width: 120,
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
                width: 150,
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
                width: 150,
                child: Center(
                  child: Text(
                    "PROD MGR",
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
            DataColumn(
              label: SizedBox(
                width: 140,
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
                width: 140,
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
          ],
          rows: SOPByIdData.map((item) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      initialValue: item['SOPNum']?.toString() ?? '',
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
                          borderSide: const BorderSide(color: Colors.grey),
                        ),

                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          item['SOPNum'] = value;
                        });
                      },
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      initialValue: item['PONum']?.toString() ?? '',
                      textAlign: TextAlign.center,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),

                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),

                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          item['PONum'] = value;
                        });
                      },
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 140,
                    child: Center(
                      child: InkWell(
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
                              const Icon(Icons.calendar_month, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                formatDate(item['ODD']?.toString()),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.tryParse(item['ODD'] ?? '') ??
                                DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              item['ODD'] = DateFormat(
                                'yyyy-MM-dd',
                              ).format(pickedDate);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 260,
                    child: TextFormField(
                      initialValue: item['customer']?.toString() ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),

                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),

                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          item['customer'] = value;
                        });
                      },
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      initialValue: item['program']?.toString() ?? '',
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
                          borderSide: const BorderSide(color: Colors.grey),
                        ),

                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          item['program'] = value;
                        });
                      },
                    ),
                  ),
                ),
                // DataCell(
                //   SizedBox(
                //     width: 90,
                //     child: Center(
                //       child: Text(
                //         item['Location']?.toString() ?? '',
                //         textAlign: TextAlign.center,
                //         style: TextStyle(fontSize: 12),
                //       ),
                //     ),
                //   ),
                // ),
                DataCell(
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      value: locations.contains(item['Location']?.toString())
                          ? item['Location']?.toString()
                          : null,
                      hint: const Text(
                        'Select Location',
                        style: TextStyle(fontSize: 12),
                      ),
                      dropdownColor: Colors.white,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 22, 129, 218),
                            width: 2,
                          ),
                        ),
                      ),
                      items: locations.map((location) {
                        return DropdownMenuItem<String>(
                          value: location,
                          child: Text(location, style: TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          item['Location'] = value ?? '';
                          final selected = locationOptions.firstWhere(
                            (e) => e['Location']?.toString() == value,
                            orElse: () => <String, dynamic>{},
                          );
                          if (selected.isNotEmpty) {
                            item['SOPLocationId'] = selected['SOPLocationId'];
                          }
                        });
                      },
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 140,
                    child: Center(
                      child: InkWell(
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
                              const Icon(Icons.calendar_month, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                formatDate(item['SOPEntryDateIn']?.toString()),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.tryParse(
                                  item['SOPEntryDateIn'] ?? '',
                                ) ??
                                DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );

                          if (pickedDate != null) {
                            setState(() {
                              item['SOPEntryDateIn'] = DateFormat(
                                'yyyy-MM-dd',
                              ).format(pickedDate);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 140,
                    child: Center(
                      child: InkWell(
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
                              const Icon(Icons.calendar_month, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                formatDate(
                                  item['SOPOrderEntryOut']?.toString(),
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.tryParse(
                                  item['SOPOrderEntryOut'] ?? '',
                                ) ??
                                DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );

                          if (pickedDate != null) {
                            setState(() {
                              item['SOPOrderEntryOut'] = DateFormat(
                                'yyyy-MM-dd',
                              ).format(pickedDate);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      value: prodMgrs.contains(item['prodMgr']?.toString())
                          ? item['prodMgr']?.toString()
                          : null,
                      hint: const Text(
                        'Select Manager',
                        style: TextStyle(fontSize: 12),
                      ),
                      dropdownColor: Colors.white,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 22, 129, 218),
                            width: 2,
                          ),
                        ),
                      ),
                      items: prodMgrs.map((mgr) {
                        return DropdownMenuItem<String>(
                          value: mgr,
                          child: Text(mgr, style: TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          item['prodMgr'] = value ?? '';
                          final selected = prodMgrOptions.firstWhere(
                            (e) => e['Name']?.toString() == value,
                            orElse: () => <String, dynamic>{},
                          );
                          if (selected.isNotEmpty) {
                            item['SOPProductionManagerId'] =
                                selected['SOPProductionManagerId'];
                          }
                        });
                      },
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 140,
                    child: Center(
                      child: InkWell(
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
                              const Icon(Icons.calendar_month, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                formatDate(
                                  item['FinalDeliveryDate']?.toString(),
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.tryParse(
                                  item['FinalDeliveryDate'] ?? '',
                                ) ??
                                DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );

                          if (pickedDate != null) {
                            setState(() {
                              item['FinalDeliveryDate'] = DateFormat(
                                'yyyy-MM-dd',
                              ).format(pickedDate);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      initialValue:
                          item['OrderEntryComments']?.toString() ?? '',
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
                          borderSide: const BorderSide(color: Colors.grey),
                        ),

                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          item['OrderEntryComments'] = value;
                        });
                      },
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
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Align(
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

              SizedBox(height: 20),

              buildTable(),

              SizedBox(height: 20),

              SizedBox(
                width: 200,
                height: 48,
                child: ElevatedButton(
                  onPressed: SOPByIdData.isEmpty
                      ? null
                      : () => handleUpdateShippingOut(SOPByIdData.first),
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
