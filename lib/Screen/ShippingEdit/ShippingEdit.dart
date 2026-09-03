import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/ShippingEdit/Components/ShippingEditEntry.dart';
import 'package:overview_app/Screen/ShippingIn/Services/ShippingInService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Utils/responsive.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/AppToast.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class ShippingEdit extends StatefulWidget {
  @override
  _ShippingEditState createState() => _ShippingEditState();
}

class _ShippingEditState extends State<ShippingEdit> {
  final ShippingInService _service = ShippingInService();
  final TextEditingController SOPController = TextEditingController();
  final ScrollController _headerHorizontalScroll = ScrollController();
  final ScrollController _bodyHorizontalScroll = ScrollController();
  List<Map<String, dynamic>> shippingEditHistory = [];
  bool isLoading = false;

  int? _sortColumnIndex;
  bool _sortAscending = true;

  static const List<String> _sortKeys = [
    'sopNum',
    'poNum',
    'odd',
    'customer',
    'program',
    'location',
    'shippingDateIn',
    'lastEditedOn',
  ];

  List<Map<String, dynamic>> get _sortedHistory {
    if (_sortColumnIndex == null ||
        _sortColumnIndex! < 0 ||
        _sortColumnIndex! >= _sortKeys.length) {
      return shippingEditHistory;
    }
    final key = _sortKeys[_sortColumnIndex!];
    final rows = List<Map<String, dynamic>>.from(shippingEditHistory);
    rows.sort((a, b) {
      final cmp = _compareValues(a[key], b[key], key);
      if (cmp != 0) return _sortAscending ? cmp : -cmp;
      final sa = a['sopNum']?.toString() ?? '';
      final sb = b['sopNum']?.toString() ?? '';
      return sa.compareTo(sb);
    });
    return rows;
  }

  DateTime? _asDateTime(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty ||
        text == '-' ||
        text == '*' ||
        text.startsWith('0001-01-01')) {
      return null;
    }
    return DateTime.tryParse(text);
  }

  int _compareValues(dynamic a, dynamic b, String key) {
    final isDate = key == 'odd' ||
        key == 'shippingDateIn' ||
        key == 'lastEditedOn';
    if (isDate) {
      final da = _asDateTime(a);
      final db = _asDateTime(b);
      if (da != null && db != null) return da.compareTo(db);
      if (da != null) return -1;
      if (db != null) return 1;
      return 0;
    }
    final sa = a?.toString().trim() ?? '';
    final sb = b?.toString().trim() ?? '';
    final ia = int.tryParse(sa);
    final ib = int.tryParse(sb);
    if (ia != null && ib != null) return ia.compareTo(ib);
    return sa.toLowerCase().compareTo(sb.toLowerCase());
  }

  void _onSort(int columnIndex) {
    if (columnIndex < 0 || columnIndex >= _sortKeys.length) return;
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }

  Future<void> GetShippingEditHistory() async {
    await Dioservices.setToken();
    setState(() {
      isLoading = true;
    });
    try {
      final response = await _service.ShippingInHistory();
      final data = response.data["data"];
      setState(() {
        shippingEditHistory = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
      // debugPrint("SHIPPING EDIT HISTORY DATA: $data");
    } catch (e) {
      print("Error while fetch shipping edit data $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _headerHorizontalScroll.addListener(_syncBodyHorizontalScroll);
    _bodyHorizontalScroll.addListener(_syncHeaderHorizontalScroll);
    GetShippingEditHistory();
  }

  @override
  void dispose() {
    _headerHorizontalScroll.removeListener(_syncBodyHorizontalScroll);
    _bodyHorizontalScroll.removeListener(_syncHeaderHorizontalScroll);
    _headerHorizontalScroll.dispose();
    _bodyHorizontalScroll.dispose();
    SOPController.dispose();
    super.dispose();
  }

  void _syncBodyHorizontalScroll() {
    if (!_bodyHorizontalScroll.hasClients) {
      return;
    }
    if (_bodyHorizontalScroll.offset != _headerHorizontalScroll.offset) {
      _bodyHorizontalScroll.jumpTo(_headerHorizontalScroll.offset);
    }
  }

  void _syncHeaderHorizontalScroll() {
    if (!_headerHorizontalScroll.hasClients) {
      return;
    }
    if (_headerHorizontalScroll.offset != _bodyHorizontalScroll.offset) {
      _headerHorizontalScroll.jumpTo(_bodyHorizontalScroll.offset);
    }
  }

  String formatDate(dynamic date) {
    if (date == null) return "*";
    try {
      String dateStr = date.toString();
      if (dateStr.startsWith("0001-01-01")) {
        return "*";
      }
      DateTime parsedDate = DateTime.parse(dateStr);
      return DateFormat('MM/dd/yyyy').format(parsedDate);
    } catch (e) {
      // print("Date parse error: $e");
      return "-";
    }
  }

  String formatDateTime(dynamic date) {
    if (date == null) return "*";
    try {
      String dateStr = date.toString();
      if (dateStr.startsWith("0001-01-01")) {
        return "*";
      }
      DateTime parsedDate = DateTime.parse(dateStr);
      return DateFormat('MM/dd/yyyy hh:mm:ss a').format(parsedDate);
    } catch (e) {
      print("DateTime parse error: $e");
      return "-";
    }
  }

  static const Color _tableHeaderColor = Color.fromARGB(255, 57, 73, 95);
  static const List<String> _headers = [
    'SOP',
    'PO Num',
    'ODD',
    'Customer',
    'Prgm',
    'Loc.',
    'Ship In',
    'Last Edited On',
    'Action',
  ];
  static const List<double> _minColumnWidths = [
    90, // SOP
    170, // PO Num
    100, // ODD
    280, // Customer
    120, // Prgm
    80, // Loc.
    110, // Ship In
    160, // Last Edited On
    72, // Action
  ];

  double get _minTableWidth =>
      _minColumnWidths.fold<double>(0, (total, width) => total + width);

  List<double> _columnWidthsFor(double availableWidth) {
    if (availableWidth <= _minTableWidth) {
      return _minColumnWidths;
    }
    final scale = availableWidth / _minTableWidth;
    return _minColumnWidths.map((w) => w * scale).toList();
  }

  double _tableContentWidth(double availableWidth) =>
      availableWidth > _minTableWidth ? availableWidth : _minTableWidth;

  Widget _headerCell(String text, double width, {int? sortIndex}) {
    final sortable = sortIndex != null;
    final active = sortable && _sortColumnIndex == sortIndex;
    final up = !active || _sortAscending;

    return SizedBox(
      width: width,
      height: 56,
      child: Material(
        color: _tableHeaderColor,
        child: InkWell(
          onTap: sortable ? () => _onSort(sortIndex) : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 0.5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Align(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
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
                    if (sortable) ...[
                      const SizedBox(width: 3),
                      Icon(
                        up ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: active
                            ? Colors.white
                            : const Color(0x99B8C8E8),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bodyTextCell(
    String text,
    double width, {
    bool wrap = false,
  }) {
    final displayText = wrap
        ? text
            .replaceAll('-', '-\u200B')
            .replaceAll('_', '_\u200B')
            .replaceAll('#', '#\u200B')
        : text;
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 0.5),
      ),
      child: Text(
        displayText,
        textAlign: TextAlign.left,
        softWrap: wrap,
        maxLines: wrap ? null : 1,
        overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildTableHeaderRow(List<double> widths) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _headers.length; i++)
          _headerCell(
            _headers[i],
            widths[i],
            sortIndex: i < _sortKeys.length ? i : null,
          ),
      ],
    );
  }

  Widget _buildTableDataRow(
    Map<String, dynamic> item,
    List<double> widths,
  ) {
    final values = [
      item['sopNum']?.toString() ?? '',
      item['poNum']?.toString() ?? '',
      formatDate(item['odd']?.toString()),
      item['customer']?.toString() ?? '',
      item['program']?.toString() ?? '',
      item['location']?.toString() ?? '',
      formatDate(item['shippingDateIn']?.toString()),
      formatDateTime(item['lastEditedOn']?.toString()),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < values.length; i++)
            _bodyTextCell(
              values[i],
              widths[i],
              // SOP, PO Num, Customer, Prgm — wrap long values instead of "..."
              wrap: i == 0 || i == 1 || i == 3 || i == 4,
            ),
          Container(
            width: widths.last,
            constraints: const BoxConstraints(minHeight: 56),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 0.5),
            ),
            child: IconButton(
              onPressed: () async {
                final sopNumber = item['sopNum']?.toString() ?? '';
                // print("PASSING SOP: $sopNumber");
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShippingEditEntry(sopNumber: sopNumber),
                  ),
                );
                if (updated == true) {
                  await GetShippingEditHistory();
                }
              },
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
        ],
      ),
    );
  }

  Widget buildTable() {
    return Responsive.hideScrollbars(
      context,
      LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = _tableContentWidth(constraints.maxWidth);
        final columnWidths = _columnWidthsFor(constraints.maxWidth);

        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _headerHorizontalScroll,
              child: SizedBox(
                width: contentWidth,
                child: _buildTableHeaderRow(columnWidths),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _bodyHorizontalScroll,
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      children: _sortedHistory
                          .map(
                            (item) => _buildTableDataRow(item, columnWidths),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final isTablet = MediaQuery.sizeOf(context).width >= 700;
    final sopField = TextField(
      controller: SOPController,
      decoration: InputDecoration(
        hintText: 'Enter SOP Number',
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: isTablet ? 12 : 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTablet ? 4 : 12),
          borderSide: BorderSide(
            color: isTablet ? const Color(0xFFBDBDBD) : const Color(0xFF2196F3),
            width: isTablet ? 1 : 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTablet ? 4 : 12),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
      ),
      textInputAction: TextInputAction.search,
    );
    final searchButton = ElevatedButton.icon(
      onPressed: () async {
        final sopNumber = SOPController.text.trim();
        if (sopNumber.isEmpty) {
          AppToast.error(context, 'Please enter SOP number');
          return;
        }

        // print("Searching for SOP: $sopNumber");
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShippingEditEntry(sopNumber: sopNumber),
          ),
        );
        if (updated == true) {
          await GetShippingEditHistory();
        }
      },
      icon: const Icon(Icons.search, size: 20),
      label: Text(isTablet ? 'Search for Entry' : 'Search'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTablet ? 4 : 12),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(),
      drawer: const CommonDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isTablet)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Search SOP to Shipping Edit',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(width: 360, child: sopField),
                    const SizedBox(width: 16),
                    searchButton,
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Search SOP to Shipping Edit',
                    style: TextStyle(
                      fontSize: r.pageTitleSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: r.sectionGap),
                  SizedBox(
                    height: 44,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: sopField),
                        const SizedBox(width: 8),
                        searchButton,
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: Center(child: AppLoader())
                    )
                  : buildTable(),
            ),
          ],
        ),
      ),
    );
  }
}
