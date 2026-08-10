import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/router/app_router.dart' show pushMemberRoute;
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pressable.dart';
import '../../domain/entities/search_hit.dart';
import '../../domain/repositories/search_repository.dart';

/// One box, one ranked list.
///
/// What this replaces: a screen that received per-type buckets in whatever
/// order the server's queries happened to run, grouped them under headings, and
/// routed every tap through its own `type → section route` map. Three
/// consequences, all of which a member could see:
///
/// * relevance was an accident of statement order, so the thing you named
///   exactly could sit below three things that mentioned it;
/// * tapping a member opened the roster, not that member;
/// * typing "Events" — a query this screen *suggests* — returned "No results
///   found", because only the titles of things were ever matched.
///
/// Ranking and routing are now the server's answers (it is the only side that
/// knows what it found), and this screen's job is to show them in order and get
/// out of the way. Places come first, under their own heading, because "go
/// here" is a different kind of answer from "here is a match".
class SearchScreen extends StatefulWidget {
  final SearchRepository repo;
  const SearchScreen({super.key, required this.repo});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  String _error = '';
  List<SearchHit> _hits = const [];
  Timer? _debounce;
  List<String> _recent = [];

  /// Guards against a slow early request landing after a fast later one and
  /// repainting the screen with results for a query nobody is looking at.
  int _requestId = 0;

  static const _recentKey = 'recent_searches';

  /// Every one of these must return something. They are a promise printed on
  /// the screen — and before destinations existed, three of the four were
  /// answered with "No results found".
  static const _suggested = ['Blood', 'Events', 'Tournaments', 'Jobs'];

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

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    // 250ms, not 500: a search that lags half a second behind the keyboard
    // feels broken, and the query is a single indexed round trip.
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final query = _searchController.text.trim();
      // The server refuses anything shorter, and asking is just an error.
      if (query.length >= 2) {
        _performSearch(query);
      } else {
        setState(() {
          _hits = const [];
          _isLoading = false;
          _error = '';
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    final id = ++_requestId;
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final hits = await widget.repo.search(query, lang: trLang());
      if (!mounted || id != _requestId) return;
      if (hits.isNotEmpty) _rememberQuery(query);
      setState(() {
        _hits = hits;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = trId('couldn_t_load_the_feed');
        _isLoading = false;
      });
    }
  }

  /// The server said where this goes. Routed through [pushMemberRoute] so a
  /// result on a personal route asks for a name on the way instead of bouncing
  /// silently back to Home.
  void _open(SearchHit hit) {
    if (hit.route.isEmpty) return;
    pushMemberRoute(context, hit.route);
  }

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
          textInputAction: TextInputAction.search,
          style: TextStyle(color: context.cText, fontSize: 16),
          decoration: InputDecoration(
            hintText: trId('search_people_events_news'),
            hintStyle:
                TextStyle(color: context.cTextSecondary.withValues(alpha: 0.5)),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, color: context.cTextSecondary),
              onPressed: _searchController.clear,
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_searchController.text.trim().length < 2) return _startingPoints();
    if (_isLoading && _hits.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error.isNotEmpty) {
      return Center(
          child: Text(_error, style: TextStyle(color: AppColors.danger)));
    }
    if (_hits.isEmpty) return _nothingFound();

    final places = _hits.where((h) => h.isDestination).toList();
    final things = _hits.where((h) => !h.isDestination).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (places.isNotEmpty) ...[
          _label(trId('go_to')),
          ...places.map(_row),
          const SizedBox(height: 20),
        ],
        if (things.isNotEmpty) ...[
          if (places.isNotEmpty) _label(trId('results')),
          ...things.map(_row),
        ],
      ],
    );
  }

  /// An empty answer should still leave somewhere to go. A bare "No results
  /// found" on a black screen is where this search left members standing.
  Widget _nothingFound() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 40),
          Icon(Icons.search_off_rounded,
              size: 44, color: context.cTextSecondary),
          const SizedBox(height: 12),
          Center(
            child: Text(trId('no_results_found'),
                style: TextStyle(color: context.cTextSecondary, fontSize: 16)),
          ),
          const SizedBox(height: 28),
          _label(trId('suggested')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggested.map((q) => _chip(q, () => _run(q))).toList(),
          ),
        ],
      );

  void _run(String query) {
    _searchController.text = query;
    _searchController.selection =
        TextSelection.collapsed(offset: query.length);
  }

  Widget _startingPoints() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_recent.isNotEmpty) ...[
            _label(trId('recent')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recent.map((q) => _chip(q, () => _run(q))).toList(),
            ),
            const SizedBox(height: 24),
          ],
          _label(trId('suggested')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggested.map((q) => _chip(q, () => _run(q))).toList(),
          ),
        ],
      );

  /// Icon and tint by type — decoration only. Where a result leads is the
  /// server's answer, never a lookup on this string.
  static (IconData, Color) _look(SearchHit hit) => switch (hit.type) {
        'DESTINATION' => (Icons.arrow_forward_rounded, Color(0xFF6366F1)),
        'USER' => (Icons.person_rounded, Color(0xFFEC4899)),
        'EVENT' => (Icons.event_rounded, Color(0xFF8B5CF6)),
        'TOURNAMENT' || 'TEAM' => (Icons.emoji_events_rounded, Color(0xFFF97316)),
        'CHESS_TOURNAMENT' => (Icons.extension_rounded, Color(0xFF0EA5E9)),
        'ANNOUNCEMENT' => (Icons.campaign_rounded, Color(0xFF16A34A)),
        'WORK' => (Icons.handyman_rounded, Color(0xFF0891B2)),
        'OPPORTUNITY' => (Icons.school_rounded, Color(0xFF7C3AED)),
        'DIRECTORY' => (Icons.contact_phone_rounded, Color(0xFF64748B)),
        'PLANTATION' => (Icons.park_rounded, Color(0xFF15803D)),
        'BLOOD_DONOR' => (Icons.bloodtype_rounded, Color(0xFFDC2626)),
        'ISSUE' => (Icons.report_problem_rounded, Color(0xFFEAB308)),
        'POST' => (Icons.chat_bubble_rounded, Color(0xFF6366F1)),
        _ => (Icons.search_rounded, Color(0xFF6366F1)),
      };

  Widget _row(SearchHit hit) {
    final (icon, tint) = _look(hit);
    return GestureDetector(
      onTap: () => _open(hit),
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
                  color:
                      tint.withValues(alpha: context.isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tint, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hit.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.cText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((hit.subtitle ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        hit.subtitle!,
                        style: TextStyle(
                            fontSize: 13, color: context.cTextSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: context.cTextSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Text(
          text.toUpperCase(),
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
}
