import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/InventoryPickedLog/Services/InventoryPickedLogService.dart';
import 'package:overview_app/Services/DioServices.dart';

String _formatDisplayDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value == '-') return '-';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('dd-MMM-yy').format(parsed.toLocal());
}

String _inventoryActionErrorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    debugPrint(
      'inventory action HTTP ${e.response?.statusCode} body: $data',
    );
    if (data is Map) {
      for (final key in ['message', 'error', 'msg', 'detail']) {
        final v = data[key];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString();
        }
      }
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        return errors.first.toString();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      return data;
    }
    if (e.message != null && e.message!.trim().isNotEmpty) {
      return e.message!;
    }
  }
  return e.toString();
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
  final String location;
  final String leadHandComments;

  ViewPickLogModel({
    required this.TDGPN,
    required this.description,
    required this.vendor,
    required this.vendorPN,
    required this.qtyPerFixture,
    required this.unitOfMeasure,
    required this.totalQtyNeeded,
    required this.location,
    required this.leadHandComments,
  });
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
  String pickListLogNumber = '-';
  String datePicked = '-';
  String rma = '-';
  String leadHandSignOff = '-';

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
    });
    try {
      await Dioservices.setToken();
      final response = await _service.ViewInventoryPickListService(widget.id);
      final payload = response.data;
      debugPrint('ViewInventoryPickListService response: $payload');

      Map<String, dynamic> root = <String, dynamic>{};
      List<dynamic> rawRows = <dynamic>[];

      if (payload is Map) {
        root = Map<String, dynamic>.from(
          payload.map((k, v) => MapEntry(k.toString(), v)),
        );
        final dynamic firstLevel =
            root['data'] ??
            root['sheetData'] ??
            root['items'] ??
            root['rows'] ??
            root['result'] ??
            root['list'] ??
            root['content'] ??
            root['records'] ??
            root['excelFixtureDetails'] ??
            root['excelFixtureDetail'];

        if (firstLevel is List) {
          rawRows = firstLevel;
        } else if (firstLevel is Map) {
          final nested = Map<String, dynamic>.from(
            firstLevel.map((k, v) => MapEntry(k.toString(), v)),
          );
          root = {...root, ...nested};
          final dynamic secondLevel =
              nested['data'] ??
              nested['sheetData'] ??
              nested['items'] ??
              nested['rows'] ??
              nested['result'] ??
              nested['list'] ??
              nested['content'] ??
              nested['records'] ??
              nested['excelFixtureDetails'] ??
              nested['excelFixtureDetail'];
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
        return '-';
      }

      String asDash(String value) => value.trim().isEmpty ? '-' : value.trim();

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
            if (value != null && value.toString().trim().isNotEmpty) {
              return value.toString();
            }
          }
          return '-';
        }

        return ViewPickLogModel(
          TDGPN: rowPick(const ['TDGPN', 'tdgpn', 'partNumber']),
          description: rowPick(
            const ['Description', 'description', 'partDescription', 'fixtureDescription', 'desc'],
          ),
          vendor: rowPick(const ['Vendor', 'vendor', 'vendorName']),
          vendorPN: rowPick(const ['VendorPN', 'vendorPN', 'vendorPn', 'vendorPartNo']),
          qtyPerFixture: rowPick(
            const ['QuantityPerFixture', 'qtyPerFixture', 'quantityPerFixture'],
          ),
          unitOfMeasure: rowPick(const ['UnitOfMeasure', 'unitOfMeasure', 'uom']),
          totalQtyNeeded: rowPick(
            const ['TotalQtyNeeded', 'totalQtyNeeded', 'requiredQuantity', 'qty'],
          ),
          location: rowPick(const ['Location', 'location', 'locationName']),
          leadHandComments: rowPick(const ['LeadHandComments', 'leadHandComments', 'comments']),
        );
      }).toList();

      final sheetDataForSubmit =
          _sheetDataListFromResponse(root, rawRows);

      setState(() {
        _sheetDataForSubmit = sheetDataForSubmit;
        referenceSop = asDash(pickFrom(const ['sopNum', 'sopNumber', 'SOPNum']));
        pickListNo = asDash(
          pickFrom(const ['pickListNumber', 'pickListNo', 'pickListId']),
        );
        project = asDash(pickFrom(const ['project', 'projectName']));
        fixture = asDash(pickFrom(const ['fixture', 'fixtureNumber']));
        quantity = asDash(pickFrom(const ['tempQuantity', 'quantity', 'qty']));
        blankListDescription = asDash(
          pickFrom(const ['description', 'partDescription', 'fixtureDescription']),
        );
        requiredOn = _formatDisplayDate(asDash(
          pickFrom(const ['odd', 'requiredOn', 'requiredDate', 'dateRequired']),
        ));
        pickListPrintedOn = _formatLongDisplayDate(asDash(
          pickFrom(const ['pickListPrintedOn', 'printedOn', 'createdAt']),
        ));
        pickListLogNumber = asDash(
          pickFrom(const ['pickListLogNumber', 'pickLogNumber', 'id']),
        );
        datePicked = _formatDisplayDate(asDash(
          pickFrom(const ['datePicked', 'pickedDate', 'updatedAt', 'createdAt']),
        ));
        rma = asDash(pickFrom(const ['RMA', 'rma']));
        leadHandSignOff = asDash(
          pickFrom(const ['leadHandSignOff', 'leadHandComments', 'MPFRequestedBy']),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pick list is still loading or has no line items. Wait and try again.',
          ),
        ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await fetchData();
    } catch (e) {
      debugPrint('AcceptInventory error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_inventoryActionErrorMessage(e))),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pick list is still loading or has no line items. Wait and try again.',
          ),
        ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await fetchData();
    } catch (e) {
      debugPrint('RejectInventory error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_inventoryActionErrorMessage(e))),
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
      backgroundColor: const Color(0xFFE9ECEF),
      appBar: AppBar(
        title: const Text('Pick Log View'),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tableWidth = constraints.maxWidth > 820
                ? 760.0
                : constraints.maxWidth - 16;
            final isMobile = constraints.maxWidth < 480;

            return SizedBox(
              width: tableWidth,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: isActionLoading || isLoading
                                ? null
                                : _handleVoid,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
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
                              backgroundColor: const Color(0xFF15803D),
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
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      _buildInfoGrid(today, isMobile: isMobile),
                      const SizedBox(height: 16),
                      _buildPickedItemsTable(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoGrid(String today, {required bool isMobile}) {
    const borderColor = Color(0xFF2C3138);
    final rowHeight = isMobile ? 48.0 : 56.0;
    final labelFontSize = isMobile ? 10.0 : 24.0;
    final valueFontSize = isMobile ? 10.0 : 22.0;
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
                  fontSize: isMobile ? labelFontSize : 14,
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

  Widget _buildPickedItemsTable() {
    const headerBg = Color(0xFF334155);
    const borderColor = Color(0xFFD1D5DB);
    const headerTextStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    const bodyTextStyle = TextStyle(color: Color(0xFF111827), fontSize: 11);

    final headers = const [
      'TDGPN',
      'Description',
      'Vendor',
      'VendorPN',
      'Qty Per Fixture',
      'Unit of Measure',
      'Total Qty Needed',
      'Location (Qty)',
      'LeadHandComments',
    ];
    final rows = data.isEmpty
        ? const <List<String>>[
            ['-', '-', '-', '-', '-', '-', '-', '-', '-'],
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
                  row.location,
                  row.leadHandComments,
                ],
              )
              .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: borderColor)),
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 120,
          horizontalMargin: 10,
          columnSpacing: 14,
          headingRowColor: WidgetStateProperty.all(headerBg),
          border: TableBorder.all(color: borderColor),
          columns: headers
              .map(
                (header) =>
                    DataColumn(label: Text(header, style: headerTextStyle)),
              )
              .toList(),
          rows: rows
              .map(
                (row) => DataRow(
                  cells: List.generate(row.length, (index) {
                    final cell = row[index];
                    final isDescriptionColumn = index == 1;
                    return DataCell(
                      SizedBox(
                        width: isDescriptionColumn ? 280 : null,
                        child: Text(
                          cell,
                          style: bodyTextStyle,
                          maxLines: isDescriptionColumn ? 6 : 2,
                          softWrap: true,
                          overflow: isDescriptionColumn
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
