import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overview_app/Screen/InventoryPickedLog/Services/InventoryPickedLogService.dart';
import 'package:overview_app/Screen/InventoryPickedLog/ViewPickedLog.dart';
import 'package:overview_app/Services/DioServices.dart';
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

  final List<String> itemList = ['Pending Pick List', 'Accepted', 'Rejected'];

  int _apiStatusForSelection(String selection) {
    switch (selection) {
      case 'Accepted':
        return 1;
      case 'Rejected':
        return 2;
      case 'Pending Pick List':
      default:
        return 0;
    }
  }

  String? get _pickListSearchValue {
    final value = _pickListSearchController.text.trim();
    return value.isEmpty ? null : value;
  }

  String _orDash(String value) => value.trim().isEmpty ? '-' : value;

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

  Widget _bomHeaderCell(String label, double w) {
    final borderColor = Colors.grey.shade300;
    return SizedBox(
      width: w,
      height: 44,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 57, 73, 95),
          border: Border(
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            height: 1.0,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _bomDataCell(String value, double w) {
    final borderColor = Colors.grey.shade300;
    return SizedBox(
      width: w,
      child: Container(
        height: 56,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
        ),
      ),
    );
  }

  // Exact width for each table column, left to right.
  static const List<double> _colWidths = [
    140, // Pick list Number
    100, // SOP
    150, // Fixture
    260, // Description
    130, // Project
    95, // Quantity
    80, // RMA
    160, // MPF Requested By
    170, // Created At
    90, // Actions
  ];

  double get _leftStickyWidth =>
      _colWidths.take(3).fold<double>(0, (sum, w) => sum + w);

  double get _actionsColWidth => _colWidths[9];

  double get _scrollableTableWidth =>
      _colWidths.skip(3).take(6).fold<double>(0, (sum, w) => sum + w);

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

  Widget _buildLeftStickyHeaderRow() {
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: _leftStickyShadow),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bomHeaderCell("Pick list Number", _colWidths[0]),
          _bomHeaderCell("SOP", _colWidths[1]),
          _bomHeaderCell("Fixture", _colWidths[2]),
        ],
      ),
    );
  }

  Widget _buildLeftStickyDataRow(ItemModel item) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: _leftStickyShadow,
      ),
      child: ColoredBox(
        color: Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bomDataCell(_orDash(item.pickListNumber), _colWidths[0]),
            _bomDataCell(_orDash(item.sopNum), _colWidths[1]),
            _bomDataCell(_orDash(item.fixture), _colWidths[2]),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableHeaderRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bomHeaderCell("Description", _colWidths[3]),
        _bomHeaderCell("Project", _colWidths[4]),
        _bomHeaderCell("Quantity", _colWidths[5]),
        _bomHeaderCell("RMA", _colWidths[6]),
        _bomHeaderCell("MPF Requested By", _colWidths[7]),
        _bomHeaderCell("Created At", _colWidths[8]),
      ],
    );
  }

  Widget _buildScrollableDataRow(ItemModel item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bomDataCell(_orDash(item.description), _colWidths[3]),
        _bomDataCell(_orDash(item.project), _colWidths[4]),
        _bomDataCell(_orDash(item.tempQuantity), _colWidths[5]),
        _bomDataCell(_orDash(item.RMA), _colWidths[6]),
        _bomDataCell(_orDash(item.MPFRequestedBy), _colWidths[7]),
        _bomDataCell(_formatDateValue(item.createdAt), _colWidths[8]),
      ],
    );
  }

  Widget _buildActionsHeaderCell() {
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: _rightStickyShadow),
      child: _bomHeaderCell("Actions", _actionsColWidth),
    );
  }

  Widget _buildActionsDataCell(ItemModel item) {
    final borderColor = Colors.grey.shade300;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: _rightStickyShadow,
      ),
      child: SizedBox(
        width: _actionsColWidth,
        child: Container(
          height: 56,
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
            onPressed: () {
              debugPrint('View clicked - passed pickedLogId: ${item.id}');
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ViewPickedLog(id: item.id)),
              );
            },
            icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
            label: const Text("View"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF1565C0),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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

  Widget _buildStickyActionsTable() {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStickyColumnPane(
            width: _leftStickyWidth,
            header: _buildLeftStickyHeaderRow(),
            controller: _leftVerticalScroll,
            rowBuilder: _buildLeftStickyDataRow,
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _scrollableTableWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScrollableHeaderRow(),
                    Expanded(
                      child: ListView.builder(
                        controller: _bodyVerticalScroll,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return _buildScrollableDataRow(items[index]);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildStickyColumnPane(
            width: _actionsColWidth,
            header: _buildActionsHeaderCell(),
            controller: _actionsVerticalScroll,
            rowBuilder: _buildActionsDataCell,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStickyHeader() {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          SizedBox(width: _leftStickyWidth, child: _buildLeftStickyHeaderRow()),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _scrollableTableWidth,
                child: _buildScrollableHeaderRow(),
              ),
            ),
          ),
          SizedBox(width: _actionsColWidth, child: _buildActionsHeaderCell()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(),
      drawer: const CommonDrawer(),
      body: Container(
        color: Colors.white,
        child: Container(
          // padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.center,
                child: Text(
                  "Inventory Picked Log",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // DropdownButton<String>(
              //   hint: Text("Pending Pick List"),
              //   value: selectedPickList,
              //   items: itemList.map((item) {
              //     return DropdownMenuItem(value: item, child: Text(item));
              //   }).toList(),
              //   onChanged: (value) {
              //     setState(() {
              //       selectedPickList = value;
              //     });
              //   },
              // ),
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        value: selectedPickList,
                        items: itemList.map((item) {
                          return DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => selectedPickList = value);
                          fetchInvetoryPickedData();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 155,
                    child: TextField(
                      controller: _pickListSearchController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Pick List Number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color.fromARGB(255, 22, 129, 218),
                            width: 2,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => fetchInvetoryPickedData(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // SizedBox(
                  //   height: 48,
                  //   child: ElevatedButton.icon(
                  //     onPressed: fetchInvetoryPickedData,
                  //     icon: const Icon(Icons.search),
                  //     label: const Text('Search'),
                  //   ),
                  // ),
                ],
              ),

              const SizedBox(height: 16),

              if (isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color.fromARGB(255, 57, 73, 95),
                    ),
                  ),
                )
              else
                Expanded(
                  child: items.isEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildEmptyStickyHeader(),
                            const Expanded(
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Text("No Inventory Data Found"),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildStickyActionsTable(),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
