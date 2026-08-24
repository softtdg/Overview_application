import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/InventoryPickedLog/Services/InventoryPickedLogService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Utils/responsive.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/AppToast.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

String _formatDisplayDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value == '-') return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('dd-MMM-yy').format(parsed.toLocal());
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

String _formatLongDisplayDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value == '-') return '-';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('MMMM d, yyyy').format(parsed.toLocal());
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
  String backorderQty;
  bool locationWasSelected;

  /// Currently selected location value (may be "A, B" for all, or one site).
  String location;

  /// Individual location options when more than one exists.
  final List<String> locationChoices;
  final String leadHandComments;

  ViewPickLogModel({
    required this.TDGPN,
    required this.description,
    required this.vendor,
    required this.vendorPN,
    required this.qtyPerFixture,
    required this.unitOfMeasure,
    required this.totalQtyNeeded,
    required this.actualQtyPicked,
    this.backorderQty = '',
    this.locationWasSelected = false,
    required this.location,
    required this.locationChoices,
    required this.leadHandComments,
  });

  bool get hasMultipleLocations => locationChoices.length > 1;
}

class ViewPickedLog extends StatefulWidget {
  final String id;

  const ViewPickedLog({super.key, required this.id});

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
  String pickListPrintedOn = '-';
  String pickListLogNumber = '';
  String datePicked = '';
  String rma = '-';
  String leadHandSignOff = '-';

  /// 0 = default styling; 1 = highlight info grid with mint green.
  int mpfStatus = 0;

  @override
  void initState() {
    super.initState();
    fetchData();
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
          root = {...root, ...nested};
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
          location: locationChoices.length > 1
              ? locationChoices.join(', ')
              : _formatLocationDisplay(locationRaw),
          locationChoices: locationChoices,
          leadHandComments: rowPick(const ['LeadHandComments']),
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
        quantity = pickFrom(const ['tempQuantity']);
        blankListDescription = pickFrom(const ['description']);
        requiredOn = _formatDisplayDate(pickFrom(const ['odd']));
        pickListPrintedOn = _formatLongDisplayDate(
          pickFrom(const ['createdAt']),
        );
        rma = pickFrom(const ['RMA']);
        leadHandSignOff = mpfRequestedBy;
        mpfStatus = parsedMpfStatus;
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

  // Future<void> _handleAcceptInventoryPickList() async {
  //   if (isActionLoading || isLoading) return;
  //   if (_sheetDataForSubmit.isEmpty) {
  //     if (!mounted) return;
  //     AppToast.error(
  //       context,
  //       'Pick list is still loading or has no line items. Wait and try again.',
  //     );
  //     return;
  //   }
  //   setState(() {
  //     isActionLoading = true;
  //   });
  //   try {
  //     await Dioservices.setToken();
  //     final response = await _service.AcceptInventoryPickList(
  //       widget.id,
  //       sheetData: _sheetDataForSubmit,
  //     );
  //     final message = response.data is Map && response.data['message'] != null
  //         ? response.data['message'].toString()
  //         : 'Inventory accepted successfully';
  //     if (!mounted) return;
  //     AppToast.success(context, message);
  //     await fetchData();
  //   } catch (e) {
  //     debugPrint('AcceptInventoryPickList error: $e');
  //     if (!mounted) return;
  //     AppToast.error(
  //       context,
  //       AppToast.friendlyMessage(e, fallback: 'Action failed'),
  //     );
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         isActionLoading = false;
  //       });
  //     }
  //   }
  // }

  Future<void> _handleAcceptInventoryPickList() async {
    if (isActionLoading || isLoading) return;

    if (_sheetDataForSubmit.isEmpty) {
      if (!mounted) return;
      AppToast.error(
        context,
        'Pick list is still loading or has no line items. Wait and try again.',
      );
      return;
    }

    // Validate location for every dropdown/line item
    for (int i = 0; i < _sheetDataForSubmit.length; i++) {
      final row = _sheetDataForSubmit[i];

      final location = row['location'];

      if (location == null || location.toString().trim().isEmpty) {
        if (!mounted) return;

        AppToast.error(
          context,
          'Please select a location for every item before accepting.',
        );

        return;
      }
    }

    setState(() {
      isActionLoading = true;
    });

    try {
      await Dioservices.setToken();

      final response = await _service.AcceptInventoryPickList(
        widget.id,
        sheetData: _sheetDataForSubmit,
      );

      final message = response.data is Map && response.data['message'] != null
          ? response.data['message'].toString()
          : 'Inventory accepted successfully';

      if (!mounted) return;

      AppToast.success(context, message);

      await fetchData();
    } catch (e) {
      debugPrint('AcceptInventoryPickList error: $e');

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

  Future<void> _handlePicked() async {
    if (isActionLoading || isLoading) return;
    if (_sheetDataForSubmit.isEmpty) {
      if (!mounted) return;
      AppToast.error(
        context,
        'Pick list is still loading or has no line items. Wait and try again.',
      );
      return;
    }
    final missingLocationIndex = data.indexWhere(
      (row) => row.hasMultipleLocations && !row.locationWasSelected,
    );
    if (missingLocationIndex != -1) {
      setState(() {
        _showLocationValidation = true;
      });
      if (!mounted) return;
      AppToast.error(
        context,
        'Please select a location for every location dropdown before picking.',
      );
      return;
    }
    setState(() {
      isActionLoading = true;
    });
    try {
      await Dioservices.setToken();
      final response = await _service.AcceptInventory(
        widget.id,
        sheetData: _sheetDataForSubmit,
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
    if (isActionLoading || isLoading) return;
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
    final today = pickListPrintedOn == '-' || pickListPrintedOn.isEmpty
        ? DateFormat('MMMM d, yyyy').format(DateTime.now())
        : pickListPrintedOn;

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
    const defaultLabelBg = Color(0xFFB9C7D9);
    const defaultValueBg = Color(0xFFF1F3F5);
    const mpfHighlightBg = Color.fromRGBO(240, 253, 244, 1);
    final isMpf = mpfStatus == 1;

    // Row 1: full mint green when mpfStatus == 1.
    // Column 1 (labels): mint green for all rows when mpfStatus == 1.
    // Other body cells: white when MPF; default colors otherwise.
    final row1Bg = isMpf ? mpfHighlightBg : defaultLabelBg;
    final row1ValueBg = isMpf ? mpfHighlightBg : defaultValueBg;
    final col1Bg = isMpf ? mpfHighlightBg : defaultLabelBg;
    final bodyValueBg = isMpf ? Colors.white : defaultValueBg;

    final printedOnLabel = isMpf
        ? 'MPF DATE\nREQUESTED ON'
        : 'PICK LIST\nPRINTED ON';
    final requestedByLabel = isMpf
        ? 'MPF\nREQUESTED BY'
        : 'LEAD HAND\nSIGN OFF';

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
                'REFERENCE\nSOP #',
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
                bgColor: row1ValueBg,
                fontSize: valueFontSize,
                isBold: true,
                alignCenter: true,
              ),
            ),
            Expanded(
              flex: 15,
              child: _tableCell(
                'PICK\nLIST #$pickListNo',
                height: rowHeight,
                bgColor: row1Bg,
                fontSize: isMobile ? labelFontSize : 11,
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
                bgColor: row1Bg,
                fontSize: labelFontSize,
                isLabel: true,
              ),
            ),
            Expanded(
              flex: 22,
              child: _tableCell(
                today,
                height: rowHeight,
                bgColor: row1ValueBg,
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
                'PICK LIST LOG\nNUMBER',
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
                bgColor: isMpf ? mpfHighlightBg : bodyValueBg,
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
    const borderColor = Color(0xFFD1D5DB);
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

    final headers = [
      'TDGPN',
      'Description',
      'Vendor',
      'VendorPN',
      'Qty Per Fixture',
      'Unit of Measure',
      'Total Qty Needed',
      'Actual Qty To Be Picked',
      'For Backorder',
      'Location (Qty)',
      'LeadHandComments',
    ];
    // Column index 7 = Actual Qty (editable), 8 = For Backorder (blank),
    // 9 = Location (Qty) — dropdown when multiple locations.
    const actualQtyCol = 7;
    const forBackorderCol = 8;
    const locationCol = 9;

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
      final actual = parseQuantity(row.actualQtyPicked);
      if (total == null || actual == null) return null;
      final remainder = total - actual;
      return remainder > 0 && remainder < total ? remainder : null;
    }

    final rows = data.isEmpty
        ? const <List<String>>[
            ['-', '-', '-', '-', '-', '-', '-', '-', '', '-', '-'],
          ]
        : data
              .map(
                (row) => [
                  row.TDGPN,
                  row.description,
                  row.vendor,
                  row.vendorPN,
                  row.qtyPerFixture,
                  row.unitOfMeasure,
                  row.totalQtyNeeded,
                  row.actualQtyPicked,
                  row.backorderQty,
                  row.location,
                  row.leadHandComments,
                ],
              )
              .toList();

    double columnWidth(int index) {
      if (index == 1) return 300;
      if (index == forBackorderCol) return 120;
      if (index == locationCol) return 200;
      return 108;
    }

    final tableWidth = List.generate(
      headers.length,
      columnWidth,
    ).fold<double>(0, (sum, width) => sum + width);
    final contentHeight = headerHeight + rows.length * dataRowHeight;
    final scrollRows = contentHeight > maxHeight;
    // Include 2px for the container's top+bottom border so inner Column never overflows.
    final tableHeight = (scrollRows ? maxHeight : contentHeight) + 2;

    Widget buildTableRow(
      List<String> cells, {
      required bool isHeader,
      int? rowIndex,
    }) {
      final textStyle = isHeader ? headerTextStyle : bodyTextStyle;
      final rowHeight = isHeader ? headerHeight : dataRowHeight;

      return Container(
        height: rowHeight,
        width: tableWidth,
        color: isHeader ? headerBg : Colors.white,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(cells.length, (index) {
            final centerCell = isHeader || index > 1;
            final isLastColumn = index == cells.length - 1;

            Widget child;
            if (!isHeader &&
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
                      _sheetDataForSubmit[rowIndex]['ForBackorder'] = value;
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
                        _sheetDataForSubmit[rowIndex]['ForBackorder'] = value;
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
                    }
                  });
                },
              );
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

    return Container(
      height: tableHeight,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(border: Border.all(color: borderColor)),
      child: Responsive.hideScrollbars(
        context,
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                height: constraints.maxHeight,
                child: Column(
                  children: [
                    buildTableRow(headers, isHeader: true),
                    if (scrollRows)
                      Expanded(
                        child: ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            return buildTableRow(
                              rows[index],
                              isHeader: false,
                              rowIndex: index,
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
                        ),
                      ),
                  ],
                ),
              ),
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
  });

  final String initialValue;
  final TextStyle textStyle;
  final ValueChanged<String> onChanged;

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
    // The combined value is the default selection; individual locations remain available.
    final allOption = choices.join(', ');
    final items = <String>[allOption, ...choices];
    final selected = items.contains(value) && value.trim().isNotEmpty
        ? value
        : allOption;
    final borderColor = isSelectionMissing
        ? const Color(0xFFDC2626)
        : Colors.grey.shade400;

    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      style: textStyle,
      icon: Icon(
        Icons.arrow_drop_down,
        size: 20,
        color: isSelectionMissing ? const Color(0xFFB91C1C) : null,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                style: textStyle,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
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
