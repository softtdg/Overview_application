import 'package:flutter/material.dart';
import 'package:overview_app/Screen/ShippingOut/Components/EditShippingOutEntry.dart';
import 'package:overview_app/Screen/ShippingOut/Components/ShippingOutTable.dart';
import 'package:overview_app/Screen/ShippingOut/Services/ShippingOutServices.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Utils/responsive.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/AppToast.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class ShippingOut extends StatefulWidget {
  @override
  _ShippingOutState createState() => _ShippingOutState();
}

class _ShippingOutState extends State<ShippingOut> {
  final TextEditingController SOPController = TextEditingController();
  final ShippingOutService _service = ShippingOutService();
  List<Map<String, dynamic>> ShippingOutHistory = [];
  List<Map<String, dynamic>> searchedShippingOutHistory = [];
  bool hasSearched = false;
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
    } catch (e) {
      print("Error while feth data for shipping out $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  void _runSearch() {
    final rawInput = SOPController.text.trim();
    final sopTokens = rawInput
        .split(RegExp(r'[\s,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    setState(() {
      hasSearched = true;
      searchedShippingOutHistory = sopTokens.isEmpty
          ? <Map<String, dynamic>>[]
          : ShippingOutHistory.where((item) {
              final sop = item['SOPNum']?.toString() ?? '';
              return sopTokens.contains(sop);
            }).toList();
    });
  }

  void handleSOPs() async {
    final sop = SOPController.text.trim();
    if (sop.isEmpty) {
      AppToast.error(context, "Enter SOP Number");
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });
      await _service.EditSOPNums(sop);
      if (!mounted) return;
      AppToast.success(context, "ShippingOut Date Updated Successfully");
      await GetShippingOutHistory();
      if (!mounted) return;
      _runSearch();
    } catch (e) {
      print("Error in shipping out while update shipping out date");
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      AppToast.error(context, "Something went wrong");
    }
  }

  Future<void> _openEdit(Map<String, dynamic> item) async {
    final SOPId = item['SOPId']?.toString() ?? '-';
    print("PASSING SOPId: $SOPId");
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditShippingOutEntry(SOPId: SOPId)),
    );
    if (updated == true) {
      await GetShippingOutHistory();
      if (hasSearched) {
        _runSearch();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    GetShippingOutHistory();
  }

  @override
  void dispose() {
    SOPController.dispose();
    super.dispose();
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
      onSubmitted: (_) => _runSearch(),
    );
    final searchButton = ElevatedButton.icon(
      onPressed: _runSearch,
      icon: const Icon(Icons.search, size: 20),
      label: Text(isTablet ? 'Search SOP' : 'Search'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTablet ? 4 : 12),
        ),
      ),
    );
    final updateButton = ElevatedButton.icon(
      onPressed: handleSOPs,
      icon: const Icon(Icons.save, size: 20),
      label: const Text(
        'Update SOP Shipping Out Date',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E88E5),
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
                      'Update SOP Shipping Out Date',
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
                    'Update SOP Shipping Out Date',
                    style: TextStyle(
                      fontSize: r.pageTitleSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: r.sectionGap),
                  SizedBox(
                    height: r.searchButtonHeight,
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
            if (hasSearched) ...[
              if (searchedShippingOutHistory.isNotEmpty) ...[
                Responsive.hideScrollbars(
                  context,
                  ShippingOutTable(
                    rows: searchedShippingOutHistory,
                    showLastEditedAndAction: false,
                    isSearchTable: true,
                    shrinkWrap: true,
                  ),
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: updateButton),
                const SizedBox(height: 12),
              ] else
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE57373)),
                  ),
                  child: const Text(
                    'Invalid or cancelled SOP number. Please enter a valid SOP.',
                    style: TextStyle(
                      color: Color(0xFFC62828),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
            const Text(
              'SOP History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: isLoading
                  ? const Center(child: Center(child: AppLoader()))
                  : Responsive.hideScrollbars(
                      context,
                      ShippingOutTable(
                        rows: ShippingOutHistory,
                        onEdit: _openEdit,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
