import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/InventoryPickedLog/Services/InventoryPickedLogService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Utils/responsive.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/AppToast.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _formatDisplayDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value == '-') return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('MMM-d-yyyy').format(parsed.toLocal());
}

String _blankIfZero(String value) {
  final raw = value.trim();
  if (raw.isEmpty || raw == '-') return '';
  final parsed = num.tryParse(raw.replaceAll(',', ''));
  if (parsed != null && parsed == 0) return '';
  return raw;
}

List<Map<String, dynamic>> _deepCopyMapList(List<dynamic> list) {
  return list
      .whereType<Map>()
      .map(
        (m) => Map<String, dynamic>.from(
          m.map((k, v) => MapEntry(k.toString(), v)),
        ),
      )
      .toList();
}

/// Backend accept/reject expects a `sheetData` array (same shape as list/detail API).
List<Map<String, dynamic>> _sheetDataListFromResponse(
  Map<String, dynamic> root,
  List<dynamic> tableSourceRows,
) {
  dynamic fromRoot = root['sheetData'];
  if (fromRoot is List && fromRoot.isNotEmpty) {
    return _deepCopyMapList(fromRoot);
  }
  final data = root['data'];
  if (data is Map) {
    final inner = data['sheetData'];
    if (inner is List && inner.isNotEmpty) {
      return _deepCopyMapList(inner);
    }
  }
  return _deepCopyMapList(tableSourceRows);
}

class ViewPickLogModel {
  final String TDGPN;
  final String description;
  final String vendor;
  final String vendorPN;
  final String qtyPerFixture;
  final String unitOfMeasure;
  final String totalQtyNeeded;
  String actualQtyPicked;
  String mpfQty;
  String backorderQty;
  bool locationWasSelected;

  /// Currently selected location value (may be "A, B" for all, or one site).
  String location;

  /// Individual location options when more than one exists.
  final List<String> locationChoices;
  final String leadHandComments;
  String inventoryComments;

  ViewPickLogModel({
    required this.TDGPN,
    required this.description,
    required this.vendor,
    required this.vendorPN,
    required this.qtyPerFixture,
    required this.unitOfMeasure,
    required this.totalQtyNeeded,
    required this.actualQtyPicked,
    this.mpfQty = '',
    this.backorderQty = '',
    this.locationWasSelected = false,
    required this.location,
    required this.locationChoices,
    required this.leadHandComments,
    this.inventoryComments = '',
  });

  bool get hasMultipleLocations => locationChoices.length > 1;
}

class ViewPickedLog extends StatefulWidget {
  final String id;
  final int status;

  const ViewPickedLog({super.key, required this.id, this.status = 0});

  @override
  State<ViewPickedLog> createState() => ViewPickedLogState();
}

class ViewPickedLogState extends State<ViewPickedLog> {
  final InventoryPickedLogService _service = InventoryPickedLogService();
  List<ViewPickLogModel> data = [];

  /// Original line items for PUT accept/reject (server requires `sheetData`).
  List<Map<String, dynamic>> _sheetDataForSubmit = [];
  bool isLoading = true;
  bool isActionLoading = false;
  bool _showLocationValidation = false;
  String referenceSop = '-';
  String pickListNo = '-';
  String project = '-';
  String fixture = '-';
  String quantity = '-';
  String requiredOn = '-';
  String blankListDescription = '-';
  String pickListLogNumber = '';
  String datePicked = '';
  String rma = '-';
  String leadHandSignOff = '-';
  final ScrollController _tdgpnVerticalScroll = ScrollController();
  final ScrollController _bodyVerticalScroll = ScrollController();

  /// 0 = default styling; 1 = highlight info grid with mint green.
  int mpfStatus = 0;

  /// 0 = pending, 1 = accepted, 2 = rejected.
  int pickListStatus = 0;

  bool get _isReadOnly => pickListStatus == 1 || pickListStatus == 2;

  @override
  void initState() {
    super.initState();
    pickListStatus = widget.status;
    _tdgpnVerticalScroll.addListener(
      () => _syncVerticalScroll(_tdgpnVerticalScroll, _bodyVerticalScroll),
    );
    _bodyVerticalScroll.addListener(
      () => _syncVerticalScroll(_bodyVerticalScroll, _tdgpnVerticalScroll),
    );
    fetchData();
  }

  @override
  void dispose() {
    _tdgpnVerticalScroll.dispose();
    _bodyVerticalScroll.dispose();
    super.dispose();
  }

  void _syncVerticalScroll(ScrollController source, ScrollController target) {
    if (!target.hasClients) return;
    if (target.offset != source.offset) {
      target.jumpTo(source.offset);
    }
  }

  /// Split a location string into individual sites when more than one exists.
  /// Slash locations like "W3A7/W3D2 (53)" stay as a single value.
  List<String> _locationParts(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '-') return const [];

    List<String> parts;
    if (trimmed.contains(',')) {
      parts = trimmed
          .split(RegExp(r'\s*,\s*'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (trimmed.contains('\n') || trimmed.contains('\r')) {
      // API often returns: "CONSUMABLE\nCR5B1 (0)"
      parts = trimmed
          .split(RegExp(r'[\r\n]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (RegExp(r'CONSUMABLE', caseSensitive: false).hasMatch(trimmed) &&
        trimmed.contains('/')) {
      // e.g. "CONSUMABLE/CR5E" or "CONSUMABLE (1635)/CR5E"
      parts = trimmed
          .split('/')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      return const [];
    }

    return parts.length >= 2 ? parts : const [];
  }

  /// Any row with multiple locations becomes selectable options.
  List<String> _splitConsumableLocations(String raw) {
    final parts = _locationParts(raw);
    return parts;
  }

  /// Plain-text location: "CONSUMABLE,\nCR5B1 (0)" when two sites exist.
  String _formatLocationDisplay(String raw) {
    final parts = _locationParts(raw);
    if (parts.length < 2) return raw;
    return parts.join(',\n');
  }

  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
    });
    try {
      await Dioservices.setToken();
      final response = await _service.ViewInventoryPickListService(widget.id);
      final payload = response.data;

      Map<String, dynamic> root = <String, dynamic>{};
      List<dynamic> rawRows = <dynamic>[];

      if (payload is Map) {
        root = Map<String, dynamic>.from(
          payload.map((k, v) => MapEntry(k.toString(), v)),
        );
        final dynamic firstLevel = root['data'];

        if (firstLevel is List) {
          rawRows = firstLevel;
        } else if (firstLevel is Map) {
          final nested = Map<String, dynamic>.from(
            firstLevel.map((k, v) => MapEntry(k.toString(), v)),
          );
          root = nested;
          final dynamic secondLevel = nested['sheetData'];
          if (secondLevel is List) rawRows = secondLevel;
        }
      } else if (payload is List) {
        rawRows = payload;
      }

      Map<String, dynamic> detailMap = <String, dynamic>{};
      final rootDetail = root['excelFixtureDetail'];
      if (rootDetail is Map) {
        detailMap = Map<String, dynamic>.from(
          rootDetail.map((k, v) => MapEntry(k.toString(), v)),
        );
      }

      String pickFrom(List<String> keys) {
        for (final key in keys) {
          final value = root[key] ?? detailMap[key];
          if (value == null) continue;
          final text = value.toString().trim();
          if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
        }
        return '';
      }

      String tempQty(List<String> keys) {
        for (final key in keys) {
          final value = root[key] ?? detailMap[key];
          if (value == null) continue;
          final text = value.toString().trim();
          if (text == '0' || text == '0.0') {
            return '-';
          }

          if (text.isNotEmpty) return text;
        }
        return '';
      }

      final mpfRequestedBy = pickFrom(const ['MPFRequestedBy']);
      final skipLocationDropdown =
          mpfRequestedBy.toLowerCase() == 'usa production';

      final parsedRows = rawRows.whereType<Map>().map((raw) {
        final row = Map<String, dynamic>.from(
          raw.map((k, v) => MapEntry(k.toString(), v)),
        );
        final rowDetail = row['excelFixtureDetail'];
        final detail = rowDetail is Map
            ? Map<String, dynamic>.from(
                rowDetail.map((k, v) => MapEntry(k.toString(), v)),
              )
            : <String, dynamic>{};

        String rowPick(List<String> keys) {
          for (final key in keys) {
            final value = row[key] ?? detail[key];
            if (value == null) continue;
            if (value is List) {
              final parts = value
                  .map((e) => e?.toString().trim() ?? '')
                  .where((s) => s.isNotEmpty && s != 'null')
                  .toList();
              if (parts.isNotEmpty) return parts.join(', ');
              continue;
            }
            final text = value.toString().trim();
            if (text.isNotEmpty && text != 'null') return text;
          }
          return '';
        }

        final locationRaw = rowPick(const ['Location']);
        final locationChoices = skipLocationDropdown
            ? const <String>[]
            : _splitConsumableLocations(locationRaw);
        final actual = rowPick(const ['ActualQtyPicked']);

        return ViewPickLogModel(
          TDGPN: rowPick(const ['TDGPN']),
          description: rowPick(const ['Description']),
          vendor: rowPick(const ['Vendor']),
          vendorPN: rowPick(const ['VendorPN']),
          qtyPerFixture: rowPick(const ['QuantityPerFixture']),
          unitOfMeasure: rowPick(const ['UnitOfMeasure']),
          totalQtyNeeded: rowPick(const ['TotalQtyNeeded']),
          actualQtyPicked: actual.isNotEmpty
              ? actual
              : rowPick(const ['ActualQtyToBePicked', 'TotalQtyNeeded']),
          mpfQty: rowPick(const ['mpfQty', 'MPF']),
          backorderQty: rowPick(const ['forBackorder', 'ForBackorder']),
          location: locationChoices.length > 1
              ? locationChoices.join(', ')
              : _formatLocationDisplay(locationRaw),
          locationChoices: locationChoices,
          leadHandComments: rowPick(const ['LeadHandComments']),
          inventoryComments: rowPick(const ['InventoryComments']),
        );
      }).toList();

      final sheetDataForSubmit = _sheetDataListFromResponse(root, rawRows);

      final rawMpfStatus = root['mpfStatus'] ?? detailMap['mpfStatus'];
      final parsedMpfStatus = rawMpfStatus is num
          ? rawMpfStatus.toInt()
          : int.tryParse(rawMpfStatus?.toString() ?? '') ?? 0;

      setState(() {
        _sheetDataForSubmit = sheetDataForSubmit;
        referenceSop = pickFrom(const ['sopNum']);
        pickListNo = pickFrom(const ['pickListNumber']);
        project = pickFrom(const ['project']);
        fixture = pickFrom(const ['fixture']);
        quantity = tempQty(const ['tempQuantity']);
        blankListDescription = pickFrom(const ['description']);
        requiredOn = _formatDisplayDate(pickFrom(const ['odd']));
        rma = pickFrom(const ['RMA']);
        leadHandSignOff = mpfRequestedBy;
        mpfStatus = parsedMpfStatus;
        final rawPickStatus = root['status'] ?? detailMap['status'];
        pickListStatus = rawPickStatus is num
            ? rawPickStatus.toInt()
            : () {
                final text =
                    rawPickStatus?.toString().trim().toLowerCase() ?? '';
                if (text == 'accepted' || text == '1') return 1;
                if (text == 'rejected' || text == '2') return 2;
                if (text == 'pending' || text == '0') return 0;
                return int.tryParse(text) ?? widget.status;
              }();
        data = parsedRows;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('ViewInventoryPickListService error: $e');
      setState(() {
        _sheetDataForSubmit = [];
        isLoading = false;
      });
    }
  }

  bool _validateAllLocationsSelected() {
    final missing = data.any(
      (row) => row.hasMultipleLocations && !row.locationWasSelected,
    );
    if (!missing) return true;
    setState(() {
      _showLocationValidation = true;
    });
    if (mounted) {
      AppToast.error(
        context,
        'Please select a location for rows with multiple location values',
      );
    }
    return false;
  }

  Future<void> _handleAcceptInventoryPickList() async {
    if (_isReadOnly || isActionLoading || isLoading) return;

    if (_sheetDataForSubmit.isEmpty) {
      if (!mounted) return;
      AppToast.error(
        context,
        'Pick list is still loading or has no line items. Wait and try again.',
      );
      return;
    }

    if (!_validateAllLocationsSelected()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Are you sure?',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        content: const Text(
          'One or more selected locations have a quantity of 0 or less. Do you still want to mark this pick list as picked?',
          style: TextStyle(color: Color(0xFF374151), fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF1976D2)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Yes, Picked'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    for (var i = 0; i < _sheetDataForSubmit.length && i < data.length; i++) {
      final row = data[i];
      final loc = row.location;
      _sheetDataForSubmit[i]['Location'] = loc;
      _sheetDataForSubmit[i]['selectedLocation'] = loc;
      _sheetDataForSubmit[i]['ActualQtyPicked'] = mpfStatus == 1
          ? row.mpfQty
          : row.actualQtyPicked;
      _sheetDataForSubmit[i]['InventoryComments'] = row.inventoryComments;
      if (row.backorderQty.isNotEmpty) {
        _sheetDataForSubmit[i]['forBackorder'] =
            num.tryParse(row.backorderQty.replaceAll(',', '')) ??
            row.backorderQty;
      }
    }

    setState(() {
      isActionLoading = true;
    });

    try {
      await Dioservices.setToken();
      final picker =
          (await SharedPreferences.getInstance()).getString('UserName') ?? '';

      final response = await _service.AcceptInventory(
        widget.id,
        sheetData: _sheetDataForSubmit,
        picker: picker,
        mpfStatus: mpfStatus,
        pickLocation: leadHandSignOff.toLowerCase() == 'usa production'
            ? 'USA'
            : 'CAN',
      );

      final message = response.data is Map && response.data['message'] != null
          ? response.data['message'].toString()
          : 'Inventory accepted successfully';

      if (!mounted) return;

      AppToast.success(context, message);

      await fetchData();
    } catch (e) {
      debugPrint('AcceptInventory error: $e');

      if (!mounted) return;

      AppToast.error(
        context,
        AppToast.friendlyMessage(e, fallback: 'Action failed'),
      );
    } finally {
      if (mounted) {
        setState(() {
          isActionLoading = false;
        });
      }
    }
  }

  Future<void> _handleVoid() async {
    if (_isReadOnly || isActionLoading || isLoading) return;
    if (_sheetDataForSubmit.isEmpty) {
      if (!mounted) return;
      AppToast.error(
        context,
        'Pick list is still loading or has no line items. Wait and try again.',
      );
      return;
    }
    setState(() {
      isActionLoading = true;
    });
    try {
      await Dioservices.setToken();
      final response = await _service.RejectInventory(
        widget.id,
        sheetData: _sheetDataForSubmit,
      );
      final message = response.data is Map && response.data['message'] != null
          ? response.data['message'].toString()
          : 'Inventory rejected successfully';
      if (!mounted) return;
      AppToast.success(context, message);
      await fetchData();
    } catch (e) {
      debugPrint('RejectInventory error: $e');
      if (!mounted) return;
      AppToast.error(
        context,
        AppToast.friendlyMessage(e, fallback: 'Action failed'),
      );
    } finally {
      if (mounted) {
        setState(() {
          isActionLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('MMMM d, yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(showBackButton: true),
      drawer: const CommonDrawer(),
      body: isLoading || isActionLoading
          ? const Center(child: AppLoader())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 480;

                final maxTableHeight = (constraints.maxHeight * 0.52).clamp(
                  280.0,
                  620.0,
                );

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Text(
                              'Pick Log View',
                              style: TextStyle(
                                fontSize: isMobile ? 20 : 24,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const Spacer(),
                            if (!_isReadOnly) ...[
                              ElevatedButton(
                                onPressed: _handleVoid,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    202,
                                    25,
                                    25,
                                  ),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 14 : 22,
                                    vertical: isMobile ? 10 : 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                child: const Text(
                                  'Void',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _handleAcceptInventoryPickList,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    10,
                                    136,
                                    41,
                                  ),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 14 : 22,
                                    vertical: isMobile ? 10 : 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                child: const Text(
                                  'Picked',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildInfoGrid(today, isMobile: isMobile),
                        const SizedBox(height: 16),
                        _buildPickedItemsTable(
                          context,
                          maxHeight: maxTableHeight,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoGrid(String today, {required bool isMobile}) {
    const borderColor = Color(0xFF64748B);
    final rowHeight = isMobile ? 48.0 : 44.0;
    final labelFontSize = isMobile ? 10.0 : 12.0;
    final valueFontSize = isMobile ? 10.0 : 14.0;
    final leftLabelFlex = isMobile ? 26 : 22;
    final leftValueFlex = isMobile ? 20 : 24;
    const defaultLabelBg = Color(0xFFDBEAFE);
    const defaultValueBg = Colors.white;
    const mpfHighlightBg = Color.fromRGBO(240, 253, 244, 1);
    final isMpf = mpfStatus == 1;

    // Row 1: full mint green when mpfStatus == 1.
    // Column 1 (labels): mint green for all rows when mpfStatus == 1.
    // Other body cells: white when MPF; default colors otherwise.
    final row1Bg = isMpf ? mpfHighlightBg : defaultLabelBg;
    // final row1ValueBg = isMpf ? mpfHighlightBg : defaultValueBg;
    final col1Bg = isMpf ? mpfHighlightBg : defaultLabelBg;
    final bodyValueBg = isMpf ? Colors.white : defaultValueBg;

    final printedOnLabel = isMpf
        ? 'MPF DATE REQUESTED ON'
        : 'PICK LIST PRINTED ON';
    final requestedByLabel = isMpf ? 'MPF REQUESTED BY' : 'LEAD HAND SIGN OFF';

    Widget vLine() => Container(width: 1, color: borderColor);
    Widget hLine() =>
        Container(height: 1, width: double.infinity, color: borderColor);

    Widget row(List<Widget> cells) {
      final children = <Widget>[];
      for (var i = 0; i < cells.length; i++) {
        if (i > 0) children.add(vLine());
        children.add(cells[i]);
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          // Row 1 — full-width highlight when mpfStatus == 1
          row([
            Expanded(
              flex: leftLabelFlex,
              child: _tableCell(
                'REFERENCE SOP #',
                height: rowHeight,
                bgColor: row1Bg,
                fontSize: labelFontSize,
                isLabel: true,
              ),
            ),
            Expanded(
              flex: leftValueFlex,
              child: _tableCell(
                referenceSop,
                height: rowHeight,
                // bgColor: row1ValueBg,
                bgColor: col1Bg,
                fontSize: valueFontSize,
                isBold: true,
                alignCenter: true,
              ),
            ),
            Expanded(
              flex: 15,
              child: _tableCell(
                'PICK LIST #$pickListNo',
                height: rowHeight,
                bgColor: row1Bg,
                fontSize: isMobile ? labelFontSize : 14,
                isLabel: true,
                alignCenter: true,
                maxLines: 4,
              ),
            ),
            Expanded(
              flex: 23,
              child: _tableCell(
                printedOnLabel,
                height: rowHeight,
                // bgColor: row1Bg,
                bgColor: col1Bg,
                fontSize: labelFontSize,
                isLabel: true,
              ),
            ),
            Expanded(
              flex: 22,
              child: _tableCell(
                today,
                height: rowHeight,
                // bgColor: row1ValueBg,
                bgColor: col1Bg,
                fontSize: valueFontSize,
                isBold: true,
                alignCenter: true,
              ),
            ),
          ]),
          hLine(),
          // Row 2: PROJECT | value | empty | PICK LIST LOG NUMBER | value
          row([
            Expanded(
              flex: leftLabelFlex,
              child: _tableCell(
                'PROJECT',
                height: rowHeight,
                bgColor: col1Bg,
                fontSize: labelFontSize,
                isLabel: true,
              ),
            ),
            Expanded(
              flex: leftValueFlex,
              child: _tableCell(
                project,
                height: rowHeight,
                bgColor: bodyValueBg,
                fontSize: valueFontSize,
                alignCenter: true,
              ),
            ),
            Expanded(
              flex: 15,
              child: _tableCell(
                '',
                height: rowHeight,
                bgColor: bodyValueBg,
                fontSize: valueFontSize,
              ),
            ),
            Expanded(
              flex: 23,
              child: _tableCell(
                'PICK LIST LOG NUMBER',
                height: rowHeight,
                bgColor: col1Bg,
                fontSize: labelFontSize,
                isLabel: true,
              ),
            ),
            Expanded(
              flex: 22,
              child: _tableCell(
                pickListLogNumber,
                height: rowHeight,
                bgColor: isMpf ? mpfHighlightBg : col1Bg,
                fontSize: valueFontSize,
                alignCenter: true,
              ),
            ),
          ]),
          hLine(),
          // Rows 3–5: FIXTURE / QUANTITY / REQUIRED ON + description + right fields
          row([
            Expanded(
              flex: leftLabelFlex,
              child: _buildColumnCells(
                rowHeight: rowHeight,
                fontSize: labelFontSize,
                values: const ['FIXTURE', 'QUANTITY', 'REQUIRED ON'],
                bgColor: col1Bg,
                isLabel: true,
                borderColor: borderColor,
              ),
            ),
            Expanded(
              flex: leftValueFlex,
              child: _buildColumnCells(
                rowHeight: rowHeight,
                fontSize: valueFontSize,
                values: [fixture, quantity, requiredOn],
                bgColor: bodyValueBg,
                borderColor: borderColor,
              ),
            ),
            Expanded(
              flex: 15,
              child: _tableCell(
                blankListDescription,
                bgColor: bodyValueBg,
                fontSize: valueFontSize,
                alignCenter: true,
                maxLines: 8,
                useEllipsis: false,
              ),
            ),
            Expanded(
              flex: 23,
              child: _buildColumnCells(
                rowHeight: rowHeight,
                fontSize: labelFontSize,
                values: ['DATE PICKED', 'RMA', requestedByLabel],
                bgColor: col1Bg,
                isLabel: true,
                borderColor: borderColor,
              ),
            ),
            Expanded(
              flex: 22,
              child: _buildColumnCells(
                rowHeight: rowHeight,
                fontSize: valueFontSize,
                values: [datePicked, rma, leadHandSignOff],
                bgColor: bodyValueBg,
                borderColor: borderColor,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildColumnCells({
    required List<String> values,
    required double rowHeight,
    required double fontSize,
    required Color bgColor,
    required Color borderColor,
    bool isLabel = false,
  }) {
    return Column(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0)
            Container(height: 1, width: double.infinity, color: borderColor),
          _tableCell(
            values[i],
            height: rowHeight,
            bgColor: bgColor,
            fontSize: fontSize,
            isLabel: isLabel,
            alignCenter: !isLabel,
          ),
        ],
      ],
    );
  }

  Widget _tableCell(
    String text, {
    double? height,
    required Color bgColor,
    required double fontSize,
    bool isLabel = false,
    bool isBold = false,
    bool alignCenter = false,
    int? maxLines,
    bool useEllipsis = true,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: alignCenter ? Alignment.center : Alignment.centerLeft,
      color: bgColor,
      child: Text(
        text,
        maxLines: maxLines ?? (isLabel ? 3 : 2),
        overflow: useEllipsis ? TextOverflow.ellipsis : TextOverflow.visible,
        softWrap: true,
        style: TextStyle(
          color: const Color(0xFF0C4A7D),
          fontSize: fontSize,
          fontWeight: isLabel || isBold ? FontWeight.w700 : FontWeight.w500,
          height: 1.12,
        ),
      ),
    );
  }

  Widget _buildPickedItemsTable(
    BuildContext context, {
    required double maxHeight,
  }) {
    const headerHeight = 56.0;
    const dataRowHeight = 72.0;
    const headerBg = Color(0xFF334155);
    const borderColor = Color(0xFF9CA3AF);
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final headerTextStyle = TextStyle(
      color: Colors.white,
      fontSize: isTablet ? 14 : 12,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    final bodyTextStyle = TextStyle(
      color: const Color(0xFF111827),
      fontSize: isTablet ? 14 : 11,
    );

    final showMpfCol = mpfStatus == 1;
    final showCommentsCol = mpfStatus == 1;
    final headers = [
      'TDGPN',
      'Description',
      'Vendor',
      'VendorPN',
      'Qty Per Fixture',
      'Unit of Measure',
      'Total Qty Needed',
      'Actual Qty To Be Picked',
      if (showMpfCol) 'MPF',
      'For Backorder',
      'Location (Qty)',
      'LeadHandComments',
      if (showCommentsCol) 'Comments',
    ];
    // Column index 7 = Actual Qty (editable).
    // When mpfStatus == 1, MPF is inserted at 8 and later indexes shift.
    const actualQtyCol = 7;
    final mpfCol = showMpfCol ? 8 : -1;
    final forBackorderCol = showMpfCol ? 9 : 8;
    final locationCol = showMpfCol ? 10 : 9;
    final commentsCol = showCommentsCol ? headers.length - 1 : -1;

    double? parseQuantity(String value) {
      return double.tryParse(value.trim().replaceAll(',', ''));
    }

    String formatQuantity(double value) {
      return value == value.truncateToDouble()
          ? value.toInt().toString()
          : value.toString();
    }

    double? backorderFor(ViewPickLogModel row) {
      final total = parseQuantity(row.totalQtyNeeded);
      final actual = parseQuantity(
        mpfStatus == 1 ? row.mpfQty : row.actualQtyPicked,
      );
      if (total == null || actual == null) return null;
      final remainder = total - actual;
      return remainder > 0 && remainder < total ? remainder : null;
    }

    final emptyRow = [
      '-',
      '-',
      '-',
      '-',
      '',
      '-',
      '',
      '-',
      if (showMpfCol) '-',
      '',
      '-',
      '-',
      if (showCommentsCol) '-',
    ];
    final rows = data.isEmpty
        ? <List<String>>[emptyRow]
        : data
              .map(
                (row) => [
                  row.TDGPN,
                  row.description,
                  row.vendor,
                  row.vendorPN,
                  _blankIfZero(row.qtyPerFixture),
                  row.unitOfMeasure,
                  _blankIfZero(row.totalQtyNeeded),
                  showMpfCol ? '' : row.actualQtyPicked,
                  if (showMpfCol) row.mpfQty,
                  row.backorderQty,
                  row.location,
                  row.leadHandComments,
                  if (showCommentsCol) row.inventoryComments,
                ],
              )
              .toList();

    double columnWidth(int index) {
      if (index == 0) return 130;
      if (index == 1) return 300;
      if (index == mpfCol) return 90;
      if (index == forBackorderCol) return 120;
      if (index == locationCol) return 200;
      if (index == commentsCol) return 180;
      return 108;
    }

    final contentHeight = headerHeight + rows.length * dataRowHeight;
    final scrollRows = contentHeight > maxHeight;
    // Include 2px for the container's top+bottom border so inner Column never overflows.
    final tableHeight = (scrollRows ? maxHeight : contentHeight) + 2;

    final duplicateTdgpn = <String>{};
    final tdgpnCounts = <String, int>{};
    for (final row in data) {
      final key = row.TDGPN.trim();
      if (key.isEmpty || key == '-') continue;
      tdgpnCounts[key] = (tdgpnCounts[key] ?? 0) + 1;
    }
    for (final entry in tdgpnCounts.entries) {
      if (entry.value > 1) duplicateTdgpn.add(entry.key);
    }

    Widget buildTableRow(
      List<String> cells, {
      required bool isHeader,
      int? rowIndex,
      required int start,
      required int end,
      required double width,
    }) {
      final textStyle = isHeader ? headerTextStyle : bodyTextStyle;
      final rowHeight = isHeader ? headerHeight : dataRowHeight;
      final isDuplicateTdgpn =
          !isHeader &&
          rowIndex != null &&
          rowIndex < data.length &&
          duplicateTdgpn.contains(data[rowIndex].TDGPN.trim());

      return Container(
        height: rowHeight,
        width: width,
        color: isHeader
            ? headerBg
            : isDuplicateTdgpn
            ? const Color(0xFFDBEAFE)
            : Colors.white,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(end - start, (offset) {
            final index = start + offset;
            final centerCell = isHeader || index > 1;
            final isLastColumn = index == cells.length - 1;

            Widget child;
            if (!isHeader &&
                !_isReadOnly &&
                mpfStatus != 1 &&
                index == actualQtyCol &&
                rowIndex != null &&
                rowIndex < data.length) {
              child = _ActualQtyField(
                key: ValueKey('actual-qty-$rowIndex-${data[rowIndex].TDGPN}'),
                initialValue: data[rowIndex].actualQtyPicked,
                textStyle: bodyTextStyle,
                onChanged: (value) {
                  setState(() {
                    data[rowIndex].actualQtyPicked = value;
                    if (rowIndex < _sheetDataForSubmit.length) {
                      _sheetDataForSubmit[rowIndex]['ActualQtyPicked'] = value;
                    }
                  });
                },
              );
            } else if (!isHeader &&
                !_isReadOnly &&
                index == mpfCol &&
                rowIndex != null &&
                rowIndex < data.length) {
              child = _ActualQtyField(
                key: ValueKey('mpf-qty-$rowIndex-${data[rowIndex].TDGPN}'),
                initialValue: data[rowIndex].mpfQty,
                textStyle: bodyTextStyle,
                onChanged: (value) {
                  data[rowIndex].mpfQty = value;
                  if (rowIndex < _sheetDataForSubmit.length) {
                    _sheetDataForSubmit[rowIndex]['mpfQty'] = value;
                  }
                },
              );
            } else if (!isHeader &&
                !_isReadOnly &&
                index == forBackorderCol &&
                rowIndex != null &&
                rowIndex < data.length) {
              final row = data[rowIndex];
              final remainder = backorderFor(row);
              if (row.backorderQty.isNotEmpty) {
                child = _BackorderQtyField(
                  key: ValueKey('backorder-$rowIndex-${row.TDGPN}'),
                  initialValue: row.backorderQty,
                  textStyle: bodyTextStyle,
                  onChanged: (value) {
                    row.backorderQty = value;
                    if (rowIndex < _sheetDataForSubmit.length) {
                      _sheetDataForSubmit[rowIndex]['forBackorder'] =
                          num.tryParse(value.replaceAll(',', '')) ?? value;
                    }
                  },
                );
              } else if (remainder != null) {
                child = ElevatedButton(
                  onPressed: () {
                    final value = formatQuantity(remainder);
                    setState(() {
                      row.backorderQty = value;
                      if (rowIndex < _sheetDataForSubmit.length) {
                        _sheetDataForSubmit[rowIndex]['forBackorder'] =
                            num.tryParse(value.replaceAll(',', '')) ?? value;
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 33, 93, 224),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text(
                    'Add\nBackorder',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                );
              } else {
                child = const SizedBox.shrink();
              }
            } else if (!isHeader &&
                !_isReadOnly &&
                index == locationCol &&
                rowIndex != null &&
                rowIndex < data.length &&
                data[rowIndex].hasMultipleLocations) {
              child = _LocationSelectField(
                key: ValueKey('loc-$rowIndex-${data[rowIndex].TDGPN}'),
                choices: data[rowIndex].locationChoices,
                value: data[rowIndex].location,
                isSelectionMissing:
                    _showLocationValidation &&
                    !data[rowIndex].locationWasSelected,
                textStyle: bodyTextStyle,
                onChanged: (value) {
                  setState(() {
                    data[rowIndex].location = value;
                    data[rowIndex].locationWasSelected = true;
                    if (rowIndex < _sheetDataForSubmit.length) {
                      _sheetDataForSubmit[rowIndex]['Location'] = value;
                      _sheetDataForSubmit[rowIndex]['selectedLocation'] = value;
                    }
                  });
                },
              );
            } else if (!isHeader &&
                index == commentsCol &&
                rowIndex != null &&
                rowIndex < data.length) {
              if (!_isReadOnly) {
                child = _ActualQtyField(
                  key: ValueKey(
                    'inv-comments-$rowIndex-${data[rowIndex].TDGPN}',
                  ),
                  initialValue: data[rowIndex].inventoryComments,
                  textStyle: bodyTextStyle,
                  keyboardType: TextInputType.text,
                  textAlign: TextAlign.start,
                  onChanged: (value) {
                    data[rowIndex].inventoryComments = value;
                    if (rowIndex < _sheetDataForSubmit.length) {
                      _sheetDataForSubmit[rowIndex]['InventoryComments'] =
                          value;
                    }
                  },
                );
              } else {
                child = Text(
                  cells[index],
                  style: textStyle,
                  textAlign: TextAlign.center,
                  softWrap: true,
                );
              }
            } else if (!isHeader && index == 1) {
              child = _buildDescriptionCell(cells[index], textStyle);
            } else {
              child = Text(
                cells[index],
                style: textStyle,
                textAlign: centerCell ? TextAlign.center : TextAlign.start,
                softWrap: true,
                maxLines: isHeader ? 3 : null,
              );
            }

            return Container(
              width: columnWidth(index),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              alignment: centerCell ? Alignment.center : Alignment.centerLeft,
              decoration: BoxDecoration(
                color:
                    !isHeader &&
                        index == locationCol &&
                        rowIndex != null &&
                        rowIndex < data.length &&
                        _showLocationValidation &&
                        !_isReadOnly &&
                        data[rowIndex].hasMultipleLocations &&
                        !data[rowIndex].locationWasSelected
                    ? const Color(0xFFFEE2E2)
                    : null,
                border: Border(
                  right: isLastColumn
                      ? BorderSide.none
                      : const BorderSide(color: borderColor),
                  bottom: const BorderSide(color: borderColor),
                ),
              ),
              child: child,
            );
          }),
        ),
      );
    }

    Widget buildColumnPane({
      required int start,
      required int end,
      required double width,
      ScrollController? controller,
    }) {
      return SizedBox(
        width: width,
        child: Column(
          children: [
            buildTableRow(
              headers,
              isHeader: true,
              start: start,
              end: end,
              width: width,
            ),
            if (scrollRows)
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    return buildTableRow(
                      rows[index],
                      isHeader: false,
                      rowIndex: index,
                      start: start,
                      end: end,
                      width: width,
                    );
                  },
                ),
              )
            else
              ...rows.asMap().entries.map(
                (e) => buildTableRow(
                  e.value,
                  isHeader: false,
                  rowIndex: e.key,
                  start: start,
                  end: end,
                  width: width,
                ),
              ),
          ],
        ),
      );
    }

    final tdgpnWidth = columnWidth(0);
    final restWidth = List.generate(
      headers.length - 1,
      (i) => columnWidth(i + 1),
    ).fold<double>(0, (sum, width) => sum + width);
    final fullTableWidth = tdgpnWidth + restWidth;
    final isMobileTable = Responsive.isMobileTableLayout(context);

    return Container(
      height: tableHeight,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(border: Border.all(color: borderColor)),
      child: Responsive.hideScrollbars(
        context,
        LayoutBuilder(
          builder: (context, constraints) {
            if (isMobileTable) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: fullTableWidth,
                  height: constraints.maxHeight,
                  child: buildColumnPane(
                    start: 0,
                    end: headers.length,
                    width: fullTableWidth,
                    controller: _bodyVerticalScroll,
                  ),
                ),
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(2, 0),
                      ),
                    ],
                  ),
                  child: buildColumnPane(
                    start: 0,
                    end: 1,
                    width: tdgpnWidth,
                    controller: _tdgpnVerticalScroll,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: restWidth,
                      height: constraints.maxHeight,
                      child: buildColumnPane(
                        start: 1,
                        end: headers.length,
                        width: restWidth,
                        controller: _bodyVerticalScroll,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Bold the first line only when it starts with "GOES INTO".
  Widget _buildDescriptionCell(String text, TextStyle baseStyle) {
    final breakAt = text.indexOf('\n');
    final firstLine = breakAt < 0 ? text : text.substring(0, breakAt);
    final shouldBold = firstLine.toUpperCase().startsWith('GOES INTO');

    if (!shouldBold) {
      return Text(
        text,
        style: baseStyle,
        textAlign: TextAlign.start,
        softWrap: true,
      );
    }

    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w700);
    if (breakAt < 0) {
      return Text(
        text,
        style: boldStyle,
        textAlign: TextAlign.start,
        softWrap: true,
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, breakAt), style: boldStyle),
          TextSpan(text: text.substring(breakAt), style: baseStyle),
        ],
      ),
      textAlign: TextAlign.start,
      softWrap: true,
    );
  }
}

class _ActualQtyField extends StatefulWidget {
  const _ActualQtyField({
    super.key,
    required this.initialValue,
    required this.textStyle,
    required this.onChanged,
    this.keyboardType = TextInputType.number,
    this.textAlign = TextAlign.center,
  });

  final String initialValue;
  final TextStyle textStyle;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;
  final TextAlign textAlign;

  @override
  State<_ActualQtyField> createState() => _ActualQtyFieldState();
}

class _ActualQtyFieldState extends State<_ActualQtyField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _ActualQtyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: widget.keyboardType,
      textAlign: widget.textAlign,
      style: widget.textStyle,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _LocationSelectField extends StatelessWidget {
  const _LocationSelectField({
    super.key,
    required this.choices,
    required this.value,
    required this.isSelectionMissing,
    required this.textStyle,
    required this.onChanged,
  });

  final List<String> choices;
  final String value;
  final bool isSelectionMissing;
  final TextStyle textStyle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final allOption = choices.join(', ');
    final items = <String>[allOption, ...choices];
    final selected = items.contains(value) && value.trim().isNotEmpty
        ? value
        : allOption;
    final borderColor = isSelectionMissing
        ? const Color(0xFFDC2626)
        : Colors.grey.shade400;

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: Colors.white,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          surface: Colors.white,
          surfaceTint: Colors.transparent,
        ),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        isExpanded: true,
        style: textStyle.copyWith(color: const Color(0xFF111827)),
        dropdownColor: Colors.white,
        icon: Icon(
          Icons.arrow_drop_down,
          size: 20,
          color: isSelectionMissing ? const Color(0xFFB91C1C) : null,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: BorderSide(color: borderColor, width: 1.5),
          ),
        ),
        items: items
            .map(
              (opt) => DropdownMenuItem<String>(
                value: opt,
                child: Text(
                  opt,
                  style: textStyle.copyWith(color: const Color(0xFF111827)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _BackorderQtyField extends StatefulWidget {
  const _BackorderQtyField({
    super.key,
    required this.initialValue,
    required this.textStyle,
    required this.onChanged,
  });

  final String initialValue;
  final TextStyle textStyle;
  final ValueChanged<String> onChanged;

  @override
  State<_BackorderQtyField> createState() => _BackorderQtyFieldState();
}

class _BackorderQtyFieldState extends State<_BackorderQtyField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _BackorderQtyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: widget.textStyle,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}
