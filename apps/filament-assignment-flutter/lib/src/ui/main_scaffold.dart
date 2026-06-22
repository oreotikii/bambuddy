import 'dart:async';

import 'package:floaty_nav_bar/floaty_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_model.dart';
import '../data/assignment_repository.dart';
import 'assign_screen.dart';
import 'design_effects.dart';
import 'home_screen.dart';
import 'scanner_sheet.dart';
import 'weigh_screen.dart';

/// Bottom-nav shell for the three primary surfaces (Status / Weigh / Assign),
/// replacing the original per-screen activities.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key, this.repository, this.scannerLauncher});

  final AssignmentRepository? repository;
  final CodeScannerLauncher? scannerLauncher;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final _weighKey = GlobalKey<WeighScreenState>();
  final _assignKey = GlobalKey<AssignScreenState>();
  int _index = 0;

  void _selectTab(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  void _scanWeighQr() {
    final state = _weighKey.currentState;
    if (state == null) return;
    unawaited(state.scanQr());
  }

  void _scanAssignQr() {
    final state = _assignKey.currentState;
    if (state == null) return;
    unawaited(state.scanQr());
  }

  FloatyActionButton _scanQrButton(
    ColorScheme cs, {
    required String heroTag,
    required VoidCallback onTap,
  }) {
    return FloatyActionButton(
      heroTag: heroTag,
      tooltip: 'Scan QR',
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      icon: Icon(Icons.qr_code_scanner, color: cs.onPrimary),
      onTap: onTap,
    );
  }

  Widget _tabIcon(
    ColorScheme cs, {
    required int index,
    required IconData selectedIcon,
    required IconData icon,
    required String tooltip,
  }) {
    final selected = _index == index;
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Icon(
          selected ? selectedIcon : icon,
          color: selected ? cs.onPrimary : cs.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final navSurface = Color.alphaBlend(
      cs.primary.withValues(alpha: 0.06),
      cs.surfaceContainerLowest,
    );
    final inactiveTabColor = Color.alphaBlend(
      cs.onSurface.withValues(alpha: 0.08),
      navSurface,
    );
    final selectedTabColor = Color.lerp(cs.primary, Colors.white, 0.08)!;

    return Scaffold(
      extendBody: true,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => context.read<AppModel>().pingActivity(),
        child: SmoothTabStage(
          index: _index,
          children: [
            const HomeScreen(),
            WeighScreen(
              key: _weighKey,
              repository: widget.repository,
              scannerLauncher: widget.scannerLauncher,
            ),
            AssignScreen(
              key: _assignKey,
              repository: widget.repository,
              scannerLauncher: widget.scannerLauncher,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _SpacedCircularFloatyNavBar(
        selectedTab: _index,
        height: 74,
        tabSpacing: 8,
        margin: const EdgeInsetsDirectional.only(top: 10, bottom: 18),
        backgroundColor: navSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.56),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.16),
            blurRadius: 28,
            spreadRadius: -6,
            offset: const Offset(0, 4),
          ),
        ],
        shape: const CircleShape(),
        tabs: [
          FloatyTab(
            isSelected: _index == 0,
            title: 'Status',
            icon: _tabIcon(
              cs,
              index: 0,
              selectedIcon: Icons.dashboard,
              icon: Icons.dashboard_outlined,
              tooltip: 'Status',
            ),
            selectedColor: selectedTabColor,
            unselectedColor: inactiveTabColor,
            onTap: () => _selectTab(0),
          ),
          FloatyTab(
            isSelected: _index == 1,
            title: 'Weigh',
            icon: _tabIcon(
              cs,
              index: 1,
              selectedIcon: Icons.scale,
              icon: Icons.scale_outlined,
              tooltip: 'Weigh',
            ),
            selectedColor: selectedTabColor,
            unselectedColor: inactiveTabColor,
            floatyActionButton: _scanQrButton(
              cs,
              heroTag: 'scan-qr-weigh',
              onTap: _scanWeighQr,
            ),
            onTap: () => _selectTab(1),
          ),
          FloatyTab(
            isSelected: _index == 2,
            title: 'Assign',
            icon: _tabIcon(
              cs,
              index: 2,
              selectedIcon: Icons.assignment_turned_in,
              icon: Icons.assignment_turned_in_outlined,
              tooltip: 'Assign',
            ),
            selectedColor: selectedTabColor,
            unselectedColor: inactiveTabColor,
            floatyActionButton: _scanQrButton(
              cs,
              heroTag: 'scan-qr-assign',
              onTap: _scanAssignQr,
            ),
            onTap: () => _selectTab(2),
          ),
        ],
        gap: 18,
      ),
    );
  }
}

class _SpacedCircularFloatyNavBar extends StatelessWidget {
  const _SpacedCircularFloatyNavBar({
    required this.tabs,
    required this.selectedTab,
    this.height = 60,
    this.gap = 16,
    this.tabSpacing = 8,
    this.margin = const EdgeInsetsDirectional.symmetric(vertical: 16),
    this.backgroundColor,
    this.boxShadow,
    this.shape = const CircleShape(),
  });

  final List<FloatyTab> tabs;
  final int selectedTab;
  final double height;
  final double gap;
  final double tabSpacing;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final FloatyShape shape;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actionButton = tabs[selectedTab].floatyActionButton;
    final tabChildren = <Widget>[];

    for (var index = 0; index < tabs.length; index += 1) {
      if (index > 0) {
        tabChildren.add(SizedBox(width: tabSpacing));
      }
      tabChildren.add(FloatyTabWidget(floatyTab: tabs[index], shape: shape));
    }

    return SafeArea(
      child: Container(
        height: height,
        margin: margin,
        alignment: Alignment.bottomCenter,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: ShapeDecoration(
                  color: backgroundColor ?? cs.surface,
                  shape: shape.shapeBorder,
                  shadows: boxShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: tabChildren,
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: actionButton == null
                  ? const SizedBox.shrink()
                  : SizedBox(width: gap),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              child: actionButton == null
                  ? const SizedBox.shrink()
                  : SizedBox(
                      height: actionButton.size,
                      width: actionButton.size,
                      child: FloatingActionButton(
                        shape: actionButton.shape ?? shape.shapeBorder,
                        backgroundColor:
                            actionButton.backgroundColor ?? cs.primary,
                        foregroundColor:
                            actionButton.foregroundColor ?? cs.onPrimary,
                        onPressed: actionButton.onTap,
                        heroTag: actionButton.heroTag,
                        autofocus: actionButton.autofocus,
                        clipBehavior: actionButton.clipBehavior,
                        enableFeedback: actionButton.enableFeedback,
                        focusColor: actionButton.focusColor,
                        hoverColor: actionButton.hoverColor,
                        splashColor: actionButton.splashColor,
                        tooltip: actionButton.tooltip,
                        mini: actionButton.mini,
                        focusNode: actionButton.focusNode,
                        isExtended: actionButton.isExtended,
                        key: ValueKey(actionButton.icon.hashCode),
                        materialTapTargetSize:
                            actionButton.materialTapTargetSize,
                        mouseCursor: actionButton.mouseCursor,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey(actionButton.icon.hashCode),
                            child: actionButton.icon,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
