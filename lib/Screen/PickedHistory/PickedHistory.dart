import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/Login/login.dart';
import 'package:overview_app/Screen/PickedHistory/Services/PickedHistoryService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ItemModel {
  final String sopNumber;
  final String fixtureNumber;
  final String dateChanged;
  final String picked;

  ItemModel({
    required this.sopNumber,
    required this.fixtureNumber,
    required this.dateChanged,
    required this.picked,
  });
}

class PickedHistory extends StatefulWidget {
  @override
  _PickedHistoryState createState() => _PickedHistoryState();
}

class _PickedHistoryState extends State<PickedHistory> {
  final PickedHistoryService _service = PickedHistoryService();
  String username = "";
  List<ItemModel> items = [];
  bool isLoading = false;

  static const List<double> _bomColWidths = [150, 170, 170, 130];

  double get _tableWidth =>
      _bomColWidths.fold<double>(0, (sum, w) => sum + w);

  Future<void> fetchHistoryData() async {
    setState(() {
      isLoading = true;
    });

    try {
      await Dioservices.setToken();
      final Response response = await _service.PickedLogHistoryService();
      final List<ItemModel> parsedItems = _parseItems(response.data);

      if (!mounted) return;
      setState(() {
        items = parsedItems;
        isLoading = false;
      });

      debugPrint("PICKED HISTORY STATUS: ${response.statusCode}");
      debugPrint("PICKED HISTORY ROW COUNT: ${parsedItems.length}");
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      debugPrint("Error in fetching picked history data: $e");
    }
  }

  static String _normalizeFieldKey(String input) =>
      input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static Map<String, dynamic> _normalizedFieldMap(Map<String, dynamic> row) {
    final out = <String, dynamic>{};
    row.forEach((k, v) {
      out[_normalizeFieldKey(k)] = v;
    });
    return out;
  }

  static String _firstMatchingValue(
    Map<String, dynamic> normalizedRow,
    List<String> keys,
  ) {
    for (final key in keys) {
      final current =
          normalizedRow[_normalizeFieldKey(key)]?.toString().trim();
      if (current != null && current.isNotEmpty) return current;
    }
    return "-";
  }

  static String _formatDateValue(String value) {
    final raw = value.trim();
    if (raw.isEmpty || raw == "-") return "-";

    DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      final fallbackFormats = [
        DateFormat("yyyy-MM-dd HH:mm:ss"),
        DateFormat("yyyy-MM-dd HH:mm"),
        DateFormat("yyyy-MM-dd"),
        DateFormat("dd-MM-yyyy HH:mm:ss"),
        DateFormat("dd-MM-yyyy HH:mm"),
        DateFormat("dd-MM-yyyy"),
        DateFormat("dd/MM/yyyy hh:mm:ss a"),
        DateFormat("dd/MM/yyyy hh:mm a"),
        DateFormat("dd/MM/yyyy"),
      ];
      for (final format in fallbackFormats) {
        try {
          parsed = format.parseStrict(raw);
          break;
        } catch (_) {}
      }
    }

    if (parsed == null) return raw;
    return DateFormat("dd/MM/yyyy hh:mm:ss a").format(parsed.toLocal());
  }

  List<ItemModel> _parseItems(dynamic payload) {
    dynamic data = payload;
    if (payload is Map<String, dynamic>) {
      data = payload['data'] ?? payload['items'] ?? payload['result'] ?? payload;
      if (data is Map<String, dynamic>) {
        data =
            data['data'] ??
            data['items'] ??
            data['rows'] ??
            data['result'] ??
            data['list'];
      }
    }
    if (data is! List) return [];

    final parsed = <ItemModel>[];
    for (final raw in data.whereType<Map>()) {
      final row = Map<String, dynamic>.from(raw);
      final normalizedRow = _normalizedFieldMap(row);
      parsed.add(
        ItemModel(
          sopNumber: _firstMatchingValue(
            normalizedRow,
            const ["SOPNum", "SOPNumber", "sopNumber", "sopNo"],
          ),
          fixtureNumber: _firstMatchingValue(
            normalizedRow,
            const ["FixtureNumber"],
          ),
          dateChanged: _firstMatchingValue(
            normalizedRow,
            const [
              "dateChanged",
              "createdAt",
              "updatedAt",
            ],
          ),
          picked: _firstMatchingValue(
            normalizedRow,
            const ["Status", "PickStatus", "PickedStatus", "Picked", "isPicked"],
          ),
        ),
      );
    }

    if (parsed.isNotEmpty && parsed.first.sopNumber == "-" && parsed.first.fixtureNumber == "-") {
      final firstRaw = data.first;
      if (firstRaw is Map) {
        debugPrint("PickedHistory: first row keys => ${firstRaw.keys.toList()}");
      }
    }
    return parsed;
  }

  @override
  void initState() {
    super.initState();
    fetchHistoryData();
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
      height: 40,
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
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
      ),
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
                  "Picked History",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
              else if (items.isEmpty)
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text("No picked history found"),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: SingleChildScrollView(
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _bomHeaderCell("SOP Number", _bomColWidths[0]),
                                  _bomHeaderCell(
                                    "Fixture Number",
                                    _bomColWidths[1],
                                  ),
                                  _bomHeaderCell(
                                    "Date Changed",
                                    _bomColWidths[2],
                                  ),
                                  _bomHeaderCell("Status", _bomColWidths[3]),
                                ],
                              ),
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
                                          item.sopNumber,
                                          _bomColWidths[0],
                                        ),
                                        _bomDataCell(
                                          item.fixtureNumber,
                                          _bomColWidths[1],
                                        ),
                                        _bomDataCell(
                                          _formatDateValue(item.dateChanged),
                                          _bomColWidths[2],
                                        ),
                                        _bomDataCell(
                                          item.picked,
                                          _bomColWidths[3],
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}
