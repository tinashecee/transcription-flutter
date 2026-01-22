import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:package_info_plus/package_info_plus.dart';

import '../../domain/repositories/recording_repository.dart';
import '../../data/providers.dart';
import 'sidebar_provider.dart';

/// A collapsible sidebar widget for court/courtroom filtering.
/// Used in both the recordings list and recording detail screens.
class CollapsibleSidebar extends ConsumerStatefulWidget {
  const CollapsibleSidebar({
    super.key,
    this.selectedCourt,
    this.selectedCourtroom,
    required this.onCourtSelected,
    required this.onCourtroomSelected,
  });

  final String? selectedCourt;
  final String? selectedCourtroom;
  final ValueChanged<String?> onCourtSelected;
  final ValueChanged<String?> onCourtroomSelected;

  @override
  ConsumerState<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends ConsumerState<CollapsibleSidebar> {
  bool _isLoading = true;
  String? _errorMessage;
  List<String> _courts = [];
  Map<String, List<String>> _courtroomsByCourt = {};
  String _appVersion = '';
  
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSearching = false;
  String _searchQuery = '';

  static const double _expandedWidth = 280.0;
  static const double _collapsedWidth = 70.0;
  static const Color _primaryColor = Color(0xFF115343);

  @override
  void initState() {
    super.initState();
    _loadCourtsAndRooms();
    _loadVersion();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'v${info.version}';
      });
    }
  }

  Future<void> _loadCourtsAndRooms() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(recordingRepositoryProvider);
      final results = await Future.wait([
        repo.fetchCourts(),
        repo.fetchCourtroomsByCourt(),
      ]);

      if (mounted) {
        setState(() {
          _courts = (results[0] as List<String>)..sort();
          _courtroomsByCourt = results[1] as Map<String, List<String>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _toggleCollapsed() {
    ref.read(sidebarCollapsedProvider.notifier).update((state) => !state);
  }

  void _toggleSearch() {
    final isCollapsed = ref.read(sidebarCollapsedProvider);
    if (isCollapsed) {
      _toggleCollapsed();
      setState(() => _isSearching = true);
    } else {
      setState(() {
        _isSearching = !_isSearching;
        if (!_isSearching) {
          _searchController.clear();
          _searchQuery = '';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final filteredCourts = _courts.where((court) {
      if (_searchQuery.isEmpty) return true;
      return court.toLowerCase().contains(_searchQuery);
    }).toList();

    // Sort priority: Exact/Starts with > Contains > Alphabetical
    if (_searchQuery.isNotEmpty) {
      filteredCourts.sort((a, b) {
        final aLower = a.toLowerCase();
        final bLower = b.toLowerCase();
        final aStarts = aLower.startsWith(_searchQuery);
        final bStarts = bLower.startsWith(_searchQuery);
        if (aStarts && !bStarts) return -1;
        if (!aStarts && bStarts) return 1;
        return aLower.compareTo(bLower);
      });
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: isCollapsed ? _collapsedWidth : _expandedWidth,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sidebar Header with toggle
          Padding(
            padding: EdgeInsets.all(isCollapsed ? 16 : 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isCollapsed)
                  InkWell(
                    onTap: _toggleCollapsed,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/images/jsc_logo_1.webp',
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: IconButton(
                            onPressed: _toggleCollapsed,
                            icon: const Icon(Icons.chevron_left, color: Colors.white),
                            tooltip: 'Collapse',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Sticky "All" Item
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 16),
            child: _SidebarItem(
              icon: Icons.dashboard_rounded,
              label: 'All',
              isSelected: widget.selectedCourt == null,
              isCollapsed: isCollapsed,
              onTap: () => widget.onCourtSelected(null),
              // hasExpandIcon removed
            ),
          ),

          const SizedBox(height: 24),

          // Sticky Search/Header for Courts
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 16),
            child: isCollapsed
                ? IconButton(
                    onPressed: _toggleSearch,
                    icon: const Icon(Icons.search, color: Colors.white70, size: 24),
                    tooltip: 'Search Courts',
                  )
                : _isSearching
                    ? Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: GoogleFonts.roboto(color: Colors.white, fontSize: 13),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.trim().toLowerCase();
                            });
                            debugPrint('[SidebarSearch] query: $_searchQuery');
                          },
                          decoration: InputDecoration(
                            hintText: 'Search courts...',
                            hintStyle: GoogleFonts.roboto(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            prefixIcon: const Icon(Icons.search,
                                color: Colors.white54, size: 22),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white54, size: 18),
                              onPressed: _toggleSearch,
                            ),
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              'COURTS',
                              style: GoogleFonts.roboto(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _toggleSearch,
                            icon: Icon(Icons.search,
                                color: Colors.white.withOpacity(0.5), size: 22),
                            tooltip: 'Search',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
          ),

          const SizedBox(height: 8),

          // Scrollable List of Courts
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : RawScrollbar(
                  controller: _scrollController,
                  thumbColor: Colors.white.withOpacity(0.4),
                  radius: const Radius.circular(20),
                  thickness: 6,
                  interactive: true,
                  thumbVisibility: true,
                  child: ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: isCollapsed ? 8 : 16,
                        vertical: 8,
                      ),
                      children: [
                        ...filteredCourts.map(
                          (court) => _SidebarItem(
                            icon: Icons.account_balance_rounded,
                            label: court,
                            isSelected: widget.selectedCourt == court,
                            isCollapsed: isCollapsed,
                            onTap: () => widget.onCourtSelected(court),
                          ),
                        ),
                      if (filteredCourts.isEmpty && !_isLoading)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No courts found',
                            style: GoogleFonts.roboto(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // App Version Footer
          if (!isCollapsed && _appVersion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/testimony.png',
                    height: 70,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _appVersion,
                    style: GoogleFonts.roboto(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
    this.hasExpandIcon = false,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;
  final bool hasExpandIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isCollapsed ? 8 : 4),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: isCollapsed ? label : '',
          preferBelow: false,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 12 : 16,
                vertical: isCollapsed ? 12 : 12,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.transparent,
                ),
              ),
              child: isCollapsed
                  ? Center(
                      child: Icon(
                        icon,
                        size: 20,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.6),
                      ),
                    )
                  : Row(
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withOpacity(0.6),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: GoogleFonts.roboto(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.6),
                              fontSize: 14,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasExpandIcon)
                          Icon(
                            Icons.expand_more,
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withOpacity(0.6),
                            size: 18,
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
