import 'package:flutter/material.dart';

/// Wraps a horizontally scrolling child and fades whichever edge still has
/// content behind it. Without this a clipped table just looks broken — the
/// last column is sliced mid-word with nothing saying "swipe for more".
class HorizontalScrollFade extends StatefulWidget {
  const HorizontalScrollFade({
    super.key,
    required this.builder,
    this.background = Colors.white,
    this.fadeWidth = 36,
  });

  /// Builds the scrollable. Must attach the supplied controller to it.
  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  /// Colour the edges fade into — match the surface behind the table.
  final Color background;

  final double fadeWidth;

  @override
  State<HorizontalScrollFade> createState() => _HorizontalScrollFadeState();
}

class _HorizontalScrollFadeState extends State<HorizontalScrollFade> {
  final ScrollController _controller = ScrollController();
  bool _atStart = true;
  bool _atEnd = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncEdges);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncEdges);
    _controller.dispose();
    super.dispose();
  }

  void _syncEdges() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    // 1px slack so rounding never leaves a sliver of fade at rest.
    final atStart = position.pixels <= position.minScrollExtent + 1;
    final atEnd = position.pixels >= position.maxScrollExtent - 1;
    if (atStart == _atStart && atEnd == _atEnd) return;
    setState(() {
      _atStart = atStart;
      _atEnd = atEnd;
    });
  }

  Widget _fade({required bool leading}) {
    return IgnorePointer(
      child: Container(
        width: widget.fadeWidth,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: leading ? Alignment.centerLeft : Alignment.centerRight,
            end: leading ? Alignment.centerRight : Alignment.centerLeft,
            colors: [widget.background, widget.background.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Content or viewport width can change without a scroll event.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncEdges());

    return Stack(
      children: [
        widget.builder(context, _controller),
        if (!_atStart)
          Positioned(left: 0, top: 0, bottom: 0, child: _fade(leading: true)),
        if (!_atEnd)
          Positioned(right: 0, top: 0, bottom: 0, child: _fade(leading: false)),
      ],
    );
  }
}
