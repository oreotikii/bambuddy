import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_villains/villain.dart';
import 'package:glass_kit/glass_kit.dart';

const appMotionDuration = Duration(milliseconds: 400);
const _tabMotionOffset = Offset(0, 0.012);
const _tabMotionCurve = Curves.easeOutCubic;

class CravVillainScreenTransition extends StatelessWidget {
  const CravVillainScreenTransition({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Villain(
      villainAnimation: VillainAnimation.fromBottom(
        relativeOffset: 0.035,
        to: appMotionDuration,
        curve: Curves.easeOutCubic,
      ),
      secondaryVillainAnimation: VillainAnimation.fade(
        to: appMotionDuration,
        curve: Curves.easeOutCubic,
      ),
      child: child,
    );
  }
}

class ConsoleGlassNavigation extends StatelessWidget {
  const ConsoleGlassNavigation({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final measuredWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width - 20;
          return GlassContainer.frostedGlass(
            height: 76,
            width: measuredWidth,
            borderRadius: BorderRadius.circular(18),
            blur: 14,
            frostedOpacity: 0.08,
            borderWidth: 1,
            gradient: LinearGradient(
              colors: [
                cs.surfaceContainerHigh.withValues(alpha: 0.82),
                cs.surfaceContainer.withValues(alpha: 0.58),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderColor: cs.outline.withValues(alpha: 0.74),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
            child: child,
          );
        },
      ),
    );
  }
}

class FrostedPanel extends StatelessWidget {
  const FrostedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
              gradient: LinearGradient(
                colors: [
                  cs.surfaceContainerHigh.withValues(alpha: 0.72),
                  cs.surfaceContainer.withValues(alpha: 0.46),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class SmoothTabStage extends StatelessWidget {
  const SmoothTabStage({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return IndexedStack(index: index, children: children);
    }

    final orderedIndexes = <int>[
      for (var i = 0; i < children.length; i += 1)
        if (i != index) i,
      if (index >= 0 && index < children.length) index,
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        for (final childIndex in orderedIndexes)
          _SmoothTabPane(
            key: ValueKey('smooth-tab-pane-$childIndex'),
            active: childIndex == index,
            child: children[childIndex],
          ),
      ],
    );
  }
}

class _SmoothTabPane extends StatelessWidget {
  const _SmoothTabPane({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeFocus(
        excluding: !active,
        child: ExcludeSemantics(
          excluding: !active,
          child: TickerMode(
            enabled: active,
            child: AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: appMotionDuration,
              curve: _tabMotionCurve,
              child: AnimatedSlide(
                offset: active ? Offset.zero : _tabMotionOffset,
                duration: appMotionDuration,
                curve: _tabMotionCurve,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
