import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/InventoryPickedLog/Services/InventoryPickedLogService.dart';
import 'package:overview_app/Screen/InventoryPickedLog/ViewPickedLog.dart';
import 'package:overview_app/Services/DioServices.dart';
import 'package:overview_app/Utils/responsive.dart';
import 'package:overview_app/Widgets/AppLoader.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';

class ItemModel {
  final String id;
  final String pickListNumber;
  final String sopNum;
  final String fixture;
  final String description;
  final String project;
  final String tempQuantity;
  final String RMA;
  final String MPFRequestedBy;
  final String createdAt;
  final int status;

  ItemModel({
    required this.id,
    required this.pickListNumber,
    required this.sopNum,
    required this.fixture,
    required this.description,
    required this.project,
    required this.tempQuantity,
    required this.RMA,
    required this.MPFRequestedBy,
    required this.createdAt,
    this.status = 0,
  });
}

class InventoryPickedLog extends StatefulWidget {
  @override
  _InventoryPickedLogState createState() => _InventoryPickedLogState();
}

class _InventoryPickedLogState extends State<InventoryPickedLog> {
  final InventoryPickedLogService _service = InventoryPickedLogService();
  final TextEditingController _pickListSearchController =
      TextEditingController();
  final ScrollController _leftVerticalScroll = ScrollController();
  final ScrollController _bodyVerticalScroll = ScrollController();
  final ScrollController _actionsVerticalScroll = ScrollController();
  String username = "";
  bool isLoading = false;
  List<ItemModel> items = [];

  String selectedPickList = 'Pending Pick List';

  final List<String> itemList = [
    'All',
    'Pending Pick List',
    'Accepted',
    'Rejected',
  ];

  int _apiStatusForSelection(String selection) {
    switch (selection) {
      case 'Accepted':
        return 1;
      case 'Rejected':
        return 2;
      case 'Pending Pick List':
      case 'All':
        return 3;
      default:
        return 0;
    }
  }

  String? get _pickListSearchValue {
    final value = _pickListSearchController.text.trim();
    return value.isEmpty ? null : value;
  }

  String _orDash(String value) => value.trim().isEmpty ? '-' : value;

  int _statusFromApi(dynamic value) {
    if (value is num) return value.toInt();
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text == 'accepted' || text == '1') return 1;
    if (text == 'rejected' || text == '2') return 2;
    if (text == 'pending' || text == '0') return 0;
    return int.tryParse(text) ?? 0;
  }

  String _statusLabel(int status) {
    switch (status) {
      case 1:
        return 'Accepted';
      case 2:
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  Color _statusColor(int status) {
    switch (status) {
      case 1:
        return const Color(0xFF15803D);
      case 2:
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFEA580C);
    }
  }

  String _formatDateValue(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '-';

    DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      for (final format in [
        DateFormat("yyyy-MM-dd HH:mm:ss"),
        DateFormat("yyyy-MM-dd HH:mm"),
        DateFormat("yyyy-MM-dd"),
        DateFormat("dd-MM-yyyy HH:mm:ss"),
        DateFormat("dd-MM-yyyy HH:mm"),
        DateFormat("dd-MM-yyyy"),
        DateFormat("dd/MM/yyyy HH:mm:ss"),
        DateFormat("dd/MM/yyyy HH:mm"),
        DateFormat("dd/MM/yyyy"),
      ]) {
        try {
          parsed = format.parseStrict(raw);
          break;
        } catch (_) {}
      }
    }

    if (parsed == null) return raw;
    return DateFormat("dd MMM yyyy, HH:mm").format(parsed.toLocal());
  }

  Future<void> fetchInvetoryPickedData() async {
    setState(() {
      isLoading = true;
    });

    try {
      await Dioservices.setToken();
      final Response response = await _service.InventroyService(
        status: _apiStatusForSelection(selectedPickList),
        pickListNumber: _pickListSearchValue,
      );
      final payload = response.data;
      List<dynamic> rows = [];

      if (payload is List) {
        rows = payload;
      } else if (payload is Map<String, dynamic>) {
        final map = payload;
        final dynamic firstLevel = map['data'];

        if (firstLevel is List) {
          rows = firstLevel;
        } else if (firstLevel is Map<String, dynamic>) {
          final nested = firstLevel;
          final dynamic secondLevel = nested['data'];
          if (secondLevel is List) {
            rows = secondLevel;
          }
        }
      }

      final loadedItems = rows.map<ItemModel>((raw) {
        final item = raw is Map
            ? Map<String, dynamic>.from(
                raw.map((k, v) => MapEntry(k.toString(), v)),
              )
            : <String, dynamic>{};
        final rawDetail = item['excelFixtureDetail'];
        final detail = rawDetail is Map
            ? Map<String, dynamic>.from(
                rawDetail.map((k, v) => MapEntry(k.toString(), v)),
              )
            : <String, dynamic>{};

        String pick(List<String> keys) {
          for (final key in keys) {
            final value = item[key] ?? detail[key];
            if (value != null && value.toString().trim().isNotEmpty) {
              return value.toString();
            }
          }
          return '';
        }

        String rma = pick(const ['RMA', 'rma']);
        if (rma.isEmpty) {
          final hasBackorders = item['hasBackorders'] ?? item['hasbackorders'];
          if (hasBackorders != null) {
            rma = hasBackorders.toString().toLowerCase() == 'true'
                ? 'Yes'
                : 'No';
          }
        }

        var status = _statusFromApi(
          item['status'] ?? item['Status'] ?? detail['status'],
        );
        if (status == 0 && selectedPickList == 'Accepted') status = 1;
        if (status == 0 && selectedPickList == 'Rejected') status = 2;

        return ItemModel(
          // Accept/reject routes need the list row primary key, not the display pick list #.
          id: pick(const ['id']).trim(),
          pickListNumber: pick(const ['pickListNumber']),
          sopNum: pick(const ['sopNum']),
          fixture: pick(const ['fixture']),
          description: pick(const ['description']),
          project: pick(const ['project']),
          tempQuantity: pick(const ['tempQuantity']),
          RMA: rma,
          MPFRequestedBy: pick(const ['MPFRequestedBy']),
          createdAt: pick(const ['createdAt']),
          status: status,
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        items = loadedItems;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      debugPrint("Error in inventory picked log $e");
    }
  }

  void _syncVerticalScroll(
    ScrollController source,
    List<ScrollController> targets,
  ) {
    for (final target in targets) {
      if (!target.hasClients) continue;
      if (target.offset != source.offset) {
        target.jumpTo(source.offset);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _leftVerticalScroll.addListener(
      () => _syncVerticalScroll(_leftVerticalScroll, [
        _bodyVerticalScroll,
        _actionsVerticalScroll,
      ]),
    );
    _bodyVerticalScroll.addListener(
      () => _syncVerticalScroll(_bodyVerticalScroll, [
        _leftVerticalScroll,
        _actionsVerticalScroll,
      ]),
    );
    _actionsVerticalScroll.addListener(
      () => _syncVerticalScroll(_actionsVerticalScroll, [
        _leftVerticalScroll,
        _bodyVerticalScroll,
      ]),
    );
    fetchInvetoryPickedData();
  }

  @override
  void dispose() {
    _leftVerticalScroll.dispose();
    _bodyVerticalScroll.dispose();
    _actionsVerticalScroll.dispose();
    _pickListSearchController.dispose();
    super.dispose();
  }

  Widget _bomHeaderCell(
    String label,
    double w, {
    required double fontSize,
    required double height,
    required double hPad,
  }) {
    final borderColor = Colors.grey.shade300;
    return SizedBox(
      width: w,
      height: height,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 57, 73, 95),
          border: Border(
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            height: 1.0,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _bomDataCell(
    String value,
    double w, {
    required double fontSize,
    required double rowH,
    required double vPad,
    required double hPad,
    Color? textColor,
    FontWeight? fontWeight,
    Alignment alignment = Alignment.centerLeft,
  }) {
    final borderColor = Colors.grey.shade300;
    return SizedBox(
      width: w,
      child: Container(
        height: rowH,
        alignment: alignment,
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
        child: Text(
          value,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            height: 1.15,
            color: textColor,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }

  // Base widths; scaled up on wide screens to fill available space.
  static const List<double> _baseColWidths = [
    140, // Pick list Number
    100, // SOP
    150, // Fixture
    260, // Description
    130, // Project
    95, // Quantity
    80, // RMA
    160, // MPF Requested By
    170, // Created At
    100, // Status
    90, // Actions
  ];

  double get _minTableWidth =>
      _baseColWidths.fold<double>(0, (sum, w) => sum + w);

  List<double> _columnWidthsForAvailable(double available) {
    final sum = _minTableWidth;
    if (available <= sum) return List<double>.from(_baseColWidths);
    final scale = available / sum;
    final scaled = _baseColWidths.map((w) => w * scale).toList();
    final scaledSum = scaled.fold<double>(0, (a, b) => a + b);
    scaled[scaled.length - 1] += available - scaledSum;
    return scaled;
  }

  /// Phone & small tablet → larger text. Big tablet → slightly compact.
  ({double fontSize, double headerH, double rowH, double vPad, double hPad})
  _densityFor(Size screenSize) {
    final shortest = screenSize.shortestSide;
    final width = screenSize.width;

    if (shortest >= 800 || width >= 1100) {
      return (fontSize: 14, headerH: 38, rowH: 48, vPad: 7, hPad: 10);
    }
    return (fontSize: 14, headerH: 42, rowH: 56, vPad: 8, hPad: 10);
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

  Widget _buildLeftStickyHeaderRow(
    List<double> colW, {
    required double fontSize,
    required double headerH,
    required double hPad,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: _leftStickyShadow),
      child: Row(
        children: [
          _bomHeaderCell(
            "Pick list Number",
            colW[0],
            fontSize: fontSize,
            height: headerH,
            hPad: hPad,
          ),
          _bomHeaderCell(
            "SOP",
            colW[1],
            fontSize: fontSize,
            height: headerH,
            hPad: hPad,
          ),
          _bomHeaderCell(
            "Fixture",
            colW[2],
            fontSize: fontSize,
            height: headerH,
            hPad: hPad,
          ),
        ],
      ),
    );
  }

  Widget _buildLeftStickyDataRow(
    ItemModel item,
    List<double> colW, {
    required double fontSize,
    required double rowH,
    required double vPad,
    required double hPad,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: _leftStickyShadow,
      ),
      child: ColoredBox(
        color: Colors.white,
        child: Row(
          children: [
            _bomDataCell(
              _orDash(item.pickListNumber),
              colW[0],
              fontSize: fontSize,
              rowH: rowH,
              vPad: vPad,
              hPad: hPad,
            ),
            _bomDataCell(
              _orDash(item.sopNum),
              colW[1],
              fontSize: fontSize,
              rowH: rowH,
              vPad: vPad,
              hPad: hPad,
            ),
            _bomDataCell(
              _orDash(item.fixture),
              colW[2],
              fontSize: fontSize,
              rowH: rowH,
              vPad: vPad,
              hPad: hPad,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableHeaderRow(
    List<double> colW, {
    required double fontSize,
    required double headerH,
    required double hPad,
  }) {
    return Row(
      children: [
        _bomHeaderCell(
          "Description",
          colW[3],
          fontSize: fontSize,
          height: headerH,
          hPad: hPad,
        ),
        _bomHeaderCell(
          "Project",
          colW[4],
          fontSize: fontSize,
          height: headerH,
          hPad: hPad,
        ),
        _bomHeaderCell(
          "Quantity",
          colW[5],
          fontSize: fontSize,
          height: headerH,
          hPad: hPad,
        ),
        _bomHeaderCell(
          "RMA",
          colW[6],
          fontSize: fontSize,
          height: headerH,
          hPad: hPad,
        ),
        _bomHeaderCell(
          "MPF Requested By",
          colW[7],
          fontSize: fontSize,
          height: headerH,
          hPad: hPad,
        ),
        _bomHeaderCell(
          "Created At",
          colW[8],
          fontSize: fontSize,
          height: headerH,
          hPad: hPad,
        ),
        _bomHeaderCell(
          "Status",
          colW[9],
          fontSize: fontSize,
          height: headerH,
          hPad: hPad,
        ),
      ],
    );
  }

  Widget _buildScrollableDataRow(
    ItemModel item,
    List<double> colW, {
    required double fontSize,
    required double rowH,
    required double vPad,
    required double hPad,
  }) {
    return Row(
      children: [
        _bomDataCell(
          _orDash(item.description),
          colW[3],
          fontSize: fontSize,
          rowH: rowH,
          vPad: vPad,
          hPad: hPad,
        ),
        _bomDataCell(
          _orDash(item.project),
          colW[4],
          fontSize: fontSize,
          rowH: rowH,
          vPad: vPad,
          hPad: hPad,
        ),
        _bomDataCell(
          _orDash(item.tempQuantity),
          colW[5],
          fontSize: fontSize,
          rowH: rowH,
          vPad: vPad,
          hPad: hPad,
        ),
        _bomDataCell(
          _orDash(item.RMA),
          colW[6],
          fontSize: fontSize,
          rowH: rowH,
          vPad: vPad,
          hPad: hPad,
        ),
        _bomDataCell(
          _orDash(item.MPFRequestedBy),
          colW[7],
          fontSize: fontSize,
          rowH: rowH,
          vPad: vPad,
          hPad: hPad,
        ),
        _bomDataCell(
          _formatDateValue(item.createdAt),
          colW[8],
          fontSize: fontSize,
          rowH: rowH,
          vPad: vPad,
          hPad: hPad,
        ),
        _bomDataCell(
          _statusLabel(item.status),
          colW[9],
          fontSize: fontSize,
          rowH: rowH,
          vPad: vPad,
          hPad: hPad,
          textColor: _statusColor(item.status),
          fontWeight: FontWeight.w700,
          alignment: Alignment.center,
        ),
      ],
    );
  }

  Widget _buildActionsHeaderCell(
    double actionW, {
    required double fontSize,
    required double headerH,
    required double hPad,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: _rightStickyShadow),
      child: _bomHeaderCell(
        "Actions",
        actionW,
        fontSize: fontSize,
        height: headerH,
        hPad: hPad,
      ),
    );
  }

  Widget _buildActionsDataCell(
    ItemModel item,
    double actionW, {
    required double rowH,
  }) {
    final borderColor = Colors.grey.shade300;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: _rightStickyShadow,
      ),
      child: SizedBox(
        width: actionW,
        child: Container(
          height: rowH,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(color: borderColor),
              bottom: BorderSide(color: borderColor),
            ),
          ),
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ViewPickedLog(id: item.id, status: item.status),
                ),
              );
              if (!mounted) return;
              fetchInvetoryPickedData();
            },
            icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
            label: const Text("View"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF1565C0),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.35),
              surfaceTintColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickyColumnPane({
    required double width,
    required Widget header,
    required ScrollController controller,
    required Widget Function(ItemModel item) rowBuilder,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          header,
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: items.length,
              itemBuilder: (context, index) => rowBuilder(items[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullHeaderRow(
    List<double> colW, {
    required double fontSize,
    required double headerH,
    required double hPad,
  }) {
    return Row(
      children: [
        _bomHeaderCell(
          "Pick list Number",
          colW[0],
          fontSize: fontSize,
          height: headerH,
          hPad: hPad,
        ),
        _bomHeaderCell(
          "SOP",
          colW[1],
          fontSize: fontSize,
          height: headerH,
          hPad: hPad,
        ),
        _bomHeaderCell(
          "Fixture",
          colW[2],
          fontSize: fontSize,
          height: headerH,
          hPad: hPad,
        ),
        _buildScrollableHeaderRow(
          colW,
          fontSize: fontSize,
          headerH: headerH,
          hPad: hPad,
        ),
        _bomHeaderCell(
          "Actions",
          colW[10],
          fontSize: fontSize,
          height: headerH,
          hPad: hPad,
        ),
      ],
    );
  }

  Widget _buildFullDataRow(
    ItemModel item,
    List<double> colW, {
    required double fontSize,
    required double rowH,
    required double vPad,
    required double hPad,
  }) {
    return Row(
      children: [
        _bomDataCell(
          _orDash(item.pickListNumber),
          colW[0],
          fontSize: fontSize,
          rowH: rowH,
          vPad: vPad,
          hPad: hPad,
        ),
        _bomDataCell(
          _orDash(item.sopNum),
          colW[1],
          fontSize: fontSize,
          rowH: rowH,
          vPad: vPad,
          hPad: hPad,
        ),
        _bomDataCell(
          _orDash(item.fixture),
          colW[2],
          fontSize: fontSize,
          rowH: rowH,
          vPad: vPad,
          hPad: hPad,
        ),
        _buildScrollableDataRow(
          item,
          colW,
          fontSize: fontSize,
          rowH: rowH,
          vPad: vPad,
          hPad: hPad,
        ),
        _buildActionsDataCell(item, colW[10], rowH: rowH),
      ],
    );
  }

  Widget _buildFullScrollableTable({
    required List<double> colW,
    required double fontSize,
    required double headerH,
    required double rowH,
    required double vPad,
    required double hPad,
    required double maxWidth,
  }) {
    final tableW = colW.fold<double>(0, (sum, w) => sum + w);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SizedBox(
        width: maxWidth,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableW,
            child: Column(
              children: [
                _buildFullHeaderRow(
                  colW,
                  fontSize: fontSize,
                  headerH: headerH,
                  hPad: hPad,
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _bodyVerticalScroll,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return _buildFullDataRow(
                        items[index],
                        colW,
                        fontSize: fontSize,
                        rowH: rowH,
                        vPad: vPad,
                        hPad: hPad,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickyActionsTable({
    required List<double> colW,
    required double fontSize,
    required double headerH,
    required double rowH,
    required double vPad,
    required double hPad,
  }) {
    final leftW = colW[0] + colW[1] + colW[2];
    final middleW = colW.skip(3).take(7).fold<double>(0, (sum, w) => sum + w);
    final actionW = colW[10];

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStickyColumnPane(
            width: leftW,
            header: _buildLeftStickyHeaderRow(
              colW,
              fontSize: fontSize,
              headerH: headerH,
              hPad: hPad,
            ),
            controller: _leftVerticalScroll,
            rowBuilder: (item) => _buildLeftStickyDataRow(
              item,
              colW,
              fontSize: fontSize,
              rowH: rowH,
              vPad: vPad,
              hPad: hPad,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scrollW = middleW > constraints.maxWidth
                    ? middleW
                    : constraints.maxWidth;
                // If middle needs to stretch further within Expanded, rescale
                // middle columns only to fill the expanded area.
                final midCols = colW.skip(3).take(7).toList();
                final midSum = midCols.fold<double>(0, (a, b) => a + b);
                final effectiveMid = scrollW >= midSum
                    ? () {
                        final scale = scrollW / midSum;
                        final scaled = midCols.map((w) => w * scale).toList();
                        final s = scaled.fold<double>(0, (a, b) => a + b);
                        scaled[scaled.length - 1] += scrollW - s;
                        return scaled;
                      }()
                    : midCols;
                final effectiveColW = [
                  colW[0],
                  colW[1],
                  colW[2],
                  ...effectiveMid,
                  colW[10],
                ];
                final tableMidW = effectiveMid.fold<double>(0, (a, b) => a + b);

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableMidW,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildScrollableHeaderRow(
                          effectiveColW,
                          fontSize: fontSize,
                          headerH: headerH,
                          hPad: hPad,
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _bodyVerticalScroll,
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              return _buildScrollableDataRow(
                                items[index],
                                effectiveColW,
                                fontSize: fontSize,
                                rowH: rowH,
                                vPad: vPad,
                                hPad: hPad,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildStickyColumnPane(
            width: actionW,
            header: _buildActionsHeaderCell(
              actionW,
              fontSize: fontSize,
              headerH: headerH,
              hPad: hPad,
            ),
            controller: _actionsVerticalScroll,
            rowBuilder: (item) =>
                _buildActionsDataCell(item, actionW, rowH: rowH),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStickyHeader({
    required List<double> colW,
    required double fontSize,
    required double headerH,
    required double hPad,
  }) {
    final leftW = colW[0] + colW[1] + colW[2];
    final middleW = colW.skip(3).take(7).fold<double>(0, (sum, w) => sum + w);
    final actionW = colW[10];

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          SizedBox(
            width: leftW,
            child: _buildLeftStickyHeaderRow(
              colW,
              fontSize: fontSize,
              headerH: headerH,
              hPad: hPad,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: middleW,
                child: _buildScrollableHeaderRow(
                  colW,
                  fontSize: fontSize,
                  headerH: headerH,
                  hPad: hPad,
                ),
              ),
            ),
          ),
          SizedBox(
            width: actionW,
            child: _buildActionsHeaderCell(
              actionW,
              fontSize: fontSize,
              headerH: headerH,
              hPad: hPad,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final density = _densityFor(MediaQuery.sizeOf(context));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(),
      drawer: const CommonDrawer(),
      body: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                r.pagePaddingH,
                r.pagePaddingV,
                r.pagePaddingH,
                0,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const fieldHeight = 48.0;
                  final isNarrow = constraints.maxWidth < 700;
                  final sharedBorder = OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color.fromARGB(255, 229, 231, 235),
                      width: 2,
                    ),
                  );
                  final focusedBorder = OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF38485E),
                      width: 2,
                    ),
                  );

                  final title = Text(
                    "Inventory Pick Log",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: r.pageTitleSize,
                      fontWeight: FontWeight.bold,
                    ),
                  );

                  final dropdown = SizedBox(
                    height: fieldHeight,
                    width: isNarrow ? double.infinity : 220,
                    child: DropdownButtonFormField<String>(
                      dropdownColor: Colors.white,
                      isDense: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: sharedBorder,
                        enabledBorder: sharedBorder,
                        focusedBorder: focusedBorder,
                      ),
                      value: selectedPickList,
                      items: itemList.map((item) {
                        return DropdownMenuItem(
                          value: item,
                          child: Text(
                            item,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => selectedPickList = value);
                        fetchInvetoryPickedData();
                      },
                    ),
                  );

                  final searchField = SizedBox(
                    height: fieldHeight,
                    width: isNarrow ? double.infinity : 280,
                    child: TextField(
                      controller: _pickListSearchController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Search by Pick List Number...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: sharedBorder,
                        enabledBorder: sharedBorder,
                        focusedBorder: focusedBorder,
                      ),
                      onChanged: (value) {
                        if (value.trim().isEmpty) {
                          fetchInvetoryPickedData();
                        }
                      },
                      onSubmitted: (_) => fetchInvetoryPickedData(),
                    ),
                  );

                  final searchButton = SizedBox(
                    height: fieldHeight,
                    child: ElevatedButton.icon(
                      onPressed: fetchInvetoryPickedData,
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text(
                        'Search',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );

                  final controls = isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            dropdown,
                            const SizedBox(height: 10),
                            SizedBox(
                              height: fieldHeight,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: searchField),
                                  const SizedBox(width: 8),
                                  searchButton,
                                ],
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            dropdown,
                            const SizedBox(width: 12),
                            searchField,
                            const SizedBox(width: 12),
                            searchButton,
                          ],
                        );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [title, const SizedBox(height: 10), controls],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      title,
                      const SizedBox(width: 16),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: controls,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(height: r.sectionGap),
            if (isLoading)
              const Expanded(child: Center(child: AppLoader()))
            else
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    r.pagePaddingH,
                    0,
                    r.pagePaddingH,
                    r.pagePaddingV,
                  ),
                  child: Responsive.hideScrollbars(
                    context,
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final colW = _columnWidthsForAvailable(
                          constraints.maxWidth,
                        );
                        final leftW = colW[0] + colW[1] + colW[2];
                        final actionW = colW[10];
                        final isPhone = MediaQuery.sizeOf(context).width < 700;
                        final tooNarrow =
                            isPhone ||
                            constraints.maxWidth < leftW + actionW + 48;
                        if (items.isEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              tooNarrow
                                  ? SizedBox(
                                      width: constraints.maxWidth,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: _buildFullHeaderRow(
                                          colW,
                                          fontSize: density.fontSize,
                                          headerH: density.headerH,
                                          hPad: density.hPad,
                                        ),
                                      ),
                                    )
                                  : _buildEmptyStickyHeader(
                                      colW: colW,
                                      fontSize: density.fontSize,
                                      headerH: density.headerH,
                                      hPad: density.hPad,
                                    ),
                              const Expanded(
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Text("No Inventory Data Found"),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        if (tooNarrow) {
                          return _buildFullScrollableTable(
                            colW: colW,
                            fontSize: density.fontSize,
                            headerH: density.headerH,
                            rowH: density.rowH,
                            vPad: density.vPad,
                            hPad: density.hPad,
                            maxWidth: constraints.maxWidth,
                          );
                        }
                        return _buildStickyActionsTable(
                          colW: colW,
                          fontSize: density.fontSize,
                          headerH: density.headerH,
                          rowH: density.rowH,
                          vPad: density.vPad,
                          hPad: density.hPad,
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
