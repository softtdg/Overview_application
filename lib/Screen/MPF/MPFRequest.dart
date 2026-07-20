import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:overview_app/Screen/MPF/Components/picklist.dart';
import 'package:overview_app/Screen/MPF/Services/MPFServices.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MPFRequest extends StatefulWidget {
  @override
  _MPFRequestState createState() => _MPFRequestState();
}

enum _SopValidation { none, validating, valid, invalid }

class _MPFRequestState extends State<MPFRequest> {
  final _sopController = TextEditingController();
  final _mpfRequestService = const MPFServices();
  _SopValidation _validation = _SopValidation.none;
  List<Map<String, dynamic>> _fixtures = [];
  Timer? _debounce;
  final _projectNameController = TextEditingController();
  final _mpfRequestedByOtherController = TextEditingController();

  bool _showCustomSop = false;
  final _customSopController = TextEditingController();
  final _newCustomSopController = TextEditingController();
  final _fixtureController = TextEditingController();
  _SopValidation _fixtureValidation = _SopValidation.none;
  Timer? _fixtureDebounce;

  bool _showPartBox = false;
  String? _mpfRequestedBy;
  final List<_PartItem> _partItems = [_PartItem()];

  static const _mpfRequestedByList = [
    "GEORGEK",
    "GARY",
    "JOED",
    "JOEL",
    "BELA",
    "PREET",
    "JENIFFER",
    "Other",
  ];

  static const _commentOptions = [
    "EVALUATION SAMPLE",
    "WARRANTY RMA",
    "PROTOTYPE",
    "CUSTOMER ACCOMODATIONS",
    "INTERNAL TESTING / FAI",
    "BOM-INACCURATE",
    "NO PICK LIST",
    "REWORK",
    "QC REJECTS",
    "WRONG QTY",
    "SCRAP",
    "ENGINEERING TESTING (no SOP)",
    "DEFECTIVE/DAMAGED PART",
    "Other",
  ];

  static const _pageBg = Color(0xFFF5F7F9);
  static const _titleColor = Color(0xFF001D3D);
  static const _borderColor = Color(0xFFDEE2E6);
  static const _successColor = Color(0xFF2E7D32);
  static const _errorColor = Color.fromARGB(255, 172, 16, 32);

  Future<void> _validateSop(String value) async {
    if (value.trim().isEmpty) {
      setState(() {
        _validation = _SopValidation.none;
        _fixtures = [];
      });
      return;
    }

    setState(() {
      _validation = _SopValidation.validating;
      _fixtures = [];
    });

    try {
      await Dioservices.setToken();

      final check = await _mpfRequestService.SOPCheck(value);
      if (check.data["data"] == null) {
        setState(() {
          _validation = _SopValidation.invalid;
          _fixtures = [];
        });
        return;
      }

      final list = await _mpfRequestService.SOPList(value);
      final fixtures = List<Map<String, dynamic>>.from(
        list.data["data"]["fixtures"] ?? [],
      );

      setState(() {
        _validation = _SopValidation.valid;
        _fixtures = fixtures;
      });
    } catch (_) {
      setState(() {
        _validation = _SopValidation.invalid;
        _fixtures = [];
      });
    }
  }

  Future<void> _validateFixture(String value) async {
    if (value.trim().isEmpty) {
      setState(() => _fixtureValidation = _SopValidation.none);
      return;
    }

    setState(() => _fixtureValidation = _SopValidation.validating);

    try {
      await Dioservices.setToken();
      final user =
          (await SharedPreferences.getInstance()).getString('UserName') ?? '';
      final response = await _mpfRequestService.fixtureDetails(
        fixtureNumber: value.trim(),
        sopNumber: _customSopController.text.trim(),
        mpf: "true",
        user: user,
      );
      setState(() {
        _fixtureValidation = response.data["data"] == null
            ? _SopValidation.invalid
            : _SopValidation.valid;
      });
    } catch (_) {
      setState(() => _fixtureValidation = _SopValidation.invalid);
    }
  }

  void _openLivePdmPickList() {
    final sop = _newCustomSopController.text.trim();
    final fixture = _fixtureController.text.trim();
    if (sop.isEmpty || fixture.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PickList(
          fixtureNumber: fixture,
          sopNumber: sop,
          mpf: "true",
          customMpf: true,
          livePdmMpf: true,
        ),
      ),
    );
  }

  Future<void> _searchPartNumber(int index, String partNumber) async {
    if (partNumber.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _partItems[index].results = [];
        _partItems[index].magnifiedData = null;
        _partItems[index].isSearching = false;
      });
      return;
    }

    setState(() => _partItems[index].isSearching = true);

    try {
      await Dioservices.setToken();
      final response = await _mpfRequestService.searchPartNumber(
        partNumber.trim(),
      );
      final data = List<Map<String, dynamic>>.from(response.data["data"] ?? []);

      if (!mounted) return;
      setState(() {
        _partItems[index].results = data;
        _partItems[index].magnifiedData = null;
        _partItems[index].isSearching = false;
      });
    } catch (e) {
      print("Error in searchPartNumber api call: $e");
      if (!mounted) return;
      setState(() {
        _partItems[index].results = [];
        _partItems[index].magnifiedData = null;
        _partItems[index].isSearching = false;
      });
    }
  }

  Future<void> _submitInventoryPicklist() async {
    try {
      await Dioservices.setToken();

      final sheetData = _partItems.map((item) {
        final partDetail = item.magnifiedData ?? {};

        final commentValue = item.comment == "Other"
            ? item.commentController.text.trim()
            : item.comment;

        return {
          "ActualQtyPicked": "",
          "ConsumableOrVMI": false,
          "Description": partDetail["Description"] ?? "",
          "InventoryComments": commentValue ?? "",
          "LeadHandComments": "",
          "Location": "",
          "Quantity": 0,
          "QuantityAvailable": 0,
          "QuantityPerFixture": 0,
          "Size": partDetail["Size"] ?? 0,
          "TDGPN": item.partController.text.trim(),
          "TotalQtyNeeded": 0,
          "UnitOfMeasure": item.unitOfMeasure ?? "PCS",
          "UnitPrice": "0",
          "Vendor": partDetail["Vendor"] ?? "",
          "VendorPN": partDetail["VendorPN"] ?? "",
          "isGray": false,
          "isGrayRow": false,
          "isLightTrellis": false,
          "mpfQty": item.qtyController.text.trim(),
          "userModifiedActualQty": false,
          "userModifiedComments":
              commentValue != null && commentValue.toString().isNotEmpty,
        };
      }).toList();

      final mpfRequestedByValue = _mpfRequestedBy == "Other"
          ? _mpfRequestedByOtherController.text.trim()
          : _mpfRequestedBy;

      final payload = {
        "InventoryComments": "",
        "excelFixtureDetail": {
          "description": "MPF Request for REVIEW",
          "sopNum": _sopController.text.trim(),
          "programName": "",
          "fixture": "",
          "tempQuantity": 0,
          "odd": DateTime.now().toUtc().toIso8601String(),
        },
        "sheetData": sheetData,
        "project": _projectNameController.text.trim(),
        "RMA": "",
        "MPFRequestedBy": mpfRequestedByValue ?? "",
        "mpfPageRequest": 1,
        "mpfStatus": 1,
        "sheetType": 0,
        "zeroLevel": false,
      };

      // print("Inventory Picklist Payload::::::::::::: ${payload}");

      final response = await _mpfRequestService.inventoryPickList(payload);

      // print("INVENTORY PICKLIST RESPONSE: ${response}");

      if (response.statusCode == 200) {
        _margaretDialog();
      }
    } catch (e) {
      print("Error in SubmitMPFRequest api call: $e");
    }
  }

  void _resetForm() {
    setState(() {
      _sopController.clear();
      _projectNameController.clear();

      _validation = _SopValidation.none;
      _fixtures = [];
      _showPartBox = false;
      _showCustomSop = false;
      _fixtureValidation = _SopValidation.none;
      _fixtureController.clear();
      _newCustomSopController.clear();
    });
  }

  Future<void> _getMagnifiedFixtureData(int index, String tdgpn) async {
    try {
      await Dioservices.setToken();
      final response = await _mpfRequestService.magnifiedFixtureData(tdgpn);
      // print("magnifiedFixtureData response: ${response.data["data"]}");
      final data = response.data["data"];

      Map<String, dynamic>? partDetail;
      if (data is Map) {
        final nested = data["partDetail"];
        if (nested is Map) {
          partDetail = Map<String, dynamic>.from(nested);
        } else {
          partDetail = Map<String, dynamic>.from(data);
        }
      } else if (data is List && data.isNotEmpty && data.first is Map) {
        partDetail = Map<String, dynamic>.from(data.first);
      }

      if (!mounted) return;
      setState(() {
        _partItems[index].magnifiedData = partDetail;
      });
    } catch (e) {
      print("Error in magnifiedFixtureData api call $e");
    }
  }

  TableRow _fixtureRow(Map<String, dynamic> fixture) {
    final qty =
        fixture["tempQuantity"] ?? fixture["Quantity"] ?? fixture["qty"];
    return TableRow(
      children: [
        _bodyCell(fixture["FixtureNumber"]?.toString() ?? "-"),
        _bodyCell(fixture["Description"]?.toString() ?? "-"),
        _bodyCell(qty?.toString() ?? "-", align: TextAlign.center),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Center(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PickList(
                      fixtureNumber: fixture["FixtureNumber"]?.toString() ?? "",
                      sopNumber: _sopController.text.trim(),
                      mpf: "true",
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text("Picklist"),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF37475E),
                side: const BorderSide(color: Color(0xFF37475E)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _requiredLabel(String text) {
    return Text.rich(
      TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _titleColor,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: _errorColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPartItem(int index) {
    final item = _partItems[index];
    OutlineInputBorder fieldBorder() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: _borderColor),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Item ${index + 1}",
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _requiredLabel('Part No'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: item.partController,
                      onChanged: (value) {
                        if (item.suppressSearch) return;
                        if (item.searchDebounce?.isActive ?? false) {
                          item.searchDebounce!.cancel();
                        }
                        setState(() => item.magnifiedData = null);
                        item.searchDebounce = Timer(
                          const Duration(milliseconds: 300),
                          () => _searchPartNumber(index, value),
                        );
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Enter part number',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        enabledBorder: fieldBorder(),
                        focusedBorder: fieldBorder(),
                      ),
                    ),
                    if (item.magnifiedData != null) ...[
                      const SizedBox(height: 12),
                      _buildMagnifiedBox(item.magnifiedData!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _requiredLabel('Qty'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: item.qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Enter quantity',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        enabledBorder: fieldBorder(),
                        focusedBorder: fieldBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _requiredLabel('Unit of Measure'),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: item.unitOfMeasure,
                      isExpanded: true,
                      dropdownColor: Colors.white,

                      items: const [
                        DropdownMenuItem(
                          value: "Select...",
                          child: Text("Select..."),
                        ),
                        DropdownMenuItem(value: "MM", child: Text("MM")),
                        DropdownMenuItem(value: "CM", child: Text("CM")),
                        DropdownMenuItem(value: "M", child: Text("M")),
                        DropdownMenuItem(value: "LBS", child: Text("LBS")),
                        DropdownMenuItem(value: "G", child: Text("G")),
                        DropdownMenuItem(value: "KG", child: Text("KG")),
                        DropdownMenuItem(value: "ML", child: Text("ML")),
                        DropdownMenuItem(value: "L", child: Text("L")),
                        DropdownMenuItem(value: "PCS", child: Text("PCS")),
                      ],

                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            item.unitOfMeasure = value;
                          });
                        }
                      },

                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        enabledBorder: fieldBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(
                            color: Color(0xFF1976D2),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _requiredLabel('Comment'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: item.comment,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      hint: const Text('Select Comment'),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        enabledBorder: fieldBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(
                            color: Color(0xFF1976D2),
                            width: 1.5,
                          ),
                        ),
                      ),
                      items: _commentOptions
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => item.comment = value);
                      },
                    ),
                    if (item.comment == "Other") ...[
                      const SizedBox(height: 12),
                      _requiredLabel('Other (Comment)'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: item.commentController,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Enter comment',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          enabledBorder: fieldBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(
                              color: Color(0xFF1976D2),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (item.isSearching || item.results.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPartResults(index),
          ],
        ],
      ),
    );
  }

  void _margaretDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Blue Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1976D2),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      "MPF Request Submitted Successfully",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // Green Tick
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green, width: 4),
                  ),
                  child: const Icon(Icons.check, color: Colors.green, size: 45),
                ),

                const SizedBox(height: 25),

                const Text(
                  "For any inquiry, see MARGARET",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  "Your MPF request has been processed successfully.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, color: Colors.grey),
                ),

                const SizedBox(height: 30),

                const Divider(height: 1),

                Container(
                  color: const Color(0xFFF9FAFB),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _resetForm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      minimumSize: const Size(110, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "OK",
                      style: TextStyle(color: Colors.white, fontSize: 17),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _invalidFixtureDialog() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color.fromARGB(255, 235, 215, 137)),
      ),
      child: const Text(
        "This fixture is not available in the standard picklist flow. Use Live PDM search to load fixture data and continue.",
        style: TextStyle(
          fontSize: 15,
          color: Color.fromARGB(255, 82, 34, 6),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildMagnifiedBox(Map<String, dynamic> data) {
    String v(List<String> keys) {
      for (final k in keys) {
        final val = data[k];
        if (val != null && val.toString().trim().isNotEmpty) {
          return val.toString().trim();
        }
      }
      return 'N/A';
    }

    Widget line(List<(String, String)> pairs) {
      return Text.rich(
        TextSpan(
          children: [
            for (int i = 0; i < pairs.length; i++) ...[
              TextSpan(
                text: '${pairs[i].$1}: ',
                style: const TextStyle(fontSize: 12, color: _titleColor),
              ),
              TextSpan(
                text: pairs[i].$2,
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E)),
              ),
              if (i < pairs.length - 1)
                const TextSpan(
                  text: '  |  ',
                  style: TextStyle(fontSize: 12, color: _borderColor),
                ),
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F9),
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            v(['Description']),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 6),
          line([
            ('Material', v(['Material'])),
            ('Finish', v(['Finish'])),
          ]),
          const SizedBox(height: 4),
          line([
            ('Vendor', v(['Vendor'])),
            ('Vendor PN', v(['VendorPN'])),
          ]),
        ],
      ),
    );
  }

  Widget _buildPartResults(int index) {
    final item = _partItems[index];
    String cell(Map<String, dynamic> row, List<String> keys) {
      for (final k in keys) {
        final v = row[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return '-';
    }

    const columnWidths = {
      0: FlexColumnWidth(2),
      1: FlexColumnWidth(3),
      2: FlexColumnWidth(1.4),
    };

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Table(
            columnWidths: columnWidths,
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder(bottom: BorderSide(color: _borderColor)),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF1F3F5)),
                children: [
                  _partResultHeader('TDG PN'),
                  _partResultHeader('DESCRIPTION'),
                  _partResultHeader('FIELD'),
                  _partResultHeader('VALUE'),
                ],
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: item.isSearching
                ? const SizedBox(
                    height: 80,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Searching...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF495057),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Table(
                      columnWidths: columnWidths,
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      border: TableBorder(
                        horizontalInside: BorderSide(color: _borderColor),
                      ),
                      children: [
                        ...item.results.map((row) {
                          final partNo = cell(row, ['TDGPN']);
                          return TableRow(
                            children: [
                              _partResultCell(
                                partNo,
                                onTap: () {
                                  item.searchDebounce?.cancel();
                                  item.suppressSearch = true;
                                  setState(() {
                                    item.partController.text = partNo;
                                    item.results = [];
                                    item.isSearching = false;
                                  });
                                  item.suppressSearch = false;
                                  _getMagnifiedFixtureData(index, partNo);
                                },
                              ),
                              _partResultCell(cell(row, ['Description'])),
                              _partResultCell('TDGPN'),
                              _partResultCell(cell(row, ['TDGPN'])),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _partResultHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: _titleColor,
        ),
      ),
    );
  }

  Widget _partResultCell(String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(text, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _headerCell(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        textAlign: align,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _bodyCell(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 14),
        softWrap: true,
      ),
    );
  }

  bool get _showContinueBox {
    return _validation == _SopValidation.invalid &&
        _projectNameController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _validation == _SopValidation.valid;
    final isInvalid = _validation == _SopValidation.invalid;
    final fieldColor = isValid
        ? _successColor
        : isInvalid
        ? _errorColor
        : _borderColor;

    String? helperText;
    if (_validation == _SopValidation.valid) {
      helperText = 'Valid SOP number';
    } else if (_validation == _SopValidation.invalid) {
      helperText = 'Invalid SOP number';
    } else if (_validation == _SopValidation.validating) {
      helperText = 'Checking SOP number...';
    }

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: const CommonAppBar(),
      drawer: const CommonDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MPF Request',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _titleColor,
              ),
            ),

            const SizedBox(height: 16),

            Divider(color: _borderColor, height: 1),

            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey),
                // boxShadow: [
                //   BoxShadow(
                //     color: Colors.black.withOpacity(0.05),
                //     blurRadius: 8,
                //     offset: const Offset(0, 2),
                //   ),
                // ],
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SOP Number field
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SOP No',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _titleColor,
                              ),
                            ),

                            const SizedBox(height: 8),

                            TextField(
                              controller: _sopController,
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                if (_debounce?.isActive ?? false) {
                                  _debounce!.cancel();
                                }
                                _debounce = Timer(
                                  const Duration(milliseconds: 500),
                                  () {
                                    _validateSop(value);
                                  },
                                );
                              },
                              style: TextStyle(
                                fontSize: 16,
                                color: isValid || isInvalid ? fieldColor : null,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide(color: fieldColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide(
                                    color: fieldColor,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),

                            if (helperText != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                helperText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isValid
                                      ? _successColor
                                      : isInvalid
                                      ? _errorColor
                                      : const Color(0xFF6C757D),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // projec name field
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Project Name',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _titleColor,
                              ),
                            ),

                            const SizedBox(height: 8),

                            TextField(
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide(color: fieldColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide(
                                    color: fieldColor,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              controller: _projectNameController,
                              onChanged: (value) {
                                setState(() {
                                  if (value.trim().isEmpty) {
                                    _showCustomSop = false;
                                    _showPartBox = false;
                                    _fixtureValidation = _SopValidation.none;
                                    _fixtureController.clear();
                                    _newCustomSopController.clear();
                                  }
                                });
                              },
                              textCapitalization: TextCapitalization.characters,
                              autocorrect: false,
                              enableSuggestions: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_showContinueBox && !_showCustomSop && !_showPartBox) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "How would you like to continue?",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Select whether you want to proceed with a fixture or a part request.",
                      style: TextStyle(
                        color: Color.fromARGB(255, 75, 75, 75),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _newCustomSopController.text = _sopController.text
                                  .trim();
                              _showCustomSop = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                              side: BorderSide(color: Colors.blue),
                            ),
                          ),
                          child: const Text("Fixture"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _showPartBox = true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                              side: BorderSide(color: Colors.blue),
                            ),
                          ),
                          child: const Text("Part"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            if (_showContinueBox && _showCustomSop) ...[
              const SizedBox(height: 20),
              Builder(
                builder: (context) {
                  final fixtureValid =
                      _fixtureValidation == _SopValidation.valid;
                  final fixtureInvalid =
                      _fixtureValidation == _SopValidation.invalid;
                  final fixtureColor = fixtureValid
                      ? _successColor
                      : fixtureInvalid
                      ? _errorColor
                      : _borderColor;

                  String? fixtureHelper;
                  if (fixtureValid) {
                    fixtureHelper = 'Fixture checked successfully';
                  } else if (fixtureInvalid) {
                    fixtureHelper = 'Fixture not found';
                  } else if (_fixtureValidation == _SopValidation.validating) {
                    fixtureHelper = 'Checking fixture...';
                  }

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "No SOP Found - Add Custom SOP",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _titleColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Enter SOP and fixture details to continue with a custom setup.",
                          style: TextStyle(color: Color(0xFF6C757D)),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SOP',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _newCustomSopController,
                                    style: const TextStyle(fontSize: 16),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: BorderSide(
                                          color: _borderColor,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: BorderSide(
                                          color: _borderColor,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fixture',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _fixtureController,
                                    onChanged: (value) {
                                      if (_fixtureDebounce?.isActive ?? false) {
                                        _fixtureDebounce!.cancel();
                                      }
                                      _fixtureDebounce = Timer(
                                        const Duration(milliseconds: 500),
                                        () => _validateFixture(value),
                                      );
                                    },
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: fixtureValid || fixtureInvalid
                                          ? fixtureColor
                                          : null,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: BorderSide(
                                          color: fixtureColor,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: BorderSide(
                                          color: fixtureColor,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (fixtureHelper != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      fixtureHelper,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: fixtureValid
                                            ? _successColor
                                            : fixtureInvalid
                                            ? _errorColor
                                            : const Color(0xFF6C757D),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Show the yellow message box
                        if (fixtureInvalid) ...[
                          const SizedBox(height: 12),
                          _invalidFixtureDialog(),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: fixtureValid ? () {} : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1976D2),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color.fromARGB(
                                  255,
                                  222,
                                  227,
                                  233,
                                ),
                                disabledForegroundColor: const Color.fromARGB(
                                  255,
                                  131,
                                  129,
                                  129,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: const Text("Submit"),
                            ),
                            if (fixtureInvalid) ...[
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: _openLivePdmPickList,
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text("Search from Live PDM"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF37475E),
                                  side: const BorderSide(
                                    color: Color(0xFF37475E),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            if (_showContinueBox && _showPartBox) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Expanded(
                          child: Text(
                            "MPF Request Items",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _titleColor,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _requiredLabel('MPF Requested By'),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 220,
                              child: DropdownButtonFormField<String>(
                                value: _mpfRequestedBy,
                                isExpanded: true,
                                dropdownColor: Colors.white,
                                hint: const Text('Select MPF Requested By'),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1976D2),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                items: _mpfRequestedByList
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => _mpfRequestedBy = value);
                                },
                              ),
                            ),
                            if (_mpfRequestedBy == "Other") ...[
                              const SizedBox(height: 12),
                              _requiredLabel('Other (MPF Requested By)'),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 220,
                                child: TextField(
                                  controller: _mpfRequestedByOtherController,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Enter MPF Requested By',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF1976D2),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _partItems.add(_PartItem()));
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("Add Row"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    for (int i = 0; i < _partItems.length; i++) ...[
                      _buildPartItem(i),
                      const SizedBox(height: 12),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          _submitInventoryPicklist();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text("Submit MPF Request"),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (!_showContinueBox && _fixtures.isNotEmpty) ...[
              const SizedBox(height: 20),

              Text(
                "Fixtures for SOP : ${_sopController.text}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // fixtures table
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const tableMinWidth = 640.0;
                    final tableWidth = constraints.maxWidth < tableMinWidth
                        ? tableMinWidth
                        : constraints.maxWidth;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1.4),
                            1: FlexColumnWidth(3.2),
                            2: FixedColumnWidth(72),
                            3: FixedColumnWidth(140),
                          },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          border: TableBorder.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: Color(0xFF37475E),
                              ),
                              children: [
                                _headerCell("FIXTURES"),
                                _headerCell("DESCRIPTION"),
                                _headerCell("QTY", align: TextAlign.center),
                                _headerCell("ACTION", align: TextAlign.center),
                              ],
                            ),
                            ..._fixtures.map(_fixtureRow),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PartItem {
  final TextEditingController partController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController commentController = TextEditingController();
  String? comment;
  String unitOfMeasure = "PCS";
  Timer? searchDebounce;
  bool suppressSearch = false;
  bool isSearching = false;
  List<Map<String, dynamic>> results = [];
  Map<String, dynamic>? magnifiedData;
}
