import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/MPF/Services/MPFServices.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _formatOdd(dynamic raw) {
  final v = raw?.toString().trim() ?? '';
  if (v.isEmpty || v.startsWith('0001-01-01')) return '';
  final d = DateTime.tryParse(v);
  if (d == null) return v;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class PickList extends StatefulWidget {
  final String fixtureNumber;
  final String sopNumber;
  final String mpf;
  final bool customMpf;
  final bool livePdmMpf;

  const PickList({
    super.key,
    required this.fixtureNumber,
    required this.sopNumber,
    required this.mpf,
    this.customMpf = false,
    this.livePdmMpf = false,
  });

  @override
  State<PickList> createState() => _PickListState();
}

class _PickListState extends State<PickList> {
  final MPFServices _services = MPFServices();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _rmaController = TextEditingController();
  final ScrollController _verticalScrollController = ScrollController();
  String? selectedMpfRequestedBy;
  String? selectedComment;

  final List<String> mpfRequestedByList = [
    "GEORGEK",
    "GARY",
    "JOED",
    "JOEL",
    "BELA",
    "PREET",
    "JENIFFER",
    "om",
    "Other",
  ];

  final List<Map<String, String>> commentOptions = [
    {"label": "EVALUATION SAMPLE", "value": "EVALUATION SAMPLE"},
    {"label": "WARRANTY RMA", "value": "WARRANTY RMA"},
    {"label": "PROTOTYPE", "value": "PROTOTYPE"},
    {"label": "CUSTOMER ACCOMODATIONS", "value": "CUSTOMER ACCOMODATIONS"},
    {"label": "INTERNAL TESTING / FAI", "value": "INTERNAL TESTING / FAI"},
    {"label": "BOM-INACCURATE", "value": "BOM-INACCURATE"},
    {"label": "NO PICK LIST", "value": "NO PICK LIST"},
    {"label": "REWORK", "value": "REWORK"},
    {"label": "QC REJECTS", "value": "QC REJECTS"},
    {"label": "WRONG QTY", "value": "WRONG QTY"},
    {"label": "SCRAP", "value": "SCRAP"},
    {
      "label": "ENGINEERING TESTING (no SOP)",
      "value": "ENGINEERING TESTING (no SOP)",
    },
    {"label": "DEFECTIVE/DAMAGED PART", "value": "DEFECTIVE/DAMAGED PART"},
    {"label": "Other", "value": "Other"},
  ];

  static const _measureOptions = [
    'MM',
    'CM',
    'M',
    'LBS',
    'G',
    'KG',
    'ML',
    'L',
    'PCS',
  ];

  String _pickListNo = '';
  String _project = '';
  String _requiredOn = '';
  String _description = '';
  String _pickListLogNumber = '0';
  String _datePicked = '';
  String _leadHandSignOff = '';
  String _oddIso = '';
  String _programName = '';
  String _sopNum = '';

  bool _dropdownOpen = false;
  bool _inventoryDownloading = false;
  int _selectedIndex = 0;
  List<({String sop, String odd, String qty, bool isBlank})> _dropdownOptions =
      [(sop: '', odd: '', qty: '', isBlank: true)];
  List<_SheetRow> _sheetRows = [];
  List<Map<String, dynamic>> _rawSheetData = [];
  Map<String, dynamic> _pickListResponse = {};
  final List<TextEditingController> _mpfControllers = [];

  void _syncMpfControllers(List<_SheetRow> rows) {
    for (final c in _mpfControllers) {
      c.dispose();
    }
    _mpfControllers
      ..clear()
      ..addAll(rows.map((r) => TextEditingController(text: r.mpfQty)));
  }

  @override
  void initState() {
    super.initState();
    if (widget.livePdmMpf) {
      _fetchLivePdmPickList();
    } else {
      _fetchSOPList();
      _fetchPickList();
    }
    _fetchPickListCount();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _rmaController.dispose();
    _verticalScrollController.dispose();
    for (final c in _mpfControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchSOPList() async {
    try {
      await Dioservices.setToken();
      final user =
          (await SharedPreferences.getInstance()).getString('UserName') ?? '';

      final response = await _services.fixtureDetails(
        fixtureNumber: widget.fixtureNumber,
        sopNumber: widget.sopNumber,
        mpf: widget.mpf,
        user: user,
      );

      final options = <({String sop, String odd, String qty, bool isBlank})>[
        (sop: '', odd: '', qty: '', isBlank: true),
      ];

      final data = response.data?['data'];
      final list = data is List
          ? data
          : data is Map && data['LeadHandEntries'] is List
          ? data['LeadHandEntries'] as List
          : null;

      if (list != null) {
        for (final e in list) {
          if (e is! Map) continue;
          final sop =
              e['SOPNum']?.toString() ??
              e['sopNumber']?.toString() ??
              widget.sopNumber;
          options.add((
            sop: sop,
            odd: _formatOdd(e['odd'] ?? e['odd']),
            qty: (e['Quantity'] ?? e['qty'] ?? '').toString(),
            isBlank: false,
          ));
        }
      }

      setState(() {
        _dropdownOptions = options;
        _selectedIndex = 0;
      });
    } catch (e) {
      debugPrint('PICK LIST DROPDOWN ERROR: $e');
      setState(() {
        _dropdownOptions = [(sop: '', odd: '', qty: '', isBlank: true)];
        _selectedIndex = 0;
      });
    }
  }

  Future<void> _fetchPickListCount() async {
    try {
      await Dioservices.setToken();
      final response = await _services.PickListCount();
      final data = response.data?['data'];
      if (data is! List || data.isEmpty) return;
      final first = data.first;
      if (first is! Map) return;
      final no = first['pickListNumber']?.toString().trim() ?? '';
      if (no.isEmpty) return;
      setState(() => _pickListNo = no);
    } catch (e) {
      debugPrint('PICK LIST COUNT ERROR: $e');
    }
  }

  Future<String> _currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    // Login saves 'UserName' — not 'Username'
    return (prefs.getString('UserName') ?? prefs.getString('Username') ?? '')
        .trim()
        .toLowerCase();
  }

  void _applyPickListMap(Map<String, dynamic> map, {List<dynamic>? rows}) {
    final detail = map['excelFixtureDetail'] is Map
        ? Map<String, dynamic>.from(map['excelFixtureDetail'])
        : <String, dynamic>{};
    String pick(String k) {
      final v = map[k] ?? detail[k];
      return v == null ? '' : v.toString().trim();
    }

    final rawRows = rows ?? map['listData'] ?? map['sheetData'] ?? const [];
    final mappedRows = (rawRows is List ? rawRows : const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    setState(() {
      _pickListResponse = map;
      _rawSheetData = mappedRows;
      _project = pick('project');
      final qty = pick('tempQuantity').isNotEmpty
          ? pick('tempQuantity')
          : pick('Quantity');
      _qtyController.text = qty.isEmpty ? '1' : qty;
      _oddIso =
          (map['ODD'] ?? detail['ODD'] ?? map['odd'] ?? detail['odd'] ?? '')
              .toString();
      _requiredOn = _formatOdd(_oddIso);
      _description = pick('description').isNotEmpty
          ? pick('description')
          : pick('Description');
      _programName = pick('programName');
      _sopNum = pick('sopNum').isNotEmpty ? pick('sopNum') : widget.sopNumber;
      final log = pick('pickListLogNumber');
      _pickListLogNumber = log.isEmpty ? '0' : log;
      _datePicked = _formatOdd(map['datePicked'] ?? detail['datePicked']);
      _rmaController.text = pick('RMA');
      _leadHandSignOff = pick('MPFRequestedBy');

      _sheetRows = mappedRows.map(_SheetRow.fromMap).toList();
      _syncMpfControllers(_sheetRows);
    });
  }

  Future<void> _downloadInventoryPickList() async {
    if (_inventoryDownloading) return;

    if (_sheetRows.isEmpty || _rawSheetData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pick list data available')),
      );
      return;
    }

    final requestedBy = selectedMpfRequestedBy?.trim() ?? '';
    if (requestedBy.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MPF Requested By is required')),
      );
      return;
    }

    setState(() => _inventoryDownloading = true);

    try {
      await Dioservices.setToken();

      final qty = double.tryParse(_qtyController.text.trim()) ?? 1;
      final sheetData = <Map<String, dynamic>>[];
      var hasAtLeastOneMpfQty = false;
      var hasMissingCommentForMpfQty = false;
      for (var i = 0; i < _rawSheetData.length; i++) {
        final item = _rawSheetData[i];
        final isGray =
            item['isGray'] == true ||
            item['isGrayRow'] == true ||
            (i < _sheetRows.length && _sheetRows[i].isGray);
        if (isGray) continue;

        final row = Map<String, dynamic>.from(item);
        final totalQty = row['TotalQtyNeeded'] ?? row['totalQtyNeeded'] ?? 0;
        final controllerQty = i < _mpfControllers.length
            ? _mpfControllers[i].text.trim()
            : '';
        final mpfQty = controllerQty.isNotEmpty
            ? controllerQty
            : (row['mpfQty'] ?? '');
        final hasMpf =
            mpfQty.toString().trim().isNotEmpty &&
            mpfQty.toString().trim() != '0';
        final commentValue =
            (row['InventoryComments'] ??
                    row['Comments'] ??
                    selectedComment ??
                    '')
                .toString()
                .trim();

        if (hasMpf) {
          hasAtLeastOneMpfQty = true;
          if (commentValue.isEmpty) {
            hasMissingCommentForMpfQty = true;
          }
        }

        row['ActualQtyPicked'] = '';
        row['mpfQty'] = hasMpf ? mpfQty : '';
        row['TotalQtyNeeded'] = totalQty ?? 0;
        row['QuantityPerFixture'] = row['QuantityPerFixture'] ?? 0;
        row['Quantity'] = row['Quantity'] ?? 0;
        row['Size'] = row['Size'] ?? 0;
        row['TDGPN'] = row['TDGPN'] ?? '';
        row['Description'] = row['Description'] ?? '';
        row['Vendor'] = row['Vendor'] ?? '';
        row['VendorPN'] = row['VendorPN'] ?? '';
        row['UnitOfMeasure'] = row['UnitOfMeasure'] ?? 'PCS';
        row['Location'] = row['Location'] ?? '';
        row['LeadHandComments'] = row['LeadHandComments'] ?? '';
        row['InventoryComments'] = commentValue;
        row['isGray'] = false;
        sheetData.add(row);
      }

      if (sheetData.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No editable (non-gray) rows to download'),
          ),
        );
        return;
      }

      if (!hasAtLeastOneMpfQty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enter at least one MPF quantity when MPF is enabled',
            ),
          ),
        );
        return;
      }

      if (hasMissingCommentForMpfQty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Comments are required for all items with MPF quantities',
            ),
          ),
        );
        return;
      }

      final detail = _pickListResponse['excelFixtureDetail'] is Map
          ? Map<String, dynamic>.from(_pickListResponse['excelFixtureDetail'])
          : <String, dynamic>{};

      final pickListNumber = int.tryParse(_pickListNo) ?? 1;

      final payload = {
        'excelFixtureDetail': {
          'description': detail['description']?.toString().isNotEmpty == true
              ? detail['description']
              : (_description.isNotEmpty ? _description : 'Blank Pick List'),
          'sopNum': detail['sopNum'] ?? _sopNum,
          'programName': detail['programName'] ?? _programName,
          'fixture': widget.fixtureNumber,
          'tempQuantity': qty,
          'odd':
              detail['odd'] ??
              (_oddIso.isNotEmpty
                  ? _oddIso
                  : DateTime.now().toUtc().toIso8601String()),
        },
        'sheetData': sheetData,
        'project': _project,
        'RMA': _rmaController.text.trim(),
        'pickListNumber': pickListNumber,
        'mpfStatus': 1,
        'MPFRequestedBy': requestedBy,
        'InventoryComments': '',
        'sheetType': 0,
        'zeroLevel': false,
      };

      final response = await _services.inventoryPickList(payload);
      final root = response.data;
      final ok =
          response.statusCode == 200 &&
          (root is! Map ||
              root['status']?.toString().toUpperCase() == 'SUCCESS' ||
              root['status'] == null);

      if (!mounted) return;
      if (ok) {
        _margaretDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              root is Map && root['message'] != null
                  ? root['message'].toString()
                  : 'Failed to create inventory pick list',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('INVENTORY PICK LIST DOWNLOAD ERROR: $e');
      if (!mounted) return;
      String message = 'Failed to create inventory pick list';
      if (e is DioException && e.response?.data is Map) {
        message = e.response!.data['message']?.toString() ?? message;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _inventoryDownloading = false);
    }
  }

  void _margaretDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1976D2),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      "MPF Request Submitted Successfully",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green, width: 4),
                  ),
                  child: const Icon(Icons.check, color: Colors.green, size: 45),
                ),
                const SizedBox(height: 25),
                const Text(
                  "For any inquiry, see MARGARET",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Your MPF request has been processed successfully.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                const Divider(height: 1),
                Container(
                  color: const Color(0xFFF9FAFB),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      minimumSize: const Size(110, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "OK",
                      style: TextStyle(color: Colors.white, fontSize: 17),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchPickList() async {
    try {
      await Dioservices.setToken();
      final user = await _currentUser();
      final response = await _services.PickListData(user, widget.fixtureNumber);
      print("PICK LIST DATA [[[[response.data:]]]] ${response.data}");
      final data = response.data?['data'];
      final Map<String, dynamic>? map = data is Map
          ? Map<String, dynamic>.from(data)
          : data is List && data.isNotEmpty && data.first is Map
          ? Map<String, dynamic>.from(data.first)
          : null;
      if (map == null) return;
      _applyPickListMap(map);
    } catch (e) {
      debugPrint('PICK LIST ERROR: $e');
    }
  }

  Future<void> _fetchLivePdmPickList() async {
    try {
      await Dioservices.setToken();
      final user = await _currentUser();
      if (user.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not found. Please log in again.'),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      debugPrint(
        'LIVE PDM CALL → sop=${widget.sopNumber} fixture=${widget.fixtureNumber} user=$user',
      );

      final response = await _services.getFixtureDataFromLivePdm(
        sopNumber: widget.sopNumber,
        fixtureNumber: widget.fixtureNumber,
        user: user,
        lhrEntryId: '',
      );

      debugPrint('LIVE PDM URL: ${response.requestOptions.uri}');

      // Match web: response.data.data.listData
      final root = response.data;
      if (root is! Map) return;

      final data = root['data'];
      if (data is! Map) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              root['message']?.toString() ?? 'Live PDM returned no data',
            ),
          ),
        );
        return;
      }

      final map = Map<String, dynamic>.from(data);
      final listData = map['listData'];
      _applyPickListMap(map, rows: listData is List ? listData : const []);
    } catch (e) {
      debugPrint('LIVE PDM PICK LIST ERROR: $e');
      String message = 'Live PDM request failed';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        } else if (e.response?.statusCode == 401) {
          message = 'Session expired. Please log out and log in again.';
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
      );
    }
  }

  Widget editableCell(
    TextEditingController controller, {
    double? width,
    required double rowHeight,
    Color bgColor = Colors.white,
    Color? textColor,
    double fontSize = 14,
    TextInputType keyboardType = TextInputType.text,
    bool showBottomBorder = true,
    bool showRightBorder = true,
  }) {
    const inputBorderColor = Color(0xFF1B5E20);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: const BorderSide(color: inputBorderColor),
    );

    return Container(
      width: width,
      height: rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textAlign: TextAlign.center,
        expands: true,
        maxLines: null,
        style: TextStyle(
          color: textColor ?? const Color(0xFF0C4A7D),
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          border: inputBorder,
          enabledBorder: inputBorder,
          focusedBorder: inputBorder.copyWith(
            borderSide: const BorderSide(color: inputBorderColor, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget mpfRequestedByDropdown({
    required double rowHeight,
    Color bgColor = const Color(0xFFF1F3F5),
    Color? textColor,
    double fontSize = 14,
  }) {
    return Container(
      height: rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(bottom: BorderSide.none, right: BorderSide.none),
      ),
      child: DropdownButtonFormField<String>(
        value: selectedMpfRequestedBy,
        isExpanded: true,
        dropdownColor: Colors.white,
        isDense: true,
        style: TextStyle(
          color: textColor ?? const Color(0xFF0C4A7D),
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.grey),
          ),
        ),
        hint: const Text('Select...'),
        items: mpfRequestedByList.map((name) {
          return DropdownMenuItem(value: name, child: Text(name));
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedMpfRequestedBy = value;
          });
        },
      ),
    );
  }

  Widget commentDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedComment,
      isExpanded: true,
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Colors.grey),
        ),
      ),
      hint: const Text('Common comment...'),
      items: commentOptions.map((option) {
        return DropdownMenuItem<String>(
          value: option['value'],
          child: Text(option['label']!),
        );
      }).toList(),
      onChanged: (value) => setState(() => selectedComment = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 480;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(),
      drawer: const CommonDrawer(),
      body: Column(
        children: [
          _buildPageHeader(),
          Expanded(
            child: Scrollbar(
              controller: _verticalScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              child: SingleChildScrollView(
                controller: _verticalScrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLeadHandDropdown(),
                    const SizedBox(height: 16),
                    _buildInfoGrid(isMobile: isMobile),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: commentDropdown()),
                        const SizedBox(width: 8),
                        Flexible(
                          child: OutlinedButton(
                            onPressed: selectedComment == null
                                ? null
                                : _applyCommentToAll,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              isMobile ? 'Apply All' : 'Apply Comment to All',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSheetTable(),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _inventoryDownloading
                            ? null
                            : _downloadInventoryPickList,
                        icon: _inventoryDownloading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF065F46),
                                ),
                              )
                            : const Icon(Icons.download, size: 18),
                        label: Text(
                          _inventoryDownloading
                              ? 'Downloading...'
                              : 'Inventory pick list download',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB7E5B3),
                          foregroundColor: const Color(0xFF065F46),
                          disabledBackgroundColor: const Color(0xFF9CA3AF),
                          disabledForegroundColor: const Color(0xFFD1D5DB),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Manual Pick Form',
            style: TextStyle(
              color: Color(0xFF1B5E20),
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fixture : ${widget.fixtureNumber}',
            style: const TextStyle(color: Color(0xFF1A3B5D), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadHandDropdown() {
    const selectedBg = Color(0xFFD6E4F0);
    final selected =
        _dropdownOptions[_selectedIndex.clamp(0, _dropdownOptions.length - 1)];
    final label = selected.isBlank ? 'Blank Pick List' : 'SOP: ${selected.sop}';
    final screenWidth = MediaQuery.sizeOf(context).width;
    const cols = 3;
    const gap = 8.0;
    const pad = 8.0;
    final dropdownWidth = (screenWidth * 0.72).clamp(420.0, 640.0);
    final tileWidth = (dropdownWidth - pad * 2 - gap * (cols - 1)) / cols;

    return SizedBox(
      width: dropdownWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select SOPLeadHandEntryId',
            style: TextStyle(
              color: Color(0xFF1B5E20),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _dropdownOpen = !_dropdownOpen),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  Icon(
                    _dropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  ),
                ],
              ),
            ),
          ),
          if (_dropdownOpen)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(pad),
                  child: Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (var i = 0; i < _dropdownOptions.length; i++)
                        SizedBox(
                          width: tileWidth,
                          child: _sopDropdownTile(i, selectedBg),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sopDropdownTile(int index, Color selectedBg) {
    final item = _dropdownOptions[index];
    final isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
          _dropdownOpen = false;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.white,
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: item.isBlank
            ? const Text(
                'Blank Pick List',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SOP: ${item.sop}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('ODD: ${item.odd}'),
                  Text('Qty: ${item.qty}'),
                ],
              ),
      ),
    );
  }

  String get _mpfRequestedOn =>
      DateFormat('MMMM d, yyyy').format(DateTime.now());

  String get _referenceSop {
    final selected =
        _dropdownOptions[_selectedIndex.clamp(0, _dropdownOptions.length - 1)];
    if (!selected.isBlank && selected.sop.isNotEmpty) return selected.sop;
    return widget.sopNumber;
  }

  Widget _buildInfoGrid({required bool isMobile}) {
    const borderColor = Color(0xFF2C3138);
    final rowHeight = isMobile ? 48.0 : 44.0;
    final labelFontSize = isMobile ? 10.0 : 12.0;
    final valueFontSize = isMobile ? 10.0 : 14.0;
    final leftLabelFlex = isMobile ? 26 : 22;
    final leftValueFlex = isMobile ? 20 : 24;
    final isBlankPickList =
        _dropdownOptions[_selectedIndex.clamp(0, _dropdownOptions.length - 1)]
            .isBlank;
    final labelBg = isBlankPickList
        ? const Color(0xFFB9C7D9)
        : const Color(0xFFE8F5E9);
    final valueBg = isBlankPickList
        ? const Color(0xFFF1F3F5)
        : const Color(0xFFF5F9F5);
    final pickListLogBg = isBlankPickList ? const Color(0xFFE8F5E9) : valueBg;
    final textColor = isBlankPickList
        ? const Color(0xFF0C4A7D)
        : const Color(0xFF166534);

    return Container(
      decoration: BoxDecoration(border: Border.all(color: borderColor)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                  textColor: textColor,
                  isLabel: true,
                ),
              ),
              Expanded(
                flex: leftValueFlex,
                child: _tableCell(
                  _referenceSop,
                  height: rowHeight,
                  bgColor: labelBg,
                  fontSize: valueFontSize,
                  textColor: textColor,
                  isBold: true,
                  alignCenter: true,
                ),
              ),
              Expanded(
                flex: 15,
                child: _tableCell(
                  _pickListNo.isEmpty
                      ? 'PICK\nLIST #'
                      : 'PICK\nLIST #$_pickListNo',
                  height: rowHeight,
                  bgColor: labelBg,
                  fontSize: isMobile ? labelFontSize : 11,
                  textColor: textColor,
                  isLabel: true,
                  alignCenter: true,
                  maxLines: 4,
                ),
              ),
              Expanded(
                flex: 23,
                child: _tableCell(
                  'MPF DATE \nREQUESTED ON',
                  height: rowHeight,
                  bgColor: labelBg,
                  fontSize: labelFontSize,
                  textColor: textColor,
                  isLabel: true,
                ),
              ),
              Expanded(
                flex: 22,
                child: _tableCell(
                  _mpfRequestedOn,
                  height: rowHeight,
                  bgColor: labelBg,
                  fontSize: valueFontSize,
                  textColor: textColor,
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
                  textColor: textColor,
                  isLabel: true,
                ),
              ),
              Expanded(
                flex: leftValueFlex,
                child: Column(
                  children: [
                    _tableCell(
                      _project,
                      height: rowHeight,
                      bgColor: valueBg,
                      fontSize: valueFontSize,
                      textColor: textColor,
                      alignCenter: true,
                    ),
                    _tableCell(
                      widget.fixtureNumber,
                      height: rowHeight,
                      bgColor: valueBg,
                      fontSize: valueFontSize,
                      textColor: textColor,
                      alignCenter: true,
                    ),
                    editableCell(
                      _qtyController,
                      rowHeight: rowHeight,
                      bgColor: Colors.white,
                      fontSize: valueFontSize,
                      textColor: textColor,
                      keyboardType: TextInputType.number,
                    ),
                    _tableCell(
                      _requiredOn,
                      height: rowHeight,
                      bgColor: valueBg,
                      fontSize: valueFontSize,
                      textColor: textColor,
                      alignCenter: true,
                      showBottomBorder: false,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 15,
                child: _tableCell(
                  _description,
                  height: rowHeight * 4,
                  bgColor: valueBg,
                  fontSize: valueFontSize,
                  textColor: textColor,
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
                    'MPF REQUESTED BY',
                  ],
                  bgColor: labelBg,
                  textColor: textColor,
                  isLabel: true,
                ),
              ),
              Expanded(
                flex: 22,
                child: Column(
                  children: [
                    _tableCell(
                      _pickListLogNumber,
                      height: rowHeight,
                      bgColor: pickListLogBg,
                      fontSize: valueFontSize,
                      textColor: textColor,
                      alignCenter: true,
                    ),
                    _tableCell(
                      _datePicked,
                      height: rowHeight,
                      bgColor: valueBg,
                      fontSize: valueFontSize,
                      textColor: textColor,
                      alignCenter: true,
                    ),
                    editableCell(
                      _rmaController,
                      rowHeight: rowHeight,
                      bgColor: Colors.white,
                      fontSize: valueFontSize,
                      textColor: textColor,
                    ),
                    mpfRequestedByDropdown(
                      rowHeight: rowHeight,
                      bgColor: valueBg,
                      fontSize: valueFontSize,
                      textColor: textColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _applyCommentToAll() {
    final comment = selectedComment;
    if (comment == null) return;
    setState(() {
      _sheetRows = [
        for (final r in _sheetRows)
          r.isGray ? r : r.copyWith(comments: comment),
      ];
      for (var i = 0; i < _rawSheetData.length; i++) {
        final isGray =
            _rawSheetData[i]['isGray'] == true ||
            _rawSheetData[i]['isGrayRow'] == true;
        if (isGray) continue;
        _rawSheetData[i]['InventoryComments'] = comment;
        _rawSheetData[i]['Comments'] = comment;
      }
    });
  }

  void _copyTotalToActual() {
    setState(() {
      _sheetRows = [
        for (final r in _sheetRows)
          r.isGray ? r : r.copyWith(mpfQty: r.totalQtyNeeded),
      ];
      for (var i = 0; i < _rawSheetData.length && i < _sheetRows.length; i++) {
        if (_sheetRows[i].isGray) continue;
        final total =
            _rawSheetData[i]['TotalQtyNeeded'] ?? _sheetRows[i].totalQtyNeeded;
        _rawSheetData[i]['mpfQty'] = total;
        if (i < _mpfControllers.length) {
          _mpfControllers[i].text = total.toString();
        }
      }
    });
  }

  void _updateMpfQty(int index, String value) {
    if (index < 0 || index >= _sheetRows.length) return;
    _sheetRows[index] = _sheetRows[index].copyWith(mpfQty: value);
    if (index < _rawSheetData.length) {
      _rawSheetData[index]['mpfQty'] = value;
    }
  }

  void _updateRowComment(int index, String? value) {
    if (index < 0 || index >= _sheetRows.length) return;
    final comment = value ?? '';
    setState(() {
      _sheetRows[index] = _sheetRows[index].copyWith(comments: comment);
      if (index < _rawSheetData.length) {
        _rawSheetData[index]['InventoryComments'] = comment;
        _rawSheetData[index]['Comments'] = comment;
      }
    });
  }

  void _updateUnitOfMeasure(int index, String? value) {
    if (index < 0 || index >= _sheetRows.length) return;
    final uom = (value ?? '').trim().toUpperCase();
    setState(() {
      _sheetRows[index] = _sheetRows[index].copyWith(unitOfMeasure: uom);
      if (index < _rawSheetData.length) {
        _rawSheetData[index]['UnitOfMeasure'] = uom;
      }
    });
  }

  Widget _unitOfMeasureDropdown({
    required int index,
    required String current,
    required double width,
    required double rowHeight,
  }) {
    final normalized = current.trim().toUpperCase();
    final value = _measureOptions.contains(normalized) ? normalized : '';
    final display = value.isEmpty ? 'Select...' : value;

    return Container(
      width: width,
      height: rowHeight,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFD1D5DB)),
          bottom: BorderSide(color: Color(0xFFD1D5DB)),
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: '',
        initialValue: value,
        position: PopupMenuPosition.under,
        offset: const Offset(0, 2),
        color: Colors.white,
        elevation: 4,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 90, maxWidth: 120),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
        onSelected: (v) => _updateUnitOfMeasure(index, v),
        itemBuilder: (context) {
          final options = ['', ..._measureOptions];
          return [
            for (final o in options)
              PopupMenuItem<String>(
                value: o,
                height: 36,
                padding: EdgeInsets.zero,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  color: o == value
                      ? const Color(0xFF2563EB)
                      : Colors.transparent,
                  child: Text(
                    o.isEmpty ? 'Select...' : o,
                    style: TextStyle(
                      fontSize: 14,
                      color: o == value
                          ? Colors.white
                          : const Color(0xFF111827),
                    ),
                  ),
                ),
              ),
          ];
        },
        child: Container(
          width: 90,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFFD1D5DB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  display,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: value.isEmpty
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF111827),
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: Color(0xFF374151),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetTable() {
    const headerBg = Color(0xFF016626);
    const borderColor = Color(0xFFD1D5DB);
    const headerH = 72.0;
    const rowH = 56.0;
    const widths = [
      90.0,
      260.0,
      90.0,
      100.0,
      110.0,
      110.0, // Unit of measure (~90px control, centered in cell)
      110.0,
      120.0,
      150.0,
      110.0,
      140.0,
      110.0,
    ];
    final tableW = widths.fold<double>(0, (a, b) => a + b);
    const headerStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 12,
      height: 1.15,
    );
    const bodyStyle = TextStyle(fontSize: 12, color: Color(0xFF111827));

    Widget headerCell(String text, double w) {
      return Container(
        width: w,
        height: headerH,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: const BoxDecoration(
          color: headerBg,
          border: Border(right: BorderSide(color: borderColor)),
        ),
        child: Text(text, style: headerStyle, textAlign: TextAlign.center),
      );
    }

    Widget mpfHeader(double w) {
      return Container(
        width: w,
        height: headerH,
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: headerBg,
          border: Border(right: BorderSide(color: borderColor)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('MPF', style: headerStyle),
            const SizedBox(height: 4),
            OutlinedButton(
              onPressed: _copyTotalToActual,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Copy Value from\nTotal Qty Needed',
                style: TextStyle(fontSize: 9, height: 1.1),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    Widget dataCell(
      String text,
      double w, {
      bool last = false,
      Color bgColor = Colors.white,
    }) {
      return Container(
        width: w,
        height: rowH,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            right: last
                ? BorderSide.none
                : const BorderSide(color: borderColor),
            bottom: const BorderSide(color: borderColor),
          ),
        ),
        child: Text(
          text,
          style: bodyStyle,
          textAlign: TextAlign.center,
          softWrap: true,
        ),
      );
    }

    Widget mpfInputCell({
      required int index,
      required _SheetRow row,
      required double w,
      required Color bgColor,
    }) {
      if (row.isGray) {
        return dataCell('', w, bgColor: bgColor);
      }
      final controller = index < _mpfControllers.length
          ? _mpfControllers[index]
          : TextEditingController(text: row.mpfQty);

      return Container(
        width: w,
        height: rowH,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          border: const Border(
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
        child: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: bodyStyle,
          onChanged: (v) => _updateMpfQty(index, v),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: const BorderSide(color: Color(0xFF9CA3AF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: const BorderSide(color: Color(0xFF9CA3AF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: const BorderSide(
                color: Color(0xFF1B5E20),
                width: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    Widget commentDropdownCell({
      required int index,
      required _SheetRow row,
      required double w,
      required Color bgColor,
      bool last = false,
    }) {
      if (row.isGray) {
        return dataCell(row.comments, w, last: last, bgColor: bgColor);
      }

      final options = commentOptions.map((e) => e['value']!).toList();
      final current = row.comments.trim();
      final value = options.contains(current) ? current : '';
      final display = value.isEmpty ? 'Select comment...' : value;

      return Container(
        width: w,
        height: rowH,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            right: last
                ? BorderSide.none
                : const BorderSide(color: borderColor),
            bottom: const BorderSide(color: borderColor),
          ),
        ),
        child: PopupMenuButton<String>(
          tooltip: '',
          initialValue: value,
          position: PopupMenuPosition.under,
          offset: const Offset(0, 2),
          color: Colors.white,
          elevation: 4,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
            side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
          ),
          onSelected: (v) => _updateRowComment(index, v),
          itemBuilder: (context) {
            final all = ['', ...options];
            return [
              for (final o in all)
                PopupMenuItem<String>(
                  value: o,
                  height: 36,
                  padding: EdgeInsets.zero,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: o == value
                        ? const Color(0xFF2563EB)
                        : Colors.transparent,
                    child: Text(
                      o.isEmpty ? 'Select comment...' : o,
                      style: TextStyle(
                        fontSize: 13,
                        color: o == value
                            ? Colors.white
                            : const Color(0xFF111827),
                      ),
                    ),
                  ),
                ),
            ];
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    display,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: value.isEmpty
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF111827),
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: Color(0xFF374151),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final rows = _sheetRows.isEmpty
        ? [
            const _SheetRow(
              tdgpn: '-',
              description: '-',
              vendor: '-',
              vendorPN: '-',
              qtyPerFixture: '-',
              unitOfMeasure: '-',
              totalQtyNeeded: '-',
              actualQty: '',
              mpfQty: '',
              location: '-',
              leadHandComments: '-',
              comments: '',
              isGray: false,
            ),
          ]
        : _sheetRows;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableW,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: tableW,
              height: headerH,
              child: Row(
                children: [
                  headerCell('TDGPN', widths[0]),
                  headerCell('Description', widths[1]),
                  headerCell('Vendor', widths[2]),
                  headerCell('VendorPN', widths[3]),
                  headerCell('Quantity Per\nFixture', widths[4]),
                  headerCell('Unit of\nmeasure', widths[5]),
                  headerCell('Total Qty\nNeeded', widths[6]),
                  headerCell('Actual Qty To\nBe Picked', widths[7]),
                  mpfHeader(widths[8]),
                  headerCell('Location (Qty)', widths[9]),
                  headerCell('LeadHandComments', widths[10]),
                  headerCell('Comments', widths[11]),
                ],
              ),
            ),
            ...rows.asMap().entries.map((entry) {
              final index = entry.key;
              final r = entry.value;
              final cells = [
                r.tdgpn,
                r.description,
                r.vendor,
                r.vendorPN,
                r.qtyPerFixture,
                r.unitOfMeasure,
                r.totalQtyNeeded,
                r.actualQty,
                r.mpfQty,
                r.location,
                r.leadHandComments,
                r.comments,
              ];
              final isPlaceholder = _sheetRows.isEmpty;
              final rowBg = r.isGray ? const Color(0xFFE9ECEF) : Colors.white;
              return SizedBox(
                width: tableW,
                height: rowH,
                child: Row(
                  children: List.generate(12, (i) {
                    if (i == 5 && !isPlaceholder && !r.isGray) {
                      return ColoredBox(
                        color: rowBg,
                        child: _unitOfMeasureDropdown(
                          index: index,
                          current: r.unitOfMeasure,
                          width: widths[5],
                          rowHeight: rowH,
                        ),
                      );
                    }
                    if (i == 5 && r.isGray) {
                      return dataCell(
                        r.unitOfMeasure,
                        widths[5],
                        bgColor: rowBg,
                      );
                    }
                    if (i == 8 && !isPlaceholder) {
                      return mpfInputCell(
                        index: index,
                        row: r,
                        w: widths[8],
                        bgColor: rowBg,
                      );
                    }
                    if (i == 11 && !isPlaceholder) {
                      return commentDropdownCell(
                        index: index,
                        row: r,
                        w: widths[11],
                        bgColor: rowBg,
                        last: true,
                      );
                    }
                    return dataCell(
                      cells[i],
                      widths[i],
                      last: i == 11,
                      bgColor: rowBg,
                    );
                  }),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnCells({
    required List<String> values,
    required double rowHeight,
    required double fontSize,
    required Color bgColor,
    List<Color>? cellColors,
    Color? textColor,
    bool isLabel = false,
    bool showRightBorder = true,
  }) {
    return Column(
      children: List.generate(values.length, (index) {
        final isLast = index == values.length - 1;
        final cellBg = cellColors != null && index < cellColors.length
            ? cellColors[index]
            : bgColor;
        return _tableCell(
          values[index],
          height: rowHeight,
          bgColor: cellBg,
          fontSize: fontSize,
          textColor: textColor,
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
    Color? textColor,
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
          color: textColor ?? const Color(0xFF0C4A7D),
          fontSize: fontSize,
          fontWeight: isLabel || isBold ? FontWeight.w700 : FontWeight.w500,
          height: 1.12,
        ),
      ),
    );
  }
}

class _SheetRow {
  final String tdgpn;
  final String description;
  final String vendor;
  final String vendorPN;
  final String qtyPerFixture;
  final String unitOfMeasure;
  final String totalQtyNeeded;
  final String actualQty;
  final String mpfQty;
  final String location;
  final String leadHandComments;
  final String comments;
  final bool isGray;

  const _SheetRow({
    required this.tdgpn,
    required this.description,
    required this.vendor,
    required this.vendorPN,
    required this.qtyPerFixture,
    required this.unitOfMeasure,
    required this.totalQtyNeeded,
    required this.actualQty,
    required this.mpfQty,
    required this.location,
    required this.leadHandComments,
    required this.comments,
    this.isGray = false,
  });

  _SheetRow copyWith({
    String? tdgpn,
    String? description,
    String? vendor,
    String? vendorPN,
    String? qtyPerFixture,
    String? unitOfMeasure,
    String? totalQtyNeeded,
    String? actualQty,
    String? mpfQty,
    String? location,
    String? leadHandComments,
    String? comments,
    bool? isGray,
  }) {
    return _SheetRow(
      tdgpn: tdgpn ?? this.tdgpn,
      description: description ?? this.description,
      vendor: vendor ?? this.vendor,
      vendorPN: vendorPN ?? this.vendorPN,
      qtyPerFixture: qtyPerFixture ?? this.qtyPerFixture,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      totalQtyNeeded: totalQtyNeeded ?? this.totalQtyNeeded,
      actualQty: actualQty ?? this.actualQty,
      mpfQty: mpfQty ?? this.mpfQty,
      location: location ?? this.location,
      leadHandComments: leadHandComments ?? this.leadHandComments,
      comments: comments ?? this.comments,
      isGray: isGray ?? this.isGray,
    );
  }

  static _SheetRow fromMap(Map raw) {
    final row = Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
    final detail = row['excelFixtureDetail'] is Map
        ? Map<String, dynamic>.from(row['excelFixtureDetail'])
        : <String, dynamic>{};
    String p(String k) {
      final v = row[k] ?? detail[k];
      return v?.toString().trim() ?? '';
    }

    final uom = p('UnitOfMeasure').toUpperCase();
    final isGray =
        row['isGray'] == true ||
        row['isGrayRow'] == true ||
        row['isGrey'] == true;

    return _SheetRow(
      tdgpn: p('TDGPN'),
      description: p('Description'),
      vendor: p('Vendor'),
      vendorPN: p('VendorPN'),
      qtyPerFixture: p('QuantityPerFixture'),
      unitOfMeasure: uom,
      totalQtyNeeded: p('TotalQtyNeeded'),
      actualQty: p('ActualQtyPicked').isNotEmpty
          ? p('ActualQtyPicked')
          : p('ActualQtyToBePicked'),
      mpfQty: p('mpfQty'),
      location: p('Location'),
      leadHandComments: p('LeadHandComments'),
      comments: p('InventoryComments').isNotEmpty
          ? p('InventoryComments')
          : p('Comments'),
      isGray: isGray,
    );
  }
}
