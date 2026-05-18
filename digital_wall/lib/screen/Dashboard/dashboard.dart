import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
// import '../Landing/landing.dart';

const String _ociBaseUrl =
    "https://yzs2ppflgbk8.objectstorage.ca-toronto-1.oci.customer-oci.com";
const String _ociNamespace = "yzs2ppflgbk8";
const String _ociBucket = "digitalwall";

String buildOciObjectUrl(String objectPath) {
  final normalizedPath = objectPath.trim();
  if (normalizedPath.isEmpty ||
      normalizedPath == 'null' ||
      normalizedPath == 'undefined') {
    return '';
  }

  if (normalizedPath.startsWith('https://') ||
      normalizedPath.startsWith('http://') ||
      normalizedPath.startsWith('data:')) {
    return normalizedPath;
  }

  final pathForEncode = normalizedPath.startsWith('/')
      ? normalizedPath.substring(1)
      : normalizedPath;
  final encodedObjectName = Uri.encodeComponent(pathForEncode);

  if (_ociBaseUrl.contains('/n/') && _ociBaseUrl.contains('/b/')) {
    return '$_ociBaseUrl/o/$encodedObjectName';
  }
  return '$_ociBaseUrl/n/$_ociNamespace/b/$_ociBucket/o/$encodedObjectName';
}

// ------------MODEL----------------
class FileObject {
  final String filename;
  final String originalname;

  FileObject({required this.filename, required this.originalname});

  factory FileObject.fromJson(Map<String, dynamic> json) {
    return FileObject(
      filename: json['filename'],
      originalname: json['originalname'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileObject &&
        other.filename == filename &&
        other.originalname == originalname;
  }

  @override
  int get hashCode => filename.hashCode ^ originalname.hashCode;
}

class Project {
  final num code;
  final String title;
  final String? image;

  /// Shown on the right side of the title row (OCI path or URL).
  final String? logo;

  /// Shown on the top-left of the project hero image (OCI path or URL).
  final String? manufactureLogo;
  final num cont_del_total;
  final num cont_del_rem;
  final num cont_del_sts;
  final DateTime risk_status;
  final num risk_sts;
  final num comp_drawing_total;
  final num comp_drawing_rem;
  final num comp_drawing_sts;
  final num parts_to_buy_total;
  final num parts_to_buy_rem;
  final num parts_to_buy_sts;
  final num pro_readiness_total;
  final num pro_readiness_rem;
  final num pro_readiness_sts;
  final num cont_deliverable_total;
  final num cont_deliverable_rem;
  final num cont_deliverable_sts;
  final String amount;
  final String amount_rem;
  final num amount_sts;
  final String currencyCode;
  final String currencySymbol;
  final List<FileObject> SCL;
  final List<FileObject> pro_plan;

  Project({
    required this.code,
    required this.title,
    required this.image,
    this.logo,
    this.manufactureLogo,
    required this.cont_del_total,
    required this.cont_del_rem,
    required this.cont_del_sts,
    required this.risk_status,
    required this.risk_sts,
    required this.comp_drawing_total,
    required this.comp_drawing_rem,
    required this.comp_drawing_sts,
    required this.parts_to_buy_total,
    required this.parts_to_buy_rem,
    required this.parts_to_buy_sts,
    required this.pro_readiness_total,
    required this.pro_readiness_rem,
    required this.pro_readiness_sts,
    required this.cont_deliverable_total,
    required this.cont_deliverable_rem,
    required this.cont_deliverable_sts,
    required this.amount,
    required this.amount_rem,
    required this.amount_sts,
    required this.currencyCode,
    required this.currencySymbol,
    required this.SCL,
    required this.pro_plan,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    List<FileObject> parseFiles(dynamic v) {
      if (v is List) {
        return v
            .whereType<Map>()
            .map((f) => FileObject.fromJson(Map<String, dynamic>.from(f)))
            .toList();
      }
      return [];
    }

    return Project(
      code: json['code'] ?? 0,
      title: json['title'] ?? '',
      image: json['image'],
      logo: json['logo']?.toString(),
      manufactureLogo: json['manufactureLogo']?.toString() ?? '',
      cont_del_total: json['cont_del_total'] ?? 0,
      cont_del_rem: json['cont_del_rem'] ?? 0,
      cont_del_sts: json['cont_del_sts'] ?? 0,
      risk_status: json['risk_status'] != null
          ? DateTime.parse(json['risk_status'])
          : DateTime.now(),
      risk_sts: json['risk_sts'] ?? 0,
      comp_drawing_total: json['comp_drawing_total'] ?? 0,
      comp_drawing_rem: json['comp_drawing_rem'] ?? 0,
      comp_drawing_sts: json['comp_drawing_sts'] ?? 0,
      parts_to_buy_total: json['parts_to_buy_total'] ?? 0,
      parts_to_buy_rem: json['parts_to_buy_rem'] ?? 0,
      parts_to_buy_sts: json['parts_to_buy_sts'] ?? 0,
      pro_readiness_total: json['pro_readiness_total'] ?? 0,
      pro_readiness_rem: json['pro_readiness_rem'] ?? 0,
      pro_readiness_sts: json['pro_readiness_sts'] ?? 0,
      cont_deliverable_total: json['cont_deliverable_total'] ?? 0,
      cont_deliverable_rem: json['cont_deliverable_rem'] ?? 0,
      cont_deliverable_sts: json['cont_deliverable_sts'] ?? 0,
      amount: json['amount']?.toString() ?? '0',
      amount_rem: json['amount_rem']?.toString() ?? '0',
      amount_sts: json['amount_sts'] ?? 0,
      currencyCode: json['currencyCode'] ?? '',
      currencySymbol: json['currencySymbol'] ?? '',
      SCL: parseFiles(json['SCL'] ?? ''),
      pro_plan: parseFiles(json['pro_plan'] ?? ''),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<Project> projects = [];
  bool isLoading = true;
  List<String> searchSuggestion = [];
  List<Map<String, dynamic>> searchResults = []; // Store full search results
  bool isSearching = false;
  final Map<num, FileObject?> _selectedSclByProject = {};
  final Map<num, FileObject?> _selectedProPlanByProject = {};
  String _searchQuery = '';
  String _userName = "";
  late TextEditingController _searchController;
  final GlobalKey _searchBoxKey = GlobalKey();
  static const double _searchFieldWidth = 280;
  static const int _pageSize = 3;
  static const Color _searchFieldBg = Color(0xFF1C213E);
  static const Color _searchFieldBorder = Color(0xFF5E668A);
  static const Color _searchFieldText = Color.fromARGB(255, 201, 207, 233);

  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    fetchProjects(resetToFirstPage: true);
    _loadUserName();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearchSuggestions() {
    setState(() {
      searchSuggestion = [];
      _searchController.clear();
      _searchQuery = '';
      isSearching = false;
    });
    fetchProjects(resetToFirstPage: true);
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    setState(() => _currentPage = page);
    fetchProjects();
  }

  List<Object> _paginationItems() {
    final t = _totalPages;
    final c = _currentPage;
    if (t <= 1) return <Object>[];
    if (t <= 7) {
      return List<Object>.generate(t, (i) => i + 1);
    }
    if (c <= 4) {
      return <Object>[1, 2, 3, 4, 5, '…', t];
    }
    if (c >= t - 3) {
      return <Object>[1, '…', t - 4, t - 3, t - 2, t - 1, t];
    }
    return <Object>[1, '…', c - 1, c, c + 1, '…', t];
  }

  Widget _pageNavButton({
    required VoidCallback? onPressed,
    bool isActive = false,
    Widget? child,
    String? label,
    double size = 28,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isActive
              ? BorderSide.none
              : const BorderSide(color: Color(0xFF5B6478)),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child:
                child ??
                Text(
                  label ?? '',
                  style: TextStyle(
                    color: onPressed == null && !isActive
                        ? Colors.white24
                        : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationBar() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    final items = _paginationItems();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pageNavButton(
          onPressed: _currentPage > 1
              ? () => _goToPage(_currentPage - 1)
              : null,
          child: Icon(
            Icons.chevron_left,
            size: 18,
            color: _currentPage > 1 ? Colors.white : Colors.white24,
          ),
        ),
        const SizedBox(width: 4),
        ...items.map((e) {
          if (e == '…') {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: SizedBox(
                width: 22,
                height: 28,
                child: Center(
                  child: Text(
                    '…',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1,
                    ),
                  ),
                ),
              ),
            );
          }
          final page = e as int;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _pageNavButton(
              label: '$page',
              isActive: page == _currentPage,
              onPressed: () => _goToPage(page),
            ),
          );
        }),
        const SizedBox(width: 4),
        _pageNavButton(
          onPressed: _currentPage < _totalPages
              ? () => _goToPage(_currentPage + 1)
              : null,
          child: Icon(
            Icons.chevron_right,
            size: 18,
            color: _currentPage < _totalPages ? Colors.white : Colors.white24,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectCardSlot(Project project) {
    return buildProjectCard(
      context,
      project,
      _selectedSclByProject[project.code],
      _selectedProPlanByProject[project.code],
      _fetchProjectImage,
      buildOciObjectUrl,
      (sclFile) {
        setState(() {
          _selectedSclByProject[project.code] = sclFile;
        });
      },
      (proPlanFile) {
        setState(() {
          _selectedProPlanByProject[project.code] = proPlanFile;
        });
      },
      compact: true,
      fillAvailableHeight: true,
    );
  }

  Widget _buildSearchSuggestionsPanel(double width) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: Container(
        width: width,
        constraints: const BoxConstraints(maxHeight: 240),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: isSearching
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Searching...', style: TextStyle(fontSize: 14)),
                  ],
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: searchSuggestion.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final suggestion = searchSuggestion[index];
                  return InkWell(
                    onTap: () => _selectProjectFromSearch(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(
                        suggestion,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget? _buildSearchSuggestionsOverlay() {
    if (!isSearching && searchSuggestion.isEmpty) return null;

    final searchBox =
        _searchBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (searchBox == null) return null;

    final offset = searchBox.localToGlobal(Offset.zero);
    final top = offset.dy + searchBox.size.height + 4;
    final left = offset.dx;

    return Positioned(
      left: left,
      top: top,
      width: searchBox.size.width,
      child: GestureDetector(
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: _buildSearchSuggestionsPanel(searchBox.size.width),
      ),
    );
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('uname') ?? "";
    final userRole = prefs.getString('userRole') ?? "";

    setState(() {
      // Show "admin" if role is admin, otherwise show actual username
      _userName = userRole == 'admin' ? 'admin' : userName;
    });
  }

  Future<Uint8List?> _fetchProjectImage(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      if (token == null) {
        return null;
      }

      final response = await http.post(
        Uri.parse("http://192.168.1.22:8000/api/projects/file"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'filePath': filePath, 'image': filePath}),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> fetchProjectsBySearch(String code) async {
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      if (token == null) {
        setState(() => isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse(
          'http://192.168.1.22:8000/api/projects/get_projects_by_code/$code',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> data;
        if (decoded is Map<String, dynamic> && decoded['projects'] is List) {
          data = decoded['projects'] as List<dynamic>;
        } else if (decoded is Map<String, dynamic> && decoded['data'] is List) {
          data = decoded['data'] as List<dynamic>;
        } else {
          data = [];
        }

        setState(() {
          projects = data.map((json) => Project.fromJson(json)).toList();
          _selectedSclByProject.clear();
          _selectedProPlanByProject.clear();
          _totalPages = 1;
          _currentPage = 1;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchProjects({bool resetToFirstPage = false}) async {
    if (resetToFirstPage) {
      _currentPage = 1;
    }
    setState(() {
      isLoading = true;
    });
    final Uri url = Uri.parse(
      'https://digitalwall.api.tdgoverview.cloud/api/projects/getPaginatedProjects'
      '?page=$_currentPage&limit=$_pageSize',
    );
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> data;
        if (decoded is Map<String, dynamic> && decoded['projects'] is List) {
          data = decoded['projects'] as List<dynamic>;
        } else if (decoded is Map<String, dynamic> && decoded['data'] is List) {
          data = decoded['data'] as List<dynamic>;
        } else if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic>) {
          data = [decoded];
        } else {
          throw Exception("Unexpected projects response shape");
        }

        int totalPages = 1;
        if (decoded is Map<String, dynamic>) {
          final m = decoded;
          num? fromKeys;
          for (final k in [
            'totalPages',
            'total_pages',
            'lastPage',
            'last_page',
            'pageCount',
          ]) {
            final v = m[k];
            if (v is num && v >= 1) {
              fromKeys = v;
              break;
            }
          }
          if (fromKeys != null) {
            totalPages = fromKeys.ceil();
          } else {
            final total = m['total'] ?? m['totalCount'] ?? m['count'];
            if (total is num && _pageSize > 0) {
              totalPages = (total / _pageSize).ceil();
            } else if (data.length < _pageSize) {
              totalPages = _currentPage;
            } else {
              totalPages = _currentPage + 1;
            }
          }
        } else {
          if (data.length < _pageSize) {
            totalPages = _currentPage;
          } else {
            totalPages = _currentPage + 1;
          }
        }
        if (totalPages < 1) totalPages = 1;
        if (_currentPage > totalPages) {
          _currentPage = totalPages;
        }

        setState(() {
          projects = data.map((json) => Project.fromJson(json)).toList();
          _selectedSclByProject.clear();
          _selectedProPlanByProject.clear();
          _totalPages = totalPages;
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        throw Exception("Failed to load projects");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _searchProjects(String query) async {
    if (query.isEmpty) return;

    setState(() {
      isSearching = true;
    });

    // Get the access token
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      setState(() {
        isSearching = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          "http://192.168.1.22:8000/api/projects/get_projects_title?search=$query",
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);

        // Check if response has projects array
        if (responseData['projects'] != null) {
          var projects = responseData['projects'] as List<dynamic>;

          setState(() {
            searchResults = projects.cast<Map<String, dynamic>>();
            searchSuggestion = projects
                .map((project) => project['title'] as String)
                .toList();
            isSearching = false;
          });
        } else {
          setState(() {
            searchResults = [];
            searchSuggestion = [];
            isSearching = false;
          });
        }
      } else {
        setState(() {
          isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        isSearching = false;
      });
    }
  }

  Future<void> _selectProjectFromSearch(String title) async {
    final projectData = searchResults.cast<Map<String, dynamic>?>().firstWhere(
      (project) => project?['title'] == title,
      orElse: () => null,
    );

    if (projectData == null) return;

    final code = projectData['code'];
    if (code == null) return;

    setState(() {
      searchSuggestion = [];
      isSearching = false;
      _searchQuery = title;
      _searchController.text = title;
    });

    await fetchProjectsBySearch(code.toString());
  }

  // Future<void> _performLogout() async {
  //   // Show confirmation dialog
  //   bool? shouldLogout = await showDialog<bool>(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Logout'),
  //         content: const Text('Are you sure you want to logout?'),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.of(context).pop(false),
  //             child: const Text('Cancel'),
  //           ),
  //           ElevatedButton(
  //             onPressed: () => Navigator.of(context).pop(true),
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: Color.fromARGB(255, 223, 61, 49),
  //               foregroundColor: Colors.white,
  //             ),
  //             child: const Text('Yes, Logout'),
  //           ),
  //         ],
  //       );
  //     },
  //   );

  //   // Only proceed with logout if user confirmed
  //   if (shouldLogout == true) {
  //     try {
  //       // Clear all stored user data
  //       final prefs = await SharedPreferences.getInstance();
  //       await prefs.remove('accessToken');
  //       await prefs.remove('uname');
  //       await prefs.remove('userRole');

  //       // Navigate to login page
  //       if (mounted) {
  //         Navigator.pushAndRemoveUntil(
  //           context,
  //           MaterialPageRoute(builder: (context) => const Landing()),
  //           (route) => false,
  //         );
  //       }
  //     } catch (e) {
  //       // Still navigate to login even if there's an error
  //       if (mounted) {
  //         Navigator.pushAndRemoveUntil(
  //           context,
  //           MaterialPageRoute(builder: (context) => const Landing()),
  //           (route) => false,
  //         );
  //       }
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF0D0F36),
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            toolbarHeight: 56,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('assets/images/tdg_logo.png', height: 32),
                  SizedBox(
                    key: _searchBoxKey,
                    width: _searchFieldWidth,
                    height: 36,
                    child: TextField(
                      controller: _searchController,
                      cursorColor: _searchFieldText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _searchFieldText,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search projects...',
                        hintStyle: const TextStyle(
                          color: _searchFieldText,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: _searchFieldBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: _searchFieldBorder,
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: _searchFieldBorder,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: _searchFieldBorder,
                            width: 1,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        isDense: true,
                        prefixIcon: const Icon(
                          Icons.search,
                          color: _searchFieldText,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: _searchFieldText,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    isSearching = false;
                                    searchSuggestion = [];
                                  });
                                  fetchProjects(resetToFirstPage: true);
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        _searchQuery = value;
                        if (value.isNotEmpty) {
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (_searchQuery == value) {
                              _searchProjects(value);
                            }
                          });
                        } else {
                          setState(() {
                            isSearching = false;
                            searchSuggestion = [];
                          });
                          fetchProjects(resetToFirstPage: true);
                        }
                      },
                    ),
                  ),
                  _buildPaginationBar(),
                ],
              ),
            ),
          ),
          backgroundColor: Colors.white,
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : projects.isEmpty
              ? const Center(child: Text('No projects found'))
              : ColoredBox(
                  color: const Color(0xFFF5F5F5),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < _pageSize; i++)
                          Expanded(
                            child: i < projects.length
                                ? Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _buildProjectCardSlot(projects[i]),
                                  )
                                : const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
        if (isSearching || searchSuggestion.isNotEmpty)
          Positioned.fill(
            child: GestureDetector(
              onTap: _clearSearchSuggestions,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
        Builder(
          builder: (_) {
            final overlay = _buildSearchSuggestionsOverlay();
            return overlay ?? const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

Future<Uint8List?> _fetchFileFromAPI(String filename) async {
  try {
    final ociUrl = buildOciObjectUrl(filename);
    if (ociUrl.isNotEmpty) {
      final ociResponse = await http.get(Uri.parse(ociUrl));
      if (ociResponse.statusCode == 200 && ociResponse.bodyBytes.isNotEmpty) {
        return ociResponse.bodyBytes;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      return null;
    }

    final response = await http.post(
      Uri.parse("http://192.168.1.22:8000/api/projects/file"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'filePath': filename, 'image': filename}),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      return null;
    }
  } catch (e) {
    return null;
  }
}

const Color _dashboardBorder = Color(0xFFD1D5DB);
const Color _dashboardHeaderBg = Color(0xFFF3F4F6);
const Color _dashboardLabelColor = Color(0xFF1E3A5F);

Widget _statusDiamond(Color color, {bool doubleIcon = false}) {
  if (color == Colors.transparent) return const SizedBox.shrink();

  Widget diamond(Color c) => Transform.rotate(
    angle: 0.785398,
    child: Container(width: 10, height: 10, color: c),
  );

  if (doubleIcon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        diamond(const Color(0xFFDF3D31)),
        const SizedBox(width: 4),
        diamond(const Color(0xFFDF3D31)),
      ],
    );
  }
  return diamond(color);
}

Widget _dashboardDataRow({
  required String title,
  String subtitle = '',
  required String value,
  Color statusColor = Colors.transparent,
  bool doubleIcon = false,
  bool compact = false,
}) {
  final labelSize = compact ? 10.0 : 11.0;
  final valueSize = compact ? 13.0 : 15.0;

  return Padding(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 8 : 10,
      vertical: compact ? 8 : 10,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 2,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: labelSize,
                      fontWeight: FontWeight.w700,
                      color: _dashboardLabelColor,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      '/ $subtitle',
                      style: TextStyle(
                        fontSize: labelSize - 1,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.w700,
                  color: _dashboardLabelColor,
                ),
              ),
            ],
          ),
        ),
        _statusDiamond(statusColor, doubleIcon: doubleIcon),
      ],
    ),
  );
}

Widget buildInfoRow(
  String title,
  String subtitle,
  String value,
  Color statusColor, {
  bool doubleIcon = false,
  int index = 0,
  bool compact = false,
}) {
  return _dashboardDataRow(
    title: title,
    subtitle: subtitle,
    value: value,
    statusColor: statusColor,
    doubleIcon: doubleIcon,
    compact: compact,
  );
}

Widget buildDateRow(
  String title,
  String date, {
  Color statusColor = Colors.yellow,
  int index = 0,
  bool compact = false,
}) {
  return _dashboardDataRow(
    title: title,
    value: date,
    statusColor: statusColor,
    compact: compact,
  );
}

const _dashboardRowDivider = Divider(
  height: 1,
  thickness: 1,
  color: _dashboardBorder,
);

bool _hasDashboardAsset(String? path) {
  final t = path?.trim() ?? '';
  return t.isNotEmpty && t != 'null';
}

/// Header / overlay logo using the same OCI URL + authenticated fallback as the hero image.
Widget _dashboardLogoImage(
  String relativePath,
  double height,
  double width,
  String Function(String) buildImageUrl,
  Future<Uint8List?> Function(String) fetchImage,
) {
  final url = buildImageUrl(relativePath);
  if (url.isEmpty) {
    return SizedBox(width: width, height: height);
  }
  return SizedBox(
    width: width,
    height: height,
    child: Image.network(
      url,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return FutureBuilder<Uint8List?>(
          future: fetchImage(relativePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            if (snapshot.hasData && snapshot.data != null) {
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.contain,
                width: width,
                height: height,
              );
            }
            return const SizedBox.shrink();
          },
        );
      },
    ),
  );
}

Widget buildProjectCard(
  BuildContext context,
  Project project,
  FileObject? selectedSclFile,
  FileObject? selectedProPlanFile,
  Future<Uint8List?> Function(String) fetchImage,
  String Function(String) buildImageUrl,
  Function(FileObject?) onSclFileSelected,
  Function(FileObject?) onProPlanFileSelected, {
  bool compact = false,
  bool fillAvailableHeight = false,
}) {
  final titleSize = compact ? 11.0 : 14.0;
  final imageHeight = compact ? 140.0 : 180.0;
  final headerLogoHeight = compact ? 36.0 : 44.0;
  final headerLogoWidth = compact ? 64.0 : 80.0;
  final headerHeight = compact ? 52.0 : 64.0;
  final overlayLogoHeight = compact ? 32.0 : 40.0;
  final overlayLogoWidth = compact ? 56.0 : 72.0;
  final rowCompact = compact;

  Widget buildImageSection() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: ColoredBox(color: Colors.grey[300]!)),
        Positioned.fill(
          child: project.image != null && project.image!.trim().isNotEmpty
              ? Image.network(
                  buildImageUrl(project.image!),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return FutureBuilder<Uint8List?>(
                      future: fetchImage(project.image!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (snapshot.hasData && snapshot.data != null) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                          );
                        }

                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Text('Image not available'),
                          ),
                        );
                      },
                    );
                  },
                )
              : Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                ),
        ),
        if (_hasDashboardAsset(project.manufactureLogo))
          Positioned(
            top: 5,
            left: 5,
            child: Container(
              color: Colors.white.withValues(alpha: 0.92),
              padding: const EdgeInsets.all(4),
              child: _dashboardLogoImage(
                project.manufactureLogo!.trim(),
                overlayLogoHeight,
                overlayLogoWidth,
                buildImageUrl,
                fetchImage,
              ),
            ),
          ),
      ],
    );
  }

  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _dashboardBorder),
      borderRadius: BorderRadius.circular(4),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: fillAvailableHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Container(
          height: headerHeight,
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
          color: _dashboardHeaderBg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  project.title,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: _dashboardLabelColor,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_hasDashboardAsset(project.logo)) ...[
                const SizedBox(width: 8),
                _dashboardLogoImage(
                  project.logo!.trim(),
                  headerLogoHeight,
                  headerLogoWidth,
                  buildImageUrl,
                  fetchImage,
                ),
              ],
            ],
          ),
        ),
        _dashboardRowDivider,
        if (fillAvailableHeight)
          Expanded(child: buildImageSection())
        else
          SizedBox(
            height: imageHeight,
            width: double.infinity,
            child: buildImageSection(),
          ),
        _dashboardRowDivider,
        buildInfoRow(
          "Total Contract Deliverables",
          "Fixtures + Files + Legal",
          "${project.cont_del_rem} / ${project.cont_del_total}",
          getStatusColor(project.cont_del_sts),
          compact: rowCompact,
        ),
        _dashboardRowDivider,
        buildDateRow(
          "FUD & Risk status",
          project.risk_status.toLocal().toString().split(' ')[0],
          statusColor: getStatusColor(project.risk_sts),
          compact: rowCompact,
        ),
        _dashboardRowDivider,
        buildInfoRow(
          "Component Drawings",
          "Drawings Open",
          "${project.comp_drawing_rem} / ${project.comp_drawing_total}",
          getStatusColor(project.comp_drawing_sts),
          compact: rowCompact,
        ),
        _dashboardRowDivider,
        buildInfoRow(
          "Parts To Buy (PBOM)",
          "Parts Open",
          "${project.parts_to_buy_rem} / ${project.parts_to_buy_total}",
          getStatusColor(project.parts_to_buy_sts),
          compact: rowCompact,
        ),
        _dashboardRowDivider,
        buildInfoRow(
          "Production Readiness",
          "Fixtures Open",
          "${project.pro_readiness_rem} / ${project.pro_readiness_total}",
          getStatusColor(project.pro_readiness_sts),
          compact: rowCompact,
        ),
        _dashboardRowDivider,
        buildInfoRow(
          "Contract Deliverables",
          "Deliverables",
          "${project.cont_deliverable_rem} / ${project.cont_deliverable_total}",
          getStatusColor(project.cont_deliverable_sts),
          compact: rowCompact,
        ),
        _dashboardRowDivider,
        buildInfoRow(
          "NRC Amount",
          "",
          "${project.amount_rem} ${project.currencySymbol} / ${project.amount} ${project.currencySymbol}",
          getStatusColor(project.amount_sts),
          doubleIcon: project.amount_sts == 5,
          compact: rowCompact,
        ),
        _dashboardRowDivider,
        Padding(
          padding: EdgeInsets.all(compact ? 6 : 8),
          child: Row(
            children: [
              Expanded(
                child: buildFileDropdown(
                  context,
                  "SCL",
                  project.SCL,
                  selectedSclFile,
                  onSclFileSelected,
                  (file) => _showFilePreview(context, file, _fetchFileFromAPI),
                  compact: rowCompact,
                ),
              ),
              SizedBox(width: compact ? 6 : 8),
              Expanded(
                child: buildFileDropdown(
                  context,
                  "PLAN",
                  project.pro_plan,
                  selectedProPlanFile,
                  onProPlanFileSelected,
                  (file) => _showFilePreview(context, file, _fetchFileFromAPI),
                  compact: rowCompact,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget buildFileDropdown(
  BuildContext context,
  String label,
  List<FileObject> files,
  FileObject? selectedFile,
  Function(FileObject?) onFileSelected,
  Function(FileObject) onPreview, {
  int index = 0,
  bool compact = false,
}) {
  final fontSize = compact ? 10.0 : 12.0;

  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 6 : 8,
      vertical: compact ? 4 : 6,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _dashboardBorder),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: _dashboardLabelColor,
          ),
        ),
        const SizedBox(height: 4),
        files.isEmpty
            ? Text(
                'No Files',
                style: TextStyle(fontSize: fontSize, color: Colors.grey[600]),
              )
            : DropdownButton<FileObject>(
                value: selectedFile != null && files.contains(selectedFile)
                    ? selectedFile
                    : null,
                underline: const SizedBox(),
                isDense: true,
                isExpanded: true,
                hint: Text(
                  'Documents',
                  style: TextStyle(fontSize: fontSize, color: Colors.grey[700]),
                ),
                items: files.map((file) {
                  return DropdownMenuItem<FileObject>(
                    value: file,
                    child: Text(
                      file.originalname,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(fontSize: fontSize),
                    ),
                  );
                }).toList(),
                onChanged: (file) {
                  onFileSelected(file);
                  if (file != null) {
                    onPreview(file);
                  }
                },
              ),
      ],
    ),
  );
}

/// In-app spreadsheet preview using a public HTTPS object URL (same bucket as images).
/// Embeds the file in a [WebView] via Microsoft Office Online viewer.
class _ExcelPreviewPanel extends StatefulWidget {
  final String objectPath;

  const _ExcelPreviewPanel({required this.objectPath});

  @override
  State<_ExcelPreviewPanel> createState() => _ExcelPreviewPanelState();
}

class _ExcelPreviewPanelState extends State<_ExcelPreviewPanel> {
  late final WebViewController _webViewController;
  bool _pageLoading = true;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _pageLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _pageLoading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _pageLoading = false);
          },
        ),
      );
    _loadEmbeddedViewer();
  }

  String get _objectUrl => buildOciObjectUrl(widget.objectPath);

  void _loadEmbeddedViewer() {
    final src = _objectUrl;
    if (src.isEmpty) {
      setState(() => _pageLoading = false);
      return;
    }
    final embedUrl =
        'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(src)}';
    _webViewController.loadRequest(Uri.parse(embedUrl));
  }

  @override
  Widget build(BuildContext context) {
    final src = _objectUrl;
    if (src.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No public file URL could be built for this object.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_pageLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: WebViewWidget(controller: _webViewController)),
      ],
    );
  }
}

void _showFilePreview(
  BuildContext context,
  FileObject file,
  Future<Uint8List?> Function(String) fetchFile,
) {
  final isPdf = file.originalname.toLowerCase().endsWith('.pdf');
  final isExcel =
      file.originalname.toLowerCase().endsWith('.xlsx') ||
      file.originalname.toLowerCase().endsWith('.xls');
  final isImage =
      file.originalname.toLowerCase().endsWith('.jpg') ||
      file.originalname.toLowerCase().endsWith('.jpeg') ||
      file.originalname.toLowerCase().endsWith('.png') ||
      file.originalname.toLowerCase().endsWith('.gif') ||
      file.originalname.toLowerCase().endsWith('.bmp');

  // Show modal dialog similar to web implementation
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Header with title and close button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        file.originalname,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // Content area
              Expanded(
                child: isExcel
                    ? _ExcelPreviewPanel(objectPath: file.filename)
                    : FutureBuilder<Uint8List?>(
                        future: fetchFile(file.filename),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Loading file...'),
                                ],
                              ),
                            );
                          } else if (snapshot.hasError) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error,
                                    size: 50,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(height: 16),
                                  Text('Error: ${snapshot.error}'),
                                ],
                              ),
                            );
                          } else if (snapshot.hasData &&
                              snapshot.data != null) {
                            // Show different content based on file type
                            if (isImage) {
                              // Display image files
                              return Container(
                                padding: const EdgeInsets.all(16),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              );
                            } else if (isPdf) {
                              // Display actual PDF content
                              return _PdfViewerWidget(pdfData: snapshot.data!);
                            } else {
                              // Display other file types
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.description,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'File Size: ${(snapshot.data!.length / 1024).toStringAsFixed(1)} KB',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Preview not available for this file type',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } else {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.description,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text('No data available'),
                                ],
                              ),
                            );
                          }
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PdfViewerWidget extends StatefulWidget {
  final Uint8List pdfData;

  const _PdfViewerWidget({required this.pdfData});

  @override
  State<_PdfViewerWidget> createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends State<_PdfViewerWidget> {
  String? localPath;
  int currentPage = 0;
  int totalPages = 0;
  bool isReady = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _createFileOfPdfData();
  }

  Future<void> _createFileOfPdfData() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(widget.pdfData);
      setState(() {
        localPath = file.path;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (errorMessage.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 50, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $errorMessage'),
            ],
          ),
        ),
      );
    }

    if (localPath == null) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Navigation controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: currentPage > 0
                          ? () {
                              setState(() {
                                currentPage--;
                              });
                            }
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('${currentPage + 1} / $totalPages'),
                    IconButton(
                      onPressed: currentPage < totalPages - 1
                          ? () {
                              setState(() {
                                currentPage++;
                              });
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                if (isReady)
                  Text(
                    'Page ${currentPage + 1} of $totalPages',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // PDF Viewer
          Expanded(
            child: PDFView(
              filePath: localPath!,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: false,
              pageFling: true,
              pageSnap: true,
              onRender: (pages) {
                setState(() {
                  totalPages = pages!;
                  isReady = true;
                });
              },
              onPageChanged: (int? page, int? total) {
                setState(() {
                  currentPage = page ?? 0;
                });
              },
              onError: (error) {
                setState(() {
                  errorMessage = error.toString();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

Color getStatusColor(num status) {
  switch (status) {
    case 1:
      return Colors.transparent; // Display nothing
    case 2:
      return Colors.yellow[700]!; // Yellow
    case 3:
      return Colors.green[600]!; // Green
    case 4:
      return const Color.fromARGB(255, 223, 61, 49); // Red
    case 5:
      return const Color.fromARGB(255, 223, 61, 49); // Double red (darker red)
    default:
      return Colors.grey;
  }
}
