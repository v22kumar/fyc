import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A self-advancing horizontal carousel with a dot indicator — the Home hero.
/// Auto-advances every [interval], pauses while the user drags, and resumes
/// after. Pure Flutter (`PageView`), no external package.
class DSCarousel extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double height;
  final Duration interval;
  final EdgeInsets itemPadding;

  const DSCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.height = 150,
    this.interval = const Duration(seconds: 5),
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  State<DSCarousel> createState() => _DSCarouselState();
}

class _DSCarouselState extends State<DSCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  void _startAuto() {
    _timer?.cancel();
    if (widget.itemCount <= 1) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.itemCount;
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification && n.dragDetails != null) {
                _timer?.cancel();
              } else if (n is ScrollEndNotification) {
                _startAuto();
              }
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.itemCount,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => Padding(
                padding: widget.itemPadding,
                child: widget.itemBuilder(context, i),
              ),
            ),
          ),
        ),
        if (widget.itemCount > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.itemCount, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : context.cBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
