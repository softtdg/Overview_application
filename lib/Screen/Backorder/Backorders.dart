import 'dart:math';
import 'package:data_table_2/data_table_2.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:overview_app/Screen/Backorder/Services/BackorderService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:overview_app/Widgets/pagination_bar.dart';

class Backorders extends StatefulWidget {
  const Backorders({super.key});

  @override
  State<Backorders> createState() => _BackordersTableState();
}

class _BackordersTableState extends State<Backorders> {
  final TextEditingController _searchController = TextEditingController();
  final _backorderService = BackorderService();
  final List<Map<String, dynamic>> _allRows = [];
  final List<Map<String, dynamic>> _rows = [];
  String _searchQuery = "";
  int _currentPage = 1;
  static const int _rowsPerPage = 50;
  bool _isLoading = false;

  String _text(dynamic v) {
    if (v == null) return '-';
    if (v is List) {
      final parts = v
          .where(
            (item) =>
                item != null &&
                item.toString().trim().isNotEmpty &&
                item.toString().trim() != 'null',
          )
          .map((item) => item.toString().trim())
          .toList();
      return parts.isEmpty ? '-' : parts.join(', ');
    }
    final s = v.toString().trim();
    return s.isEmpty || s == 'null' ? '-' : s;
  }

  String _formatDate(String raw) {
    if (raw == '-' || raw.startsWith('0001-01-01')) return '-';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    final x = d.toLocal();
    return '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
  }

  String _backorderNotice(Map bo) {
    final tdgpn = _text(bo['TDGPN']);
    final qty = _text(bo['Quantity']);
    final uom = _text(bo['UOM']);
    final closed = _formatDate(_text(bo['ClosedDate']));
    return closed == '-'
        ? 'Missing: $tdgpn ($qty) $uom'
        : 'Missing: $tdgpn ($qty) $uom - CLOSED - $closed';
  }

  List<Map<String, dynamic>> _parseRows(List? raw) {
    if (raw == null) return [];

    final rows = <Map<String, dynamic>>[];

    for (final item in raw.whereType<Map>()) {
      final base = Map<String, dynamic>.from(item);

      final productionDateOut =
          item["SOP"]?["ProductionLogEntry"]?["ProductionDateOut"];

      final notProduced = isNotProduced(productionDateOut);

      /// Purchasing Notice
      if (_text(item["LeadHandCommentsForPurchasing"]).isNotEmpty) {
        final purchasingColor =
            (item["NotifyPurchasing"] == true && notProduced)
            ? const Color(0xFF99CCFF)
            : const Color(0xFF607D99);

        rows.add({
          ...base,
          "DateSent": _formatDate(_text(item["NotifiedPurchasingDate"])),
          "Dept": "Purchasing",
          "Notice": _text(item["LeadHandCommentsForPurchasing"]),
          "Response": _text(item["PurchasingComments"]),
          "BgColor": purchasingColor,
          "NoticeType": "purchasing",
        });
      }

      /// Backorders
      final bos = item["Backorders"];
      if (bos is List) {
        for (final bo in bos.whereType<Map>()) {
          final qty = num.tryParse('${bo["Quantity"]}') ?? 0;
          final recv = num.tryParse('${bo["Received"]}') ?? 0;
          final backorderColor = qty != recv
              ? const Color(0xFF99CCFF)
              : const Color(0xFF607D99);

          rows.add({
            ...base,
            "DateSent": _formatDate(_text(bo["NoticeDate"])),
            "Dept": "Purchasing",
            "Notice": _backorderNotice(bo),
            "Response": _text(bo["Response"]),
            "BgColor": backorderColor,
            "NoticeType": "backorder",
            "SOPBackorderEntryId": bo["SOPBackorderEntryId"],
            "TDGPN": bo["TDGPN"],
            "OriginalReceived": recv.toInt(),
            "Qty (Backordered)": _text(bo["Quantity"]),
            "Qty (Received)": _text(bo["Received"]),
            "UOM": _text(bo["UOM"]),
          });
        }
      }

      /// Production Notice
      if (_text(item["InventoryCommentsForProduction"]).isNotEmpty) {
        final productionColor =
            (item["NotifyProduction"] == true && notProduced)
            ? const Color(0xFFFFCCCC)
            : const Color(0xFFC9A1A1);

        rows.add({
          ...base,
          "DateSent": _formatDate(_text(item["NotifiedProductionDate"])),
          "Dept": "Production",
          "Notice": _text(item["InventoryCommentsForProduction"]),
          "Response": _text(item["ProductionComments"]),
          "BgColor": productionColor,
          "NoticeType": "production",
        });
      }
    }

    return rows;
  }

  Future<void> _getCriticalItemList() async {
    setState(() => _isLoading = true);
    try {
      await Dioservices.setToken();
      final response = await _backorderService.criticalItemList();
      print("RESPONSE FROM CRITICAL ITEM LIST API: ${response.data}");

      final payload = response.data;
      final rawData = payload is Map ? payload['data'] : payload;
      final data = _parseRows(rawData is List ? rawData : null);

      if (!mounted) return;
      setState(() {
        _allRows
          ..clear()
          ..addAll(data);
        _rows.clear();
        if (_searchQuery.isNotEmpty) {
          _rows.addAll(_allRows.where((row) => _rowMatches(row, _searchQuery)));
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error in _getCriticalItemList: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  bool _rowMatches(Map<String, dynamic> row, String search) {
    final sop = row["SOP"];
    final log = sop is Map ? sop["ProductionLogEntry"] : null;
    final leadHand = log is Map ? log["LeadHand"] : null;
    final assembler = row["Assembler"];

    final fields = [
      sop is Map ? sop["SOPNum"] : null,
      sop is Map ? sop["ODD"] : null,
      leadHand is Map ? leadHand["LeadHandName"] : null,
      assembler is Map ? assembler["Name"] : null,
      row["FixtureNumber"],
      row["FixtureDescription"],
      row["Quantity"],
      row["Hours"],
      row["Amount"],
      row["InventoryComments"],
      row["Picked"] == true ? "Yes" : "No",
      row["DateSent"],
      row["Dept"],
      row["Notice"],
      row["Response"],
      row["UOM"],
      row["Qty (Backordered)"],
      row["Qty (Received)"],
      row["Status"],
    ];

    return fields.any((v) => _text(v).toLowerCase().contains(search));
  }

  void _filterRows(String value) {
    final search = value.toLowerCase().trim();

    setState(() {
      _searchQuery = search;
      _currentPage = 1;
      _rows.clear();
      if (search.isNotEmpty) {
        _rows.addAll(_allRows.where((row) => _rowMatches(row, search)));
      }
    });
  }

  int get _totalPages =>
      _rows.isEmpty ? 1 : ((_rows.length + _rowsPerPage - 1) ~/ _rowsPerPage);

  List<Map<String, dynamic>> get _pagedRows {
    if (_rows.isEmpty) return [];
    final page = _currentPage.clamp(1, _totalPages);
    final start = (page - 1) * _rowsPerPage;
    final end = min(start + _rowsPerPage, _rows.length);
    return _rows.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    _getCriticalItemList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _heading(String text) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  DataColumn2 _column(String text, {required double minWidth}) {
    return DataColumn2(
      headingRowAlignment: MainAxisAlignment.center,
      minWidth: minWidth,
      label: SizedBox(width: minWidth, child: _heading(text)),
    );
  }

  Widget _tableTextCell(
    String text, {
    double? width = 90,
    TextAlign align = TextAlign.center,
    int maxLines = 5,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    final style = TextStyle(fontSize: 13, fontWeight: fontWeight);

    Widget child;
    if (_searchQuery.isEmpty) {
      child = Text(
        text,
        textAlign: align,
        softWrap: true,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    } else {
      final lower = text.toLowerCase();
      final spans = <TextSpan>[];
      var start = 0;
      var index = lower.indexOf(_searchQuery);

      while (index != -1) {
        if (index > start) {
          spans.add(TextSpan(text: text.substring(start, index), style: style));
        }
        spans.add(
          TextSpan(
            text: text.substring(index, index + _searchQuery.length),
            style: style.copyWith(backgroundColor: const Color(0xFFFFFF00)),
          ),
        );
        start = index + _searchQuery.length;
        index = lower.indexOf(_searchQuery, start);
      }
      if (start < text.length) {
        spans.add(TextSpan(text: text.substring(start), style: style));
      }

      child = Text.rich(
        TextSpan(children: spans),
        textAlign: align,
        softWrap: true,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : (width ?? 90.0);
        return SizedBox(
          width: cellWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: child,
          ),
        );
      },
    );
  }

  Widget _fillBgCell(String text, Color? color, {int maxLines = 5}) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        if (color != null) ColoredBox(color: color),
        Align(
          alignment: Alignment.center,
          child: _tableTextCell(text, width: null, maxLines: maxLines),
        ),
      ],
    );
  }

  Widget _receivedQtyField(Map<String, dynamic> row) {
    final raw = _text(row["Qty (Received)"]);
    final value = raw == '-' ? '0' : raw;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: SizedBox(
          width: 64,
          height: 34,
          child: TextFormField(
            key: ValueKey('received-${row["SOPBackorderEntryId"]}'),
            initialValue: value,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: const BorderSide(color: Color(0xFF607D99)),
              ),
            ),
            onChanged: (v) {
              row["Qty (Received)"] = v.trim().isEmpty ? '0' : v.trim();
            },
          ),
        ),
      ),
    );
  }

  double _rowHeightFor(Map<String, dynamic> row) {
    const minHeight = 56.0;
    const verticalPadding = 16.0;
    const lineHeight = 18.0;
    const maxLines = 4;

    int estimateLines(String text, double columnWidth) {
      if (text.isEmpty || text == '-') return 1;
      final charsPerLine = max(12, (columnWidth / 7).floor());
      return min(maxLines, max(1, (text.length / charsPerLine).ceil()));
    }

    final lines = [
      estimateLines(_text(row["InventoryComments"]), 220),
      estimateLines(_text(row["FixtureDescription"]), 280),
      estimateLines(_text(row["Notice"]), 280),
      estimateLines(_text(row["Response"]), 280),
    ].reduce(max);

    return max(minHeight, lines * lineHeight + verticalPadding);
  }

  List<DataColumn2> _columns() {
    return [
      _column("SOP", minWidth: 56),
      _column("ODD", minWidth: 90),
      _column("Lead\nHand", minWidth: 82),
      _column("Assembler", minWidth: 90),
      _column("Fixture", minWidth: 96),
      _column("Desc", minWidth: 280),
      _column("Qty", minWidth: 40),
      _column("Time To\nBuild/Per\nUnit", minWidth: 88),
      _column("Total\nTime To\nBuild", minWidth: 92),
      _column("Amount", minWidth: 70),
      _column("Inventory\nComment", minWidth: 220),
      _column("Picked", minWidth: 58),
      _column("Date Sent", minWidth: 90),
      _column("Dept", minWidth: 88),
      _column("Notice", minWidth: 200),
      _column("Response", minWidth: 200),
      _column("UOM", minWidth: 60),
      _column("Qty\nBackordered", minWidth: 90),
      _column("Qty\nReceived", minWidth: 90),
      // _column("Status", minWidth: 70),
    ];
  }

  bool isNotProduced(dynamic productionDateOut) {
    if (productionDateOut == null) return true;
    final value = productionDateOut.toString().trim();
    if (value.isEmpty || value == "0001-01-01T00:00:00.000Z") return true;
    final date = DateTime.tryParse(value);
    if (date == null) return true;
    return date.millisecondsSinceEpoch == 0;
  }

  Color? getPickedColor(Map<String, dynamic> row) {
    if (row["Picked"] != true) return null;

    final sop = row["SOP"];
    final log = sop is Map ? sop["ProductionLogEntry"] : null;
    final dateOut = log is Map ? log["ProductionDateOut"] : null;
    final backorders = row["Backorders"];

    final lightBlue =
        isNotProduced(dateOut) &&
        backorders is List &&
        backorders.any((b) {
          if (b is! Map) return false;
          return (num.tryParse('${b["Quantity"]}') ?? 0) !=
              (num.tryParse('${b["Received"]}') ?? 0);
        });

    return lightBlue ? const Color(0xFF99CCFF) : const Color(0xFF607D99);
  }

  Color? getResponseColor(Map<String, dynamic> row) {
    const lightRed = Color(0xFFD9534F);
    const darkRed = Color(0xFF913734);
    final bg = row["BgColor"] as Color?;
    if (bg == null) return null;

    if (_text(row["Response"]) != '-') return bg;
    if (bg == const Color(0xFFC9A1A1) || bg == const Color(0xFFFFCCCC)) {
      return bg;
    }

    final sop = row["SOP"];
    final log = sop is Map ? sop["ProductionLogEntry"] : null;
    final notProduced = isNotProduced(
      log is Map ? log["ProductionDateOut"] : null,
    );
    final type = row["NoticeType"]?.toString();

    if (type == 'purchasing') {
      return row["NotifyPurchasing"] == true && notProduced
          ? lightRed
          : darkRed;
    }
    if (type == 'backorder') {
      final qty = num.tryParse('${row["Qty (Backordered)"]}') ?? 0;
      final recv = num.tryParse('${row["Qty (Received)"]}') ?? 0;
      return qty != recv && notProduced ? lightRed : darkRed;
    }

    return bg == const Color(0xFF99CCFF) ? lightRed : darkRed;
  }

  void _clearSearch() {
    _searchController.clear();
    _filterRows('');
  }

  int _receivedValue(Map<String, dynamic> row) {
    final raw = '${row["Qty (Received)"]}'.trim();
    if (raw.isEmpty || raw == '-' || raw == 'null') return 0;
    return int.tryParse(raw) ?? 0;
  }

  Future<void> _saveChanges() async {
    final byTdgpn = <String, Map<int, List<Map<String, dynamic>>>>{};

    for (final row in _allRows) {
      if (row["NoticeType"] != "backorder") continue;

      final leadId = int.tryParse('${row["SOPLeadHandEntryId"]}');
      final boId = int.tryParse('${row["SOPBackorderEntryId"]}');
      if (leadId == null || boId == null) continue;

      final received = _receivedValue(row);
      final original = row["OriginalReceived"];
      final originalReceived = original is num
          ? original.toInt()
          : int.tryParse('$original') ?? 0;
      if (received == originalReceived) continue;

      final tdgpn = '${row["TDGPN"] ?? ''}'.trim();
      if (tdgpn.isEmpty) continue;

      byTdgpn.putIfAbsent(tdgpn, () => {}).putIfAbsent(leadId, () => []).add({
        "SOPBackorderEntryId": boId,
        "Received": received,
      });
    }

    if (byTdgpn.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No received qty changes to save")),
      );
      return;
    }

    try {
      await Dioservices.setToken();

      for (final entry in byTdgpn.entries) {
        final payload = {
          "TDGPN": entry.key,
          "entries": entry.value.entries
              .map((e) => {"SOPLeadHandEntryId": e.key, "backorders": e.value})
              .toList(),
        };
        print("SAVE PAYLOAD: $payload");
        final response = await _backorderService.backOrderUpdate(payload);
        print("RESPONSE FROM SAVE CHANGES API: ${response.data}");
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Saved successfully")));

      await _getCriticalItemList();
    } on DioException catch (e) {
      final serverMessage = e.response?.data;
      print("ERROR SAVING CHANGES: ${e.message}");
      print("SERVER RESPONSE: $serverMessage");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Save failed: ${serverMessage ?? e.message}")),
      );
    } catch (e) {
      print("ERROR SAVING CHANGES: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Save failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 700;

    const tableBorderColor = Color(0xFFD1D5DB);
    const clearBlue = Color(0xFF5BA3E0);
    const navy = Color(0xFF2F3E55);
    const saveGreen = Color(0xFF15803D);

    const tableBorder = TableBorder(
      top: BorderSide(color: tableBorderColor),
      bottom: BorderSide(color: tableBorderColor),
      left: BorderSide(color: tableBorderColor),
      right: BorderSide(color: tableBorderColor),
      horizontalInside: BorderSide(color: tableBorderColor),
      verticalInside: BorderSide(color: tableBorderColor),
    );

    final searchField = TextField(
      controller: _searchController,
      onChanged: _filterRows,
      decoration: InputDecoration(
        hintText: "Search in table...",
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF607D99), width: 1.5),
        ),
      ),
    );

    final clearButton = OutlinedButton(
      onPressed: _clearSearch,
      style: OutlinedButton.styleFrom(
        foregroundColor: clearBlue,
        side: const BorderSide(color: clearBlue),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: const Text("Clear", style: TextStyle(fontWeight: FontWeight.w600)),
    );

    final addManualButton = ElevatedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.add, size: 18),
      label: const Text("Add Manually Entry"),
      style: ElevatedButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );

    final saveButton = ElevatedButton.icon(
      onPressed: _saveChanges,
      icon: const Icon(Icons.save, size: 18),
      label: const Text("Save"),
      style: ElevatedButton.styleFrom(
        backgroundColor: saveGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );

    final headerBar = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: isTablet
          ? Row(
              children: [
                const Text(
                  "Backorder",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(width: 280, child: searchField),
                const SizedBox(width: 10),
                clearButton,
                const Spacer(),
                addManualButton,
                const SizedBox(width: 10),
                saveButton,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Backorder",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 12),
                searchField,
                const SizedBox(height: 10),
                clearButton,
                const SizedBox(height: 10),
                addManualButton,
                const SizedBox(height: 10),
                saveButton,
              ],
            ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(),
      drawer: const CommonDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerBar,
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 12),
                Expanded(
                  child: _isLoading || _rows.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF607D99)))
                      : Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF9AA8B8),
                                  ),
                                ),
                                child: ClipRRect(
                                  child: DataTable2(
                                    fixedTopRows: 1,
                                    showCheckboxColumn: false,
                                    headingRowColor: MaterialStateProperty.all(
                                      const Color(0xFF344963),
                                    ),
                                    dataRowColor: MaterialStateProperty.all(
                                      Colors.white,
                                    ),
                                    headingRowHeight: 52,
                                    dataRowHeight: 52,
                                    columnSpacing: 0,
                                    horizontalMargin: 0,
                                    dividerThickness: 1,
                                    minWidth: 2200,
                                    border: tableBorder,
                                    columns: _columns(),
                                    rows: _pagedRows.map((row) {
                                return DataRow2(
                                  specificRowHeight: _rowHeightFor(row),
                                  cells: [
                                    DataCell(
                                      _tableTextCell(
                                        _text(row["SOP"]["SOPNum"].toString()),
                                        width: 56,
                                      ),
                                    ),
                                    DataCell(
                                      _tableTextCell(
                                        _formatDate(
                                          row["SOP"]["ODD"].toString(),
                                        ),
                                        width: 90,
                                      ),
                                    ),
                                    DataCell(
                                      _tableTextCell(
                                        _text(
                                          row["SOP"]["ProductionLogEntry"]["LeadHand"]["LeadHandName"]
                                              .toString(),
                                        ),
                                        width: 82,
                                      ),
                                    ),
                                    DataCell(
                                      _tableTextCell(
                                        _text(
                                          row["Assembler"]["Name"].toString(),
                                        ),
                                        width: 90,
                                      ),
                                    ),
                                    DataCell(
                                      _tableTextCell(
                                        _text(row["FixtureNumber"].toString()),
                                        width: 96,
                                      ),
                                    ),
                                    DataCell(
                                      _tableTextCell(
                                        _text(row["FixtureDescription"]),
                                        width: 280,
                                        maxLines: 4,
                                      ),
                                    ),
                                    DataCell(
                                      _tableTextCell(
                                        _text(row["Quantity"].toString()),
                                        width: 40,
                                      ),
                                    ),
                                    DataCell(
                                      _tableTextCell(
                                        _text(row["Hours"].toString()),
                                        width: 88,
                                      ),
                                    ),
                                    DataCell(
                                      _tableTextCell(
                                        _text(
                                          "${((((row["Quantity"] as num?) ?? 0) * ((row["Hours"] as num?) ?? 0)).ceil())}h",
                                        ),
                                        width: 92,
                                      ),
                                    ),
                                    DataCell(
                                      _tableTextCell(
                                        _text(row["Amount"].toString()),
                                        width: 70,
                                      ),
                                    ),
                                    DataCell(
                                      _tableTextCell(
                                        _text(row["InventoryComments"]),
                                        width: 220,
                                        maxLines: 4,
                                      ),
                                    ),
                                    DataCell(
                                      _fillBgCell(
                                        row["Picked"] == true ? "Yes" : "No",
                                        getPickedColor(row),
                                      ),
                                    ),
                                    DataCell(
                                      _fillBgCell(
                                        _text(row["DateSent"]),
                                        row["BgColor"] as Color?,
                                      ),
                                    ),
                                    DataCell(
                                      _fillBgCell(
                                        _text(row["Dept"]),
                                        row["BgColor"] as Color?,
                                      ),
                                    ),
                                    DataCell(
                                      _fillBgCell(
                                        _text(row["Notice"]),
                                        row["BgColor"] as Color?,
                                        maxLines: 4,
                                      ),
                                    ),
                                    DataCell(
                                      _fillBgCell(
                                        _text(row["Response"]),
                                        getResponseColor(row),
                                        maxLines: 4,
                                      ),
                                    ),
                                    DataCell(
                                      _tableTextCell(
                                        _text(row["UOM"].toString()),
                                        width: 60,
                                      ),
                                    ),
                                    DataCell(
                                      _tableTextCell(
                                        _text(
                                          row["Qty (Backordered)"].toString(),
                                        ),
                                        width: 90,
                                      ),
                                    ),
                                    DataCell(
                                      row["NoticeType"] == "backorder"
                                          ? _receivedQtyField(row)
                                          : _tableTextCell("-", width: 90),
                                    ),
                                    // DataCell(
                                    //   Padding(
                                    //     padding: const EdgeInsets.symmetric(
                                    //       horizontal: 8,
                                    //     ),
                                    //     child: OutlinedButton(
                                    //       onPressed: () {},
                                    //       style: OutlinedButton.styleFrom(
                                    //         minimumSize: const Size(80, 38),
                                    //         backgroundColor: const Color(0xFF1E88E5),
                                    //         side: const BorderSide(
                                    //           color: Color(0xFF344963),
                                    //         ),
                                    //         shape: RoundedRectangleBorder(
                                    //           borderRadius: BorderRadius.circular(3),
                                    //         ),
                                    //       ),
                                    //       child: Text(
                                    //         row["Status"].toString(),
                                    //         style: const TextStyle(
                                    //           fontSize: 13,
                                    //           color: Color(0xFFF0F1F3),
                                    //           fontWeight: FontWeight.w600,
                                    //         ),
                                    //       ),
                                    //     ),
                                    //   ),
                                    // ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      if (_rows.isNotEmpty)
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(color: Color(0xFF9AA8B8)),
                              right: BorderSide(color: Color(0xFF9AA8B8)),
                              bottom: BorderSide(color: Color(0xFF9AA8B8)),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: PaginationBar(
                            currentPage: _currentPage.clamp(1, _totalPages),
                            totalPages: _totalPages,
                            onPageChanged: (page) {
                              setState(() => _currentPage = page);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
