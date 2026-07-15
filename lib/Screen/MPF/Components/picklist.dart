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

  const PickList({
    super.key,
    required this.fixtureNumber,
    required this.sopNumber,
    required this.mpf,
  });

  @override
  State<PickList> createState() => _PickListState();
}

class _PickListState extends State<PickList> {
  final MPFServices _services = MPFServices();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _rmaController = TextEditingController();
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

  String _pickListNo = '';
  String _project = '';
  String _requiredOn = '';
  String _description = '';
  String _pickListLogNumber = '0';
  String _datePicked = '';
  String _leadHandSignOff = '';

  bool _dropdownOpen = false;
  int _selectedIndex = 0;
  List<({String sop, String odd, String qty, bool isBlank})> _dropdownOptions =
      [(sop: '', odd: '', qty: '', isBlank: true)];
  List<_SheetRow> _sheetRows = [];

  @override
  void initState() {
    super.initState();
    _fetchSOPList();
    _fetchPickList();
    _fetchPickListCount();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _rmaController.dispose();
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

  Future<void> _fetchPickList() async {
    try {
      await Dioservices.setToken();
      final user =
          (await SharedPreferences.getInstance()).getString('UserName') ?? '';
      final response = await _services.PickListData(user, widget.fixtureNumber);
      print("PICK LIST DATA [[[[response.data:]]]] ${response.data}");
      final data = response.data?['data'];
      final Map<String, dynamic>? map = data is Map
          ? Map<String, dynamic>.from(data)
          : data is List && data.isNotEmpty && data.first is Map
          ? Map<String, dynamic>.from(data.first)
          : null;
      if (map == null) return;

      final detail = map['excelFixtureDetail'] is Map
          ? Map<String, dynamic>.from(map['excelFixtureDetail'])
          : <String, dynamic>{};
      String pick(String k) {
        final v = map[k] ?? detail[k];
        return v == null ? '' : v.toString().trim();
      }

      setState(() {
        _project = pick('project');
        _qtyController.text = pick('tempQuantity');
        _requiredOn = _formatOdd(
          map['ODD'] ?? detail['ODD'] ?? map['odd'] ?? detail['odd'],
        );
        _description = pick('description');
        final log = pick('pickListLogNumber');
        _pickListLogNumber = log.isEmpty ? '0' : log;
        _datePicked = _formatOdd(map['datePicked'] ?? detail['datePicked']);
        _rmaController.text = pick('RMA');
        _leadHandSignOff = pick('MPFRequestedBy');

        final rawRows = map['listData'] ?? map['sheetData'];
        _sheetRows = rawRows is List
            ? rawRows.whereType<Map>().map(_SheetRow.fromMap).toList()
            : [];
      });
    } catch (e) {
      debugPrint('PICK LIST ERROR: $e');
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
            child: SingleChildScrollView(
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
                ],
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
    final pickListLogBg =
        isBlankPickList ? const Color(0xFFE8F5E9) : valueBg;
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
      _sheetRows = _sheetRows
          .map(
            (r) => _SheetRow(
              tdgpn: r.tdgpn,
              description: r.description,
              vendor: r.vendor,
              vendorPN: r.vendorPN,
              qtyPerFixture: r.qtyPerFixture,
              unitOfMeasure: r.unitOfMeasure,
              totalQtyNeeded: r.totalQtyNeeded,
              actualQty: r.actualQty,
              mpfQty: r.mpfQty,
              location: r.location,
              leadHandComments: r.leadHandComments,
              comments: comment,
            ),
          )
          .toList();
    });
  }

  void _copyTotalToActual() {
    setState(() {
      _sheetRows = _sheetRows
          .map(
            (r) => _SheetRow(
              tdgpn: r.tdgpn,
              description: r.description,
              vendor: r.vendor,
              vendorPN: r.vendorPN,
              qtyPerFixture: r.qtyPerFixture,
              unitOfMeasure: r.unitOfMeasure,
              totalQtyNeeded: r.totalQtyNeeded,
              actualQty: r.totalQtyNeeded,
              mpfQty: r.mpfQty,
              location: r.location,
              leadHandComments: r.leadHandComments,
              comments: r.comments,
            ),
          )
          .toList();
    });
  }

  Widget _buildSheetTable() {
    const headerBg = Color(0xFF1B5E20);
    const borderColor = Color(0xFFD1D5DB);
    const headerH = 72.0;
    const rowH = 56.0;
    const widths = [
      90.0,
      260.0,
      90.0,
      100.0,
      110.0,
      100.0,
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

    Widget dataCell(String text, double w, {bool last = false}) {
      return Container(
        width: w,
        height: rowH,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
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
            ...rows.map((r) {
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
              return SizedBox(
                width: tableW,
                height: rowH,
                child: Row(
                  children: List.generate(12, (i) {
                    if (i == 8) {
                      return Container(
                        width: widths[8],
                        height: rowH,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            right: BorderSide(color: borderColor),
                            bottom: BorderSide(color: borderColor),
                          ),
                        ),
                      );
                    }
                    return dataCell(cells[i], widths[i], last: i == 11);
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
  });

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

    return _SheetRow(
      tdgpn: p('TDGPN'),
      description: p('Description'),
      vendor: p('Vendor'),
      vendorPN: p('VendorPN'),
      qtyPerFixture: p('QuantityPerFixture'),
      unitOfMeasure: p('UnitOfMeasure'),
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
    );
  }
}