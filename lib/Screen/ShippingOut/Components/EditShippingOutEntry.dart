import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/ShippingOut/Components/ShippingOutTable.dart';
import 'package:overview_app/Screen/ShippingOut/Services/ShippingOutServices.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/AppToast.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class EditShippingOutEntry extends StatefulWidget {
  final String SOPId;
  EditShippingOutEntry({required this.SOPId});

  @override
  _EditShippingOutEntryState createState() => _EditShippingOutEntryState();
}

class _EditShippingOutEntryState extends State<EditShippingOutEntry> {
  List<Map<String, dynamic>> SOPByIdData = [];
  List<Map<String, dynamic>> ShippingOutHistory = [];
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
  bool isHistoryLoading = true;

  Future<void> GetSOPById() async {
    await Dioservices.setToken();
    try {
      final response = await _service.SOPById(widget.SOPId);
      final data = response.data['data'];
      if (!mounted) return;
      SOPByIdData = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("Error fetching SOP by ID: $e");
    }
  }

  Future<void> GetLocations() async {
    await Dioservices.setToken();
    try {
      final response = await _service.Locations();
      if (!mounted) return;
      locationOptions = List<Map<String, dynamic>>.from(
        response.data['data'],
      );
      locations = locationOptions
          .map(_optionLocationName)
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint("Error fetching locations: $e");
    }
  }

  Future<void> GetProgMgr() async {
    await Dioservices.setToken();
    try {
      final response = await _service.ProdMgr();
      final data = response.data['data'];
      if (!mounted) return;
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
    } catch (e) {
      debugPrint("Error fetching Prod Mgr: $e");
    }
  }

  Future<void> GetShippingOutHistory() async {
    await Dioservices.setToken();
    try {
      final response = await _service.ShippingOutHistory();
      final data = response.data['data'];
      if (!mounted) return;
      setState(() {
        ShippingOutHistory = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint("Error fetching shipping out history: $e");
    }
  }

  Future<void> _loadPage() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      isHistoryLoading = true;
    });
    try {
      await Future.wait([
        GetSOPById(),
        GetLocations(),
        GetProgMgr(),
        GetShippingOutHistory(),
      ]);
      if (!mounted) return;
      _syncLocationsOntoItems();
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
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isHistoryLoading = false;
        });
      }
    }
  }

  void handleUpdateShippingOut(Map<String, dynamic> item) async {
    try {
      setState(() {
        isLoading = true;
      });

      if (item['SOPLocationId'] == null &&
          _itemLocationName(item).isNotEmpty) {
        final selected = _matchLocationOption(item);
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
        AppToast.error(context, "Please select a valid location");
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
      await _service.UpdateShippingOut(widget.SOPId, payload);
      // debugPrint("Update shipping out response: ${resposne.data}");
      setState(() {
        isLoading = false;
      });
      AppToast.success(context, "Shipping out updated successfully");
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error updating shipping out: $e");
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        AppToast.error(context, "Failed to update shipping out");
      }
    }
  }

  String _optionLocationName(Map<String, dynamic> option) {
    final value = option['Location'] ?? option['location'] ?? '';
    return value.toString().trim();
  }

  String _optionLocationId(Map<String, dynamic> option) {
    return (option['SOPLocationId'] ?? option['sopLocationId'] ?? '')
        .toString()
        .trim();
  }

  String _itemLocationName(Map<String, dynamic> item) {
    for (final key in const ['Location', 'location']) {
      final text = item[key]?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  String _itemLocationId(Map<String, dynamic> item) {
    return (item['SOPLocationId'] ?? item['sopLocationId'] ?? '')
        .toString()
        .trim();
  }

  Map<String, dynamic> _matchLocationOption(Map<String, dynamic> item) {
    final id = _itemLocationId(item);
    final name = _itemLocationName(item).toLowerCase();
    for (final option in locationOptions) {
      if (id.isNotEmpty && _optionLocationId(option) == id) return option;
      final optionName = _optionLocationName(option).toLowerCase();
      if (name.isNotEmpty && optionName == name) return option;
    }
    return <String, dynamic>{};
  }

  String? _dropdownLocationValue(Map<String, dynamic> item) {
    final matched = _matchLocationOption(item);
    if (matched.isNotEmpty) {
      final name = _optionLocationName(matched);
      if (name.isNotEmpty && locations.contains(name)) return name;
    }
    final raw = _itemLocationName(item);
    if (raw.isEmpty) return null;
    for (final loc in locations) {
      if (loc.toLowerCase() == raw.toLowerCase()) return loc;
    }
    return locations.contains(raw) ? raw : null;
  }

  void _syncLocationsOntoItems() {
    if (SOPByIdData.isEmpty) return;
    for (final item in SOPByIdData) {
      final matched = _matchLocationOption(item);
      if (matched.isNotEmpty) {
        item['Location'] = _optionLocationName(matched);
        item['SOPLocationId'] =
            matched['SOPLocationId'] ?? matched['sopLocationId'];
      }
      final name = _itemLocationName(item);
      if (name.isNotEmpty &&
          !locations.any((loc) => loc.toLowerCase() == name.toLowerCase())) {
        locations.add(name);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    SOPController.dispose();
    POController.dispose();
    ODDController.dispose();
    CustomerController.dispose();
    ProgramController.dispose();
    LocationController.dispose();
    SOPEntryDateInController.dispose();
    SOPOrderEntryOutController.dispose();
    ProdMgrController.dispose();
    FinalDeliveryDateController.dispose();
    CommentsController.dispose();
    super.dispose();
  }

  Future<void> _openHistoryEdit(Map<String, dynamic> item) async {
    final sopId = item['SOPId']?.toString() ?? '';
    if (sopId.isEmpty || sopId == widget.SOPId) return;
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditShippingOutEntry(SOPId: sopId)),
    );
    if (updated == true && mounted) {
      await GetShippingOutHistory();
    }
  }

  bool _isMinDate(dynamic date) {
    if (date == null) return false;
    final dateStr = date.toString().trim();
    if (dateStr.isEmpty || dateStr.toLowerCase() == 'null') return false;
    return dateStr.startsWith('0001-01-01');
  }

  bool _isNullOrEmptyDate(dynamic date) {
    if (date == null) return true;
    final dateStr = date.toString().trim();
    return dateStr.isEmpty || dateStr.toLowerCase() == 'null';
  }

  String formatDate(dynamic date) {
    // null or API min value → placeholder
    if (_isNullOrEmptyDate(date) || _isMinDate(date)) return 'dd-mm-yyyy';
    try {
      final parsedDate = DateTime.parse(date.toString());
      return DateFormat('MM-dd-yyyy').format(parsedDate);
    } catch (e) {
      debugPrint("Date parse error: $e");
      return 'dd-mm-yyyy';
    }
  }

  DateTime _initialPickerDate(dynamic date) {
    if (_isNullOrEmptyDate(date) || _isMinDate(date)) return DateTime.now();
    final parsed = DateTime.tryParse(date.toString());
    if (parsed == null || parsed.year < 2000) return DateTime.now();
    return parsed;
  }

  Future<DateTime?> _pickDateWithStyledPicker(DateTime? initialDate) {
    const pickerAccent = Color.fromARGB(255, 57, 73, 95);
    final safeInitial = (initialDate == null || initialDate.year < 2000)
        ? DateTime.now()
        : initialDate;
    return showDatePicker(
      context: context,
      initialDate: safeInitial,
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

  Widget _buildDateDisplay(dynamic rawDate) {
    final isPlaceholder =
        _isNullOrEmptyDate(rawDate) || _isMinDate(rawDate);
    final value = formatDate(rawDate);

    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isPlaceholder ? Colors.grey.shade700 : Colors.black87,
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
    );
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
          dataRowMinHeight: 48,
          dataRowMaxHeight: double.infinity,
          horizontalMargin: 12,
          columnSpacing: 12,
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
                        onTap: () async {
                          final pickedDate = await _pickDateWithStyledPicker(
                            _initialPickerDate(item['ODD']),
                          );

                          if (pickedDate != null) {
                            setState(() {
                              item['ODD'] = pickedDate.toIso8601String();
                            });
                          }
                        },
                        child: _buildDateDisplay(item['ODD']),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: SizedBox(
                      width: 260,
                      child: TextFormField(
                        initialValue: item['customer']?.toString() ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        isDense: true,
                        value: _dropdownLocationValue(item),
                        hint: const Text(
                          'Select Location',
                          style: TextStyle(fontSize: 12),
                        ),
                        dropdownColor: Colors.white,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
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
                            (e) =>
                                _optionLocationName(e).toLowerCase() ==
                                (value ?? '').toLowerCase(),
                            orElse: () => <String, dynamic>{},
                          );
                          if (selected.isNotEmpty) {
                            item['SOPLocationId'] =
                                selected['SOPLocationId'] ??
                                selected['sopLocationId'];
                          }
                        });
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
                        onTap: () async {
                          final pickedDate = await _pickDateWithStyledPicker(
                            _initialPickerDate(item['SOPEntryDateIn']),
                          );

                          if (pickedDate != null) {
                            setState(() {
                              item['SOPEntryDateIn'] = DateFormat(
                                'yyyy-MM-dd',
                              ).format(pickedDate);
                            });
                          }
                        },
                        child: _buildDateDisplay(item['SOPEntryDateIn']),
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
                          final pickedDate = await _pickDateWithStyledPicker(
                            _initialPickerDate(item['SOPOrderEntryOut']),
                          );

                          if (pickedDate != null) {
                            setState(() {
                              item['SOPOrderEntryOut'] = DateFormat(
                                'yyyy-MM-dd',
                              ).format(pickedDate);
                            });
                          }
                        },
                        child: _buildDateDisplay(item['SOPOrderEntryOut']),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        isDense: true,
                        value: prodMgrs.contains(item['prodMgr']?.toString())
                            ? item['prodMgr']?.toString()
                            : null,
                        hint: const Text(
                          'Select Manager',
                          style: TextStyle(fontSize: 12),
                        ),
                        dropdownColor: Colors.white,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
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
                ),
                DataCell(
                  SizedBox(
                    width: 140,
                    child: Center(
                      child: InkWell(
                        onTap: () async {
                          final pickedDate = await _pickDateWithStyledPicker(
                            _initialPickerDate(item['FinalDeliveryDate']),
                          );

                          if (pickedDate != null) {
                            setState(() {
                              item['FinalDeliveryDate'] = DateFormat(
                                'yyyy-MM-dd',
                              ).format(pickedDate);
                            });
                          }
                        },
                        child: _buildDateDisplay(item['FinalDeliveryDate']),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 140,
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
    final updateButton = Center(
      child: SizedBox(
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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Icon(Icons.save, size: 20, color: Colors.white),
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
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(showBackButton: true),
      drawer: const CommonDrawer(),
      body: isLoading
          ? const Center(child: AppLoader())
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(height: 20),
                        buildTable(),
                        const SizedBox(height: 20),
                        updateButton,
                        const SizedBox(height: 16),
                        const Text(
                          'SOP History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: true,
                    child: isHistoryLoading
                        ? const Center(child: AppLoader())
                        : ShippingOutTable(
                            rows: ShippingOutHistory,
                            onEdit: _openHistoryEdit,
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
