import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/ShippingOut/Components/EditShippingOutEntry.dart';
import 'package:overview_app/Screen/ShippingOut/Services/ShippingOutServices.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class ShippingOut extends StatefulWidget {
  @override
  _ShippingOutState createState() => _ShippingOutState();
}

class _ShippingOutState extends State<ShippingOut> {
  final TextEditingController SOPController = TextEditingController();
  final ShippingOutService _service = ShippingOutService();
  final ScrollController _headerHorizontalScroll = ScrollController();
  final ScrollController _bodyHorizontalScroll = ScrollController();
  List<Map<String, dynamic>> ShippingOutHistory = [];
  bool isLoading = false;

  Future<void> GetShippingOutHistory() async {
    await Dioservices.setToken();
    setState(() {
      isLoading = true;
    });
    try {
      final response = await _service.ShippingOutHistory();
      final data = response.data["data"];
      setState(() {
        ShippingOutHistory = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
      // debugPrint("SHIPPING OUT DATA $data");
    } catch (e) {
      print("Error while feth data for shipping out $e");
    }
  }

  void handleSOPs() async {
    try {
      setState(() {
        isLoading = true;
      });
      await _service.EditSOPNums(SOPController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ShippingOut Date Updated Successfully")),
      );
      await GetShippingOutHistory();
    } catch (e) {
      print("Error in shipping out while update shipping out date");
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Something went wrong")));
    }
  }

  @override
  void initState() {
    super.initState();
    _headerHorizontalScroll.addListener(_syncBodyHorizontalScroll);
    _bodyHorizontalScroll.addListener(_syncHeaderHorizontalScroll);
    GetShippingOutHistory();
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
      print("DateTime parse error: $e");
      return "-";
    }
  }

  static const Color _tableHeaderColor = Color.fromARGB(255, 57, 73, 95);

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

  Widget _bodyTextCell(
    String text,
    double width, {
    bool wrap = false,
  }) {
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

  Widget _buildTableHeaderRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerCell('SOP', 60),
        _headerCell('PO Num', 80),
        _headerCell('ODD', 90),
        _headerCell('Customer', 260),
        _headerCell('Prgm', 100),
        _headerCell('Loc.', 90),
        _headerCell('SOP Entry', 140),
        _headerCell('SOP Out', 75),
        _headerCell('PROD MGR', 70),
        _headerCell('Delivery Date', 100),
        _headerCell('New Comments', 110),
        _headerCell('Last Edited On', 100),
        _headerCell('Action', 90),
      ],
    );
  }

  Widget _buildTableDataRow(Map<String, dynamic> item) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bodyTextCell(item['SOPNum']?.toString() ?? '-', 60),
          _bodyTextCell(item['PONum']?.toString() ?? '-', 80),
          _bodyTextCell(formatDate(item['ODD']?.toString() ?? '-'), 90),
          _bodyTextCell(item['customer']?.toString() ?? '-', 260, wrap: true),
          _bodyTextCell(item['program']?.toString() ?? '-', 100),
          _bodyTextCell(item['Location']?.toString() ?? '-', 90),
          _bodyTextCell(
            formatDate(item['SOPEntryDateIn']?.toString() ?? '-'),
            140,
          ),
          _bodyTextCell(
            formatDate(item['SOPOrderEntryOut']?.toString() ?? '-'),
            75,
          ),
          _bodyTextCell(item['prodMgr']?.toString() ?? '-', 70),
          _bodyTextCell(
            formatDate(item['FinalDeliveryDate']?.toString() ?? '-'),
            100,
          ),
          _bodyTextCell(item['OrderEntryComments']?.toString() ?? '-', 110),
          _bodyTextCell(
            formatDateTime(item['LastEdit']?.toString() ?? '-'),
            100,
          ),
          Container(
            width: 90,
            constraints: const BoxConstraints(minHeight: 56),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 0.5),
            ),
            child: OutlinedButton.icon(
              onPressed: () async {
                final SOPId = item['SOPId']?.toString() ?? '-';
                print("PASSING SOPId: $SOPId");
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditShippingOutEntry(SOPId: SOPId),
                  ),
                );
                if (updated == true) {
                  await GetShippingOutHistory();
                }
              },
              icon: const Icon(
                Icons.edit,
                size: 20,
                color: Colors.black,
              ),
              label: const Text(''),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
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
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _headerHorizontalScroll,
          child: _buildTableHeaderRow(),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _bodyHorizontalScroll,
              child: Column(
                children: ShippingOutHistory
                    .map(_buildTableDataRow)
                    .toList(growable: false),
              ),
            ),
          ),
        ),
      ],
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
      onPressed: handleSOPs,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTablet ? 4 : 12),
        ),
      ),
      child: const Text(
        'Update SOP Shipping Out Date',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      'Update SOP Shipping Out Date',
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
                    'Update SOP Shipping Out Date',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
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
