import 'dart:math';
import 'package:data_table_2/data_table_2.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:overview_app/Screen/Backorder/Services/BackorderService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Utils/api_date.dart';
import 'package:overview_app/Utils/responsive.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/AppToast.dart';
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
  static const int _lastSortableColumnIndex = 11; // Picked (Date Sent+ not sortable)
  bool _isLoading = false;
  int? _sortColumnIndex;
  bool _sortAscending = true;

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
    if (raw == '-' || raw.trim().isEmpty) return '-';
    return ApiDate.formatMmDdYyyy(raw, empty: '-');
  }

  String _formatAmount(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw == '-' || raw.toLowerCase() == 'null') {
      return '\$0';
    }
    if (raw.startsWith('\$')) return raw;

    final n = num.tryParse(raw.replaceAll(',', ''));
    if (n == null) return '\$$raw';

    if (n == n.roundToDouble()) {
      return '\$${n.toInt()}';
    }
    return '\$${n.toStringAsFixed(2)}';
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
      // print("RESPONSE FROM CRITICAL ITEM LIST API: ${response.data}");

      final payload = response.data;
      final rawData = payload is Map ? payload['data'] : payload;
      final data = _parseRows(rawData is List ? rawData : null);

      if (!mounted) return;
      setState(() {
        _allRows
          ..clear()
          ..addAll(data);
        _applySearchFilter();
        _isLoading = false;
      });
    } catch (e) {
      print('Error in _getCriticalItemList: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  bool _rowMatches(Map<String, dynamic> row, String search) {
    return _matchesNoticePartNumber(row, search);
  }

  bool _matchesNoticePartNumber(Map<String, dynamic> row, String search) {
    final tdgpn = _text(row["TDGPN"]).toLowerCase();
    if (tdgpn.isNotEmpty && tdgpn != '-' && tdgpn.contains(search)) {
      return true;
    }

    // Backorder notices: "Missing: <TDGPN> (qty) UOM"
    final notice = _text(row["Notice"]);
    if (notice.isEmpty || notice == '-') return false;

    final missingMatch = RegExp(
      r'missing:\s*([^\s(]+)',
      caseSensitive: false,
    ).firstMatch(notice);
    final part = missingMatch?.group(1)?.toLowerCase() ?? '';
    return part.isNotEmpty && part.contains(search);
  }

  void _applySearchFilter() {
    _rows.clear();
    if (_searchQuery.isEmpty) {
      _rows.addAll(_allRows);
    } else {
      _rows.addAll(_allRows.where((row) => _rowMatches(row, _searchQuery)));
    }
  }

  void _filterRows(String value) {
    final search = value.toLowerCase().trim();

    setState(() {
      _searchQuery = search;
      _currentPage = 1;
      _applySearchFilter();
    });
  }

  int get _totalPages =>
      _rows.isEmpty ? 1 : ((_rows.length + _rowsPerPage - 1) ~/ _rowsPerPage);

  String _sopNum(Map<String, dynamic> row) {
    final sop = row['SOP'];
    if (sop is Map) return _text(sop['SOPNum']);
    return '';
  }

  String _oddRaw(Map<String, dynamic> row) {
    final sop = row['SOP'];
    if (sop is Map) return _text(sop['ODD']);
    return '';
  }

  String _leadHandName(Map<String, dynamic> row) {
    final sop = row['SOP'];
    final log = sop is Map ? sop['ProductionLogEntry'] : null;
    final leadHand = log is Map ? log['LeadHand'] : null;
    if (leadHand is Map) return _text(leadHand['LeadHandName']);
    return '';
  }

  String _assemblerName(Map<String, dynamic> row) {
    final assembler = row['Assembler'];
    if (assembler is Map) return _text(assembler['Name']);
    return '';
  }

  double _numFromRow(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final n = num.tryParse(_text(row[key]).replaceAll(',', ''));
      if (n != null) return n.toDouble();
    }
    return 0;
  }

  double _totalBuildHours(Map<String, dynamic> row) {
    final qty = _numFromRow(row, ['Quantity']);
    final hours = _numFromRow(row, ['Hours']);
    return (qty * hours).ceilToDouble();
  }

  int _pickedSortKey(Map<String, dynamic> row) => row['Picked'] == true ? 1 : 0;

  int _compareForSort(Map<String, dynamic> a, Map<String, dynamic> b, int col) {
    switch (col) {
      case 0:
        final sa = _sopNum(a);
        final sb = _sopNum(b);
        final ia = int.tryParse(sa);
        final ib = int.tryParse(sb);
        if (ia != null && ib != null) return ia.compareTo(ib);
        return sa.toLowerCase().compareTo(sb.toLowerCase());
      case 1:
        final da = ApiDate.parseFlexible(_oddRaw(a));
        final db = ApiDate.parseFlexible(_oddRaw(b));
        if (da != null && db != null) return da.compareTo(db);
        if (da != null) return -1;
        if (db != null) return 1;
        return _oddRaw(a).toLowerCase().compareTo(_oddRaw(b).toLowerCase());
      case 2:
        return _leadHandName(
          a,
        ).toLowerCase().compareTo(_leadHandName(b).toLowerCase());
      case 3:
        return _assemblerName(
          a,
        ).toLowerCase().compareTo(_assemblerName(b).toLowerCase());
      case 4:
        return _text(
          a['FixtureNumber'],
        ).toLowerCase().compareTo(_text(b['FixtureNumber']).toLowerCase());
      case 5:
        return _text(
          a['FixtureDescription'],
        ).toLowerCase().compareTo(_text(b['FixtureDescription']).toLowerCase());
      case 6:
        return _numFromRow(
          a,
          ['Quantity'],
        ).compareTo(_numFromRow(b, ['Quantity']));
      case 7:
        return _numFromRow(a, ['Hours']).compareTo(_numFromRow(b, ['Hours']));
      case 8:
        return _totalBuildHours(a).compareTo(_totalBuildHours(b));
      case 9:
        return _numFromRow(a, ['Amount']).compareTo(_numFromRow(b, ['Amount']));
      case 10:
        return _text(
          a['InventoryComments'],
        ).toLowerCase().compareTo(_text(b['InventoryComments']).toLowerCase());
      case 11:
        return _pickedSortKey(a).compareTo(_pickedSortKey(b));
      default:
        return 0;
    }
  }

  List<Map<String, dynamic>> get _sortedRows {
    final list = List<Map<String, dynamic>>.from(_rows);
    final col = _sortColumnIndex;
    if (col == null || col > _lastSortableColumnIndex) return list;

    list.sort((a, b) {
      final cmp = _compareForSort(a, b, col);
      if (cmp != 0) return _sortAscending ? cmp : -cmp;
      return _sopNum(a).compareTo(_sopNum(b));
    });
    return list;
  }

  void _onSort(int columnIndex, bool ascending) {
    if (columnIndex > _lastSortableColumnIndex) return;
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _currentPage = 1;
    });
  }

  List<Map<String, dynamic>> get _pagedRows {
    final sorted = _sortedRows;
    if (sorted.isEmpty) return [];
    final page = _currentPage.clamp(1, _totalPages);
    final start = (page - 1) * _rowsPerPage;
    final end = min(start + _rowsPerPage, sorted.length);
    return sorted.sublist(start, end);
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

  Widget _heading(String text, {required int columnIndex}) {
    final multi = text.contains('\n');
    final sortable = columnIndex <= _lastSortableColumnIndex;
    final active = sortable && _sortColumnIndex == columnIndex;
    final up = !active || _sortAscending;

    const textStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 12,
      height: 1.15,
    );

    final sortIcon = sortable
        ? Icon(
            up ? Icons.arrow_upward : Icons.arrow_downward,
            size: 11,
            color: active ? Colors.white : const Color(0x99B8C8E8),
          )
        : null;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: multi
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      text,
                      textAlign: TextAlign.left,
                      maxLines: 3,
                      softWrap: true,
                      overflow: TextOverflow.clip,
                      style: textStyle,
                    ),
                  ),
                  if (sortIcon != null) ...[
                    const SizedBox(width: 2),
                    sortIcon,
                  ],
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      text,
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: textStyle,
                    ),
                  ),
                  if (sortIcon != null) ...[
                    const SizedBox(width: 4),
                    sortIcon,
                  ],
                ],
              ),
      ),
    );
  }

  DataColumn2 _fixedColumn(
    String text, {
    required double width,
    required int columnIndex,
  }) {
    final sortable = columnIndex <= _lastSortableColumnIndex;
    return DataColumn2(
      headingRowAlignment: MainAxisAlignment.start,
      fixedWidth: width,
      onSort: sortable ? _onSort : null,
      label: SizedBox(
        width: width,
        child: _heading(text, columnIndex: columnIndex),
      ),
    );
  }

  DataColumn2 _scrollColumn(
    String text, {
    required double minWidth,
    required int columnIndex,
  }) {
    final sortable = columnIndex <= _lastSortableColumnIndex;
    return DataColumn2(
      headingRowAlignment: MainAxisAlignment.start,
      minWidth: minWidth,
      size: ColumnSize.S,
      onSort: sortable ? _onSort : null,
      label: SizedBox(
        width: minWidth,
        child: _heading(text, columnIndex: columnIndex),
      ),
    );
  }

  /// SOP / ODD / Lead Hand keep fixed widths and stay sticky.
  /// Other columns use minWidth only (not fixedWidth) so DataTable2 can
  /// scroll horizontally without asserting.
  static const double _sopW = 56;
  static const double _oddW = 90;
  static const double _leadHandW = 80;
  static const double _fixtureW = 96;
  static const List<double> _otherPreferred = [
    96, // Assembler
    96, // Fixture
    150, // Desc
    52, // Qty
    104, // Time To Build/Per Unit
    100, // Total Time To Build
    80, // Amount
    120, // Inventory Comment
    72, // Picked
    88, // Date Sent
    72, // Dept
    260, // Notice
    130, // Response
    48, // UOM
    72, // B/O QTY
    56, // QTY (Received)
  ];

  Widget _tableTextCell(
    String text, {
    double? width = 90,
    TextAlign align = TextAlign.left,
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: child,
          ),
        );
      },
    );
  }

  Widget _fillBgCell(
    String text,
    Color? color, {
    int maxLines = 5,
    bool showTooltip = false,
  }) {
    final content = Align(
      alignment: Alignment.centerLeft,
      child: _tableTextCell(text, width: null, maxLines: maxLines),
    );

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        if (color != null) ColoredBox(color: color),
        if (showTooltip && text.isNotEmpty && text != '-')
          Tooltip(
            message: text,
            waitDuration: const Duration(milliseconds: 400),
            child: content,
          )
        else
          content,
      ],
    );
  }

  Widget _receivedQtyField(Map<String, dynamic> row) {
    final raw = _text(row["Qty (Received)"]);
    final value = raw == '-' ? '0' : raw;
    final maxQty = num.tryParse('${row["Qty (Backordered)"]}') ?? 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: SizedBox(
          width: 64,
          height: 34,
          child: _ReceivedQtyInput(
            key: ValueKey('received-${row["SOPBackorderEntryId"]}'),
            initialValue: value,
            maxQty: maxQty,
            onChanged: (v) {
              row["Qty (Received)"] = v;
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

    int estimateLines(String text, double columnWidth, {int maxLines = 4}) {
      if (text.isEmpty || text == '-') return 1;
      final charsPerLine = max(12, (columnWidth / 7).floor());
      return min(maxLines, max(1, (text.length / charsPerLine).ceil()));
    }

    final lines = [
      estimateLines(_text(row["InventoryComments"]), 120),
      estimateLines(_text(row["FixtureDescription"]), 140),
      estimateLines(_text(row["Notice"]), 260, maxLines: 8),
      estimateLines(_text(row["Response"]), 120),
    ].reduce(max);

    return max(minHeight, lines * lineHeight + verticalPadding);
  }

  List<DataColumn2> _columns() {
    final other = _otherPreferred;
    return [
      _fixedColumn("SOP", width: _sopW, columnIndex: 0),
      _fixedColumn("ODD", width: _oddW, columnIndex: 1),
      _fixedColumn("Lead Hand", width: _leadHandW, columnIndex: 2),
      _scrollColumn("Assembler", minWidth: other[0], columnIndex: 3),
      _scrollColumn("Fixture", minWidth: other[1], columnIndex: 4),
      _scrollColumn("Desc", minWidth: other[2], columnIndex: 5),
      _scrollColumn("Qty", minWidth: other[3], columnIndex: 6),
      _scrollColumn(
        "Time To Build/\nPer Unit",
        minWidth: other[4],
        columnIndex: 7,
      ),
      _scrollColumn(
        "Total Time\nTo Build",
        minWidth: other[5],
        columnIndex: 8,
      ),
      _scrollColumn("Amount", minWidth: other[6], columnIndex: 9),
      _scrollColumn("Inventory\nComment", minWidth: other[7], columnIndex: 10),
      _scrollColumn("Picked", minWidth: other[8], columnIndex: 11),
      _scrollColumn("Date Sent", minWidth: other[9], columnIndex: 12),
      _scrollColumn("Dept", minWidth: other[10], columnIndex: 13),
      _scrollColumn("Notice", minWidth: other[11], columnIndex: 14),
      _scrollColumn("Response", minWidth: other[12], columnIndex: 15),
      _scrollColumn("UOM", minWidth: other[13], columnIndex: 16),
      _scrollColumn("B/O QTY", minWidth: other[14], columnIndex: 17),
      _scrollColumn("QTY", minWidth: other[15], columnIndex: 18),
    ];
  }

  double get _tableMinWidth {
    const sticky = _sopW + _oddW + _leadHandW;
    final preferredOthers = _otherPreferred.fold<double>(0, (a, b) => a + b);
    return sticky + preferredOthers;
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

      final sop = row["SOP"];
      final sopNum = sop is Map ? '${sop["SOPNum"] ?? ''}'.trim() : '';

      // pendingAdjustments = new QTY - original QTY (e.g. 0 - 1 = -1)
      byTdgpn.putIfAbsent(tdgpn, () => {}).putIfAbsent(leadId, () => []).add({
        "SOPBackorderEntryId": boId,
        "Received": received,
        "SOP": sopNum,
        "pendingAdjustments": received - originalReceived,
      });
    }

    if (byTdgpn.isEmpty) {
      if (!mounted) return;
      AppToast.error(context, "No received qty changes to save");
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

        print('SAVE PAYLOAD: $payload');
        await _backorderService.backOrderUpdate(payload);
      }

      if (!mounted) return;
      AppToast.success(context, "Saved successfully");

      await _getCriticalItemList();
    } on DioException catch (e) {
      // print("ERROR SAVING CHANGES: ${e.message}");
      if (!mounted) return;
      AppToast.errorFrom(context, e, fallback: 'Save failed');
    } catch (e) {
      print("ERROR SAVING CHANGES: $e");
      if (!mounted) return;
      AppToast.errorFrom(context, e, fallback: 'Save failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 700;
    final r = Responsive.of(context);

    const tableBorderColor = Color(0xFFD1D5DB);
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
      style: TextStyle(fontSize: r.searchFieldFontSize),
      decoration: InputDecoration(
        hintText: 'Search by part number...',
        hintStyle: TextStyle(
          fontSize: r.searchFieldFontSize,
          color: const Color(0xFF9AA8B8),
          fontWeight: FontWeight.w500,
        ),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: r.searchFieldContentPaddingV,
        ),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                onPressed: _clearSearch,
                icon: const Icon(Icons.clear, size: 20),
              ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.fieldRadius),
          borderSide: BorderSide(
            color: isTablet ? const Color(0xFFBDBDBD) : const Color(0xFF2196F3),
            width: isTablet ? 1 : 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.fieldRadius),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
      ),
    );

    final addManualButton = SizedBox(
      height: isTablet ? null : r.searchButtonHeight,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: Icon(Icons.add, size: r.searchIconSize),
        label: Text(
          'Add Manually Entry',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isTablet ? 14 : r.searchButtonFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.fieldRadius),
          ),
        ),
      ),
    );

    final saveButton = SizedBox(
      height: isTablet ? null : r.searchButtonHeight,
      child: ElevatedButton.icon(
        onPressed: _saveChanges,
        icon: Icon(Icons.save, size: r.searchIconSize),
        label: Text(
          'Save',
          style: TextStyle(
            fontSize: isTablet ? 14 : r.searchButtonFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: saveGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.fieldRadius),
          ),
        ),
      ),
    );

    final headerBar = isTablet
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Text(
                  'Backorder',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(width: 280, child: searchField),
                const Spacer(),
                addManualButton,
                const SizedBox(width: 10),
                saveButton,
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Backorder',
                style: TextStyle(
                  fontSize: r.pageTitleSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: r.sectionGap),
              searchField,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(flex: 2, child: addManualButton),
                  const SizedBox(width: 8),
                  Expanded(flex: 1, child: saveButton),
                ],
              ),
            ],
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
              if (_allRows.isNotEmpty || _isLoading) ...[
                const SizedBox(height: 12),
                Expanded(
                  child: _isLoading
                      ? const Center(child: AppLoader())
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
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      scrollbarTheme: const ScrollbarThemeData(
                                        thickness: WidgetStatePropertyAll(0),
                                        thumbVisibility: WidgetStatePropertyAll(
                                          false,
                                        ),
                                        trackVisibility: WidgetStatePropertyAll(
                                          false,
                                        ),
                                        crossAxisMargin: 0,
                                        mainAxisMargin: 0,
                                        minThumbLength: 0,
                                      ),
                                    ),
                                    child: Responsive.hideScrollbars(
                                      context,
                                      DataTable2(
                                        fixedTopRows: 1,
                                        fixedLeftColumns: isTablet ? 3 : 0,
                                        fixedColumnsColor: Colors.white,
                                        fixedCornerColor: const Color(
                                          0xFF344963,
                                        ),
                                        showCheckboxColumn: false,
                                        sortColumnIndex: _sortColumnIndex,
                                        sortAscending: _sortAscending,
                                        sortArrowBuilder: (_, __) =>
                                            const SizedBox.shrink(),
                                        headingRowColor:
                                            MaterialStateProperty.all(
                                              const Color(0xFF344963),
                                            ),
                                        dataRowColor: MaterialStateProperty.all(
                                          Colors.white,
                                        ),
                                        headingRowHeight: 58,
                                        dataRowHeight: 52,
                                        columnSpacing: 0,
                                        horizontalMargin: 0,
                                        dividerThickness: 1,
                                        isHorizontalScrollBarVisible: false,
                                        isVerticalScrollBarVisible: false,
                                        minWidth: _tableMinWidth,
                                        border: tableBorder,
                                        columns: _columns(),
                                        rows: _pagedRows.map((row) {
                                          final sop = row["SOP"];
                                          final log = sop is Map
                                              ? sop["ProductionLogEntry"]
                                              : null;
                                          final leadHand = log is Map
                                              ? log["LeadHand"]
                                              : null;
                                          final assembler = row["Assembler"];

                                          return DataRow2(
                                            specificRowHeight: _rowHeightFor(
                                              row,
                                            ),
                                            cells: [
                                              DataCell(
                                                _tableTextCell(
                                                  _text(
                                                    sop is Map
                                                        ? sop["SOPNum"]
                                                        : null,
                                                  ),
                                                  width: _sopW,
                                                ),
                                              ),
                                              DataCell(
                                                _tableTextCell(
                                                  _formatDate(
                                                    _text(
                                                      sop is Map
                                                          ? sop["ODD"]
                                                          : null,
                                                    ),
                                                  ),
                                                  width: _oddW,
                                                ),
                                              ),
                                              DataCell(
                                                _tableTextCell(
                                                  _text(
                                                    leadHand is Map
                                                        ? leadHand["LeadHandName"]
                                                        : null,
                                                  ),
                                                  width: _leadHandW,
                                                ),
                                              ),
                                              DataCell(
                                                _tableTextCell(
                                                  _text(
                                                    assembler is Map
                                                        ? assembler["Name"]
                                                        : null,
                                                  ),
                                                  width: null,
                                                ),
                                              ),
                                              DataCell(
                                                _tableTextCell(
                                                  _text(row["FixtureNumber"]),
                                                  width: _fixtureW,
                                                ),
                                              ),
                                              DataCell(
                                                _tableTextCell(
                                                  _text(
                                                    row["FixtureDescription"],
                                                  ),
                                                  width: null,
                                                  maxLines: 4,
                                                ),
                                              ),
                                              DataCell(
                                                _tableTextCell(
                                                  _text(row["Quantity"]),
                                                  width: null,
                                                ),
                                              ),
                                              DataCell(
                                                _tableTextCell(
                                                  _text(row["Hours"]),
                                                  width: null,
                                                ),
                                              ),
                                              DataCell(
                                                _tableTextCell(
                                                  _text(
                                                    "${((((row["Quantity"] as num?) ?? 0) * ((row["Hours"] as num?) ?? 0)).ceil())}h",
                                                  ),
                                                  width: null,
                                                ),
                                              ),
                                              DataCell(
                                                _tableTextCell(
                                                  _formatAmount(row["Amount"]),
                                                  width: null,
                                                ),
                                              ),
                                              DataCell(
                                                _tableTextCell(
                                                  _text(
                                                    row["InventoryComments"],
                                                  ),
                                                  width: null,
                                                  maxLines: 4,
                                                ),
                                              ),
                                              DataCell(
                                                _fillBgCell(
                                                  row["Picked"] == true
                                                      ? "Yes"
                                                      : "No",
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
                                                  maxLines: 8,
                                                  showTooltip: true,
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
                                                  _text(row["UOM"]),
                                                  width: null,
                                                ),
                                              ),
                                              DataCell(
                                                _tableTextCell(
                                                  _text(
                                                    row["Qty (Backordered)"],
                                                  ),
                                                  width: null,
                                                ),
                                              ),
                                              DataCell(
                                                row["NoticeType"] == "backorder"
                                                    ? _receivedQtyField(row)
                                                    : _tableTextCell(
                                                        "-",
                                                        width: null,
                                                      ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
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
                                    bottom: BorderSide(
                                      color: Color(0xFF9AA8B8),
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: PaginationBar(
                                  currentPage: _currentPage.clamp(
                                    1,
                                    _totalPages,
                                  ),
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

/// Qty Received input that cannot exceed [maxQty] (Qty Backordered).
class _ReceivedQtyInput extends StatefulWidget {
  const _ReceivedQtyInput({
    super.key,
    required this.initialValue,
    required this.maxQty,
    required this.onChanged,
  });

  final String initialValue;
  final num maxQty;
  final ValueChanged<String> onChanged;

  @override
  State<_ReceivedQtyInput> createState() => _ReceivedQtyInputState();
}

class _ReceivedQtyInputState extends State<_ReceivedQtyInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatQty(num value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toString();
  }

  void _applyValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      widget.onChanged('0');
      return;
    }

    final parsed = num.tryParse(trimmed);
    if (parsed == null) {
      widget.onChanged(trimmed);
      return;
    }

    if (parsed > widget.maxQty) {
      final capped = _formatQty(widget.maxQty);
      if (_controller.text != capped) {
        _controller.value = TextEditingValue(
          text: capped,
          selection: TextSelection.collapsed(offset: capped.length),
        );
      }
      widget.onChanged(capped);
      return;
    }

    widget.onChanged(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
      onChanged: _applyValue,
    );
  }
}
