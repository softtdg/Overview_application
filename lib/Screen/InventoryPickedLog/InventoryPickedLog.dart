import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/InventoryPickedLog/Services/InventoryPickedLogService.dart';
import 'package:overview_app/Screen/InventoryPickedLog/ViewPickedLog.dart';
import 'package:overview_app/Screen/Login/login.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ItemModel {
  final String id;
  final String pickListNumber;
  final String sopNum;
  final String fixture;
  final String description;
  final String project;
  final String tempQuantity;
  final String RMA;
  final String MPFRequestedBy;
  final String createdAt;

  ItemModel({
    required this.id,
    required this.pickListNumber,
    required this.sopNum,
    required this.fixture,
    required this.description,
    required this.project,
    required this.tempQuantity,
    required this.RMA,
    required this.MPFRequestedBy,
    required this.createdAt,
  });
}

class InventoryPickedLog extends StatefulWidget {
  @override
  _InventoryPickedLogState createState() => _InventoryPickedLogState();
}

class _InventoryPickedLogState extends State<InventoryPickedLog> {
  final InventoryPickedLogService _service = InventoryPickedLogService();
  final TextEditingController _pickListSearchController =
      TextEditingController();
  String username = "";
  bool isLoading = false;
  List<ItemModel> items = [];

  String selectedPickList = 'Pending Pick List';

  final List<String> itemList = ['Pending Pick List', 'Accepted', 'Rejected'];

  int _apiStatusForSelection(String selection) {
    switch (selection) {
      case 'Accepted':
        return 1;
      case 'Rejected':
        return 2;
      case 'Pending Pick List':
      default:
        return 0;
    }
  }

  String? get _pickListSearchValue {
    final value = _pickListSearchController.text.trim();
    return value.isEmpty ? null : value;
  }

  String _orDash(String value) => value.trim().isEmpty ? '-' : value;

  String _formatDateValue(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '-';

    DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      for (final format in [
        DateFormat("yyyy-MM-dd HH:mm:ss"),
        DateFormat("yyyy-MM-dd HH:mm"),
        DateFormat("yyyy-MM-dd"),
        DateFormat("dd-MM-yyyy HH:mm:ss"),
        DateFormat("dd-MM-yyyy HH:mm"),
        DateFormat("dd-MM-yyyy"),
        DateFormat("dd/MM/yyyy HH:mm:ss"),
        DateFormat("dd/MM/yyyy HH:mm"),
        DateFormat("dd/MM/yyyy"),
      ]) {
        try {
          parsed = format.parseStrict(raw);
          break;
        } catch (_) {}
      }
    }

    if (parsed == null) return raw;
    return DateFormat("dd MMM yyyy, HH:mm").format(parsed.toLocal());
  }

  Future<void> fetchInvetoryPickedData() async {
    setState(() {
      isLoading = true;
    });

    try {
      await Dioservices.setToken();
      final Response response = await _service.InventroyService(
        status: _apiStatusForSelection(selectedPickList),
        pickListNumber: _pickListSearchValue,
      );
      final payload = response.data;
      List<dynamic> rows = [];

      if (payload is List) {
        rows = payload;
      } else if (payload is Map<String, dynamic>) {
        final map = payload;
        final dynamic firstLevel = map['data'];

        if (firstLevel is List) {
          rows = firstLevel;
        } else if (firstLevel is Map<String, dynamic>) {
          final nested = firstLevel;
          final dynamic secondLevel = nested['data'];
          if (secondLevel is List) {
            rows = secondLevel;
          }
        }
      }

      final loadedItems = rows.map<ItemModel>((raw) {
        final item = raw is Map
            ? Map<String, dynamic>.from(
                raw.map((k, v) => MapEntry(k.toString(), v)),
              )
            : <String, dynamic>{};
        final rawDetail = item['excelFixtureDetail'];
        final detail = rawDetail is Map
            ? Map<String, dynamic>.from(
                rawDetail.map((k, v) => MapEntry(k.toString(), v)),
              )
            : <String, dynamic>{};

        String pick(List<String> keys) {
          for (final key in keys) {
            final value = item[key] ?? detail[key];
            if (value != null && value.toString().trim().isNotEmpty) {
              return value.toString();
            }
          }
          return '';
        }

        String rma = pick(const ['RMA', 'rma']);
        if (rma.isEmpty) {
          final hasBackorders = item['hasBackorders'] ?? item['hasbackorders'];
          if (hasBackorders != null) {
            rma = hasBackorders.toString().toLowerCase() == 'true'
                ? 'Yes'
                : 'No';
          }
        }

        return ItemModel(
          // Accept/reject routes need the list row primary key, not the display pick list #.
          id: pick(const ['id']).trim(),
          pickListNumber: pick(const ['pickListNumber']),
          sopNum: pick(const ['sopNum']),
          fixture: pick(const ['fixture']),
          description: pick(const ['description']),
          project: pick(const ['project']),
          tempQuantity: pick(const ['tempQuantity']),
          RMA: rma,
          MPFRequestedBy: pick(const ['MPFRequestedBy']),
          createdAt: pick(const ['createdAt']),
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        items = loadedItems;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      debugPrint("Error in inventory picked log $e");
    }
  }

  @override
  void initState() {
    super.initState();
    fetchInvetoryPickedData();
  }

  @override
  void dispose() {
    _pickListSearchController.dispose();
    super.dispose();
  }

  void _showLogoutConfirmDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token');
              await prefs.remove('UserName');
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => LoginPage()),
                (route) => false,
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Widget _bomHeaderCell(String label, double w) {
    final borderColor = Colors.grey.shade300;
    return SizedBox(
      width: w,
      height: 44,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 57, 73, 95),
          border: Border(
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            height: 1.0,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _bomDataCell(String value, double w) {
    final borderColor = Colors.grey.shade300;
    return SizedBox(
      width: w,
      child: Container(
        height: 56,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
        child: Text(
          value,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // Exact width for each table column, left to right.
  static const List<double> _colWidths = [
    140, // Pick list Number
    100, // SOP
    150, // Fixture
    260, // Description
    130, // Project
    95, // Quantity
    80, // RMA
    160, // MPF Requested By
    170, // Created At
    130, // Actions
  ];

  double get _tableWidth => _colWidths.reduce((sum, w) => sum + w);

  Widget _buildHeaderRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bomHeaderCell("Pick list Number", _colWidths[0]),
        _bomHeaderCell("SOP", _colWidths[1]),
        _bomHeaderCell("Fixture", _colWidths[2]),
        _bomHeaderCell("Description", _colWidths[3]),
        _bomHeaderCell("Project", _colWidths[4]),
        _bomHeaderCell("Quantity", _colWidths[5]),
        _bomHeaderCell("RMA", _colWidths[6]),
        _bomHeaderCell("MPF Requested By", _colWidths[7]),
        _bomHeaderCell("Created At", _colWidths[8]),
        _bomHeaderCell("Actions", _colWidths[9]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(),
      drawer: CommonDrawer(
        username: username,
        onLogout: _showLogoutConfirmDialog,
      ),
      body: Container(
        color: Colors.white,
        child: Container(
          // padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.center,
                child: Text(
                  "Inventory Picked Log",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // DropdownButton<String>(
              //   hint: Text("Pending Pick List"),
              //   value: selectedPickList,
              //   items: itemList.map((item) {
              //     return DropdownMenuItem(value: item, child: Text(item));
              //   }).toList(),
              //   onChanged: (value) {
              //     setState(() {
              //       selectedPickList = value;
              //     });
              //   },
              // ),
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        value: selectedPickList,
                        items: itemList.map((item) {
                          return DropdownMenuItem(value: item, child: Text(item));
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => selectedPickList = value);
                          fetchInvetoryPickedData();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 155,
                    child: TextField(
                      controller: _pickListSearchController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Pick List Number',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => fetchInvetoryPickedData(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // SizedBox(
                  //   height: 48,
                  //   child: ElevatedButton.icon(
                  //     onPressed: fetchInvetoryPickedData,
                  //     icon: const Icon(Icons.search),
                  //     label: const Text('Search'),
                  //   ),
                  // ),
                ],
              ),

              const SizedBox(height: 16),

              if (isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color.fromARGB(255, 57, 73, 95),
                    ),
                  ),
                )
              else
                Expanded(
                  child: items.isEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: SizedBox(
                                  width: _tableWidth,
                                  child: _buildHeaderRow(),
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Text("No Inventory Data Found"),
                                ),
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: SizedBox(
                              width: _tableWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeaderRow(),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: items.length,
                                      itemBuilder: (context, index) {
                                        final item = items[index];
                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _bomDataCell(
                                              _orDash(item.pickListNumber),
                                              _colWidths[0],
                                            ),
                                            _bomDataCell(
                                              _orDash(item.sopNum),
                                              _colWidths[1],
                                            ),
                                            _bomDataCell(
                                              _orDash(item.fixture),
                                              _colWidths[2],
                                            ),
                                            _bomDataCell(
                                              _orDash(item.description),
                                              _colWidths[3],
                                            ),
                                            _bomDataCell(
                                              _orDash(item.project),
                                              _colWidths[4],
                                            ),
                                            _bomDataCell(
                                              _orDash(item.tempQuantity),
                                              _colWidths[5],
                                            ),
                                            _bomDataCell(
                                              _orDash(item.RMA),
                                              _colWidths[6],
                                            ),
                                            _bomDataCell(
                                              _orDash(item.MPFRequestedBy),
                                              _colWidths[7],
                                            ),
                                            _bomDataCell(
                                              _formatDateValue(item.createdAt),
                                              _colWidths[8],
                                            ),
                                            SizedBox(
                                              width: _colWidths[9],
                                              child: Container(
                                                height: 56,
                                                alignment: Alignment.center,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    right: BorderSide(
                                                      color:
                                                          Colors.grey.shade300,
                                                    ),
                                                    bottom: BorderSide(
                                                      color:
                                                          Colors.grey.shade300,
                                                    ),
                                                  ),
                                                ),
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    debugPrint(
                                                      'View clicked - passed pickedLogId: ${item.id}',
                                                    );
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            ViewPickedLog(
                                                              id: item.id,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    Icons
                                                        .remove_red_eye_outlined,
                                                    size: 16,
                                                  ),
                                                  label: const Text("View"),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF1565C0),
                                                    foregroundColor:
                                                        Colors.white,
                                                    disabledBackgroundColor:
                                                        const Color(0xFF1565C0),
                                                    disabledForegroundColor:
                                                        Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    elevation: 8,
                                                    shadowColor: Colors.black
                                                        .withOpacity(0.35),
                                                    surfaceTintColor:
                                                        Colors.transparent,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 6,
                                                        ),
                                                    minimumSize: const Size(
                                                      0,
                                                      34,
                                                    ),
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
