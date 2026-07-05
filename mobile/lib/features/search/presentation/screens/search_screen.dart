import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../service_locator.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pressable.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isLoading = false;
  String _error = '';
  Map<String, List<dynamic>> _results = {};
  Timer? _debounce;
  List<String> _recent = [];

  static const _recentKey = 'recent_searches';

  // Suggested quick searches shown before the user types.
  static const _suggested = ['Blood', 'Events', 'Tournaments', 'Announcements'];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _searchController.addListener(_onSearchChanged);
    _recent = (sl<LocalStorage>().getString(_recentKey) ?? '')
        .split('|')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void _rememberQuery(String query) {
    _recent.remove(query);
    _recent.insert(0, query);
    if (_recent.length > 6) _recent = _recent.sublist(0, 6);
    sl<LocalStorage>().saveString(_recentKey, _recent.join('|'));
  }

  /// Route a tapped result to the relevant screen by its type. Result taps
  /// were previously a no-op.
  void _openResult(String category, dynamic item) {
    const routeByType = {
      'USER': '/directory',
      'PEOPLE': '/directory',
      'EVENT': '/events',
      'TOURNAMENT': '/sports',
      'TEAM': '/sports',
      'ISSUE': '/issues',
      'BLOOD_DONOR': '/blood-donation',
      'ANNOUNCEMENT': '/announcements',
      'NEWS': '/announcements',
    };
    final route = routeByType[category.toUpperCase()];
    if (route != null) context.push(route);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Backend requires >= 2 characters; searching on 1 char just errors.
      if (_searchController.text.trim().length >= 2) {
        _performSearch(_searchController.text.trim());
      } else {
        setState(() {
          _results = {};
          _isLoading = false;
          _error = '';
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final response = await sl<ApiClient>().dio.get(
        '/api/v1/search',
        queryParameters: {'q': query},
      );
      
      final data = response.data;
      final newResults = <String, List<dynamic>>{};
      
      if (data is Map<String, dynamic>) {
        data.forEach((key, value) {
          if (value is List && value.isNotEmpty) {
            newResults[key] = value;
          }
        });
      } else if (data is List) {
        // Fallback if API returns flat list
        for (var item in data) {
          final type = item['type'] ?? 'Other';
          if (!newResults.containsKey(type)) {
            newResults[type] = [];
          }
          newResults[type]!.add(item);
        }
      }
      
      if (newResults.isNotEmpty) _rememberQuery(query);
      if (mounted) {
        setState(() {
          _results = newResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load results. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildResultItem(String category, dynamic item) {
    String title = item['title'] ?? item['name'] ?? 'Unknown';
    String? subtitle = item['subtitle'] ?? item['description'];
    IconData icon;
    Color iconColor;

    switch (category.toLowerCase()) {
      case 'people':
      case 'users':
        icon = Icons.person;
        iconColor = const Color(0xFFEC4899);
        break;
      case 'events':
        icon = Icons.event;
        iconColor = const Color(0xFF8B5CF6);
        break;
      case 'tournaments':
      case 'sports':
        icon = Icons.emoji_events;
        iconColor = const Color(0xFFF97316);
        break;
      case 'news':
      case 'announcements':
        icon = Icons.article;
        iconColor = const Color(0xFF16A34A);
        break;
      case 'issues':
        icon = Icons.campaign;
        iconColor = const Color(0xFFEAB308);
        break;
      default:
        icon = Icons.search;
        iconColor = const Color(0xFF6366F1);
    }

    return GestureDetector(
      onTap: () => _openResult(category, item),
      child: Pressable(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cBorder),
          boxShadow: context.isDark ? null : AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(context.isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.cText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.cTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.cTextSecondary, size: 20),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildCategorySection(String category, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
          child: Text(
            category.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: context.cTextSecondary,
            ),
          ),
        ),
        ...items.map((item) => _buildResultItem(category, item)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildEmptyState() {
    void run(String q) {
      _searchController.text = q;
      _searchController.selection = TextSelection.collapsed(offset: q.length);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_recent.isNotEmpty) ...[
          _sectionLabel(tr(en: 'RECENT', ta: 'சமீபத்தியவை', hi: 'हाल के', ml: 'സമീപകാലം')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recent.map((q) => _chip(q, () => run(q))).toList(),
          ),
          const SizedBox(height: 24),
        ],
        _sectionLabel(tr(en: 'SUGGESTED', ta: 'பரிந்துரைகள்', hi: 'सुझाव', ml: 'നിർദ്ദേശങ്ങൾ')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggested.map((q) => _chip(q, () => run(q))).toList(),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: context.cTextSecondary,
          ),
        ),
      );

  Widget _chip(String label, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: context.cSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.cBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 15, color: context.cTextSecondary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: context.cText, fontSize: 13)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        backgroundColor: context.cSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.cText),
          onPressed: () => context.pop(),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          style: TextStyle(color: context.cText, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search people, events, news...',
            hintStyle: TextStyle(color: context.cTextSecondary.withOpacity(0.5)),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, color: context.cTextSecondary),
              onPressed: () {
                _searchController.clear();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: TextStyle(color: Colors.red)))
              : _searchController.text.isEmpty
                  ? _buildEmptyState()
                  : _results.isEmpty
                      ? Center(
                          child: Text('No results found.', style: TextStyle(color: context.cTextSecondary, fontSize: 16)),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: _results.entries
                              .map((entry) => _buildCategorySection(entry.key, entry.value))
                              .toList(),
                        ),
    );
  }
}
