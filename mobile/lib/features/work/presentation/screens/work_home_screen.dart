import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/ds_screen_header.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/work_bloc.dart';
import '../widgets/listing_card.dart';
import '../widgets/listing_skeleton.dart';

/// The single place. Skills, jobs and gigs all arrive here.
///
/// Search sits above the categories because a person arrives already knowing
/// the word — "carpenter" — and making them find it in a grid is a step for
/// our convenience, not theirs.
class WorkHomeScreen extends StatefulWidget {
  const WorkHomeScreen({super.key});

  @override
  State<WorkHomeScreen> createState() => _WorkHomeScreenState();
}

class _WorkHomeScreenState extends State<WorkHomeScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    context.read<WorkBloc>().add(const WorkOpened());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Search as they type, but not on every keystroke.
  ///
  /// "carpenter" is nine requests without this, on a connection that is
  /// metered and slow — and eight of those answers are thrown away before
  /// anybody reads them. Waiting for a pause in typing costs nothing a person
  /// can feel and is most of the data bill.
  void _onTyped(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (_search.text.trim().isEmpty) return;
      _run();
    });
  }

  void _run({String? category}) {
    _debounce?.cancel();
    context.read<WorkBloc>().add(
        WorkSearched(q: _search.text.trim(), category: category));
  }

  Future<void> _refresh() async {
    // The gesture people already try. Without it, a member who suspects the
    // list is stale has to leave the screen and come back.
    final bloc = context.read<WorkBloc>();
    if (bloc.state.hasSearched) {
      bloc.add(WorkSearched(
          q: _search.text.trim(), category: bloc.state.activeCategory));
    } else {
      bloc.add(const WorkOpened());
    }
    await bloc.stream.firstWhere((s) => !s.loading && !s.searching);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DSScreenHeader(
        title: trId('work'),
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: BlocBuilder<WorkBloc, WorkState>(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
            // Always scrollable, so the pull works even on a short list.
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(DSSpacing.md),
            children: [
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: _onTyped,
                onSubmitted: (_) => _run(),
                decoration: InputDecoration(
                  hintText: trId('work_search_hint'),
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              SizedBox(height: DSSpacing.md),

              if (state.loading)
                const ListingSkeleton()
              else if (state.hasSearched)
                ..._results(context, state)
              else
                ..._categories(context, state),

              SizedBox(height: DSSpacing.lg),
              OutlinedButton.icon(
                onPressed: () => context.push('/work/list'),
                icon: const Icon(Icons.add_business_outlined),
                label: Text(trId('list_what_you_do')),
              ),
            ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _categories(BuildContext context, WorkState state) {
    if (state.categories.isEmpty) {
      // Nobody has listed anything yet. Said as an invitation rather than as a
      // failure, because the first person to list is the one who makes the
      // index worth opening.
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: DSSpacing.lg),
          child: Column(
            children: [
              Icon(Icons.handyman_outlined,
                  size: 40, color: context.cTextSecondary),
              SizedBox(height: DSSpacing.sm),
              Text(trId('work_be_the_first'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
      ];
    }

    return [
      Wrap(
        spacing: DSSpacing.xs,
        runSpacing: DSSpacing.xs,
        children: [
          // Only categories somebody is in. A tile reading "Plumbing 0" is an
          // advertisement that the app does not work.
          for (final c in state.categories)
            ActionChip(
              label: Text('${trId('work_cat_${c.code.toLowerCase()}')} · ${c.count}'),
              onPressed: () => _run(category: c.code),
            ),
        ],
      ),
    ];
  }

  List<Widget> _results(BuildContext context, WorkState state) {
    if (state.searching) {
      // The shape of the answer, not a spinner. On a bar of 3G that is most
      // of what "fast" means, and the page does not jump when results land.
      return [const ListingSkeleton()];
    }
    if (state.results.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: DSSpacing.lg),
          child: Column(
            children: [
              Text(trId('nothing_found'),
                  style: Theme.of(context).textTheme.titleSmall),
              SizedBox(height: DSSpacing.xs),
              Text(trId('work_be_the_first'),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ];
    }
    return [
      for (final l in state.results)
        ListingCard(
          listing: l,
          onOpened: (x) => context.read<WorkBloc>().add(ListingViewed(x.id)),
        ),
    ];
  }
}
