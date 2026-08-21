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

String _inventoryActionErrorMessage(Object e) {
  return AppToast.friendlyMessage(e, fallback: 'Action failed');
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
  bool isLoading = false;
  bool isActionLoading = false;
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

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  /// Only CONSUMABLE + another location becomes selectable options.
  /// Slash locations like "W3A7/W3D2 (53)" stay as plain text with "/".
  List<String> _splitConsumableLocations(String raw) {
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

    if (parts.length < 2) return const [];

    final hasConsumable = parts.any(
      (p) => p.toUpperCase().contains('CONSUMABLE'),
    );
    // Only CONSUMABLE + another site gets a dropdown.
    if (!hasConsumable) return const [];

    return parts;
  }

  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
    });
    try {
      await Dioservices.setToken();
      final response = await _service.ViewInventoryPickListService(widget.id);
      final payload = response.data;
      // debugPrint('ViewInventoryPickListService response: $payload');

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
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString();
          }
        }
        return '';
      }

      String asDash(String value) => value.trim().isEmpty ? '' : value.trim();

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

        return ViewPickLogModel(
          TDGPN: rowPick(const ['TDGPN']),
          description: rowPick(const ['Description']),
          vendor: rowPick(const ['Vendor']),
          vendorPN: rowPick(const ['VendorPN']),
          qtyPerFixture: rowPick(const ['QuantityPerFixture']),
          unitOfMeasure: rowPick(const ['UnitOfMeasure']),
          totalQtyNeeded: rowPick(const ['TotalQtyNeeded']),
          actualQtyPicked: () {
            final actual = rowPick(const ['ActualQtyPicked']);
            if (actual.isNotEmpty) return actual;
            return rowPick(const ['ActualQtyToBePicked', 'TotalQtyNeeded']);
          }(),
          location: () {
            final raw = rowPick(const ['Location']);
            final choices = _splitConsumableLocations(raw);
            if (choices.length > 1) return choices.join(', ');
            return raw;
          }(),
          locationChoices: _splitConsumableLocations(
            rowPick(const ['Location']),
          ),
          leadHandComments: rowPick(const ['LeadHandComments']),
        );
      }).toList();

      final sheetDataForSubmit = _sheetDataListFromResponse(root, rawRows);

      setState(() {
        _sheetDataForSubmit = sheetDataForSubmit;
        referenceSop = asDash(pickFrom(const ['sopNum']));
        pickListNo = asDash(pickFrom(const ['pickListNumber']));
        project = asDash(pickFrom(const ['project']));
        fixture = asDash(pickFrom(const ['fixture']));
        quantity = asDash(pickFrom(const ['tempQuantity']));
        blankListDescription = asDash(pickFrom(const ['description']));
        requiredOn = _formatDisplayDate(asDash(pickFrom(const ['odd'])));
        pickListPrintedOn = _formatLongDisplayDate(
          asDash(pickFrom(const ['createdAt'])),
        );
        pickListLogNumber = asDash(pickFrom(const ['']));
        datePicked = _formatDisplayDate(asDash(pickFrom(const [''])));
        rma = asDash(pickFrom(const ['RMA']));
        leadHandSignOff = asDash(pickFrom(const ['MPFRequestedBy']));
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
      AppToast.error(context, _inventoryActionErrorMessage(e));
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
      AppToast.error(context, _inventoryActionErrorMessage(e));
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
      body: LayoutBuilder(
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
                        onPressed: isActionLoading || isLoading
                            ? null
                            : _handleVoid,
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
                        onPressed: isActionLoading || isLoading
                            ? null
                            : _handlePicked,
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
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: AppLoader()),
                    )
                  else
                    _buildInfoGrid(today, isMobile: isMobile),
                  const SizedBox(height: 16),
                  _buildPickedItemsTable(context, maxHeight: maxTableHeight),
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
    const borderColor = Color(0xFF2C3138);
    final rowHeight = isMobile ? 48.0 : 44.0;
    final labelFontSize = isMobile ? 10.0 : 12.0;
    final valueFontSize = isMobile ? 10.0 : 14.0;
    final leftLabelFlex = isMobile ? 26 : 22;
    final leftValueFlex = isMobile ? 20 : 24;
    const labelBg = Color(0xFFB9C7D9);
    const valueBg = Color(0xFFF1F3F5);

    return Container(
      decoration: BoxDecoration(border: Border.all(color: borderColor)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: leftLabelFlex,
                child: _tableCell(
                  'REFERENCE\nSOP #',
                  height: rowHeight,
                  bgColor: labelBg,
                  fontSize: labelFontSize,
                  isLabel: true,
                ),
              ),
              Expanded(
                flex: leftValueFlex,
                child: _tableCell(
                  referenceSop,
                  height: rowHeight,
                  bgColor: labelBg,
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
                  bgColor: labelBg,
                  fontSize: isMobile ? labelFontSize : 11,
                  isLabel: true,
                  alignCenter: true,
                  maxLines: 4,
                ),
              ),
              Expanded(
                flex: 23,
                child: _tableCell(
                  'PICK LIST\nPRINTED ON',
                  height: rowHeight,
                  bgColor: labelBg,
                  fontSize: labelFontSize,
                  isLabel: true,
                ),
              ),
              Expanded(
                flex: 22,
                child: _tableCell(
                  today,
                  height: rowHeight,
                  bgColor: labelBg,
                  fontSize: valueFontSize,
                  isBold: true,
                  alignCenter: true,
                  showRightBorder: false,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                flex: leftLabelFlex,
                child: _buildColumnCells(
                  rowHeight: rowHeight,
                  fontSize: labelFontSize,
                  values: const [
                    'PROJECT',
                    'FIXTURE',
                    'QUANTITY',
                    'REQUIRED ON',
                  ],
                  bgColor: labelBg,
                  isLabel: true,
                ),
              ),
              Expanded(
                flex: leftValueFlex,
                child: _buildColumnCells(
                  rowHeight: rowHeight,
                  fontSize: valueFontSize,
                  values: [project, fixture, quantity, requiredOn],
                  bgColor: valueBg,
                ),
              ),
              Expanded(
                flex: 15,
                child: _tableCell(
                  blankListDescription,
                  height: rowHeight * 4,
                  bgColor: valueBg,
                  fontSize: valueFontSize,
                  alignCenter: false,
                  maxLines: 8,
                  useEllipsis: false,
                ),
              ),
              Expanded(
                flex: 23,
                child: _buildColumnCells(
                  rowHeight: rowHeight,
                  fontSize: labelFontSize,
                  values: const [
                    'PICK LIST LOG\nNUMBER',
                    'DATE PICKED',
                    'RMA',
                    'LEAD HAND\nSIGN OFF',
                  ],
                  bgColor: labelBg,
                  isLabel: true,
                ),
              ),
              Expanded(
                flex: 22,
                child: _buildColumnCells(
                  rowHeight: rowHeight,
                  fontSize: valueFontSize,
                  values: [pickListLogNumber, datePicked, rma, leadHandSignOff],
                  bgColor: valueBg,
                  showRightBorder: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColumnCells({
    required List<String> values,
    required double rowHeight,
    required double fontSize,
    required Color bgColor,
    bool isLabel = false,
    bool showRightBorder = true,
  }) {
    return Column(
      children: List.generate(values.length, (index) {
        final isLast = index == values.length - 1;
        return _tableCell(
          values[index],
          height: rowHeight,
          bgColor: bgColor,
          fontSize: fontSize,
          isLabel: isLabel,
          alignCenter: !isLabel,
          showBottomBorder: !isLast,
          showRightBorder: showRightBorder,
        );
      }),
    );
  }

  Widget _tableCell(
    String text, {
    required double height,
    required Color bgColor,
    required double fontSize,
    bool isLabel = false,
    bool isBold = false,
    bool alignCenter = false,
    bool showBottomBorder = true,
    bool showRightBorder = true,
    int? maxLines,
    bool useEllipsis = true,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: alignCenter ? Alignment.center : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: showRightBorder
              ? const BorderSide(color: Color(0xFF2C3138))
              : BorderSide.none,
          bottom: showBottomBorder
              ? const BorderSide(color: Color(0xFF2C3138))
              : BorderSide.none,
        ),
      ),
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
                  '', // For Backorder — button later; blank for now
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
                  data[rowIndex].actualQtyPicked = value;
                  if (rowIndex < _sheetDataForSubmit.length) {
                    _sheetDataForSubmit[rowIndex]['ActualQtyPicked'] = value;
                  }
                },
              );
            } else if (!isHeader &&
                index == locationCol &&
                rowIndex != null &&
                rowIndex < data.length &&
                data[rowIndex].hasMultipleLocations) {
              child = _LocationSelectField(
                key: ValueKey('loc-$rowIndex-${data[rowIndex].TDGPN}'),
                choices: data[rowIndex].locationChoices,
                value: data[rowIndex].location,
                textStyle: bodyTextStyle,
                onChanged: (value) {
                  setState(() {
                    data[rowIndex].location = value;
                    if (rowIndex < _sheetDataForSubmit.length) {
                      _sheetDataForSubmit[rowIndex]['Location'] = value;
                    }
                  });
                },
              );
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
    required this.textStyle,
    required this.onChanged,
  });

  final List<String> choices;
  final String value;
  final TextStyle textStyle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // First option = all locations joined (default). Then each individual.
    final allOption = choices.join(', ');
    final items = <String>[allOption, ...choices];
    final selected = items.contains(value) ? value : allOption;

    return DropdownButtonFormField<String>(
      value: selected,
      isExpanded: true,
      style: textStyle,
      icon: const Icon(Icons.arrow_drop_down, size: 20),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
