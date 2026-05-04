import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:overview_app/Screen/OpenItems/Services/OpenItemsServices.dart';
import 'package:overview_app/Screen/Public-Search/PublicSearch.dart';

/// Table header background (dark blue-gray).
const Color _kTableHeaderBg = Color(0xFF3C4B64);

/// Primary actions / closed buttons.
const Color _kPrimaryBlue = Color(0xFF1976D2);

const Color _kQtyGreen = Color(0xFF2E7D32);

const Color _kFixtureFill = Color(0xFFE3F2FD);

const Color _kFixtureBorder = Color(0xFF1976D2);

const Color _yellow = Color(0xFFFFC107);

class BackOrder extends StatefulWidget {
  const BackOrder({
    super.key,
    this.sop = '',
    this.leadHand = '',
    this.assembler = '',
    this.odd = '',
    this.fixtureId = '',
    this.description = '',
    this.qty = '',
    this.purchasingNotice = '',
    this.onUpdateEntry,
    this.onNewSearch,
    this.onPurchasingClosed,
    this.onPicked,
    this.onProductionClosed,
    this.onAddBackorder,
    this.sopLeadHandEntryId,
    this.showNewSearchButton = true,
  });

  final String sop;
  final String leadHand;
  final String assembler;
  final String odd;
  final String fixtureId;
  final String description;
  final String qty;
  final String purchasingNotice;
  final String? sopLeadHandEntryId;
  final bool showNewSearchButton;

  final VoidCallback? onUpdateEntry;
  final VoidCallback? onNewSearch;
  final VoidCallback? onPurchasingClosed;
  final VoidCallback? onPicked;
  final VoidCallback? onProductionClosed;
  final VoidCallback? onAddBackorder;

  @override
  State<BackOrder> createState() => _BackOrderState();
}

class _BackOrderState extends State<BackOrder> {
  late final TextEditingController _purchasingNoticeCtrl;
  late final TextEditingController _purchasingResponseCtrl;
  late final TextEditingController _productionNoticeCtrl;
  late final TextEditingController _productionResponseCtrl;
  late final TextEditingController _inventoryCommentCtrl;
  Map<String, dynamic>? _apiItem;
  bool? _notifyPurchasingOverride;
  bool? _pickedOverride;
  bool? _notifyProductionOverride;
  final List<Map<String, dynamic>> _editableBackorders = [];
  final List<_DraftBackorderRow> _draftBackorders = [];

  static InputDecoration _fieldDecoration({
    String? hint,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 10,
    ),
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: Colors.grey[400]!),
    );
    return InputDecoration(
      isDense: true,
      hintText: hint,
      contentPadding: contentPadding,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: _kPrimaryBlue, width: 1.2),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _purchasingNoticeCtrl = TextEditingController(
      text: widget.purchasingNotice,
    );
    _purchasingResponseCtrl = TextEditingController();
    _productionNoticeCtrl = TextEditingController();
    _productionResponseCtrl = TextEditingController();
    _inventoryCommentCtrl = TextEditingController();
    _fetchDetailByLeadHandEntryId();
  }

  @override
  void didUpdateWidget(covariant BackOrder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.purchasingNotice != widget.purchasingNotice &&
        _purchasingNoticeCtrl.text != widget.purchasingNotice) {
      _purchasingNoticeCtrl.text = widget.purchasingNotice;
    }
    if (oldWidget.sopLeadHandEntryId != widget.sopLeadHandEntryId) {
      _fetchDetailByLeadHandEntryId();
    }
  }

  Future<void> _fetchDetailByLeadHandEntryId() async {
    final id = widget.sopLeadHandEntryId?.trim() ?? '';
    if (id.isEmpty) return;
    try {
      final response = await OpenItemsServices().SearchOpenItemsByFixtureId(
        sopLeadHandEntryId: id,
      );
      final parsed =
          _mapFromSpecificInventoryResponse(response.data, id) ??
          _firstMapFromResponse(response.data);
      if (!mounted || parsed == null) return;
      setState(() {
        _apiItem = parsed;
        _editableBackorders
          ..clear()
          ..addAll(_extractBackorders(parsed));
        _notifyPurchasingOverride = null;
        _pickedOverride = null;
        _notifyProductionOverride = null;
      });
      final notice = _valueFromItem(_apiItem, [
        'LeadHandCommentsForPurchasing',
      ]);
      if (notice.isNotEmpty) {
        _purchasingNoticeCtrl.text = notice;
      }
      final productionNotice = _valueFromItem(_apiItem, [
        'InventoryCommentsForProduction',
      ]);
      if (productionNotice.isNotEmpty) {
        _productionNoticeCtrl.text = productionNotice;
      }
      final productionResponse = _valueFromItem(_apiItem, [
        'ProductionComments',
      ]);
      if (productionResponse.isNotEmpty) {
        _productionResponseCtrl.text = productionResponse;
      }
    } catch (_) {}
  }

  Map<String, dynamic>? _mapFromSpecificInventoryResponse(
    dynamic body,
    String sopLeadHandEntryId,
  ) {
    if (body is! Map) return null;
    final root = Map<String, dynamic>.from(body);
    final data = root['data'];
    if (data is! Map) return null;
    final dataMap = Map<String, dynamic>.from(data);
    final specificInventoryData = dataMap['specificInventoryData'];
    if (specificInventoryData is! List || specificInventoryData.isEmpty) {
      return null;
    }
    final first = specificInventoryData.first;
    if (first is! Map) return null;
    final sopItem = Map<String, dynamic>.from(first);

    Map<String, dynamic>? targetEntry;
    final leadHandEntries = sopItem['LeadHandEntries'];
    if (leadHandEntries is List) {
      for (final e in leadHandEntries) {
        if (e is! Map) continue;
        final map = Map<String, dynamic>.from(e);
        final id = (map['SOPLeadHandEntryId'] ?? '').toString();
        if (id == sopLeadHandEntryId) {
          targetEntry = map;
          break;
        }
      }
      targetEntry ??= leadHandEntries.isNotEmpty && leadHandEntries.first is Map
          ? Map<String, dynamic>.from(leadHandEntries.first)
          : null;
    }

    final production = sopItem['ProductionLogEntry'];
    String leadHandName = '';
    if (production is Map) {
      final leadHand = production['LeadHand'];
      if (leadHand is Map) {
        leadHandName = (leadHand['LeadHandName'] ?? '').toString();
      }
    }

    final entry = targetEntry;
    final assembler = entry?['Assembler'];
    String assemblerName = '';
    if (assembler is Map) {
      assemblerName = (assembler['Name'] ?? '').toString();
    }

    if (targetEntry == null) {
      return {...sopItem, 'SOP': sopItem['SOPNum'], 'LeadHand': leadHandName};
    }

    return {
      ...sopItem,
      ...entry!,
      'SOP': sopItem['SOPNum'],
      'LeadHand': leadHandName,
      'Assembler': assemblerName,
      'Description': entry['FixtureDescription'],
      'Components': dataMap['fixturesComponents'] is Map
          ? (Map<String, dynamic>.from(
              dataMap['fixturesComponents'],
            ))['Components']
          : null,
    };
  }

  Map<String, dynamic>? _firstMapFromResponse(dynamic body, [int depth = 0]) {
    if (body == null || depth > 10) return null;
    if (body is Map<String, dynamic>) return body;
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      for (final value in map.values) {
        final nested = _firstMapFromResponse(value, depth + 1);
        if (nested != null) return nested;
      }
      return map;
    }
    if (body is List && body.isNotEmpty) {
      final first = body.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  String _valueFromItem(Map<String, dynamic>? item, List<String> keys) {
    if (item == null) return '';
    for (final key in keys) {
      final value = item[key];
      if (value == null) continue;
      if (value is List) {
        for (final e in value) {
          if (e == null) continue;
          final text = e.toString().trim();
          if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
        }
        continue;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  List<Map<String, dynamic>> _extractBackorders(Map<String, dynamic>? item) {
    final raw = item?['Backorders'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _syncClosedDateForBackorder(Map<String, dynamic> row) {
    final quantity = int.tryParse((row['Quantity'] ?? '').toString()) ?? 0;
    final received = int.tryParse((row['Received'] ?? '').toString()) ?? 0;

    if (quantity > 0 && quantity == received) {
      // Always stamp latest edited matching row with current UTC date-time.
      row['ClosedDate'] = DateTime.now().toUtc().toIso8601String();
      setState(() {});
      return;
    }

    // When values don't match, keep it as min date so UI shows '*'.
    row['ClosedDate'] = '0001-01-01T00:00:00.000Z';
    setState(() {});
  }

  String _formatOddDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    try {
      final parsed = DateTime.parse(value);
      final dd = parsed.day.toString().padLeft(2, '0');
      final mm = parsed.month.toString().padLeft(2, '0');
      final yyyy = parsed.year.toString();
      return '$dd/$mm/$yyyy';
    } catch (_) {
      return value;
    }
  }

  String _formatDateTime(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    if (value.startsWith('0001-01-01')) return '*';
    try {
      final parsed = DateTime.parse(value);
      if (parsed.year <= 1) return '';
      final month = parsed.month.toString();
      final day = parsed.day.toString();
      final year = parsed.year.toString();
      final hour24 = parsed.hour;
      final period = hour24 >= 12 ? 'PM' : 'AM';
      final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
      final min = parsed.minute.toString().padLeft(2, '0');
      final ss = parsed.second.toString().padLeft(2, '0');
      return '$month/$day/$year,\n$hour12:$min:$ss $period';
    } catch (_) {
      return value;
    }
  }

  String _leadHandNameFromNested(Map<String, dynamic>? item) {
    if (item == null) return '';
    final production = item['ProductionLogEntry'];
    if (production is! Map) return '';
    final leadHand = production['LeadHand'];
    if (leadHand is! Map) return '';
    final name = (leadHand['LeadHandName'] ?? '').toString().trim();
    return name;
  }

  String get _sop {
    final value = _valueFromItem(_apiItem, ['SOPNum']);
    return value.isEmpty ? widget.sop : value;
  }

  String get _leadHand => _leadHandNameFromNested(_apiItem).isNotEmpty
      ? _leadHandNameFromNested(_apiItem)
      : (() {
          final value = _valueFromItem(_apiItem, ['LeadHand']);
          return value.isEmpty ? widget.leadHand : value;
        })();

  String get _assembler {
    final value = _valueFromItem(_apiItem, ['Assembler']);
    return value.isEmpty ? widget.assembler : value;
  }

  String get _odd {
    final value = _valueFromItem(_apiItem, ['ODD']);
    final raw = value.isEmpty ? widget.odd : value;
    return _formatOddDate(raw);
  }

  String get _fixtureId {
    final value = _valueFromItem(_apiItem, ['FixtureNumber']);
    return value.isEmpty ? widget.fixtureId : value;
  }

  String get _description {
    final value = _valueFromItem(_apiItem, ['FixtureDescription']);
    return value.isEmpty ? widget.description : value;
  }

  String get _qty {
    final value = _valueFromItem(_apiItem, ['Quantity']);
    return value.isEmpty ? widget.qty : value;
  }

  List<Map<String, dynamic>> get _backorders {
    return _editableBackorders;
  }

  List<String> get _componentPnOptions {
    final raw = _apiItem?['Components'];
    if (raw is! List) return ['Other'];
    return [
      'Other',
      ...raw
          .whereType<Map>()
          .map((e) => (e['TDGPN'] ?? '').toString().trim())
          .where((e) => e.isNotEmpty),
    ];
  }

  void _addDraftBackorderRow() {
    setState(() {
      _draftBackorders.add(_DraftBackorderRow());
    });
  }

  void _removeDraftBackorderRow(int index) {
    if (index < 0 || index >= _draftBackorders.length) return;
    final row = _draftBackorders.removeAt(index);
    row.dispose();
    setState(() {});
  }

  bool get _isNotifyPurchasingTrue {
    if (_notifyPurchasingOverride != null) return _notifyPurchasingOverride!;
    final value = _apiItem?['NotifyPurchasing'];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  bool get _isPickedTrue {
    if (_pickedOverride != null) return _pickedOverride!;
    final value = _apiItem?['Picked'];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  bool get _isNotifyProductionTrue {
    if (_notifyProductionOverride != null) return _notifyProductionOverride!;
    final value = _apiItem?['NotifyProduction'];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  @override
  void dispose() {
    for (final row in _draftBackorders) {
      row.dispose();
    }
    _purchasingNoticeCtrl.dispose();
    _purchasingResponseCtrl.dispose();
    _productionNoticeCtrl.dispose();
    _productionResponseCtrl.dispose();
    _inventoryCommentCtrl.dispose();
    super.dispose();
  }

  void _openPublicSearch(String fixtureNumber) {
    final fixture = fixtureNumber.trim();
    if (fixture.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Publicsearch(fixtureNumber: fixture)),
    );
  }

  Widget _actionBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton.icon(
            onPressed: _onUpdateEntry,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Update Entry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          if (widget.showNewSearchButton) ...[
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: widget.onNewSearch ?? () {},
              icon: const Icon(Icons.search, size: 18, color: _kPrimaryBlue),
              label: const Text(
                'New Search',
                style: TextStyle(
                  color: _kPrimaryBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFEFF4FA),
                foregroundColor: _kPrimaryBlue,
                side: const BorderSide(color: Color(0xFF7BAFEA), width: 1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerCell(
    String text, {
    int flex = 1,
    TextAlign align = TextAlign.center,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Text(
          text,
          textAlign: align,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _tableHeaderRow() {
    return Container(
      decoration: BoxDecoration(
        color: _kTableHeaderBg,
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _headerCell('SOP', flex: 1),
          _headerCell('Lead Hand', flex: 1),
          _headerCell('Assembler', flex: 1),
          _headerCell('ODD', flex: 1),
          _headerCell('Fixture', flex: 2),
          _headerCell('Desc', flex: 3, align: TextAlign.start),
          _headerCell('Qty', flex: 1),
          _headerCell('Notices', flex: 6, align: TextAlign.start),
        ],
      ),
    );
  }

  Widget _dataCell(Widget child, {int flex = 1, EdgeInsetsGeometry? padding}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: padding ?? const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!)),
        alignment: Alignment.topLeft,
        child: child,
      ),
    );
  }

  Widget _fixtureChip(String id) {
    return InkWell(
      onTap: id.trim().isEmpty ? null : () => _openPublicSearch(id),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _kFixtureFill,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _kFixtureBorder),
        ),
        child: Text(
          id,
          style: const TextStyle(
            color: _kFixtureBorder,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _qtyBadge(String qty) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: _kQtyGreen,
      child: Text(
        qty,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _threeColHeaderCell(
    String text, {
    required int flex,
    TextAlign align = TextAlign.start,
    bool rightBorder = true,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          border: Border(
            right: rightBorder
                ? const BorderSide(color: Color(0xFF374151), width: 1)
                : BorderSide.none,
          ),
        ),
        child: Text(
          text,
          textAlign: align,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _purchasingBlock() {
    const minPurchasingWidth = 760.0;
    Widget purchasingBodyCell({
      required Widget child,
      required int flex,
      bool rightBorder = true,
    }) {
      return Expanded(
        flex: flex,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border(
              top: const BorderSide(color: Color(0xFF374151), width: 1),
              right: rightBorder
                  ? const BorderSide(color: Color(0xFF374151), width: 1)
                  : BorderSide.none,
            ),
          ),
          child: child,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: minPurchasingWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: _kTableHeaderBg,
              child: Row(
                children: [
                  _threeColHeaderCell('Notify Purchasing', flex: 1),
                  _threeColHeaderCell(
                    'Purchasing Notice',
                    flex: 2,
                    align: TextAlign.center,
                  ),
                  _threeColHeaderCell(
                    'Purchasing Response',
                    flex: 2,
                    align: TextAlign.center,
                    rightBorder: false,
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    purchasingBodyCell(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 140,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _notifyPurchasingOverride =
                                      !_isNotifyPurchasingTrue;
                                });
                                (widget.onPurchasingClosed ?? () {})();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isNotifyPurchasingTrue
                                    ? _yellow
                                    : _kPrimaryBlue,
                                foregroundColor: _isNotifyPurchasingTrue
                                    ? Colors.black
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: const VisualDensity(
                                  horizontal: -2,
                                  vertical: -2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: Text(
                                _isNotifyPurchasingTrue
                                    ? 'Purchasing Issue is Open'
                                    : 'Purchasing Issue is Closed',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 140,
                            height: 40,
                            child: ElevatedButton(
                              onPressed: () async {
                                final newValue = !_isPickedTrue;
                                setState(() {
                                  _pickedOverride = newValue;
                                });
                                // try {
                                //   await _onUpdateEntry();
                                // } catch (e) {
                                //   setState(() {
                                //     _pickedOverride = !_pickedOverride!;
                                //   });
                                // }
                                (widget.onPicked ?? () {})();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isPickedTrue
                                    ? _yellow
                                    : _kPrimaryBlue,
                                foregroundColor: _isPickedTrue
                                    ? Colors.black
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: const VisualDensity(
                                  horizontal: -2,
                                  vertical: -2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: Text(
                                _isPickedTrue ? 'Picked' : 'Not Picked',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _isPickedTrue
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    purchasingBodyCell(
                      flex: 2,
                      child: TextField(
                        controller: _purchasingNoticeCtrl,
                        maxLines: 4,
                        decoration: _fieldDecoration(),
                      ),
                    ),
                    purchasingBodyCell(
                      flex: 2,
                      rightBorder: false,
                      child: TextField(
                        controller: _purchasingResponseCtrl,
                        maxLines: 4,
                        decoration: _fieldDecoration(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backorderSubHeader() {
    const labels = [
      'PN',
      'UOM',
      'B/o',
      "Rcv'd",
      'Response',
      'Date Closed',
      'Actions',
    ];
    const flexes = [2, 1, 1, 1, 2, 2, 1];
    return Container(
      color: _kTableHeaderBg,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              flex: flexes[i],
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  border: Border(
                    right: i != labels.length - 1
                        ? const BorderSide(color: Color(0xFF374151), width: 1)
                        : BorderSide.none,
                  ),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  softWrap: true,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                    height: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _backorderBlock() {
    const flexes = [2, 1, 1, 1, 2, 2, 1];
    const tableWidth = 760.0;
    final rawComponents = _apiItem?['Components'];
    final uomByPn = <String, String>{};
    if (rawComponents is List) {
      for (final item in rawComponents.whereType<Map>()) {
        final pn = (item['TDGPN'] ?? '').toString().trim();
        final uom = (item['UOM'] ?? '').toString().trim();
        if (pn.isEmpty || uom.isEmpty) continue;
        uomByPn[pn] = uom;
      }
    }
    final uomOptions = uomByPn.values.toSet().toList()..sort();
    if (uomOptions.isEmpty) uomOptions.addAll(['PCS', 'mm', 'SQ. cm', 'ml']);
    final tableContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _backorderSubHeader(),
        if (_backorders.isNotEmpty)
          ..._backorders.map((row) {
            final pn = (row['TDGPN'] ?? '').toString();
            final uom = (row['UOM'] ?? '').toString();
            final bo = (row['Quantity'] ?? '').toString();
            final received = (row['Received'] ?? '').toString();
            final response = (row['Response'] ?? '').toString();
            final closedDate = _formatDateTime(
              (row['ClosedDate'] ?? '').toString(),
            );
            final values = [pn, uom, bo, received, response, closedDate];
            return Container(
              color: Colors.white,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < values.length; i++)
                      Expanded(
                        flex: flexes[i],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              top: const BorderSide(
                                color: Color(0xFF374151),
                                width: 1,
                              ),
                              right: const BorderSide(
                                color: Color(0xFF374151),
                                width: 1,
                              ),
                            ),
                          ),
                          child: (i == 2 || i == 3)
                              ? TextFormField(
                                  initialValue: values[i],
                                  keyboardType: TextInputType.number,
                                  decoration: _fieldDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    row[i == 2 ? 'Quantity' : 'Received'] =
                                        value;
                                    _syncClosedDateForBackorder(row);
                                  },
                                )
                              : Text(
                                  values[i],
                                  softWrap: true,
                                  overflow: TextOverflow.clip,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                ),
                        ),
                      ),
                    Expanded(
                      flex: flexes.last,
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFF374151), width: 1),
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Colors.white,
                                title: const Text(
                                  'Delete Backorder',
                                  style: TextStyle(color: Colors.black),
                                ),
                                content: const Text(
                                  'Are you sure you want to delete this backorder?',
                                  style: TextStyle(color: Colors.black87),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.grey,
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color.fromARGB(
                                        255,
                                        201,
                                        46,
                                        44,
                                      ),
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              print("Backorder deleted");
                            }
                          },
                          child: const Icon(
                            Icons.delete,
                            color: Color.fromARGB(255, 201, 46, 44),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ...List.generate(_draftBackorders.length, (index) {
          final row = _draftBackorders[index];
          final isOtherPn = row.selectedPn == 'Other';
          return Container(
            color: Colors.white,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: flexes[0],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF374151), width: 1),
                          right: BorderSide(color: Color(0xFF374151), width: 1),
                        ),
                      ),
                      child: isOtherPn
                          ? TextField(
                              controller: row.customPnCtrl,
                              decoration: _fieldDecoration(hint: 'Enter PN'),
                            )
                          : DropdownButtonFormField<String>(
                              value: row.selectedPn,
                              isExpanded: true,
                              decoration: _fieldDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                              ),
                              hint: const Text('Pick One'),
                              items: _componentPnOptions
                                  .map(
                                    (pn) => DropdownMenuItem<String>(
                                      value: pn,
                                      child: Text(pn),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  row.selectedPn = value;
                                  if (value != 'Other') {
                                    row.customPnCtrl.clear();
                                    row.selectedUom = null;
                                  }
                                });
                              },
                            ),
                    ),
                  ),
                  Expanded(
                    flex: flexes[1],
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF374151), width: 1),
                          right: BorderSide(color: Color(0xFF374151), width: 1),
                        ),
                      ),
                      child: row.selectedPn == null
                          ? const Text('Select PN first')
                          : isOtherPn
                          ? DropdownButtonFormField<String>(
                              value: uomOptions.contains(row.selectedUom)
                                  ? row.selectedUom
                                  : null,
                              isExpanded: true,
                              decoration: _fieldDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                              ),
                              hint: const Text('Select UOM'),
                              items: uomOptions
                                  .map(
                                    (uom) => DropdownMenuItem<String>(
                                      value: uom,
                                      child: Text(uom),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  row.selectedUom = value;
                                });
                              },
                            )
                          : Text(uomByPn[row.selectedPn] ?? 'PCS'),
                    ),
                  ),
                  Expanded(
                    flex: flexes[2],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF374151), width: 1),
                          right: BorderSide(color: Color(0xFF374151), width: 1),
                        ),
                      ),
                      child: TextField(
                        controller: row.boCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _fieldDecoration(),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: flexes[3],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF374151), width: 1),
                          right: BorderSide(color: Color(0xFF374151), width: 1),
                        ),
                      ),
                      child: TextField(
                        controller: row.rcvdCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _fieldDecoration(),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: flexes[4],
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF374151), width: 1),
                          right: BorderSide(color: Color(0xFF374151), width: 1),
                        ),
                      ),
                      child: const Text(''),
                    ),
                  ),
                  Expanded(
                    flex: flexes[5],
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF374151), width: 1),
                          right: BorderSide(color: Color(0xFF374151), width: 1),
                        ),
                      ),
                      child: const Text('*'),
                    ),
                  ),
                  Expanded(
                    flex: flexes.last,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF374151), width: 1),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 18,
                        ),
                        onPressed: () => _removeDraftBackorderRow(index),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: tableWidth, child: tableContent),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFF374151), width: 1)),
          ),
          child: OutlinedButton.icon(
            onPressed: () {
              _addDraftBackorderRow();
              (widget.onAddBackorder ?? () {})();
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _kQtyGreen,
              side: const BorderSide(color: _kQtyGreen, width: 1),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Add Backorder',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _productionBlock() {
    const minProductionWidth = 760.0;
    Widget productionBodyCell({
      required Widget child,
      required int flex,
      bool rightBorder = true,
    }) {
      return Expanded(
        flex: flex,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border(
              top: const BorderSide(color: Color(0xFF374151), width: 1),
              right: rightBorder
                  ? const BorderSide(color: Color(0xFF374151), width: 1)
                  : BorderSide.none,
            ),
          ),
          child: child,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: minProductionWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: _kTableHeaderBg,
              child: Row(
                children: [
                  _threeColHeaderCell('Notify Production', flex: 1),
                  _threeColHeaderCell(
                    'Production Notice',
                    flex: 2,
                    align: TextAlign.center,
                  ),
                  _threeColHeaderCell(
                    'Production Response',
                    flex: 2,
                    align: TextAlign.center,
                    rightBorder: false,
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    productionBodyCell(
                      flex: 1,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 140,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _notifyProductionOverride =
                                    !_isNotifyProductionTrue;
                              });
                              (widget.onProductionClosed ?? () {})();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isNotifyProductionTrue
                                  ? _yellow
                                  : _kPrimaryBlue,
                              foregroundColor: _isNotifyProductionTrue
                                  ? Colors.black
                                  : Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: Text(
                              _isNotifyProductionTrue
                                  ? 'Production Issue is Open'
                                  : 'Production Issue is Closed',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    productionBodyCell(
                      flex: 2,
                      child: TextField(
                        controller: _productionNoticeCtrl,
                        maxLines: 4,
                        decoration: _fieldDecoration(),
                      ),
                    ),
                    productionBodyCell(
                      flex: 2,
                      rightBorder: false,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _productionResponseCtrl,
                        builder: (context, value, _) {
                          final text = value.text.trim();
                          return Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 88),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[400]!),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              text.isEmpty ? '-' : text,
                              style: const TextStyle(fontSize: 13, height: 1.3),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inventoryCommentBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          color: _kTableHeaderBg,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: const Text(
            'Inventory Comment',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(10),
          child: TextField(
            controller: _inventoryCommentCtrl,
            minLines: 4,
            maxLines: 8,
            decoration: _fieldDecoration(
              hint: 'Enter inventory comment...',
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _noticesColumn() {
    Widget withSectionBorder(Widget child) => Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.grey[50],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            withSectionBorder(_purchasingBlock()),
            const SizedBox(height: 10),
            withSectionBorder(_backorderBlock()),
            const SizedBox(height: 10),
            withSectionBorder(_productionBlock()),
            const SizedBox(height: 10),
            withSectionBorder(_inventoryCommentBlock()),
          ],
        ),
      ),
    );
  }

  Widget _dataRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dataCell(Text(_sop), flex: 1),
        _dataCell(Text(_leadHand.isEmpty ? ' ' : _leadHand), flex: 1),
        _dataCell(Text(_assembler.isEmpty ? ' ' : _assembler), flex: 1),
        _dataCell(Text(_odd), flex: 1),
        _dataCell(_fixtureChip(_fixtureId), flex: 2),
        _dataCell(
          Text(
            _description,
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
          flex: 3,
        ),
        _dataCell(
          Align(alignment: Alignment.topCenter, child: _qtyBadge(_qty)),
          flex: 1,
        ),
        Expanded(flex: 6, child: _noticesColumn()),
      ],
    );
  }

  Widget _mobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _actionBar(context),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              _mobileInfoRow('SOP', _sop),
              _mobileInfoRow('Lead Hand', _leadHand.isEmpty ? '-' : _leadHand),
              _mobileInfoRow(
                'Assembler',
                _assembler.isEmpty ? '-' : _assembler,
              ),
              _mobileInfoRow('ODD', _odd),
              _mobileInfoRow('Fixture', _fixtureId),
              _mobileInfoRow('Desc', _description),
              _mobileInfoRow('Qty', _qty, asQtyBadge: true),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          color: _kTableHeaderBg,
          child: const Text(
            'Notices',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        _noticesColumn(),
      ],
    );
  }

  Widget _mobileInfoRow(String label, String value, {bool asQtyBadge = false}) {
    final isFixtureRow = label.toLowerCase() == 'fixture';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isFixtureRow
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: _fixtureChip(value),
                  )
                : asQtyBadge
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: _qtyBadge(value.isEmpty ? '0' : value),
                  )
                : Text(
                    value,
                    style: const TextStyle(fontSize: 13, height: 1.3),
                  ),
          ),
        ],
      ),
    );
  }

  String? _textOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Map<String, dynamic> _buildPayload() {
    final allBackorders = <Map<String, dynamic>>[];

    for (final row in _backorders) {
      final mapped = <String, dynamic>{
        'TDGPN': (row['TDGPN'] ?? '').toString(),
        'UOM': (row['UOM'] ?? '').toString(),
        'Quantity': int.tryParse((row['Quantity'] ?? '0').toString()) ?? 0,
        'Received': int.tryParse((row['Received'] ?? '0').toString()) ?? 0,
        'RootCause': (row['RootCause'] ?? '').toString(),
        'Response': (row['Response'] ?? '').toString(),
        'ClosedDate': (row['ClosedDate'] ?? '').toString(),
      };
      final id = row['SOPBackorderEntryId'];
      if (id != null && id.toString().trim().isNotEmpty) {
        mapped['SOPBackorderEntryId'] = int.tryParse(id.toString()) ?? id;
      }
      allBackorders.add(mapped);
    }

    for (final row in _draftBackorders) {
      final pn = row.selectedPn == 'Other'
          ? row.customPnCtrl.text.trim()
          : (row.selectedPn ?? '').trim();
      final uom = row.selectedPn == 'Other'
          ? (row.selectedUom ?? '').trim()
          : '';

      if (pn.isEmpty || uom.isEmpty) continue;

      allBackorders.add({
        'TDGPN': pn,
        'UOM': uom,
        'Quantity': int.tryParse(row.boCtrl.text.trim()) ?? 0,
        'Received': int.tryParse(row.rcvdCtrl.text.trim()) ?? 0,
        'RootCause': '',
        'Response': '',
        'ClosedDate': '',
      });
    }

    return {
      'SOPLeadHandEntryId': int.tryParse(widget.sopLeadHandEntryId ?? '') ?? 0,
      'backorders': allBackorders.isNotEmpty ? allBackorders : [],
      'inventoryComments': _textOrNull(_inventoryCommentCtrl),
      'productionNotice': _textOrNull(_productionNoticeCtrl),
      'productionStatus': _isNotifyProductionTrue ? 1 : 0,
      'purchasingNotice': _textOrNull(_purchasingNoticeCtrl),
      'purchasingStatus': _isNotifyPurchasingTrue ? 1 : 0,
      'pickedStatus': _isPickedTrue ? 1 : 0,
    };
  }

  Future<void> _onUpdateEntry() async {
    final payload = _buildPayload();
    debugPrint('Update payload: $payload');
    try {
      await OpenItemsServices().CriticalUpdate(payload: payload);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Updated successfully')));
      (widget.onUpdateEntry ?? () {})();
    } on DioException catch (e) {
      final serverMessage = e.response?.data;
      debugPrint('CriticalUpdate failed: ${e.message}');
      debugPrint('CriticalUpdate response: $serverMessage');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: ${serverMessage ?? e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minTableWidth = 960.0;
        return constraints.maxWidth < minTableWidth
            ? _mobileLayout(context)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_actionBar(context), _tableHeaderRow(), _dataRow()],
              );
      },
    );
  }
}

class _DraftBackorderRow {
  _DraftBackorderRow()
    : boCtrl = TextEditingController(text: '0'),
      rcvdCtrl = TextEditingController(text: '0');

  String? selectedPn;
  String? selectedUom;
  final TextEditingController boCtrl;
  final TextEditingController rcvdCtrl;
  TextEditingController? _customPnCtrl;
  TextEditingController get customPnCtrl =>
      _customPnCtrl ??= TextEditingController();

  void dispose() {
    boCtrl.dispose();
    rcvdCtrl.dispose();
    _customPnCtrl?.dispose();
  }
}
