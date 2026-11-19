import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// Shared pieces for the scroll-driven "film" pages (Green Makeover, Privé).

// Bouncing physics with damped flings, so one hard swipe can't skip a whole
// scene. Dragging stays 1:1 with the finger; only the momentum after you let
// go is reduced and capped.
class CinematicScrollPhysics extends BouncingScrollPhysics {
  final double flingFactor;
  const CinematicScrollPhysics({super.parent, this.flingFactor = 0.5});

  @override
  CinematicScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      CinematicScrollPhysics(parent: buildParent(ancestor), flingFactor: flingFactor);

  @override
  double get maxFlingVelocity => 3600;

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) =>
      super.createBallisticSimulation(position, velocity * flingFactor);
}

// A section [length] tall whose screen-sized frame stays pinned while you
// scroll through it. The builder gets progress t (0..1) and the pixels
// scrolled into the pin. Position comes from the scroll offset itself (the
// section's own scroll position is read from the viewport), so the frame is
// exact on every frame rather than one frame late.
class PinnedScene extends StatefulWidget {
  final double length;
  final ScrollController scroll;
  final Widget Function(double t, double px) builder;
  const PinnedScene({super.key, required this.length, required this.scroll, required this.builder});
  @override
  State<PinnedScene> createState() => _PinnedSceneState();
}

class _PinnedSceneState extends State<PinnedScene> {
  double? _start;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(_measure); });
  }

  void _measure() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final vp = RenderAbstractViewport.maybeOf(box);
    if (vp != null) _start = vp.getOffsetToReveal(box, 0).offset;
  }

  @override
  Widget build(BuildContext ctx) {
    final vh = MediaQuery.of(ctx).size.height;
    final travel = math.max(1.0, widget.length - vh);
    return SizedBox(
      height: widget.length,
      child: AnimatedBuilder(
        animation: widget.scroll,
        builder: (_, __) {
          if (_start == null) _measure();
          final off = widget.scroll.hasClients ? widget.scroll.offset : 0.0;
          final px = (off - (_start ?? 0)).clamp(0.0, travel);
          return Stack(children: [
            Positioned(
              top: px, left: 0, right: 0, height: vh,
              child: RepaintBoundary(child: widget.builder(px / travel, px)),
            ),
          ]);
        },
      ),
    );
  }
}
