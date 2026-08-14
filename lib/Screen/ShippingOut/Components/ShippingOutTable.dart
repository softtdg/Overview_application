import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shared Shipping Out data table (sticky history + plain search layout).
class ShippingOutTable extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final bool showLastEditedAndAction;
  final bool isSearchTable;
  final bool shrinkWrap;
  final Future<void> Function(Map<String, dynamic> item)? onEdit;

  const ShippingOutTable({
    Key? key,
    required this.rows,
    this.showLastEditedAndAction = true,
    this.isSearchTable = false,
    this.shrinkWrap = false,
    this.onEdit,
  }) : super(key: key);

  @override
  State<ShippingOutTable> createState() => _ShippingOutTableState();
}

class _ShippingOutTableState extends State<ShippingOutTable> {
  final ScrollController _leftVerticalScroll = ScrollController();
  final ScrollController _middleVerticalScroll = ScrollController();
  final ScrollController _actionsVerticalScroll = ScrollController();
  final ScrollController _middleHorizontalScroll = ScrollController();

  static const Color _tableHeaderColor = Color.fromARGB(255, 57, 73, 95);
  static const double _rowHeight = 76;

  // SOP, PO Num, ODD | Customer..New Comments | Last Edited | Action
  static const List<double> _baseColWidths = [
    90, // SOP
    170, // PO Num
    100, // ODD
    280, // Customer
    120, // Prgm
    80, // Loc.
    110, // SOP Entry
    110, // SOP Out
    90, // PROD MGR
    110, // Delivery Date
    200, // New Comments
    150, // Last Edited On
    72, // Action
  ];

  @override
  void initState() {
    super.initState();
    _leftVerticalScroll.addListener(
      () => _syncScroll(_leftVerticalScroll, [
        _middleVerticalScroll,
        _actionsVerticalScroll,
      ]),
    );
    _middleVerticalScroll.addListener(
      () => _syncScroll(_middleVerticalScroll, [
        _leftVerticalScroll,
        _actionsVerticalScroll,
      ]),
    );
    _actionsVerticalScroll.addListener(
      () => _syncScroll(_actionsVerticalScroll, [
        _leftVerticalScroll,
        _middleVerticalScroll,
      ]),
    );
  }

  @override
  void dispose() {
    _leftVerticalScroll.dispose();
    _middleVerticalScroll.dispose();
    _actionsVerticalScroll.dispose();
    _middleHorizontalScroll.dispose();
    super.dispose();
  }

  void _syncScroll(ScrollController source, List<ScrollController> targets) {
    for (final target in targets) {
      if (!target.hasClients) continue;
      if (target.offset != source.offset) {
        target.jumpTo(source.offset);
      }
    }
  }

  String formatDate(dynamic date) {
    if (date == null) return '*';
    try {
      final dateStr = date.toString();
      if (dateStr.startsWith('0001-01-01')) return '*';
      final parsedDate = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(parsedDate);
    } catch (e) {
      return '-';
    }
  }

  String formatDateTime(dynamic date) {
    if (date == null) return '*';
    try {
      final dateStr = date.toString();
      if (dateStr.startsWith('0001-01-01')) return '*';
      final parsedDate = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy hh:mm a').format(parsedDate);
    } catch (e) {
      return '-';
    }
  }

  List<BoxShadow> get _leftStickyShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 6,
      offset: const Offset(2, 0),
    ),
  ];

  List<BoxShadow> get _rightStickyShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 6,
      offset: const Offset(-2, 0),
    ),
  ];

  List<double> _scaledMiddleWidths({
    required bool showLastEditedAndAction,
    required double availableMiddleWidth,
  }) {
    final middle = showLastEditedAndAction
        ? _baseColWidths.sublist(3, 12)
        : _baseColWidths.sublist(3, 11);
    final total = middle.fold<double>(0, (sum, w) => sum + w);
    if (availableMiddleWidth <= total) return middle;
    final scale = availableMiddleWidth / total;
    return middle.map((w) => w * scale).toList();
  }

  List<double> _plainTableWidths({
    required bool showLastEdited,
    required bool showAction,
    required double availableWidth,
  }) {
    final count = showAction ? 13 : (showLastEdited ? 12 : 11);
    final base = _baseColWidths.take(count).toList();
    final total = base.fold<double>(0, (sum, w) => sum + w);
    if (!availableWidth.isFinite || availableWidth <= total) return base;
    final scale = availableWidth / total;
    return base.map((w) => w * scale).toList();
  }

  Widget _headerCell(String text, double width) {
    return SizedBox(
      width: width,
      height: _rowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _tableHeaderColor,
          border: Border.all(color: Colors.grey, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bodyTextCell(String text, double width, {bool wrap = false}) {
    return Container(
      width: width,
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey, width: 0.5),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        softWrap: wrap,
        maxLines: wrap ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _leftHeader(List<double> leftWidths) {
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: _leftStickyShadow),
      child: Row(
        children: [
          _headerCell('SOP', leftWidths[0]),
          _headerCell('PO Num', leftWidths[1]),
          _headerCell('ODD', leftWidths[2]),
        ],
      ),
    );
  }

  Widget _leftDataRow(Map<String, dynamic> item, List<double> leftWidths) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: _leftStickyShadow,
      ),
      child: Row(
        children: [
          _bodyTextCell(item['SOPNum']?.toString() ?? '-', leftWidths[0]),
          _bodyTextCell(item['PONum']?.toString() ?? '-', leftWidths[1]),
          _bodyTextCell(formatDate(item['ODD']), leftWidths[2]),
        ],
      ),
    );
  }

  Widget _middleHeader(
    List<double> middleWidths, {
    required bool showLastEdited,
  }) {
    return Row(
      children: [
        _headerCell('Customer', middleWidths[0]),
        _headerCell('Prgm', middleWidths[1]),
        _headerCell('Loc.', middleWidths[2]),
        _headerCell('SOP Entry', middleWidths[3]),
        _headerCell('SOP Out', middleWidths[4]),
        _headerCell('PROD MGR', middleWidths[5]),
        _headerCell('Delivery Date', middleWidths[6]),
        _headerCell('New Comments', middleWidths[7]),
        if (showLastEdited) _headerCell('Last Edited On', middleWidths[8]),
      ],
    );
  }

  Widget _middleDataRow(
    Map<String, dynamic> item,
    List<double> middleWidths, {
    required bool showLastEdited,
  }) {
    return Row(
      children: [
        _bodyTextCell(
          item['customer']?.toString() ?? '-',
          middleWidths[0],
          wrap: true,
        ),
        _bodyTextCell(item['program']?.toString() ?? '-', middleWidths[1]),
        _bodyTextCell(item['Location']?.toString() ?? '-', middleWidths[2]),
        _bodyTextCell(formatDate(item['SOPEntryDateIn']), middleWidths[3]),
        _bodyTextCell(formatDate(item['SOPOrderEntryOut']), middleWidths[4]),
        _bodyTextCell(item['prodMgr']?.toString() ?? '-', middleWidths[5]),
        _bodyTextCell(formatDate(item['FinalDeliveryDate']), middleWidths[6]),
        _bodyTextCell(
          item['OrderEntryComments']?.toString() ?? '-',
          middleWidths[7],
        ),
        if (showLastEdited)
          _bodyTextCell(formatDateTime(item['LastEdit']), middleWidths[8]),
      ],
    );
  }

  Widget _actionHeader(double width) {
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: _rightStickyShadow),
      child: _headerCell('Action', width),
    );
  }

  Widget _actionDataCell(Map<String, dynamic> item, double width) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: _rightStickyShadow,
      ),
      child: Container(
        width: width,
        height: _rowHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey, width: 0.5),
        ),
        child: IconButton(
          onPressed: widget.onEdit == null ? null : () => widget.onEdit!(item),
          tooltip: 'Edit',
          icon: const Icon(Icons.edit, size: 18, color: Colors.white),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF39495F),
            foregroundColor: Colors.white,
            minimumSize: const Size(32, 32),
            padding: const EdgeInsets.all(4),
            side: const BorderSide(color: Colors.black),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }

  Widget _buildPlainHeaderRow(
    List<double> widths, {
    required bool showLastEdited,
    required bool showAction,
  }) {
    return Row(
      children: [
        _headerCell('SOP', widths[0]),
        _headerCell('PO Num', widths[1]),
        _headerCell('ODD', widths[2]),
        _headerCell('Customer', widths[3]),
        _headerCell('Prgm', widths[4]),
        _headerCell('Loc.', widths[5]),
        _headerCell('SOP Entry', widths[6]),
        _headerCell('SOP Out', widths[7]),
        _headerCell('PROD MGR', widths[8]),
        _headerCell('Delivery Date', widths[9]),
        _headerCell('New Comments', widths[10]),
        if (showLastEdited) _headerCell('Last Edited On', widths[11]),
        if (showAction)
          _headerCell('Action', widths[showLastEdited ? 12 : 11]),
      ],
    );
  }

  Widget _buildPlainDataRow(
    Map<String, dynamic> item,
    List<double> widths, {
    required bool showLastEdited,
    required bool showAction,
  }) {
    return Row(
      children: [
        _bodyTextCell(item['SOPNum']?.toString() ?? '-', widths[0]),
        _bodyTextCell(item['PONum']?.toString() ?? '-', widths[1]),
        _bodyTextCell(formatDate(item['ODD']), widths[2]),
        _bodyTextCell(
          item['customer']?.toString() ?? '-',
          widths[3],
          wrap: true,
        ),
        _bodyTextCell(item['program']?.toString() ?? '-', widths[4]),
        _bodyTextCell(item['Location']?.toString() ?? '-', widths[5]),
        _bodyTextCell(formatDate(item['SOPEntryDateIn']), widths[6]),
        _bodyTextCell(formatDate(item['SOPOrderEntryOut']), widths[7]),
        _bodyTextCell(item['prodMgr']?.toString() ?? '-', widths[8]),
        _bodyTextCell(formatDate(item['FinalDeliveryDate']), widths[9]),
        _bodyTextCell(
          item['OrderEntryComments']?.toString() ?? '-',
          widths[10],
        ),
        if (showLastEdited)
          _bodyTextCell(formatDateTime(item['LastEdit']), widths[11]),
        if (showAction)
          _actionDataCell(item, widths[showLastEdited ? 12 : 11]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final leftWidths = _baseColWidths.take(3).toList();
    final leftWidth = leftWidths.fold<double>(0, (sum, w) => sum + w);
    final actionWidth = _baseColWidths[12];
    final showAction = widget.showLastEditedAndAction;
    final showLastEdited = widget.showLastEditedAndAction;
    final rowsData = widget.rows;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.shrinkWrap || widget.isSearchTable) {
          final includeAction = showAction && !widget.isSearchTable;
          final widths = _plainTableWidths(
            showLastEdited: showLastEdited,
            showAction: includeAction,
            availableWidth: constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width,
          );
          final tableWidth = widths.fold<double>(0, (sum, w) => sum + w);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _middleHorizontalScroll,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPlainHeaderRow(
                    widths,
                    showLastEdited: showLastEdited,
                    showAction: includeAction,
                  ),
                  ...rowsData.map(
                    (item) => _buildPlainDataRow(
                      item,
                      widths,
                      showLastEdited: showLastEdited,
                      showAction: includeAction,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final reserved = leftWidth + (showAction ? actionWidth : 0);
        final middleAvailable = (constraints.maxWidth - reserved).clamp(
          0.0,
          double.infinity,
        );
        final middleWidths = _scaledMiddleWidths(
          showLastEditedAndAction: showLastEdited,
          availableMiddleWidth: middleAvailable,
        );
        final middleWidth = middleWidths.fold<double>(0, (sum, w) => sum + w);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: leftWidth,
              child: Column(
                children: [
                  _leftHeader(leftWidths),
                  Expanded(
                    child: ListView.builder(
                      controller: _leftVerticalScroll,
                      itemCount: rowsData.length,
                      itemExtent: _rowHeight,
                      itemBuilder: (context, index) {
                        return _leftDataRow(rowsData[index], leftWidths);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _middleHorizontalScroll,
                child: SizedBox(
                  width: middleWidth,
                  child: Column(
                    children: [
                      _middleHeader(
                        middleWidths,
                        showLastEdited: showLastEdited,
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: _middleVerticalScroll,
                          itemCount: rowsData.length,
                          itemExtent: _rowHeight,
                          itemBuilder: (context, index) {
                            return _middleDataRow(
                              rowsData[index],
                              middleWidths,
                              showLastEdited: showLastEdited,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (showAction)
              SizedBox(
                width: actionWidth,
                child: Column(
                  children: [
                    _actionHeader(actionWidth),
                    Expanded(
                      child: ListView.builder(
                        controller: _actionsVerticalScroll,
                        itemCount: rowsData.length,
                        itemExtent: _rowHeight,
                        itemBuilder: (context, index) {
                          return _actionDataCell(rowsData[index], actionWidth);
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
