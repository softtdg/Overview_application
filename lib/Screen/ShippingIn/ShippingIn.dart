import 'package:flutter/material.dart';
import 'package:overview_app/Screen/ShippingIn/Compomnents/EditShippingInEntry.dart';
import 'package:overview_app/Screen/ShippingIn/Services/ShippingInService.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:intl/intl.dart';

class ShippingIn extends StatefulWidget {
  @override
  _ShippingInState createState() => _ShippingInState();
}

class _ShippingInState extends State<ShippingIn> {
  final TextEditingController SOPController = TextEditingController();
  final ShippingInService _service = ShippingInService();
  final ScrollController _headerHorizontalScroll = ScrollController();
  final ScrollController _bodyHorizontalScroll = ScrollController();
  List<Map<String, dynamic>> shippingInHistory = [];
  String username = '';
  bool isLoading = false;

  Future<void> GetShippingInHistory() async {
    await Dioservices.setToken();
    setState(() {
      isLoading = true;
    });
    try {
      final response = await _service.ShippingInHistory();
      final data = response.data["data"];
      setState(() {
        shippingInHistory = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
      debugPrint("SHIPPING IN HISTORY DATA: $data");
    } catch (e) {
      print("Error while fetch shipping in data $e");
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
    GetShippingInHistory();
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
      return DateFormat('dd/MM/yyyy').format(parsedDate);
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
      return DateFormat('dd/MM/yyyy hh:mm a').format(parsedDate);
    } catch (e) {
      // print("DateTime parse error: $e");
      return "-";
    }
  }

  void handleEditShippingInDate() async {
    try {
      setState(() {
        isLoading = true;
      });
      await _service.EditShippingInDate(SOPController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Shipping in date updated successfully")),
      );
      await GetShippingInHistory();
    } catch (e) {
      print("Error while editing shipping in date $e");
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error while editing shipping in date $e")),
      );
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
    60,
    70,
    90,
    260,
    100,
    90,
    140,
    170,
    90,
  ];

  double get _minTableWidth =>
      _minColumnWidths.fold<double>(0, (total, width) => total + width);

  List<double> _columnWidthsFor(double availableWidth) {
    if (availableWidth <= _minTableWidth) {
      return _minColumnWidths;
    }
    final extra = availableWidth - _minTableWidth;
    return [
      for (var i = 0; i < _minColumnWidths.length; i++)
        _minColumnWidths[i] + (i == 3 ? extra : 0),
    ];
  }

  double _tableContentWidth(double availableWidth) =>
      availableWidth > _minTableWidth ? availableWidth : _minTableWidth;

  Widget _headerCell(String text, double width) {
    return SizedBox(
      width: width,
      height: 56,
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
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 0.5),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
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
          _headerCell(_headers[i], widths[i]),
      ],
    );
  }

  Widget _buildTableDataRow(Map<String, dynamic> item, List<double> widths) {
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
            _bodyTextCell(values[i], widths[i], wrap: i == 3),
          Container(
            width: widths.last,
            constraints: const BoxConstraints(minHeight: 56),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 0.5),
            ),
            child: OutlinedButton.icon(
              onPressed: () async {
                final sopNumber = item['sopNum']?.toString() ?? '';
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditShippingInEntry(sopNumber: sopNumber),
                  ),
                );
                if (updated == true) {
                  await GetShippingInHistory();
                }
              },
              icon: const Icon(Icons.edit, size: 20, color: Colors.black),
              label: const Text(''),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTable() {
    return LayoutBuilder(
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
                      children: shippingInHistory
                          .map((item) => _buildTableDataRow(item, columnWidths))
                          .toList(growable: false),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
    final updateButton = ElevatedButton(
      onPressed: handleEditShippingInDate,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTablet ? 4 : 12),
        ),
      ),
      child: const Text(
        'Update SOP Shipping In Date',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(),
      drawer: CommonDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isTablet)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Update SOP Shipping In Date',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(width: 360, child: sopField),
                    const SizedBox(width: 16),
                    updateButton,
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Update SOP Shipping In Date',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  sopField,
                  const SizedBox(height: 12),
                  updateButton,
                ],
              ),
            const SizedBox(height: 12),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color.fromARGB(255, 57, 73, 95),
                      ),
                    )
                  : buildTable(),
            ),
          ],
        ),
      ),
    );
  }
}
